//SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.34;

import "./River.1.t.sol";

/// @title PoC — redemption surplus stranded at zero total supply, on `main`
/// @notice Reproduces finding 1 against the CURRENT `main` codebase, which has none of the
///         stopped-earning work: no rate marks, no request anchors, and the original pro-rata
///         `maxRedeemableEth` cap. The entire LsETH supply is queued for redemption, settlement burns
///         every share, the cap-bound claim leaves the appreciation in `BufferedExceedingEth`, and the
///         first depositor into the resulting empty pool ends up owning that pre-existing surplus.
///
/// @dev Two concrete fixtures run the same scenario:
///        * `MainZeroSupplySurplusRelaxedBoundsPoC` relaxes the report bounds as the redemption suite's
///          fixture does, so a single report can take the pool from 1.00 to 1.05. It makes the mechanism
///          visible at an obvious scale.
///        * `MainZeroSupplySurplusMainnetBoundsPoC` uses the LIVE bounds (1000 bp APR, 500 bp relative)
///          and a realistic one-frame appreciation, to show the finding does not depend on the relaxed
///          parameters. It also pins the honest limit: the absorption rate is the reporting headroom of
///          the NEW pool, so a small re-entrant deposit would take the surplus in very slowly, while a
///          deposit comparable to the old pool takes it in a report or two.
abstract contract MainZeroSupplySurplusPoCBase is RiverV1TestBase {
    RedeemManagerV1 internal redeemManager;

    uint32 internal constant VALIDATOR_COUNT = 100;
    uint256 internal constant BALLAST = uint256(VALIDATOR_COUNT) * 32 ether;

    address internal holder;
    address internal newcomer;

    uint256 internal _cumExitedEth;

    /// @dev Annual APR upper bound in basis points, per fixture.
    function _aprUpperBound() internal pure virtual returns (uint256);
    /// @dev Relative lower bound in basis points, per fixture.
    function _relativeLowerBound() internal pure virtual returns (uint256);

    function setUp() public override {
        super.setUp();

        holder = makeAddr("holder");
        newcomer = makeAddr("newcomer");

        redeemManager = new RedeemManagerV1();
        LibImplementationUnbricker.unbrick(vm, address(redeemManager));
        redeemManager.initializeRedeemManagerV1(address(river));

        river.initRiverV1(
            address(deposit),
            address(elFeeRecipient),
            withdraw.getCredentials(),
            address(oracle),
            admin,
            address(allowlist),
            address(operatorsRegistry),
            collector,
            0
        );
        river.initRiverV1_1(
            address(redeemManager),
            epochsPerFrame,
            slotsPerEpoch,
            secondsPerSlot,
            0,
            epochsUntilFinal,
            _aprUpperBound(),
            _relativeLowerBound(),
            maxDailyNetCommittableAmount,
            maxDailyRelativeCommittableAmount
        );
        river.initRiverV1_2();
        withdraw.initializeWithdrawV1(address(river));
        oracle.initOracleV1(
            address(river),
            admin,
            epochsPerFrame,
            slotsPerEpoch,
            secondsPerSlot,
            0,
            _aprUpperBound(),
            _relativeLowerBound()
        );

        vm.startPrank(admin);
        oracle.addMember(oracleMember, 1);
        river.setCoverageFund(address(coverageFund));
        river.setKeeper(admin);
        vm.stopPrank();
    }

    /// @dev The whole scenario, parameterised by the settlement rate and the size of the re-entrant
    ///      deposit. Returns the surplus that ended up in the newcomer's hands and the number of reports
    ///      it took to get there.
    function _runScenario(uint256 settlementRate, uint256 newcomerDeposit)
        internal
        returns (uint256 surplus, uint256 reportCount)
    {
        // ── 0. seed the pool and put the whole of it on the consensus layer ───
        _allow(holder);
        vm.deal(holder, BALLAST);
        vm.prank(holder);
        river.deposit{value: BALLAST}();
        assertEq(river.totalSupply(), BALLAST, "the first deposit mints one share per wei");

        river.debug_moveDepositToCommitted();
        _fundConsensusLayer();

        // the oracle confirms activation: the pool is entirely CL-backed at a rate of exactly 1.0
        _submitReport(BALLAST, 0, VALIDATOR_COUNT);
        assertEq(river.underlyingBalanceFromShares(1e18), 1e18, "the seeded pool sits at 1.0");

        // ── 1. the only holder queues its ENTIRE balance ──────────────────────
        // Nothing in `requestRedeem` reserves a minimum supply.
        uint256 wholeSupply = river.totalSupply();
        assertEq(river.balanceOf(holder), wholeSupply, "the holder owns every share");
        vm.prank(holder);
        river.approve(address(redeemManager), wholeSupply);
        vm.prank(holder);
        uint32 id = redeemManager.requestRedeem(wholeSupply, holder);

        // requested at a rate of 1.0, so `maxRedeemableEth` caps the payout at the principal
        assertEq(redeemManager.getRedeemRequestDetails(id).maxRedeemableEth, wholeSupply);
        assertEq(redeemManager.getRedeemDemand(), wholeSupply);

        // ── 2. the pool appreciates and the whole CL balance is swept ─────────
        uint256 sweep = (wholeSupply * settlementRate) / 1e18;
        _submitReport(0, sweep, VALIDATOR_COUNT);

        assertEq(redeemManager.getWithdrawalEventCount(), 1);
        WithdrawalStack.WithdrawalEvent memory settlement = redeemManager.getWithdrawalEventDetails(0);
        assertEq(settlement.amount, wholeSupply, "the event settles the entire demand");
        assertEq(settlement.withdrawnEth, sweep, "priced at the post-report rate");

        // settlement burned the redeem manager's shares, which were ALL the shares
        assertEq(river.totalSupply(), 0, "FINDING: total supply reaches zero on main too");
        assertEq(river.totalUnderlyingSupply(), 0, "and River holds no assets at all");
        assertEq(redeemManager.getRedeemDemand(), 0);

        // ── 3. the cap binds and the appreciation is confiscated to the buffer ─
        surplus = sweep - wholeSupply;
        assertGt(surplus, 0, "the settlement must be priced above the request rate");

        uint32[] memory ids = new uint32[](1);
        ids[0] = id;
        uint32[] memory eventIds = new uint32[](1);
        eventIds[0] = 0;
        uint256 holderBefore = holder.balance;
        redeemManager.claimRedeemRequests(ids, eventIds);

        assertEq(holder.balance - holderBefore, wholeSupply, "the redeemer is paid its request-time value");
        assertEq(redeemManager.getBufferedExceedingEth(), surplus, "FINDING: the surplus is buffered");
        assertEq(address(redeemManager).balance, surplus);
        assertEq(river.totalUnderlyingSupply(), 0, "the surplus is outside River's accounted assets");

        // ── 4. a new depositor enters the empty pool at 1:1 ───────────────────
        _allow(newcomer);
        vm.deal(newcomer, newcomerDeposit);
        vm.prank(newcomer);
        river.deposit{value: newcomerDeposit}();

        assertEq(river.balanceOf(newcomer), newcomerDeposit, "the empty pool mints 1:1");
        assertEq(river.totalSupply(), newcomerDeposit, "the newcomer owns 100% of the pool");
        assertEq(river.underlyingBalanceFromShares(1e18), 1e18, "worth exactly what it cost, for now");

        // ── 5. later reports pull the pre-existing surplus into River ─────────
        // A 10% protocol fee is switched on first, purely to show the surplus is not fee-bearing:
        // `_pullRedeemManagerExceedingEth`'s result is never added to `trace.rewards`, so `_onEarnings`
        // never sees it.
        vm.prank(admin);
        river.setGlobalFee(1000);

        while (redeemManager.getBufferedExceedingEth() > 0 && reportCount < 400) {
            _submitReport(0, _cumExitedEth, VALIDATOR_COUNT);
            ++reportCount;
        }

        assertEq(redeemManager.getBufferedExceedingEth(), 0, "the buffer is fully drained");
        assertEq(address(redeemManager).balance, 0);

        // ── 6. the newcomer now owns the whole surplus ────────────────────────
        assertEq(river.totalSupply(), newcomerDeposit, "no other shares were ever minted");
        assertEq(river.balanceOf(newcomer), newcomerDeposit);
        assertEq(
            river.underlyingBalanceFromShares(newcomerDeposit),
            newcomerDeposit + surplus,
            "FINDING: the newcomer's position is now worth its cost plus the whole surplus"
        );
        assertEq(river.balanceOf(collector), 0, "FINDING: the surplus is transferred without a fee");
    }

    // ─── helpers ──────────────────────────────────────────────────────────────

    function _allow(address who) internal {
        address[] memory allowees = new address[](1);
        allowees[0] = who;
        uint256[] memory statuses = new uint256[](1);
        statuses[0] = LibAllowlistMasks.DEPOSIT_MASK | LibAllowlistMasks.REDEEM_MASK;
        vm.prank(allower);
        allowlist.setAllowPermissions(allowees, statuses);
    }

    /// @dev Registers one operator with `VALIDATOR_COUNT` keys and funds them from the committed balance.
    function _fundConsensusLayer() internal {
        address operatorAddress = makeAddr("operator");
        vm.prank(admin);
        uint256 operatorIndex = operatorsRegistry.addOperator("Operator", operatorAddress);

        vm.prank(operatorAddress);
        operatorsRegistry.addValidators(operatorIndex, VALIDATOR_COUNT, genBytes((48 + 96) * uint256(VALIDATOR_COUNT)));

        uint256[] memory operatorIndexes = new uint256[](1);
        operatorIndexes[0] = operatorIndex;
        uint32[] memory operatorLimits = new uint32[](1);
        operatorLimits[0] = VALIDATOR_COUNT;
        vm.prank(admin);
        operatorsRegistry.setOperatorLimits(operatorIndexes, operatorLimits, block.number);

        uint32[] memory counts = new uint32[](1);
        counts[0] = VALIDATOR_COUNT;
        vm.prank(admin);
        river.depositToConsensusLayerWithDepositRoot(_createMultiAllocation(operatorIndexes, counts), bytes32(0));
    }

    /// @dev Warps to the next reportable frame, funds the withdrawal contract with the newly exited ETH
    ///      and submits one oracle report.
    function _submitReport(uint256 validatorsBalance, uint256 cumExitedEth, uint32 validatorsCount) internal {
        uint256 epoch = river.getExpectedEpochId();
        uint256 finalityTimestamp = uint256(secondsPerSlot) * slotsPerEpoch * (epoch + epochsUntilFinal) + 1;
        if (block.timestamp < finalityTimestamp) {
            vm.warp(finalityTimestamp);
        }

        if (cumExitedEth > _cumExitedEth) {
            vm.deal(address(withdraw), address(withdraw).balance + (cumExitedEth - _cumExitedEth));
        }
        _cumExitedEth = cumExitedEth;

        IOracleManagerV1.ConsensusLayerReport memory clr;
        clr.epoch = epoch;
        clr.validatorsBalance = validatorsBalance;
        clr.validatorsSkimmedBalance = 0;
        clr.validatorsExitedBalance = cumExitedEth;
        clr.validatorsExitingBalance = 0;
        clr.validatorsCount = validatorsCount;
        clr.stoppedValidatorCountPerOperator = new uint32[](1);
        clr.rebalanceDepositToRedeemMode = false;
        clr.slashingContainmentMode = false;

        vm.prank(oracleMember);
        oracle.reportConsensusLayerData(clr);
    }
}

/// @notice The mechanism at an obvious scale: a 5% appreciation between request and settlement leaves
///         160 ETH stranded on a 3200 ETH pool, and a 1 ETH deposit into the empty pool absorbs all of it.
contract MainZeroSupplySurplusRelaxedBoundsPoC is MainZeroSupplySurplusPoCBase {
    function _aprUpperBound() internal pure override returns (uint256) {
        return 1_000_000_000;
    }

    function _relativeLowerBound() internal pure override returns (uint256) {
        return 10_000;
    }

    function testMain_RelaxedBounds_SurplusIsCapturedByTheNextDepositor() external {
        (uint256 surplus, uint256 reportCount) = _runScenario(1.05e18, 1 ether);

        assertEq(surplus, 160 ether, "5% of a 3200 ETH pool");
        emit log_named_uint("main PoC (relaxed bounds): surplus in wei", surplus);
        emit log_named_uint("main PoC (relaxed bounds): reports to absorb it", reportCount);
    }
}

/// @notice The same finding under the LIVE report bounds -- 1000 bp annual APR, 500 bp relative -- with a
///         one-frame appreciation the oracle would actually accept and a re-entrant deposit the size of
///         the pool that just left.
/// @dev The settlement rate is 1.0002, i.e. 0.02% over one frame, comfortably inside the ~0.027% a
///      mainnet report may add. The surplus is correspondingly modest (0.64 ETH on 3200 ETH) -- that is
///      the honest magnitude of this finding in production: it is bounded by the pool's appreciation
///      across the redemption window, not by the pool size.
/// @dev The report count is the other honest limit. Absorption is capped by the NEW pool's reporting
///      headroom, so it is fast only because the newcomer's deposit is comparable to the old pool. A
///      1 ETH deposit would take decades of daily reports to absorb the same 0.64 ETH -- the ETH is
///      still theirs, just not quickly.
contract MainZeroSupplySurplusMainnetBoundsPoC is MainZeroSupplySurplusPoCBase {
    function _aprUpperBound() internal pure override returns (uint256) {
        return 1000;
    }

    function _relativeLowerBound() internal pure override returns (uint256) {
        return 500;
    }

    function testMain_MainnetBounds_SurplusIsCapturedByTheNextDepositor() external {
        (uint256 surplus, uint256 reportCount) = _runScenario(1.0002e18, BALLAST);

        assertEq(surplus, 0.64 ether, "0.02% of a 3200 ETH pool");
        emit log_named_uint("main PoC (mainnet bounds): surplus in wei", surplus);
        emit log_named_uint("main PoC (mainnet bounds): reports to absorb it", reportCount);
    }
}
