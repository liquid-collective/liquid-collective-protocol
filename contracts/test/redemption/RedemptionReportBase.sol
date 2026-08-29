//SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.34;

import "forge-std/Test.sol";

import "../utils/LibImplementationUnbricker.sol";
import "../utils/RiverV1WithLegacyInit.sol";
import "../utils/UserFactory.sol";
import "../mocks/DepositContractMock.sol";

import "../../src/Allowlist.1.sol";
import "../../src/AttestationVerifier.1.sol";
import "../../src/ConsolidationCoverageFund.1.sol";
import "../../src/CoverageFund.1.sol";
import "../../src/ELFeeRecipient.1.sol";
import "../../src/ExternalConsolidationRecipientMapping.1.sol";
import "../../src/OperatorsRegistry.1.sol";
import "../../src/Oracle.1.sol";
import "../../src/RedeemManager.1.sol";
import "../../src/River.1.sol";
import "../../src/Withdraw.1.sol";

import "../../src/interfaces/IDepositDataBuffer.sol";
import "../../src/interfaces/IRedeemManager.1.sol";
import "../../src/interfaces/components/IOracleManager.1.sol";
import "../../src/libraries/BLS12_381.sol";
import "../../src/libraries/LibAllowlistMasks.sol";
import "../../src/state/river/ReportBounds.sol";
import "../../src/state/redeemManager/RateMarkStack.sol";
import "../../src/state/redeemManager/RedeemQueue.2.sol";
import "../../src/state/redeemManager/RedeemRequestAnchor.sol";
import "../../src/state/redeemManager/WithdrawalStack.sol";

/// @dev Concrete `RiverV1WithLegacyInit` so the fixture can `new` it. Production `RiverV1` no longer
///      ships `initRiverV1` / `_1` / `_2`, and the fixture bootstraps from genesis. The body is
///      deliberately EMPTY: this suite drives the RedeemManager entirely through real oracle reports,
///      so there is no test-only River surface at all.
contract RedemptionRiverV1 is RiverV1WithLegacyInit {}

/// @dev Minimal `IDepositDataBuffer`: the keeper submits a batch here and River fetches it back through
///      the AttestationVerifier when funding the consensus layer.
contract RedemptionDepositDataBuffer is IDepositDataBuffer {
    mapping(bytes32 => DepositObject) internal _batches;
    mapping(bytes32 => bool) internal _exists;

    function submitDepositData(bytes32 depositDataBufferId, DepositObject calldata batch) external {
        if (_exists[depositDataBufferId]) revert DepositDataBufferIdAlreadyExists(depositDataBufferId);
        _exists[depositDataBufferId] = true;
        DepositObject storage stored = _batches[depositDataBufferId];
        for (uint256 i = 0; i < batch.deposits.length; i++) {
            stored.deposits.push(batch.deposits[i]);
        }
        for (uint256 i = 0; i < batch.topUps.length; i++) {
            stored.topUps.push(batch.topUps[i]);
        }
        emit DepositDataSubmitted(depositDataBufferId, batch.deposits.length, batch.topUps.length);
    }

    function getDepositData(bytes32 depositDataBufferId) external view returns (DepositObject memory) {
        if (!_exists[depositDataBufferId]) revert DepositDataBufferIdNotFound(depositDataBufferId);
        return _batches[depositDataBufferId];
    }

    function getWriter() external pure returns (address) {
        return address(0);
    }

    function getAdmin() external pure returns (address) {
        return address(0);
    }
}

/// @title Redemption fulfillment test base, driven by real oracle reports
/// @notice Shared fixture for the redemption-fulfillment suites under contracts/test/redemption.
/// @dev The whole protocol is deployed and wired -- River, the Oracle, the OperatorsRegistry, the
///      Allowlist, Withdraw, the EL fee recipient, both coverage funds, the AttestationVerifier, the
///      external-consolidation recipient mapping and the deposit contract -- and EVERY input the
///      RedeemManager receives is produced by a real `oracle.reportConsensusLayerData` call travelling
///      the real path: quorum, epoch validity, report bounds, `_pullCLFunds`, the fee mint, the
///      exceeding-eth pull, `reportStoppedEarning` and `_reportWithdrawToRedeemManager`. Redeemers
///      acquire LsETH with real `river.deposit()` calls and open requests through the RedeemManager's
///      own allowlisted entry point.
///
/// @dev WHAT THE REPORT PATH LETS A TEST CHOOSE, and what it does not. This is the whole reason the
///      helpers below look the way they do:
///
///        * The pool rate is `_assetBalance() / totalSupply()`. It is not a variable, so `_reportRate`
///          solves for the `validatorsBalance` that lands the ratio on the requested figure, after
///          accounting for every other term the report moves (see `_solveValidatorsBalance`).
///        * A rate mark is priced at the rate in force BEFORE the report that pushes it
///          (LibOracleReporting L209-220), so a mark at rate m needs the pool already sitting at m --
///          i.e. one report to move the rate and a second to carry the delta. `_reportStoppedEarning`
///          therefore never moves the rate.
///        * A withdrawal event is priced at the rate in force AFTER the report
///          (`_reportWithdrawToRedeemManager`, L579-616), on both of its branches. The settlement rate
///          is never a free parameter; it is always the post-report pool rate.
///        * At most ONE mark and ONE withdrawal event per report, and at most one report per frame.
///          A frame here is 225 * 32 * 12 s, i.e. exactly one day, so every helper below warps.
///        * `_pullRedeemManagerExceedingEth` runs on every report that has headroom to the APR upper
///          bound, so the exceeding-eth buffer is returned to River by the NEXT report after the claim
///          that filled it. Assertions on the buffer are therefore always made between a claim and the
///          following report.
///
/// @dev TWO FIXTURE PARAMETERS DIFFER FROM MAINNET, both to make the states these suites are about
///      reachable at all rather than to bypass a check:
///        * `APR_UPPER_BOUND` / `RELATIVE_LOWER_BOUND` are opened up at initialization. Under mainnet
///          bounds a report may raise the pool by ~0.027% and lower it by 5%, so moving the rate from
///          1.00 to 1.05 would take ~183 frames and every scenario below would be hundreds of reports
///          long. The bounds are a rate-of-change guard on the oracle, not part of redemption
///          fulfilment; they are covered by contracts/test/Oracle.1.t.sol and the accounting suites.
///        * `GLOBAL_FEE` is 0. A non-zero fee mints shares to the collector partway through the report
///          (L360-362), which moves `totalSupply` between the bounds check and the withdrawal event and
///          makes the post-report rate a fixed point rather than a value a test can request. Fee
///          minting is covered by contracts/test/accounting.
abstract contract RedemptionReportBase is Test {
    // ─── consensus layer spec ─────────────────────────────────────────────────
    uint64 internal constant EPOCHS_PER_FRAME = 225;
    uint64 internal constant SLOTS_PER_EPOCH = 32;
    uint64 internal constant SECONDS_PER_SLOT = 12;
    uint64 internal constant EPOCHS_UNTIL_FINAL = 4;
    uint128 internal constant MAX_DAILY_NET = 3200 ether;
    uint128 internal constant MAX_DAILY_REL = 2000;

    /// @notice Zero, so no shares are minted to the collector partway through a report. See the note on
    ///         the contract.
    uint256 internal constant GLOBAL_FEE = 0;

    /// @notice Report bounds wide enough for a single report to take the pool anywhere in the band the
    ///         suites use (0.5x to 3x). See the note on the contract for why they are relaxed.
    uint256 internal constant APR_UPPER_BOUND = 1_000_000_000;
    uint256 internal constant RELATIVE_LOWER_BOUND = 10_000;

    /// @notice LsETH held by a non-redeeming holder from `setUp`, so the pool always has a supply and
    ///         a defined rate.
    /// @dev Also what keeps the rate exactly representable. River's conversions are exact rate
    ///      arithmetic only when `totalSupply` is a whole number of ether and the asset balance is
    ///      `(supply / 1e18) * rate`; a round ballast plus whole-ether request sizes keeps both true,
    ///      which is what lets the suites keep asserting exact wei against the real share math.
    /// @dev The whole ballast is pushed onto the CONSENSUS LAYER during `setUp`, and that is not
    ///      cosmetic. `_assetBalance()` is the reported CL balance plus River's ETH buffers, and only
    ///      the CL leg is a report input -- ETH sitting in a buffer cannot be reported away. A pool
    ///      whose value is all buffer therefore has a hard floor at a rate of 1.0 and could never be
    ///      slashed, so every scenario below that settles at 0.5, 0.6 or 0.95 needs the ballast on the
    ///      CL and needs it to outweigh the ETH the redeemers deposited.
    /// @dev Sized so that `POOL_BALLAST >= sum of every redeemer deposit` in the widest suite, which is
    ///      what makes a rate of 0.5 reachable: the floor is `deposits / (ballast + deposits)`.
    uint256 internal constant POOL_BALLAST = 32_768 ether;

    /// @notice Largest ETH a single initial deposit may carry, per `AttestationVerifierV1`.
    uint256 internal constant MAX_DEPOSIT_AMOUNT = 2048 ether;

    /// @notice Private key of the single root attester, whose signature funds the CL ballast.
    uint256 internal constant ROOT_ATTESTER_PK = 0xA1;

    // EIP-712 constants, matching DepositToConsensusLayerValidation
    bytes32 internal constant EIP712_DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    bytes32 internal constant NAME_HASH = keccak256("DepositToConsensusLayerValidation");
    bytes32 internal constant VERSION_HASH = keccak256("1");
    bytes32 internal constant ATTEST_TYPEHASH =
        keccak256("Attest(bytes32 depositDataBufferId,bytes32 depositRootHash)");

    // ─── contracts ────────────────────────────────────────────────────────────
    RedemptionRiverV1 internal river;
    RedeemManagerV1 internal redeemManager;
    AllowlistV1 internal allowlist;
    OracleV1 internal oracle;
    OperatorsRegistryV1 internal operatorsRegistry;
    ELFeeRecipientV1 internal elFeeRecipient;
    CoverageFundV1 internal coverageFund;
    ConsolidationCoverageFundV1 internal consolidationCoverageFund;
    WithdrawV1 internal withdraw;
    AttestationVerifierV1 internal attestationVerifier;
    ExternalConsolidationRecipientMappingV1 internal externalConsolidationRecipientMapping;
    RedemptionDepositDataBuffer internal depositBuffer;
    IDepositContract internal depositContract;

    UserFactory internal uf = new UserFactory();

    // ─── actors ───────────────────────────────────────────────────────────────
    address internal admin;
    address internal allowlistAdmin;
    address internal allowlistAllower;
    address internal allowlistDenier;
    address internal keeper;
    address internal consolidator;
    address internal oracleMember;
    address internal collector;
    address internal ballastHolder;

    // ─── report ghosts ────────────────────────────────────────────────────────
    // The report carries CUMULATIVE consensus-layer figures and River takes deltas, so the fixture has
    // to remember what it last reported.

    /// @custom:attribute Cumulative exited balance reported so far
    uint256 internal _cumExitedEth;
    /// @custom:attribute Cumulative skimmed balance reported so far
    uint256 internal _cumSkimmedEth;
    /// @custom:attribute Cumulative stopped-earning balance reported so far
    uint256 internal _cumStoppedEarningEth;
    /// @custom:attribute Cumulative deposited-and-activated ETH reported so far
    uint256 internal _cumActivatedEth;
    /// @custom:attribute Validator count reported so far. Non-decreasing, like the report requires.
    uint32 internal _reportedValidatorCount;

    /// @dev Kept for the suites that address the redeem queue by raw storage slot.
    bytes32 internal constant REDEEM_QUEUE_ID_SLOT = bytes32(uint256(keccak256("river.state.redeemQueue")) - 1);

    // ─── events (mirrored so the suites can `vm.expectEmit` them) ─────────────
    event RequestedRedeem(address indexed recipient, uint256 height, uint256 size, uint256 maxRedeemableEth, uint32 id);
    event ReportedWithdrawal(uint256 height, uint256 size, uint256 ethAmount, uint32 id);
    event ReportedStoppedEarning(uint256 height, uint256 amount, uint256 markedEth, uint32 id);
    event StoppedEarningExceededMarkableDemand(uint256 reportedLsETH, uint256 markedLsETH);
    event SetRateMarkFloor(uint256 floor);
    event SatisfiedRedeemRequest(
        uint32 indexed redeemRequestId,
        uint32 indexed withdrawalEventId,
        uint256 lsEthAmountSatisfied,
        uint256 ethAmountSatisfied,
        uint256 lsEthAmountRemaining,
        uint256 ethAmountExceeding
    );
    event ClaimedRedeemRequest(
        uint32 indexed redeemRequestId,
        address indexed recipient,
        uint256 ethAmount,
        uint256 lsEthAmount,
        uint256 remainingLsEthAmount
    );

    // ─── setUp ────────────────────────────────────────────────────────────────

    /// @notice Deploys and wires the whole protocol, then seeds the pool at a rate of exactly 1.0.
    /// @dev The RedeemManager is left at version 1 so the suites keep control of the stopped-earning
    ///      cutover: `_upgradeToV1_3` is what pins the rate mark floor, and several of them need a
    ///      pre-upgrade queue in place first.
    function setUp() public virtual {
        admin = makeAddr("admin");
        allowlistAdmin = makeAddr("allowlistAdmin");
        allowlistAllower = makeAddr("allowlistAllower");
        allowlistDenier = makeAddr("allowlistDenier");
        keeper = makeAddr("keeper");
        consolidator = makeAddr("consolidator");
        oracleMember = makeAddr("oracleMember");
        collector = makeAddr("collector");
        ballastHolder = makeAddr("ballastHolder");

        vm.warp(1_000_000);

        depositContract = new DepositContractMock();
        depositBuffer = new RedemptionDepositDataBuffer();
        river = new RedemptionRiverV1();
        redeemManager = new RedeemManagerV1();
        allowlist = new AllowlistV1();
        oracle = new OracleV1();
        operatorsRegistry = new OperatorsRegistryV1();
        elFeeRecipient = new ELFeeRecipientV1();
        coverageFund = new CoverageFundV1();
        consolidationCoverageFund = new ConsolidationCoverageFundV1();
        withdraw = new WithdrawV1();
        attestationVerifier = new AttestationVerifierV1();
        externalConsolidationRecipientMapping = new ExternalConsolidationRecipientMappingV1();

        LibImplementationUnbricker.unbrick(vm, address(river));
        LibImplementationUnbricker.unbrick(vm, address(redeemManager));
        LibImplementationUnbricker.unbrick(vm, address(allowlist));
        LibImplementationUnbricker.unbrick(vm, address(oracle));
        LibImplementationUnbricker.unbrick(vm, address(operatorsRegistry));
        LibImplementationUnbricker.unbrick(vm, address(elFeeRecipient));
        LibImplementationUnbricker.unbrick(vm, address(coverageFund));
        LibImplementationUnbricker.unbrick(vm, address(consolidationCoverageFund));
        LibImplementationUnbricker.unbrick(vm, address(withdraw));
        LibImplementationUnbricker.unbrick(vm, address(attestationVerifier));
        LibImplementationUnbricker.unbrick(vm, address(externalConsolidationRecipientMapping));

        allowlist.initAllowlistV1(allowlistAdmin, allowlistAllower);
        allowlist.initAllowlistV1_1(allowlistDenier);

        operatorsRegistry.initOperatorsRegistryV1(admin, address(river));
        redeemManager.initializeRedeemManagerV1(address(river));

        river.initRiverV1(
            address(depositContract),
            address(elFeeRecipient),
            withdraw.getCredentials(),
            address(oracle),
            admin,
            address(allowlist),
            address(operatorsRegistry),
            collector,
            GLOBAL_FEE
        );
        river.initRiverV1_1(
            address(redeemManager),
            EPOCHS_PER_FRAME,
            SLOTS_PER_EPOCH,
            SECONDS_PER_SLOT,
            0,
            EPOCHS_UNTIL_FINAL,
            APR_UPPER_BOUND,
            RELATIVE_LOWER_BOUND,
            MAX_DAILY_NET,
            MAX_DAILY_REL
        );
        river.initRiverV1_2();

        address[] memory rootAttesters = new address[](1);
        rootAttesters[0] = vm.addr(ROOT_ATTESTER_PK);
        address[] memory consolidationCommitteeAttesters = new address[](1);
        consolidationCommitteeAttesters[0] = makeAddr("consolidationCommitteeAttester");
        attestationVerifier.initAttestationVerifierV1(
            address(river), address(depositBuffer), rootAttesters, 1, bytes4(0), consolidationCommitteeAttesters, 1
        );

        externalConsolidationRecipientMapping.initExternalConsolidationRecipientMappingV1(address(river));
        consolidationCoverageFund.initConsolidationCoverageFundV1(address(river));

        vm.prank(admin);
        river.initRiverV1_3(
            withdraw.getCredentials(),
            address(consolidationCoverageFund),
            address(attestationVerifier),
            address(externalConsolidationRecipientMapping),
            consolidator
        );

        withdraw.initializeWithdrawV1(address(river));
        elFeeRecipient.initELFeeRecipientV1(address(river));
        coverageFund.initCoverageFundV1(address(river));
        oracle.initOracleV1(
            address(river),
            admin,
            EPOCHS_PER_FRAME,
            SLOTS_PER_EPOCH,
            SECONDS_PER_SLOT,
            0,
            APR_UPPER_BOUND,
            RELATIVE_LOWER_BOUND
        );

        vm.startPrank(admin);
        river.setCoverageFund(address(coverageFund));
        river.setKeeper(keeper);
        oracle.addMember(oracleMember, 1);
        // Two operators, so `reportCLETH` has a non-empty array of the right length and
        // `reportExitedETH` has somewhere to attribute the exits every settlement report carries.
        operatorsRegistry.addOperator("OperatorOne", makeAddr("operatorOne"));
        operatorsRegistry.addOperator("OperatorTwo", makeAddr("operatorTwo"));
        vm.stopPrank();

        // EIP-2537 is unavailable under Foundry, so the BLS leg of the attestation is mocked. Everything
        // else about the deposit below -- the quorum, the EIP-712 digest, the deposit root, the buffer
        // round-trip, the funded-ETH accounting -- runs for real.
        vm.mockCall(
            address(attestationVerifier),
            abi.encodeWithSelector(attestationVerifier.verifyBLSDeposit.selector),
            bytes("")
        );

        // Seed the pool. The first deposit into an empty pool mints one share per wei, so this lands the
        // rate on exactly 1.0 with a whole-ether supply.
        _allowlistUser(ballastHolder);
        vm.deal(ballastHolder, POOL_BALLAST);
        vm.prank(ballastHolder);
        river.deposit{value: POOL_BALLAST}();
        assertEq(river.totalSupply(), POOL_BALLAST, "fixture: ballast must mint one share per wei");

        _fundConsensusLayerWithBallast();
        assertEq(_poolRate(), 1e18, "fixture: the seeded pool must sit at a rate of exactly 1.0");
        assertEq(
            river.getLastConsensusLayerReport().validatorsBalance,
            POOL_BALLAST,
            "fixture: the whole ballast must end up on the consensus layer"
        );
    }

    /// @notice Moves the whole ballast onto the consensus layer, so the pool has a CL leg that a report
    ///         can mark down. See the note on `POOL_BALLAST` for why that matters.
    /// @dev Three steps, all of them the real path: a report to commit the deposit buffer, an attested
    ///      keeper deposit to hand the ETH to the deposit contract, and a report confirming activation.
    function _fundConsensusLayerWithBallast() internal {
        // 1. commit the deposit buffer, which is what `depositToConsensusLayerWithAttestation` spends
        _reportRate(1e18);
        assertEq(river.getCommittedBalance(), POOL_BALLAST, "fixture: the ballast must be fully committed");

        // 2. one batch of initial deposits, each carrying at most the 2048 ether a single 0x02 validator
        //    may be funded with. Every pubkey is distinct, which the deposit path enforces.
        uint256 validatorCount = POOL_BALLAST / MAX_DEPOSIT_AMOUNT;
        IDepositDataBuffer.Deposit[] memory deposits = new IDepositDataBuffer.Deposit[](validatorCount);
        for (uint256 i = 0; i < validatorCount; ++i) {
            deposits[i] = IDepositDataBuffer.Deposit({
                pubkey: abi.encodePacked(sha256(abi.encode("redemption-ballast-pubkey", i)), bytes16(0)),
                signature: abi.encodePacked(
                    sha256(abi.encode("redemption-ballast-sig-a", i)),
                    sha256(abi.encode("redemption-ballast-sig-b", i)),
                    bytes32(0)
                ),
                amount: MAX_DEPOSIT_AMOUNT,
                operatorIdx: 0,
                depositY: BLS12_381.DepositY({
                    pubkeyY: BLS12_381.Fp({a: bytes32(i + 1), b: bytes32(0)}),
                    signatureY: BLS12_381.Fp2({c0_a: bytes32(0), c0_b: bytes32(0), c1_a: bytes32(0), c1_b: bytes32(0)})
                })
            });
        }
        IDepositDataBuffer.DepositObject memory batch;
        batch.deposits = deposits;

        bytes32 bufferId = keccak256(abi.encode(batch));
        depositBuffer.submitDepositData(bufferId, batch);
        bytes32 rootHash = depositContract.get_deposit_root();

        bytes32 domainSeparator =
            keccak256(abi.encode(EIP712_DOMAIN_TYPEHASH, NAME_HASH, VERSION_HASH, block.chainid, address(river)));
        bytes32 structHash = keccak256(abi.encode(ATTEST_TYPEHASH, bufferId, rootHash));
        (uint8 v, bytes32 r, bytes32 s) =
            vm.sign(ROOT_ATTESTER_PK, keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash)));
        bytes[] memory signatures = new bytes[](1);
        signatures[0] = abi.encodePacked(r, s, v);

        vm.prank(keeper);
        river.depositToConsensusLayerWithAttestation(bufferId, rootHash, signatures);

        // 3. the oracle confirms the activation, which retires the in-flight ETH and puts the whole
        //    ballast into the reported consensus-layer balance
        _reportedValidatorCount = uint32(validatorCount);
        _report(
            ReportParams({
                targetRate: 1e18,
                exitedEth: 0,
                stoppedEarningEth: 0,
                activatedEth: POOL_BALLAST,
                rebalance: false,
                slashingContainment: false
            })
        );
    }

    // ─── the report driver ────────────────────────────────────────────────────

    /// @notice Everything a test can choose about one oracle report.
    struct ReportParams {
        /// @custom:attribute The pool rate the report must land on, i.e. the ETH value of 1 LsETH once
        ///                   the report has been applied. Prices the withdrawal event, if any.
        uint256 targetRate;
        /// @custom:attribute New exited ETH swept from the consensus layer this interval. Lands in
        ///                   `BalanceToRedeem` and is what funds the withdrawal event.
        uint256 exitedEth;
        /// @custom:attribute New principal that crossed exit_epoch this interval. Becomes the ETH leg of
        ///                   `reportStoppedEarning`; the LsETH leg is derived by River at the PRE-report
        ///                   rate.
        uint256 stoppedEarningEth;
        /// @custom:attribute Deposited ETH that activated on the consensus layer this interval. Retires
        ///                   the matching `InFlightDeposit`.
        uint256 activatedEth;
        /// @custom:attribute The `rebalanceDepositToRedeemMode` flag
        bool rebalance;
        /// @custom:attribute The `slashingContainmentMode` flag
        bool slashingContainment;
    }

    /// @notice Warps to the next reportable frame, funds the withdrawal contract with the swept ETH and
    ///         submits one oracle report.
    /// @dev The single funnel every other helper goes through, so there is exactly one place where a
    ///      report is built and exactly one place that has to stay in step with the pipeline.
    function _report(ReportParams memory p) internal {
        uint256 epoch = river.getExpectedEpochId();
        uint256 finalityTimestamp = uint256(SECONDS_PER_SLOT) * SLOTS_PER_EPOCH * (epoch + EPOCHS_UNTIL_FINAL) + 1;
        if (block.timestamp < finalityTimestamp) {
            vm.warp(finalityTimestamp);
        }

        // The swept ETH has to actually be on the withdrawal contract: `_pullCLFunds` reverts unless
        // `pullEth` hands River exactly the reported skimmed + exited delta.
        if (p.exitedEth > 0) {
            vm.deal(address(withdraw), address(withdraw).balance + p.exitedEth);
        }

        _cumExitedEth += p.exitedEth;
        _cumStoppedEarningEth += p.stoppedEarningEth;
        _cumActivatedEth += p.activatedEth;

        uint256[] memory exitedPerOperator = new uint256[](3);
        exitedPerOperator[0] = _cumExitedEth;
        exitedPerOperator[1] = _cumExitedEth;
        uint256[] memory activeCLETHPerOperator = new uint256[](2);

        IOracleManagerV1.ConsensusLayerReport memory report;
        report.epoch = epoch;
        report.validatorsBalance = _solveValidatorsBalance(p.targetRate, p.exitedEth, p.activatedEth);
        report.validatorsSkimmedBalance = _cumSkimmedEth;
        report.validatorsExitedBalance = _cumExitedEth;
        report.validatorsStoppedEarningBalance = _cumStoppedEarningEth;
        report.totalDepositedActivatedETH = _cumActivatedEth;
        report.validatorsCount = _reportedValidatorCount;
        report.exitedETHPerOperator = exitedPerOperator;
        activeCLETHPerOperator[0] = report.validatorsBalance;
        report.activeCLETHPerOperator = activeCLETHPerOperator;
        report.rebalanceDepositToRedeemMode = p.rebalance;
        report.slashingContainmentMode = p.slashingContainment;

        vm.prank(oracleMember);
        oracle.reportConsensusLayerData(report);
    }

    /// @notice Solves for the `validatorsBalance` that lands the post-report pool rate on `targetRate`.
    /// @dev The pool rate is `_assetBalance() / totalSupply()` and `_assetBalance()` is the reported
    ///      consensus-layer balance plus every off-CL term. Only the CL leg is a report input, so the
    ///      others have to be projected forward across the report:
    ///        + `exitedEth`, credited to `BalanceToRedeem` by `_pullCLFunds`
    ///        + the exceeding-eth buffer, credited to `BalanceToDeposit` by `_pullRedeemManagerExceedingEth`
    ///        - `activatedEth`, retired from `InFlightDeposit` once the oracle confirms activation
    ///      Nothing else moves: the EL fee recipient and both coverage funds are empty in this fixture
    ///      and the fee mint is disabled. `_skimExcessBalanceToRedeem` and `_commitBalanceToDeposit` only
    ///      shuffle terms between buffers that both count towards the asset balance.
    /// @dev The `require` below is the fixture telling a test that the rate it asked for is unreachable
    ///      rather than silently reporting something else. It fires when the requested rate would value
    ///      the pool below the ETH River is holding in its own buffers, which no consensus-layer report
    ///      can express: buffer ETH cannot be slashed. See the note on `POOL_BALLAST`.
    function _solveValidatorsBalance(uint256 targetRate, uint256 exitedEth, uint256 activatedEth)
        internal
        view
        returns (uint256)
    {
        uint256 targetAssetBalance = (river.totalSupply() * targetRate) / 1e18;
        uint256 offConsensusLayer = river.totalUnderlyingSupply()
            - river.getLastConsensusLayerReport().validatorsBalance + exitedEth
            + redeemManager.getBufferedExceedingEth() - activatedEth;
        require(targetAssetBalance >= offConsensusLayer, "report: target rate is below the off-CL asset floor");
        return targetAssetBalance - offConsensusLayer;
    }

    /// @notice One report whose only effect is to move the pool rate.
    function _reportRate(uint256 rate) internal {
        _report(
            ReportParams({
                targetRate: rate,
                exitedEth: 0,
                stoppedEarningEth: 0,
                activatedEth: 0,
                rebalance: false,
                slashingContainment: false
            })
        );
        assertEq(_poolRate(), rate, "report: the pool did not land on the requested rate");
    }

    /// @notice One report that moves the pool rate as close to `rate` as the live supply allows.
    /// @dev The non-asserting form of `_reportRate`, for the fuzzed suites. `_reportRate` can promise an
    ///      exact rate because every position it is used with is a whole number of ether at a rate with
    ///      at most two decimals, so `(supply / 1e18) * rate` divides. A fuzzer draws neither, so the
    ///      achieved rate can sit a wei below the requested one; the properties those suites assert are
    ///      inequalities and differentials that do not care, and they read the achieved rate back from
    ///      River rather than assuming it.
    /// @return The pool rate the report actually landed on.
    function _reportRateLoose(uint256 rate) internal returns (uint256) {
        _report(
            ReportParams({
                targetRate: rate,
                exitedEth: 0,
                stoppedEarningEth: 0,
                activatedEth: 0,
                rebalance: false,
                slashingContainment: false
            })
        );
        return _poolRate();
    }

    /// @notice One report carrying a stopped-earning delta of `stoppedEarningEth`, at the live rate.
    /// @dev Deliberately does not move the rate. A mark is priced at the PRE-report rate, so moving the
    ///      rate in the same report would price the mark at the rate the pool is leaving rather than the
    ///      one the test asked for.
    function _reportStoppedEarning(uint256 stoppedEarningEth) internal {
        _report(
            ReportParams({
                targetRate: _poolRate(),
                exitedEth: 0,
                stoppedEarningEth: stoppedEarningEth,
                activatedEth: 0,
                rebalance: false,
                slashingContainment: false
            })
        );
    }

    /// @notice One report that sweeps `exitedEth` of exited principal at a pool rate of `rate`.
    /// @dev The low-level form. `_reportWithdrawToRedeemManager` decides the resulting event: when the
    ///      demand outruns the swept ETH the event is `{withdrawnEth: exitedEth, amount:
    ///      sharesFromUnderlyingBalance(exitedEth)}`, otherwise it settles the whole demand at the rate.
    /// @return withdrawnEth The ETH the resulting withdrawal event carries, or 0 if none was pushed.
    function _reportWithdrawEth(uint256 exitedEth, uint256 rate) internal returns (uint256 withdrawnEth) {
        uint256 eventCountBefore = redeemManager.getWithdrawalEventCount();
        _report(
            ReportParams({
                targetRate: rate,
                exitedEth: exitedEth,
                stoppedEarningEth: 0,
                activatedEth: 0,
                rebalance: false,
                slashingContainment: false
            })
        );
        if (redeemManager.getWithdrawalEventCount() == eventCountBefore) {
            return 0;
        }
        return redeemManager.getWithdrawalEventDetails(uint32(eventCountBefore)).withdrawnEth;
    }

    /// @dev Pushes a withdrawal event settling `lsETH` of demand, funded at `settlementRate`.
    function _reportWithdraw(uint256 lsETH, uint256 settlementRate) internal returns (uint256 withdrawnEth) {
        uint256 eventCountBefore = redeemManager.getWithdrawalEventCount();
        _reportWithdrawEth(applyRate(lsETH, settlementRate), settlementRate);
        assertEq(
            redeemManager.getWithdrawalEventCount(), eventCountBefore + 1, "report: no withdrawal event was pushed"
        );
        WithdrawalStack.WithdrawalEvent memory pushed =
            redeemManager.getWithdrawalEventDetails(uint32(eventCountBefore));
        assertEq(pushed.amount, lsETH, "report: the withdrawal event settled a different amount of demand");
        return pushed.withdrawnEth;
    }

    /// @dev Settles `lsETH` of demand at `settlementRate` and claims request `id` in full.
    function _settleAndClaim(uint32 id, uint256 lsETH, uint256 settlementRate) internal returns (uint256 received) {
        _reportWithdraw(lsETH, settlementRate);
        return _claim(id);
    }

    /// @notice Asserts that the RedeemManager emitted nothing since the last `vm.recordLogs()`.
    /// @dev The report-path replacement for `assertEq(vm.getRecordedLogs().length, 0)`. A report emits a
    ///      dozen or so logs of its own -- the oracle's variant vote, River's buffer bookkeeping, the
    ///      operators registry's exited-ETH updates -- so the absence of a mark can no longer be stated
    ///      as the absence of logs. Scoped to the RedeemManager instead, which is tighter than the
    ///      original assertion rather than looser: a report that pushes no withdrawal event and pulls no
    ///      exceeding eth leaves `reportStoppedEarning` as the only thing that could make it speak.
    function _assertRedeemManagerSilent(string memory reason) internal {
        Vm.Log[] memory logs = vm.getRecordedLogs();
        for (uint256 i = 0; i < logs.length; ++i) {
            assertTrue(logs[i].emitter != address(redeemManager), reason);
        }
    }

    // ─── allowlist helpers ────────────────────────────────────────────────────

    /// @dev Grants the redeem and deposit permissions to `user`.
    function _allowlistUser(address user) internal {
        address[] memory accounts = new address[](1);
        accounts[0] = user;
        uint256[] memory permissions = new uint256[](1);
        permissions[0] = LibAllowlistMasks.REDEEM_MASK | LibAllowlistMasks.DEPOSIT_MASK;

        vm.prank(allowlistAllower);
        allowlist.setAllowPermissions(accounts, permissions);
    }

    function _generateAllowlistedUser(uint256 _salt) internal returns (address) {
        address user = uf._new(_salt);
        _allowlistUser(user);
        return user;
    }

    function _denyUser(address user) internal {
        address[] memory accounts = new address[](1);
        accounts[0] = user;
        uint256[] memory permissions = new uint256[](1);
        permissions[0] = LibAllowlistMasks.DENY_MASK;

        vm.prank(allowlistDenier);
        allowlist.setDenyPermissions(accounts, permissions);
    }

    // ─── rate helpers ─────────────────────────────────────────────────────────

    function applyRate(uint256 amount, uint256 rate) internal pure returns (uint256) {
        return (amount * rate) / 1e18;
    }

    /// @dev River's live pool rate, i.e. the ETH value of 1 LsETH.
    function _poolRate() internal view returns (uint256) {
        return river.underlyingBalanceFromShares(1e18);
    }

    // ─── request helpers ──────────────────────────────────────────────────────

    /// @dev Opens a redeem request of `amount` LsETH for `user` at the current pool rate.
    /// @dev The LsETH is bought with a real deposit. `_mintShares` hands back `floor(eth / rate)`, so
    ///      the ETH sent is the exact price of the position and the mint is asserted to be exact --
    ///      every size these suites use is a whole number of ether at a rate with at most two decimals,
    ///      or any size at all at a rate of exactly 1.0, and both divide.
    function _openRequest(address user, uint256 amount) internal returns (uint32 id) {
        uint256 cost = applyRate(amount, _poolRate());
        uint256 balanceBefore = river.balanceOf(user);
        vm.deal(user, cost);
        vm.prank(user);
        river.deposit{value: cost}();
        assertEq(
            river.balanceOf(user) - balanceBefore, amount, "openRequest: the deposit did not mint the exact position"
        );

        vm.prank(user);
        river.approve(address(redeemManager), amount);
        vm.prank(user);
        id = redeemManager.requestRedeem(amount, user);

        _alignSupplyToWholeEther();
    }

    /// @dev Opens a redeem request for as much LsETH as `targetAmount` worth of ETH actually buys at the
    ///      live rate, which is `targetAmount` itself whenever the numbers divide and a wei or two less
    ///      when they do not.
    /// @dev The non-asserting form of `_openRequest`, for the fuzzed suites: a deposit can only ever buy
    ///      `floor(eth / rate)` shares, so an exact position is unreachable at a fuzzed rate. The caller
    ///      gets the position that was actually opened and asserts against that.
    /// @return id The new request's id
    /// @return actualAmount The LsETH the request was opened for
    function _openRequestLoose(address user, uint256 targetAmount) internal returns (uint32 id, uint256 actualAmount) {
        uint256 cost = applyRate(targetAmount, _poolRate());
        if (cost == 0) {
            cost = 1;
        }
        vm.deal(user, cost);
        vm.prank(user);
        river.deposit{value: cost}();

        actualAmount = river.balanceOf(user);
        require(actualAmount > 0, "openRequestLoose: the deposit bought no shares");
        vm.prank(user);
        river.approve(address(redeemManager), actualAmount);
        vm.prank(user);
        id = redeemManager.requestRedeem(actualAmount, user);
    }

    /// @notice Tops the share supply back up to a whole number of ether, on the ballast holder.
    /// @dev River's conversions are exact rate arithmetic only while `totalSupply` is a whole number of
    ///      ether: `_reportRate` lands the asset balance on `(supply / 1e18) * rate`, and that division
    ///      is exact for any rate with at most 18 decimals precisely when the supply is. A dust-sized
    ///      request -- the 1, 2 and 3 wei positions the rounding suites are built on -- knocks the supply
    ///      off that boundary and leaves every subsequent rate a wei short of the figure the test asked
    ///      for. Topping up restores it.
    /// @dev A real deposit, like every other position in these suites, so it dilutes nobody: the ETH it
    ///      adds to the pool is exactly what the shares it mints are worth at the live rate. Only called
    ///      from `_openRequest`, and only ever a no-op or a sub-ether top-up.
    function _alignSupplyToWholeEther() internal {
        uint256 remainder = river.totalSupply() % 1e18;
        if (remainder == 0) {
            return;
        }
        uint256 topUp = 1e18 - remainder;
        uint256 cost = applyRate(topUp, _poolRate());
        vm.deal(ballastHolder, cost);
        vm.prank(ballastHolder);
        river.deposit{value: cost}();
        assertEq(river.totalSupply() % 1e18, 0, "alignSupply: the top-up did not land on a whole ether");
    }

    /// @dev Puts the contract in the state a live deployment is in just before the stopped-earning
    ///      upgrade. `setUp` only runs initializeRedeemManagerV1, leaving the version at 1, whereas
    ///      mainnet is already at 2.
    /// @dev The version is poked rather than reached by calling initializeRedeemManagerV1_2, because
    ///      RedeemQueueV1 and RedeemQueueV2 share the storage slot
    ///      keccak256("river.state.redeemQueue") - 1. Its migration re-interprets that array in place
    ///      and is only safe because init(1) runs it exactly once, before any V2 request exists.
    function _pokeVersionTo(uint256 version) internal {
        vm.store(address(redeemManager), bytes32(uint256(keccak256("river.state.version")) - 1), bytes32(version));
    }

    function _upgradeToV1_3() internal {
        _pokeVersionTo(2);
        redeemManager.initializeRedeemManagerV1_3();
    }

    /// @dev Erases the request-time anchor of `id`, which is how a request that predates the
    ///      stopped-earning upgrade looks on a live deployment: no anchor, so the legacy pro-rata cap
    ///      applies and rate marks are ignored for it.
    function _stripAnchor(uint32 id) internal {
        bytes32 anchorSlot =
            keccak256(abi.encode(uint256(id), bytes32(uint256(keccak256("river.state.redeemRequestAnchor")) - 1)));
        vm.store(address(redeemManager), anchorSlot, bytes32(0));
        vm.store(address(redeemManager), bytes32(uint256(anchorSlot) + 1), bytes32(0));
    }

    // ─── claim helpers ────────────────────────────────────────────────────────

    /// @dev Claims request `id` against the withdrawal event that currently satisfies it and returns
    ///      the ETH the recipient received.
    function _claim(uint32 id) internal returns (uint256 received) {
        uint32[] memory ids = new uint32[](1);
        ids[0] = id;
        int64[] memory resolved = redeemManager.resolveRedeemRequests(ids);
        uint32[] memory eventIds = new uint32[](1);
        eventIds[0] = uint32(uint64(resolved[0]));

        address recipient = redeemManager.getRedeemRequestDetails(id).recipient;
        uint256 balanceBefore = recipient.balance;
        redeemManager.claimRedeemRequests(ids, eventIds);
        return recipient.balance - balanceBefore;
    }

    /// @dev Claims request `id` with an explicit starting withdrawal event and recursion depth, for
    ///      the cases that need the walk truncated part-way.
    function _claimWithDepth(uint32 id, uint32 withdrawalEventId, uint16 depth) internal returns (uint256 received) {
        uint32[] memory ids = new uint32[](1);
        ids[0] = id;
        uint32[] memory eventIds = new uint32[](1);
        eventIds[0] = withdrawalEventId;

        address recipient = redeemManager.getRedeemRequestDetails(id).recipient;
        uint256 balanceBefore = recipient.balance;
        redeemManager.claimRedeemRequests(ids, eventIds, true, depth);
        return recipient.balance - balanceBefore;
    }

    // ─── axis readers ─────────────────────────────────────────────────────────

    /// @dev The first LsETH position not yet covered by any rate mark.
    function _markCursor() internal view returns (uint256) {
        uint256 count = redeemManager.getRateMarkCount();
        if (count == 0) {
            return 0;
        }
        RateMarkStack.RateMark memory last = redeemManager.getRateMarkDetails(uint32(count - 1));
        return last.height + last.amount;
    }

    /// @dev The amount of LsETH demand settled by withdrawal events so far.
    function _settledHeight() internal view returns (uint256) {
        uint256 count = redeemManager.getWithdrawalEventCount();
        if (count == 0) {
            return 0;
        }
        WithdrawalStack.WithdrawalEvent memory last = redeemManager.getWithdrawalEventDetails(uint32(count - 1));
        return last.height + last.amount;
    }

    receive() external payable {}
}
