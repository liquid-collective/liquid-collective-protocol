// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "forge-std/Test.sol";

import "../utils/BytesGenerator.sol";
import "../utils/LibImplementationUnbricker.sol";
import "../mocks/DepositContractMock.sol";

import "../../src/River.1.sol";
import "../../src/AttestationVerifier.1.sol";
import "../../src/Oracle.1.sol";
import "../../src/OperatorsRegistry.1.sol";
import "../../src/Allowlist.1.sol";
import "../../src/ELFeeRecipient.1.sol";
import "../../src/CoverageFund.1.sol";
import "../../src/RedeemManager.1.sol";
import "../../src/Withdraw.1.sol";
import "../../src/ConsolidationManager.1.sol";
import "../../src/DepositExecutor.sol";
import "../../src/FundingDeltasBuilder.sol";
import "../../src/ExternalConsolidationRecipientMapping.sol";
import "../../src/RiverV1_3Migration.sol";

import "../../src/interfaces/IOperatorRegistry.1.sol";
import "../../src/interfaces/IDepositDataBuffer.sol";
import "../../src/interfaces/components/IOracleManager.1.sol";
import "../../src/libraries/BLS12_381.sol";
import "../../src/libraries/LibAllowlistMasks.sol";
import "../../src/state/river/CLSpec.sol";
import "../../src/state/river/DailyCommittableLimits.sol";
import "../../src/state/river/ReportBounds.sol";
import "../../src/state/operatorsRegistry/Operators.3.sol";

// -----------------------------------------------------------------------
// Mock DepositDataBuffer — stores batches by ID for accounting harness deposits
// -----------------------------------------------------------------------

contract AccountingMockDepositDataBuffer is IDepositDataBuffer {
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

/// @dev Test-only OperatorsRegistry subclass exposing raw exited ETH initialization.
contract AccountingTestOperatorsRegistry is OperatorsRegistryV1 {
    function sudoSetRawExitedETH(uint256[] memory value) external {
        OperatorsV3.setRawExitedETH(value);
    }
}

abstract contract AccountingHarnessBase is Test, BytesGenerator {
    // ─── protocol constants ───────────────────────────────────────────────────
    uint64 internal constant EPOCHS_PER_FRAME = 225;
    uint64 internal constant SLOTS_PER_EPOCH = 32;
    uint64 internal constant SECONDS_PER_SLOT = 12;
    uint64 internal constant EPOCHS_UNTIL_FINAL = 4;
    uint256 internal constant DEPOSIT_SIZE = 32 ether;
    uint128 internal constant MAX_DAILY_NET = 3200 ether;
    uint128 internal constant MAX_DAILY_REL = 2000;
    bytes32 internal constant VERSION_SLOT = bytes32(uint256(keccak256("river.state.version")) - 1);
    bytes32 internal constant ADMINISTRATOR_ADDRESS_SLOT =
        bytes32(uint256(keccak256("river.state.administratorAddress")) - 1);
    bytes32 internal constant BALANCE_TO_DEPOSIT_SLOT = bytes32(uint256(keccak256("river.state.balanceToDeposit")) - 1);
    bytes32 internal constant COMMITTED_BALANCE_SLOT = bytes32(uint256(keccak256("river.state.committedBalance")) - 1);
    bytes32 internal constant DEPOSIT_CONTRACT_ADDRESS_SLOT =
        bytes32(uint256(keccak256("river.state.depositContractAddress")) - 1);
    bytes32 internal constant IN_FLIGHT_DEPOSIT_SLOT = bytes32(uint256(keccak256("river.state.inFlightDeposit")) - 1);
    bytes32 internal constant OPERATORS_REGISTRY_ADDRESS_SLOT =
        bytes32(uint256(keccak256("river.state.operatorsRegistryAddress")) - 1);
    bytes32 internal constant REDEEM_MANAGER_ADDRESS_SLOT =
        bytes32(uint256(keccak256("river.state.redeemManagerAddress")) - 1);

    // ─── contracts ────────────────────────────────────────────────────────────
    RiverV1 internal river;
    OracleV1 internal oracle;
    AccountingTestOperatorsRegistry internal operatorsRegistry;
    AllowlistV1 internal allowlist;
    ELFeeRecipientV1 internal elFeeRecipient;
    CoverageFundV1 internal coverageFund;
    RedeemManagerV1 internal redeemManager;
    WithdrawV1 internal withdraw;
    IDepositContract internal depositContract;
    AccountingMockDepositDataBuffer internal depositBuffer;
    AttestationVerifierV1 internal attestationVerifier;
    ConsolidationManagerV1 internal consolidationManager;
    DepositExecutor internal depositExecutor;
    FundingDeltasBuilder internal fundingDeltasBuilder;
    RiverV1_3Migration internal migrationHelper;
    ExternalConsolidationRecipientMappingV1 internal externalConsolidationRecipientMapping;

    /// @dev Monotonic counter mixed into pubkey/signature generation in `_makeDepositObjects`.
    ///      Without it, two batches built in the same block with the same `(i, opIdx)` produce
    ///      identical pubkeys, which collides with the on-chain `PubkeyAlreadyFunded` guard
    ///      enforced inside `AttestationVerifier.fetchAndValidateDeposits()` (initial-deposit branch).
    uint256 internal _depositBatchNonce;

    // ─── attestation ──────────────────────────────────────────────────────────
    uint256 internal constant ROOT_ATTESTER_PK_1 = 0xA1;
    uint256 internal constant ROOT_ATTESTER_PK_2 = 0xA2;
    uint256 internal constant ROOT_ATTESTER_PK_3 = 0xA3;
    address internal rootAttester1;
    address internal rootAttester2;
    address internal rootAttester3;

    // EIP-712 constants (must match DepositToConsensusLayerValidation)
    bytes32 internal constant EIP712_DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    bytes32 internal constant NAME_HASH = keccak256("DepositToConsensusLayerValidation");
    bytes32 internal constant VERSION_HASH = keccak256("1");
    bytes32 internal constant ATTEST_TYPEHASH =
        keccak256("Attest(bytes32 depositDataBufferId,bytes32 depositRootHash)");

    // ─── actors ───────────────────────────────────────────────────────────────
    address internal admin;
    address internal allower;
    address internal keeper;
    address internal consolidator;
    address internal oracleMember;
    address internal operatorOneAddr;
    address internal operatorTwoAddr;

    uint256 internal operatorOneIndex;
    uint256 internal operatorTwoIndex;

    // ─── test helpers ─────────────────────────────────────────────────────────
    uint256 private _fundUserCounter;
    /// @dev Tracks total ETH deposited by users into the river (independent of contract storage).
    uint256 internal _simTotalUserDeposited;

    // ─── setUp ────────────────────────────────────────────────────────────────
    function setUp() public virtual {
        admin = makeAddr("admin");
        allower = makeAddr("allower");
        keeper = makeAddr("keeper");
        consolidator = makeAddr("consolidator");
        oracleMember = makeAddr("oracleMember");
        operatorOneAddr = makeAddr("operatorOne");
        operatorTwoAddr = makeAddr("operatorTwo");

        rootAttester1 = vm.addr(ROOT_ATTESTER_PK_1);
        rootAttester2 = vm.addr(ROOT_ATTESTER_PK_2);
        rootAttester3 = vm.addr(ROOT_ATTESTER_PK_3);

        vm.warp(1_000_000);

        depositContract = new DepositContractMock();
        depositBuffer = new AccountingMockDepositDataBuffer();
        withdraw = new WithdrawV1();
        oracle = new OracleV1();
        allowlist = new AllowlistV1();
        redeemManager = new RedeemManagerV1();
        elFeeRecipient = new ELFeeRecipientV1();
        coverageFund = new CoverageFundV1();
        consolidationManager = new ConsolidationManagerV1();
        depositExecutor = new DepositExecutor();
        fundingDeltasBuilder = new FundingDeltasBuilder();
        externalConsolidationRecipientMapping = new ExternalConsolidationRecipientMappingV1();
        migrationHelper = new RiverV1_3Migration();
        river = new RiverV1();
        operatorsRegistry = new AccountingTestOperatorsRegistry();

        LibImplementationUnbricker.unbrick(vm, address(withdraw));
        LibImplementationUnbricker.unbrick(vm, address(oracle));
        LibImplementationUnbricker.unbrick(vm, address(allowlist));
        LibImplementationUnbricker.unbrick(vm, address(redeemManager));
        LibImplementationUnbricker.unbrick(vm, address(elFeeRecipient));
        LibImplementationUnbricker.unbrick(vm, address(coverageFund));
        LibImplementationUnbricker.unbrick(vm, address(consolidationManager));
        LibImplementationUnbricker.unbrick(vm, address(externalConsolidationRecipientMapping));
        LibImplementationUnbricker.unbrick(vm, address(river));
        LibImplementationUnbricker.unbrick(vm, address(operatorsRegistry));

        allowlist.initAllowlistV1(admin, allower);
        allowlist.initAllowlistV1_1(makeAddr("denier"));

        operatorsRegistry.initOperatorsRegistryV1(admin, address(river));

        redeemManager.initializeRedeemManagerV1(address(river));

        _bootstrapLegacyRiverState();

        // 3 root attesters with quorum=2 (quorum must be ≤ attester count and ≤ MAX_SIGNATURES)
        address[] memory _initRootAttesters = new address[](3);
        _initRootAttesters[0] = rootAttester1;
        _initRootAttesters[1] = rootAttester2;
        _initRootAttesters[2] = rootAttester3;

        // Deploy and initialize the AttestationVerifier sibling contract that River
        // delegates attestation+BLS verification to. EIP-712 verifyingContract is
        // pinned to River's address inside the validator's domain separator.
        attestationVerifier = new AttestationVerifierV1();
        LibImplementationUnbricker.unbrick(vm, address(attestationVerifier));
        address[] memory _initConsolidationCommitteeAttesters = new address[](1);
        _initConsolidationCommitteeAttesters[0] = makeAddr("consolidationCommitteeAttesterStub");
        attestationVerifier.initAttestationVerifierV1(
            address(river),
            address(depositBuffer),
            _initRootAttesters,
            2,
            bytes4(0),
            _initConsolidationCommitteeAttesters,
            1
        );

        bytes32 _initWc = withdraw.getCredentials();
        address _initConsolidationCoverageFund = makeAddr("consolidationCoverageFund");
        externalConsolidationRecipientMapping.initExternalConsolidationRecipientMappingV1(address(river));
        consolidationManager.initConsolidationManagerV1(
            address(river), address(externalConsolidationRecipientMapping), consolidator
        );
        vm.prank(admin);
        river.initRiverV1_3(
            _initWc,
            _initConsolidationCoverageFund,
            address(attestationVerifier),
            address(consolidationManager),
            address(fundingDeltasBuilder),
            address(depositExecutor),
            migrationHelper
        );
        // Mock BLS verification: EIP-2537 precompiles are unavailable in Foundry.
        vm.mockCall(
            address(attestationVerifier),
            abi.encodeWithSelector(attestationVerifier.verifyBLSDeposit.selector),
            bytes("")
        );

        withdraw.initializeWithdrawV1(address(river));
        elFeeRecipient.initELFeeRecipientV1(address(river));
        coverageFund.initCoverageFundV1(address(river));

        oracle.initOracleV1(address(river), admin, EPOCHS_PER_FRAME, SLOTS_PER_EPOCH, SECONDS_PER_SLOT, 0, 1000, 500);

        vm.startPrank(admin);
        river.setCoverageFund(address(coverageFund));
        river.setKeeper(keeper);
        oracle.addMember(oracleMember, 1);
        operatorOneIndex = operatorsRegistry.addOperator("OperatorOne", operatorOneAddr);
        operatorTwoIndex = operatorsRegistry.addOperator("OperatorTwo", operatorTwoAddr);
        vm.stopPrank();

        // Initialize the exited ETH array to zeros (opCount + 1 elements: [total, op0, op1, ...]).
        // Required because _setExitedETH accesses currentExitedETH[idx] without a bounds check,
        // so the array must be pre-populated before the first oracle report.
        uint256 opCount = operatorsRegistry.getOperatorCount();
        operatorsRegistry.sudoSetRawExitedETH(new uint256[](opCount + 1));
    }

    // ─── helpers ──────────────────────────────────────────────────────────────

    function _bootstrapLegacyRiverState() internal {
        _storeRiverAddress(ADMINISTRATOR_ADDRESS_SLOT, admin);

        vm.startPrank(admin);
        river.setCollector(makeAddr("collector"));
        river.setGlobalFee(500);
        river.setELFeeRecipient(address(elFeeRecipient));
        river.setAllowlist(address(allowlist));
        river.setDailyCommittableLimits(
            DailyCommittableLimits.DailyCommittableLimitsStruct({
                minDailyNetCommittableAmount: MAX_DAILY_NET, maxDailyRelativeCommittableAmount: MAX_DAILY_REL
            })
        );
        river.setOracle(address(oracle));
        river.setCLSpec(
            CLSpec.CLSpecStruct({
                epochsPerFrame: EPOCHS_PER_FRAME,
                slotsPerEpoch: SLOTS_PER_EPOCH,
                secondsPerSlot: SECONDS_PER_SLOT,
                genesisTime: 0,
                epochsToAssumedFinality: EPOCHS_UNTIL_FINAL
            })
        );
        river.setReportBounds(ReportBounds.ReportBoundsStruct({annualAprUpperBound: 1000, relativeLowerBound: 500}));
        vm.stopPrank();

        _storeRiverAddress(DEPOSIT_CONTRACT_ADDRESS_SLOT, address(depositContract));
        _storeRiverAddress(OPERATORS_REGISTRY_ADDRESS_SLOT, address(operatorsRegistry));
        _storeRiverAddress(REDEEM_MANAGER_ADDRESS_SLOT, address(redeemManager));

        vm.prank(address(river));
        river.approve(address(redeemManager), type(uint256).max);

        vm.store(address(river), VERSION_SLOT, bytes32(uint256(3)));
    }

    function _storeRiverAddress(bytes32 slot, address value) internal {
        vm.store(address(river), slot, bytes32(uint256(uint160(value))));
    }

    function _riverInFlightDeposit() internal view returns (uint256) {
        return uint256(vm.load(address(river), IN_FLIGHT_DEPOSIT_SLOT));
    }

    function _debugMoveDepositToCommitted() internal {
        uint256 committedBalance = uint256(vm.load(address(river), COMMITTED_BALANCE_SLOT));
        uint256 balanceToDeposit = uint256(vm.load(address(river), BALANCE_TO_DEPOSIT_SLOT));
        vm.store(address(river), COMMITTED_BALANCE_SLOT, bytes32(committedBalance + balanceToDeposit));
        vm.store(address(river), BALANCE_TO_DEPOSIT_SLOT, bytes32(0));
    }

    function _fundRiver(uint256 ethAmount) internal {
        require(ethAmount > 0, "fundRiver: zero amount");
        _simTotalUserDeposited += ethAmount;
        address user = makeAddr(string(abi.encode("fundUser", _fundUserCounter++)));
        _allowUser(user);
        vm.deal(user, ethAmount);
        vm.prank(user);
        river.deposit{value: ethAmount}();
        _debugMoveDepositToCommitted();
    }

    function _allowUser(address user) internal {
        address[] memory addrs = new address[](1);
        addrs[0] = user;
        uint256[] memory masks = new uint256[](1);
        masks[0] = LibAllowlistMasks.DEPOSIT_MASK | LibAllowlistMasks.REDEEM_MASK;
        vm.prank(allower);
        allowlist.setAllowPermissions(addrs, masks);
    }

    function _makeDeposits(uint256 opIdx, uint256[] memory amounts)
        internal
        returns (IOperatorsRegistryV1.ValidatorDeposit[] memory allocs)
    {
        allocs = new IOperatorsRegistryV1.ValidatorDeposit[](amounts.length);
        for (uint256 i = 0; i < amounts.length; i++) {
            allocs[i] = IOperatorsRegistryV1.ValidatorDeposit({
                operatorIndex: opIdx, pubkey: genBytes(48), signature: genBytes(96), depositAmount: amounts[i]
            });
        }
        return allocs;
    }

    /// @dev Convenience overload — builds `n` allocations of `DEPOSIT_SIZE` each for `opIdx`.
    function _makeDeposits(uint256 opIdx, uint256 n) internal returns (IOperatorsRegistryV1.ValidatorDeposit[] memory) {
        return _makeDeposits(opIdx, _amounts(n, DEPOSIT_SIZE));
    }

    // ─── attestation helpers ───────────────────────────────────────────────────

    function _emptyDepositY() internal pure returns (BLS12_381.DepositY memory) {
        return BLS12_381.DepositY({
            pubkeyY: BLS12_381.Fp({a: bytes32(0), b: bytes32(0)}),
            signatureY: BLS12_381.Fp2({c0_a: bytes32(0), c0_b: bytes32(0), c1_a: bytes32(0), c1_b: bytes32(0)})
        });
    }

    /// @dev Non-zero placeholder DepositY for initial deposits. BLS is mocked in this harness,
    ///      so the value only needs to differ from the zero sentinel used for top-ups.
    function _nonZeroDepositY(uint256 seed) internal pure returns (BLS12_381.DepositY memory) {
        return BLS12_381.DepositY({
            pubkeyY: BLS12_381.Fp({a: bytes32(uint256(seed) + 1), b: bytes32(0)}),
            signatureY: BLS12_381.Fp2({c0_a: bytes32(0), c0_b: bytes32(0), c1_a: bytes32(0), c1_b: bytes32(0)})
        });
    }

    /// @dev Sign an EIP-712 attestation digest with the given private key.
    function _signAttestation(uint256 pk, bytes32 bufferId, bytes32 rootHash) internal view returns (bytes memory) {
        bytes32 domainSep =
            keccak256(abi.encode(EIP712_DOMAIN_TYPEHASH, NAME_HASH, VERSION_HASH, block.chainid, address(river)));
        bytes32 structHash = keccak256(abi.encode(ATTEST_TYPEHASH, bufferId, rootHash));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSep, structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, digest);
        return abi.encodePacked(r, s, v);
    }

    /// @dev Build deposit objects from a set of (operatorIndex, amount) tuples.
    ///      Each deposit uses a deterministic pubkey/signature seeded by position and a
    ///      monotonically-incrementing batch nonce so successive `sim_deposit` calls in the
    ///      same block don't collide on pubkeys (which would trip the on-chain
    ///      `PubkeyAlreadyFunded` guard).
    function _makeDepositObjects(uint256[] memory opIndices, uint256[] memory amounts)
        internal
        returns (IDepositDataBuffer.DepositObject memory batch)
    {
        require(opIndices.length == amounts.length, "length mismatch");
        uint256 nonce = ++_depositBatchNonce;
        batch.deposits = new IDepositDataBuffer.Deposit[](opIndices.length);
        // batch.topUps left as default empty array.
        for (uint256 i = 0; i < opIndices.length; i++) {
            batch.deposits[i] = IDepositDataBuffer.Deposit({
                pubkey: abi.encodePacked(sha256(abi.encode("pubkey", i, opIndices[i], nonce)), bytes16(0)),
                signature: abi.encodePacked(
                    sha256(abi.encode("sig-a", i, opIndices[i], nonce)),
                    sha256(abi.encode("sig-b", i, opIndices[i], nonce)),
                    bytes32(0)
                ),
                amount: amounts[i],
                operatorIdx: opIndices[i],
                depositY: _nonZeroDepositY(nonce * 1000 + i)
            });
        }
    }

    /// @dev Returns the elapsed time (seconds) of a single reporting frame under the current
    ///      harness constants. Used in boundary tests that must compare against the src's
    ///      APR/lower-bound arithmetic without hardcoding the frame cadence.
    function _frameDuration() internal pure returns (uint256) {
        return uint256(EPOCHS_PER_FRAME) * uint256(SLOTS_PER_EPOCH) * uint256(SECONDS_PER_SLOT);
    }

    /// @dev Convenience: create an array of `n` identical deposit amounts.
    function _amounts(uint256 n, uint256 amountEach) internal pure returns (uint256[] memory amounts) {
        amounts = new uint256[](n);
        for (uint256 i = 0; i < n; i++) {
            amounts[i] = amountEach;
        }
    }

    /// @dev Pranks `user` and invokes `river.requestRedeem(lsEthAmount, user)`.
    function sim_requestRedeem(address user, uint256 lsEthAmount) internal {
        vm.prank(user);
        river.requestRedeem(lsEthAmount, user);
    }
}
