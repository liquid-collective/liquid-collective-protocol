//SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.34;

import "./RedemptionReportBase.sol";

/// @title Stopped-earning payout tests
/// @notice Answers the headline question of the feature: a redeemer requests at a pool rate of `x`, the
///         principal behind the request is later reported as having stopped earning while the pool sits
///         20% higher, and the request is settled. What does the redeemer finally receive?
/// @dev The answer is the STOPPED-EARNING RATE, not the request rate and not the settlement rate:
///      `payout = min(pro-rata of the withdrawal event's ETH, sliceCap)`, and for a slice a single mark
///      covers end to end the cap is that mark's `markedEth`. So the mark both lifts the request-time
///      budget (the redeemer keeps the rewards accrued while queued, up to the moment the principal
///      stopped earning) and caps it (nothing accrues after that moment, however far the pool runs on).
/// @dev The 20% step is nothing special to the contract -- it is a locked rate like any other. The two
///      concrete tests fix `x` at 1.0 and at 1.1 so the arithmetic is readable, and
///      `testFuzzStoppedEarningTwentyPercentAbove` states the same claim for any `x` in the band.
contract StoppedEarningPayoutTests is RedemptionReportBase {
    /// @dev The whole position each test queues. Whole ether, so the round rates below are exactly
    ///      representable -- see `_reportRate` on `RedemptionReportBase`.
    uint256 internal constant POSITION = 100e18;

    /// Verifies that a fully marked request pays at the stopped-earning rate rather than the request
    /// or settlement rate, with post-mark appreciation buffered.
    ///
    ///     rate     1.0 ──── request ──── 1.2 ──── stopped earning ──── 1.5 ──── sweep + claim
    ///     axis     [============ request / mark0, 100 LsETH @ 1.2 ============)
    function testStoppedEarningAtTwentyPercentAbovePaysTheStoppedEarningRate() external {
        address user = _generateAllowlistedUser(0);

        // x = 1.0. `setUp` already seeded the pool here; reported again so the request rate is explicit.
        _reportRate(1e18);
        uint32 id = _openRequest(user, POSITION);

        RedeemRequestAnchor.Anchor memory anchor = redeemManager.getRedeemRequestAnchor(id);
        assertEq(anchor.lsETHAtRequest, POSITION, "the anchor must record the position");
        assertEq(anchor.ethAtRequest, applyRate(POSITION, 1e18), "the request-time budget is 100 ETH");

        // the pool appreciates to 1.2x the request rate, and only then does the report carry the
        // stopped-earning delta: a mark is priced at the PRE-report rate, so the move and the delta are
        // two separate reports
        _reportRate(1.2e18);
        _reportStoppedEarning(applyRate(POSITION, 1.2e18));

        // one mark covering the request end to end, locking 1.2
        assertEq(redeemManager.getRateMarkCount(), 1);
        RateMarkStack.RateMark memory mark = redeemManager.getRateMarkDetails(0);
        assertEq(mark.height, 0);
        assertEq(mark.amount, POSITION, "the mark must cover the whole request");
        assertEq(mark.markedEth, applyRate(POSITION, 1.2e18), "the mark must lock 1.2");

        // the pool keeps climbing after the principal stopped earning, and the sweep is funded at 1.5,
        // so the pro-rata leg of the claim offers 150 ETH and the CAP is the binding side of the min()
        _reportRate(1.5e18);
        uint256 eventEth = _reportWithdraw(POSITION, 1.5e18);
        assertEq(eventEth, applyRate(POSITION, 1.5e18), "the event must offer the 1.5 pro-rata");

        uint256 received = _claim(id);

        // ── the answer ────────────────────────────────────────────────────────
        assertEq(received, 120e18, "the redeemer is paid at the stopped-earning rate of 1.2");
        assertEq(received, applyRate(POSITION, 1.2e18));
        assertEq(received, mark.markedEth);
        // 20 ETH more than the request rate would have paid
        assertGt(received, applyRate(POSITION, 1e18));
        // 30 ETH less than the settlement rate would have paid, and that difference is confiscated
        assertEq(redeemManager.getBufferedExceedingEth(), applyRate(POSITION, 1.5e18) - applyRate(POSITION, 1.2e18));
        assertEq(redeemManager.getRedeemRequestDetails(id).amount, 0, "the request must be fully claimed");
    }

    /// Verifies that the stopped-earning rate determines a fully marked payout independently of the
    /// original request rate.
    function testStoppedEarningRateWinsRegardlessOfTheRequestRate() external {
        address user = _generateAllowlistedUser(0);

        _reportRate(1.1e18);
        uint32 id = _openRequest(user, POSITION);
        assertEq(
            redeemManager.getRedeemRequestAnchor(id).ethAtRequest,
            applyRate(POSITION, 1.1e18),
            "the request-time budget is 110 ETH"
        );

        _reportRate(1.3e18);
        _reportStoppedEarning(applyRate(POSITION, 1.3e18));
        assertEq(redeemManager.getRateMarkDetails(0).markedEth, applyRate(POSITION, 1.3e18));

        _reportRate(1.35e18);
        _reportWithdraw(POSITION, 1.35e18);

        uint256 received = _claim(id);

        assertEq(received, 130e18, "the redeemer is paid at the stopped-earning rate of 1.3");
        assertEq(received, applyRate(POSITION, 1.3e18));
        assertEq(redeemManager.getBufferedExceedingEth(), applyRate(POSITION, 1.35e18) - applyRate(POSITION, 1.3e18));
    }

    /// Verifies that a mark is a cap rather than a floor: settlement below the marked rate pays only
    /// the event's funding and creates no exceeding ETH.
    function testStoppedEarningRateIsACapNotAFloorWhenTheSweepIsFundedBelowIt() external {
        address user = _generateAllowlistedUser(0);

        _reportRate(1e18);
        uint32 id = _openRequest(user, POSITION);

        _reportRate(1.2e18);
        _reportStoppedEarning(applyRate(POSITION, 1.2e18));
        assertEq(redeemManager.getRateMarkDetails(0).markedEth, applyRate(POSITION, 1.2e18));

        // the pool gives back part of the run-up before the sweep, so the EVENT is the binding side
        uint256 received = _settleAndClaim(id, POSITION, 1.1e18);

        assertEq(received, 110e18, "the redeemer is paid the event's ETH, below the 1.2 lock");
        assertEq(received, applyRate(POSITION, 1.1e18));
        assertLt(received, applyRate(POSITION, 1.2e18));
        assertEq(redeemManager.getBufferedExceedingEth(), 0, "the cap never bound, so nothing is confiscated");
    }

    /// Verifies that recovery after a below-request mark remains forfeited, paying the marked rate and
    /// buffering the coverage-fund recovery for remaining holders.
    ///
    ///     day 0   request 30 LsETH at a pool rate of 1.0    -> anchored at 30 ETH
    ///     day 5   a slashing takes the pool to 0.9
    ///     day 6   the principal crosses exit_epoch at 0.9   -> mark [0, 30) locks 27 ETH
    ///     day 20  the coverage fund donation is pulled in   -> the pool is whole again at 1.0
    ///     day 25  30 LsETH is swept at 1.0                  -> the event carries 30 ETH
    function testSlashThenMarkThenCoverageFundRecoveryStillPaysTheMarkedRate() external {
        _upgradeToV1_3();
        assertEq(redeemManager.getRateMarkFloor(), 0);

        address user = _generateAllowlistedUser(0);
        address donor = _generateAllowlistedUser(1);
        _grantDonatePermission(donor);

        // day 0 — request at a pool rate of 1.0
        _reportRate(1e18);
        uint32 id = _openRequest(user, 30e18);
        RedeemRequestAnchor.Anchor memory anchor = redeemManager.getRedeemRequestAnchor(id);
        assertEq(anchor.ethAtRequest, 30e18, "the request is quoted at 30 ETH");

        // day 5 — a slashing marks the pool down to 0.9
        _reportRate(0.9e18);

        // day 6 — the principal behind the request crosses exit_epoch while the pool sits at 0.9
        _reportStoppedEarning(applyRate(30e18, 0.9e18));
        RateMarkStack.RateMark memory mark = redeemManager.getRateMarkDetails(0);
        assertEq(mark.height, 0);
        assertEq(mark.amount, 30e18, "the mark must cover the whole request");
        assertEq(mark.markedEth, 27e18, "the ceiling is now 27 ETH");

        // day 20 — a coverage-fund donation big enough to restore the rate, pulled in by the next report.
        // The fixture's rate solver assumes the coverage fund is empty, so the pull lands on top of the
        // requested figure: donating the whole deficit takes a report targeting 0.9 to an achieved 1.0.
        uint256 deficit = (river.totalSupply() * (1e18 - 0.9e18)) / 1e18;
        vm.deal(donor, deficit);
        vm.prank(donor);
        coverageFund.donate{value: deficit}();
        _report(
            ReportParams({
                targetRate: 0.9e18,
                exitedEth: 0,
                stoppedEarningEth: 0,
                activatedEth: 0,
                rebalance: false,
                slashingContainment: false
            })
        );
        assertEq(_poolRate(), 1e18, "the coverage payout must make the pool whole again");

        // day 25 — the exited principal is swept at the recovered 1.0, so the event carries the full 30
        // ETH the request was quoted at
        uint256 withdrawnEth = _reportWithdraw(30e18, 1e18);
        assertEq(withdrawnEth, 30e18, "30 ETH is sitting on the withdrawal event");

        uint256 received = _claim(id);

        // ── the answer ────────────────────────────────────────────────────────
        assertEq(received, 27e18, "the redeemer is held to the marked 0.9, not the recovered 1.0");
        assertEq(received, mark.markedEth);
        assertLt(received, anchor.ethAtRequest, "no floor at the request-time rate");
        assertLt(received, withdrawnEth, "the event carried more ETH than the redeemer may take");
        // the forfeited recovery goes back to the holders who did not redeem
        assertEq(redeemManager.getBufferedExceedingEth(), 3e18);
        assertEq(redeemManager.getRedeemRequestDetails(id).amount, 0, "the request must be fully claimed");
    }

    /// @dev Grants `DONATE_MASK` on top of the redeem and deposit permissions `_allowlistUser` gives, so
    ///      the account can reach `CoverageFundV1.donate`.
    function _grantDonatePermission(address user) internal {
        address[] memory accounts = new address[](1);
        accounts[0] = user;
        uint256[] memory permissions = new uint256[](1);
        permissions[0] = LibAllowlistMasks.REDEEM_MASK | LibAllowlistMasks.DEPOSIT_MASK | LibAllowlistMasks.DONATE_MASK;

        vm.prank(allowlistAllower);
        allowlist.setAllowPermissions(accounts, permissions);
    }

    /// Verifies across fuzzed request rates that a fully covered slice pays the mark's exact locked ETH
    /// when the settlement event supplies enough.
    function testFuzzStoppedEarningTwentyPercentAbove(uint256 requestRate) external {
        // above 1.0 so the run-up is a real appreciation, and capped so 1.2x stays inside the band the
        // ballast can express
        requestRate = bound(requestRate, 1e18, 2e18);

        address user = _generateAllowlistedUser(0);

        uint256 x = _reportRateLoose(requestRate);
        (uint32 id, uint256 amount) = _openRequestLoose(user, POSITION);
        uint256 ethAtRequest = redeemManager.getRedeemRequestAnchor(id).ethAtRequest;

        // the stopped-earning rate, 20% above the request rate
        uint256 markRate = _reportRateLoose((x * 12) / 10);
        _reportStoppedEarning(river.underlyingBalanceFromShares(amount));

        assertEq(redeemManager.getRateMarkCount(), 1);
        RateMarkStack.RateMark memory mark = redeemManager.getRateMarkDetails(0);
        assertEq(mark.height, 0);
        assertEq(mark.amount, amount, "the mark must cover the whole request");

        // funded above the lock, so the cap binds
        uint256 settlementRate = _reportRateLoose((markRate * 11) / 10);
        _reportWithdraw(amount, settlementRate);

        uint256 received = _claim(id);

        // the mark's locked ETH, to the wei
        assertEq(received, mark.markedEth, "a fully marked slice is paid exactly its mark");
        // which is the position at the stopped-earning rate, less the two truncations
        assertApproxEqAbs(received, applyRate(amount, markRate), 2, "paid at the stopped-earning rate");
        // strictly better than the request-time budget, and strictly below the settlement rate
        assertGt(received, ethAtRequest, "the mark must lift the request-time budget");
        assertLt(received, applyRate(amount, settlementRate), "the mark must cap the settlement rate");
    }
}
