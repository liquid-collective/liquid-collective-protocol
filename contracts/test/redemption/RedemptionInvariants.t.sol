//SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.34;

import "forge-std/StdUtils.sol";

import "./RedemptionReportBase.sol";

import "../../src/state/redeemManager/WithdrawalStack.sol";
import "../../src/state/redeemManager/RateMarkStack.sol";
import "../../src/state/redeemManager/RedeemRequestAnchor.sol";

/// @notice The external surface the stateful handler drives. The handler is a plain contract with no
///         cheatcode access, so every action that needs `vm` (pranking a redeemer, funding a
///         withdrawal report) is delegated back to the test contract, which owns the ghost state.
/// @dev Mirrors the `IAccountingActions` idiom of contracts/test/accounting/invariant/AccountingHandler.sol.
interface IRedemptionActions {
    function handler_openRequest(uint256 userSeed, uint256 amount) external;
    function handler_moveRate(uint256 rate) external;
    function handler_reportStoppedEarning(uint256 stoppedEarningEth) external;
    function handler_reportWithdraw(uint256 lsETH) external;
    function handler_claim(uint256 idSeed, uint16 depth) external;

    function handler_requestCount() external view returns (uint256);
    function handler_redeemDemand() external view returns (uint256);
    function handler_withdrawalEventCount() external view returns (uint256);
    function handler_rateMarkCount() external view returns (uint256);
    function handler_totalRequestedHeight() external view returns (uint256);
    function handler_poolRate() external view returns (uint256);
}

/// @title Redemption fulfillment mirror
/// @notice Independent, getter-only re-derivation of `_sliceCap` and of one `claimRedeemRequests`
///         call, shared by the stateful handler and the stateless fuzz suite below.
/// @dev The contract's own walk binary-searches the mark stack; this mirror scans it linearly. That
///      is deliberate: a differential test is only worth running when the two sides are formulated
///      differently, so a bug in `_findRateMarkAtOrBefore`'s predecessor search cannot be reproduced
///      identically here and cancel out.
abstract contract RedemptionMirror is RedemptionReportBase {
    /// @notice The result of mirroring a single `claimRedeemRequests` call for one request
    struct MirrorClaim {
        /// @custom:attribute ETH the recipient should receive
        uint256 paid;
        /// @custom:attribute Pro-rata ETH the touched withdrawal events supply for the matched slices
        uint256 gross;
        /// @custom:attribute Sum of the per-slice payout caps
        uint256 capSum;
        /// @custom:attribute LsETH matched across the walk
        uint256 matched;
        /// @custom:attribute Number of (request slice, withdrawal event) pairs walked
        uint256 steps;
        /// @custom:attribute Steps where the slice cap was the binding side of `min(gross, cap)`
        uint256 capBoundSteps;
        /// @custom:attribute Steps where the withdrawal event's ETH was the binding side (or tied)
        uint256 eventBoundSteps;
    }

    /// @notice Re-derives `RedeemManagerV1._sliceCap` from public getters
    /// @dev Only valid for an anchored (post-upgrade) request; the legacy branch lives in
    ///      `_mirrorClaim`, because it depends on the request's decrementing ETH budget rather than
    ///      on the mark stack.
    function _mirrorSliceCap(
        RedeemManagerV1 manager,
        RedeemRequestAnchor.Anchor memory anchor,
        uint256 sliceStart,
        uint256 sliceAmount
    ) internal view returns (uint256 cap) {
        uint256 markCount = manager.getRateMarkCount();
        uint256 cursor = sliceStart;
        uint256 remaining = sliceAmount;

        // linear predecessor scan: drop every mark that terminates at or below the slice start. The
        // first survivor either starts above the cursor (a gap) or contains it.
        uint256 idx = 0;
        while (idx < markCount) {
            RateMarkStack.RateMark memory candidate = manager.getRateMarkDetails(uint32(idx));
            if (candidate.height + candidate.amount > cursor) break;
            unchecked {
                ++idx;
            }
        }

        while (remaining > 0) {
            if (idx >= markCount) {
                // past the last mark: the remainder can only be valued at the request-time rate
                cap += (remaining * anchor.ethAtRequest) / anchor.lsETHAtRequest;
                return cap;
            }
            RateMarkStack.RateMark memory mark = manager.getRateMarkDetails(uint32(idx));
            if (cursor < mark.height) {
                // gap below the next mark: LsETH here never stopped earning, so it keeps the
                // request-time rate
                uint256 unmarked = mark.height - cursor;
                if (unmarked > remaining) unmarked = remaining;
                cap += (unmarked * anchor.ethAtRequest) / anchor.lsETHAtRequest;
                cursor += unmarked;
                remaining -= unmarked;
                continue;
            }
            // covered by the mark: valued at the mark's locked rate over the covered portion only
            uint256 markEnd = mark.height + mark.amount;
            uint256 marked = markEnd - cursor;
            if (marked > remaining) marked = remaining;
            cap += (marked * mark.markedEth) / mark.amount;
            cursor += marked;
            remaining -= marked;
            unchecked {
                ++idx;
            }
        }
    }

    /// @notice Re-derives one `claimRedeemRequests(request, startEventId, depth)` call
    /// @dev Must be evaluated BEFORE the real call, since it reads the pre-claim request state.
    function _mirrorClaim(RedeemManagerV1 manager, uint32 id, uint32 startEventId, uint16 depth)
        internal
        view
        returns (MirrorClaim memory result)
    {
        RedeemQueueV2.RedeemRequest memory request = manager.getRedeemRequestDetails(id);
        RedeemRequestAnchor.Anchor memory anchor = manager.getRedeemRequestAnchor(id);
        uint256 eventCount = manager.getWithdrawalEventCount();

        uint256 cursor = request.height;
        uint256 remaining = request.amount;
        // the legacy cap reads the request's decrementing ETH budget, which the claim path mutates
        // between recursion frames, so the mirror has to carry it too
        uint256 budget = request.maxRedeemableEth;
        // `_claimRedeemRequest` performs one step, then recurses only while `depth > 0`
        uint256 stepsLeft = uint256(depth) + 1;
        uint32 eventId = startEventId;

        while (stepsLeft > 0 && remaining > 0 && eventId < eventCount) {
            WithdrawalStack.WithdrawalEvent memory withdrawalEvent = manager.getWithdrawalEventDetails(eventId);
            uint256 eventEnd = withdrawalEvent.height + withdrawalEvent.amount;
            // defensive: a caller passing a non-matching event would revert on-chain anyway
            if (eventEnd <= cursor) break;

            uint256 matching = eventEnd - cursor;
            if (matching > remaining) matching = remaining;

            uint256 gross = (matching * withdrawalEvent.withdrawnEth) / withdrawalEvent.amount;
            uint256 cap = anchor.lsETHAtRequest == 0
                ? (matching * budget) / remaining
                : _mirrorSliceCap(manager, anchor, cursor, matching);
            uint256 pay = gross < cap ? gross : cap;

            result.paid += pay;
            result.gross += gross;
            result.capSum += cap;
            result.matched += matching;
            result.steps += 1;
            // which side of `min(gross, cap)` actually decided this slice. Counted per SLICE rather
            // than per claim: a single claim routinely walks an event that over-funds it and one that
            // under-funds it, so a per-claim classification would hide one of the two.
            if (cap < gross) {
                result.capBoundSteps += 1;
            } else {
                result.eventBoundSteps += 1;
            }

            budget = budget > pay ? budget - pay : 0;
            cursor += matching;
            remaining -= matching;
            unchecked {
                ++eventId;
                --stepsLeft;
            }
        }
    }

    /// @notice Rolls the whole protocol back to `snapshotId` so a scenario can be replayed onto a
    ///         pristine deployment, and hands back the pair to drive.
    /// @dev Replaces the "deploy a second River + RedeemManagerV1 pair" idiom the differential
    ///      tests below used to rely on. With the complete protocol under test a second world would
    ///      mean a second River, Oracle, OperatorsRegistry, AttestationVerifier and so on, redeployed
    ///      once per fuzz run per world -- thousands of full protocol deployments across a suite. A
    ///      state rollback gives the same thing: a deployment with an empty queue, an empty withdrawal
    ///      stack, an empty mark stack and the rate mark floor still at 0. `ClaimMechanics` uses the
    ///      same snapshot idiom to replay a scenario under a second claim order.
    /// @dev Anything the caller needs from the world it is leaving must be read BEFORE this call: the
    ///      rollback restores contract storage, so only values already in memory survive it.
    function _resetToPristineProtocol(uint256 snapshotId)
        internal
        returns (RedemptionRiverV1 freshRiver, RedeemManagerV1 freshManager)
    {
        assertTrue(vm.revertTo(snapshotId), "failed to roll the protocol back to its pristine state");
        return (river, redeemManager);
    }

    /// @dev Resolves `id` to the withdrawal event that currently satisfies it, or a negative code.
    function _resolveOn(RedeemManagerV1 manager, uint32 id) internal view returns (int64) {
        uint32[] memory ids = new uint32[](1);
        ids[0] = id;
        return manager.resolveRedeemRequests(ids)[0];
    }
}

/// @title Redemption fulfillment invariant handler
/// @notice The sole Foundry invariant target. Every entry point bounds its fuzzed inputs and then
///         delegates to the test contract, which holds `vm` and the ghost accounting.
/// @dev Bounding is what keeps `fail_on_revert = false` from hiding a broken handler: an action that
///      would revert (a withdrawal larger than outstanding demand, a claim of an unsatisfied request)
///      is either bounded into range or skipped explicitly, so the call counters below are a real
///      measure of work done rather than of calls attempted. Every skip bumps `calls_skipped`, so a
///      run that bounced off the guards is visible rather than merely quiet.
///
/// @dev RATE COHERENCE. `moveRate` is the ONLY action that changes the pool rate, and every other
///      action prices itself against whatever rate is live when it runs. That is not a stylistic
///      choice — it is what makes the sampled states reachable. River derives both legs of a
///      stopped-earning report and both legs of a withdrawal event from one rate
///      (LibOracleReporting L217-219 and L588-613), so a handler that fuzzed a "mark rate" and a
///      "settlement rate" independently of the pool would spend most of its budget on states the
///      protocol cannot produce. It would also systematically miss the case that matters most: when
///      the three rates are within a few percent of each other, `min(pro-rata event ETH, sliceCap)`
///      is decided by which of two truncations lands lower, and a 3x over-funded event makes the
///      event side win unconditionally so that comparison is never exercised. `capBoundSlices` and
///      `eventBoundSlices` on the test contract exist to prove both sides actually occur.
contract RedemptionInvariantHandler is StdUtils {
    /// @notice Ceiling on queue/stack growth, so the O(n) invariant sweeps stay cheap at depth 32
    uint256 private constant MAX_ENTRIES = 24;
    /// @notice Smallest request the fuzzer may open. Below ~1 gwei every rate multiplication floors
    ///         to 0 and the run degenerates into no-ops that prove nothing.
    uint256 private constant MIN_REQUEST = 1 gwei;
    uint256 private constant MAX_REQUEST = 1_000 ether;
    /// @notice Absolute rate band the walk is clamped to. Wide enough to cross 1.0 in both directions
    ///         (a marked rate below the request rate must LOWER the cap), narrow enough that no
    ///         product overflows.
    uint256 private constant MIN_RATE = 0.5e18;
    uint256 private constant MAX_RATE = 3e18;
    /// @notice Per-report rate step, as a fraction of the LIVE rate rather than a redraw from the whole
    ///         band. The pool rate only moves when an oracle report lands, and one report can at worst
    ///         mass-slash and at best pay an unusually large reward — it cannot teleport from 0.5 to
    ///         3.0. Bounding the step is what keeps request, mark and settlement rates within a few
    ///         percent of each other often enough for the two truncations to compete.
    uint256 private constant RATE_STEP_DOWN_BPS = 7_000; // -30% in a single report
    uint256 private constant RATE_STEP_UP_BPS = 11_000; // +10% in a single report
    /// @notice Recursion depth band. Kept small on purpose: a truncated walk is the interesting case,
    ///         since it is the one that leaves a request half-settled for the next action to resume.
    uint256 private constant MAX_DEPTH = 4;

    IRedemptionActions private _test;

    // ─── call counters (used by afterInvariant to prove the run was not vacuous) ─────

    uint256 public calls_openRequest;
    uint256 public calls_moveRate;
    uint256 public calls_reportStoppedEarning;
    uint256 public calls_reportWithdraw;
    uint256 public calls_claim;
    /// @notice Actions that bounced off a guard without reaching the protocol.
    uint256 public calls_skipped;

    constructor(IRedemptionActions test_) {
        _test = test_;
    }

    /// @notice Total number of handler actions that actually reached the protocol.
    function calls_total() external view returns (uint256) {
        return calls_openRequest + calls_moveRate + calls_reportStoppedEarning + calls_reportWithdraw + calls_claim;
    }

    /// @notice Fuzzer entry point: opens a redeem request for one of three allowlisted redeemers.
    /// @param userSeed Seed selecting the redeemer; three users are enough to interleave ownership
    ///        without making the recipient-balance bookkeeping ambiguous.
    /// @param amountSeed Seed for the LsETH amount, bounded to [1 gwei, 1000 ether].
    function openRequest(uint256 userSeed, uint256 amountSeed) external {
        // Step 1: cap the queue length so the invariant sweeps stay O(MAX_ENTRIES).
        if (_test.handler_requestCount() >= MAX_ENTRIES) {
            calls_skipped++;
            return;
        }
        // Step 2: bound the redeemer and the size, then delegate. The request anchors itself at the
        // live pool rate inside `_requestRedeem`, so no rate is passed here.
        _test.handler_openRequest(bound(userSeed, 0, 2), bound(amountSeed, MIN_REQUEST, MAX_REQUEST));
        calls_openRequest++;
    }

    /// @notice Fuzzer entry point: lands an oracle report that only moves the pool rate. This is the
    ///         one and only source of rate movement, which is what lets every other action price
    ///         itself coherently against the live rate.
    /// @param rateSeed Seed for the new rate, bounded to one report's worth of movement away from the
    ///        current rate and clamped to the absolute band.
    function moveRate(uint256 rateSeed) external {
        uint256 current = _test.handler_poolRate();
        uint256 low = (current * RATE_STEP_DOWN_BPS) / 10_000;
        uint256 high = (current * RATE_STEP_UP_BPS) / 10_000;
        if (low < MIN_RATE) low = MIN_RATE;
        if (high > MAX_RATE) high = MAX_RATE;
        // the clamps can cross when the walk is already pinned against a band edge
        if (low > high) low = high;
        _test.handler_moveRate(bound(rateSeed, low, high));
        calls_moveRate++;
    }

    /// @notice Fuzzer entry point: reports a stopped-earning delta. The fuzzer chooses the ETH amount
    ///         of principal that crossed exit_epoch, exactly as River does; the LsETH leg is derived
    ///         from the live rate rather than fuzzed, because River derives it too.
    /// @dev The eth leg is bounded independently of outstanding demand on purpose: over-reporting is a
    ///      supported case that `reportStoppedEarning` clamps against `totalRequestedHeight`, and the
    ///      clamp's proportional eth scaling is exactly the arithmetic invariant I4 has to survive.
    /// @param ethSeed Seed for the reported ETH leg, bounded to [1 gwei, 2000 ether].
    function reportStoppedEarning(uint256 ethSeed) external {
        if (_test.handler_rateMarkCount() >= MAX_ENTRIES) {
            calls_skipped++;
            return;
        }
        _test.handler_reportStoppedEarning(bound(ethSeed, MIN_REQUEST, 2_000 ether));
        calls_reportStoppedEarning++;
    }

    /// @notice Fuzzer entry point: settles a slice of outstanding demand with a withdrawal event,
    ///         funded at the live pool rate.
    /// @dev `reportWithdraw` reverts when the settled LsETH exceeds `RedeemDemand`, so the amount is
    ///      bounded by the live demand rather than by a constant — that is the difference between a
    ///      handler that exercises the claim path and one that only ever reverts.
    /// @dev DECLARED CARVE-OUT: this handler never produces the zero-width withdrawal event
    ///      (`{amount: 0, withdrawnEth: dust}`) that River produces when `sharesFromUnderlyingBalance`
    ///      truncates a dust ETH leg. That event is reachable and it BRICKS a spanning claim with
    ///      Panic(0x12) — see `RedemptionRoundingAndCapsTests.testZeroWidthWithdrawalEventBricksSpanningClaim`.
    ///      It is excluded here deliberately: under `fail_on_revert = false` the resulting revert would
    ///      roll the whole handler call back and be silently invisible, which is worse than not sampling
    ///      it. The two named unit tests own that case; this suite must not be read as evidence against it.
    /// @dev Bounding the LsETH seed to `[1, demand]` USED to be enough to enforce that, because the mock
    ///      took the settled LsETH as an argument. On the real report path a test funds the settlement in
    ///      ETH and River derives the LsETH leg itself, so a dust settlement at a pool rate above 1.0
    ///      lands right back on the zero-width event. The carve-out therefore has to be enforced on the
    ///      funding rather than on the seed — see `handler_reportWithdraw`.
    /// @param lsETHSeed Seed for the settled LsETH, bounded to [1, outstanding demand].
    function reportWithdraw(uint256 lsETHSeed) external {
        if (_test.handler_withdrawalEventCount() >= MAX_ENTRIES) {
            calls_skipped++;
            return;
        }
        uint256 demand = _test.handler_redeemDemand();
        if (demand == 0) {
            calls_skipped++;
            return;
        }
        _test.handler_reportWithdraw(bound(lsETHSeed, 1, demand));
        calls_reportWithdraw++;
    }

    /// @notice Fuzzer entry point: claims a request against whichever withdrawal event satisfies it.
    /// @dev The test contract skips (rather than reverts on) an unsatisfied or fully claimed request,
    ///      and only bumps this counter when a claim actually executed.
    /// @param idSeed Seed for the redeem request id, bounded to the live queue.
    /// @param depthSeed Seed for the recursion depth, bounded to [0, 4].
    function claim(uint256 idSeed, uint256 depthSeed) external {
        uint256 count = _test.handler_requestCount();
        if (count == 0) {
            calls_skipped++;
            return;
        }
        _test.handler_claim(bound(idSeed, 0, count - 1), uint16(bound(depthSeed, 0, MAX_DEPTH)));
        calls_claim++;
    }
}

/// @title Redemption fulfillment stateful invariants
/// @notice Encodes the properties that must hold after every interleaving of open / rate move /
///         stopped-earning report / withdrawal report / claim.
/// @dev The fixture deliberately starts with two PRE-upgrade (anchor-less) requests already queued
///      before `initializeRedeemManagerV1_3` runs. That is what makes the rate mark floor non-zero,
///      so I8 is a real check, and it keeps the legacy pro-rata cap branch of the claim path inside
///      the fuzzed state space alongside the anchored branch.
///
/// @dev NO PAYOUT FLOOR IS ASSERTED HERE, and that is by design rather than an omission. Every cap
///      property below is a one-sided CEILING: I2 is `paid <= capSum`, and I9 over in
///      `RedemptionRateMarkFuzzTests` is `received <= ethAtRequest + lockedAppreciation`. Nothing in
///      this contract constrains the payout from below, so a mark whose locked rate sits BELOW a
///      covered request's request-time rate — which re-prices that slice DOWNWARDS, under
///      `ethAtRequest` — satisfies all six invariants. That outcome is supported: a mark locks the
///      rate in force when the backing principal crossed exit_epoch, in both directions, so a
///      redeemer marked during a drawdown forfeits any later recovery on the marked span. The
///      handler's own rate band is deliberately wide enough to sample it (see `MIN_RATE` and
///      `RATE_STEP_DOWN_BPS` on `RedemptionInvariantHandler`). The lower-bound behaviour is owned by
///      two named tests instead, so it cannot drift silently:
///      `RedemptionRateMarkFuzzTests.testFuzz_MarkBelowRequestRateForfeitsRecovery` and
///      `SliceCapGeometryTests.testMarkBelowRequestRateRePricesSliceDownwards`.
contract RedemptionInvariantsTest is RedemptionMirror {
    RedemptionInvariantHandler internal handler;

    /// @notice The three redeemers the handler may open requests for
    address[3] internal actors;

    // ─── ghost state ────────────────────────────────────────────────────────────

    /// @custom:attribute Cumulative ETH actually delivered to recipients across all claims
    uint256 internal ghost_totalPaid;
    /// @custom:attribute Cumulative pro-rata ETH the withdrawal events supplied for matched slices
    uint256 internal ghost_totalGross;
    /// @custom:attribute Cumulative sum of the per-slice payout caps
    uint256 internal ghost_totalCap;
    /// @custom:attribute Cumulative LsETH matched by claims
    uint256 internal ghost_totalMatched;
    /// @custom:attribute Number of claims that actually executed
    uint256 internal ghost_claimCount;

    /// @custom:attribute Non-zero iff some claim paid more than its own caps allowed (I2)
    uint256 internal ghost_capOverrun;
    /// @custom:attribute Non-zero iff paid + buffered != gross for some claim (I1, per-claim form)
    uint256 internal ghost_conservationMismatch;
    /// @custom:attribute Non-zero iff the payout diverged from the independent mirror
    uint256 internal ghost_payoutMismatch;
    /// @custom:attribute Number of claims that reverted despite resolving to a real withdrawal event
    uint256 internal ghost_claimReverted;

    /// @custom:attribute Exceeding eth that oracle reports have already reclaimed into River
    /// @dev Every report drains the staged buffer, so this is the third term the conservation identity
    ///      needs: what was confiscated is either still staged, or already back with the LsETH holders.
    uint256 internal ghost_pulledExceedingEth;

    /// @custom:attribute Slices where the cap was the binding side of `min(pro-rata event ETH, cap)`
    uint256 internal ghost_capBoundSlices;
    /// @custom:attribute Slices where the event's ETH was the binding side (or tied with the cap)
    uint256 internal ghost_eventBoundSlices;

    /// @custom:attribute Per withdrawal event: pro-rata ETH consumed by matched slices
    mapping(uint32 => uint256) internal ghost_eventGross;
    /// @custom:attribute Per withdrawal event: LsETH of its demand that has been claimed
    mapping(uint32 => uint256) internal ghost_eventLsETH;
    /// @custom:attribute Per withdrawal event: how many request slices were matched against it
    mapping(uint32 => uint256) internal ghost_eventSlices;

    /// @custom:attribute Per request id (index == id): the end position recorded at creation
    uint256[] internal ghost_endPositions;
    /// @custom:attribute The rate mark floor as pinned at upgrade time, captured ONCE in `setUp`.
    /// @dev Deliberately not refreshed per action. An earlier revision reassigned this at the top of
    ///      every handler wrapper, which made `assertGe(floor, ghost_lastFloor)` in I8 compare the floor
    ///      to itself — `RateMarkFloor.set` has a single call site, `initializeRedeemManagerV1_3`, which
    ///      runs in `setUp`, so both sides were always equal and the monotonicity half of that invariant
    ///      could not fail. Frozen here so the assertion has something to catch.
    uint256 internal ghost_lastFloor;

    /// @dev Violations are recorded into the ghost counters above and asserted from the `invariant_`
    ///      functions rather than asserted in place. Not because an in-frame assertion would be lost:
    ///      ds-test's `fail()` writes the flag via `vm.store(HEVM_ADDRESS, "failed", 1)`, which Foundry
    ///      intercepts outside the EVM journal, so it survives both the handler frame and
    ///      `fail_on_revert = false`. What is lost is the DIAGNOSIS - an in-frame failure surfaces as
    ///      `[FAIL: <empty revert data>]` on every invariant at once, with the message gone. Recording the
    ///      offending delta in a ghost and asserting it from a named `invariant_` keeps the message and
    ///      points at one property.
    function setUp() public override {
        super.setUp();

        actors[0] = _generateAllowlistedUser(1);
        actors[1] = _generateAllowlistedUser(2);
        actors[2] = _generateAllowlistedUser(3);

        // Two requests opened BEFORE the upgrade and then stripped of their anchors: this is exactly
        // what a live deployment's queue looks like at cutover. It pushes the rate mark floor to
        // 17 ether and keeps the legacy cap branch reachable from the fuzzed action set.
        _reportRateLoose(1e18);
        uint32 legacyA = _openRequest(actors[0], 10 ether);
        _stripAnchor(legacyA);
        ghost_endPositions.push(10 ether);
        uint32 legacyB = _openRequest(actors[1], 7 ether);
        _stripAnchor(legacyB);
        ghost_endPositions.push(17 ether);

        _upgradeToV1_3();
        assertEq(redeemManager.getRateMarkFloor(), 17 ether, "fixture: floor must sit at the end of the legacy queue");
        ghost_lastFloor = redeemManager.getRateMarkFloor();

        handler = new RedemptionInvariantHandler(IRedemptionActions(address(this)));
        targetContract(address(handler));
    }

    // ─── state readers used by the handler to bound its inputs ──────────────────

    function handler_requestCount() external view returns (uint256) {
        return redeemManager.getRedeemRequestCount();
    }

    function handler_redeemDemand() external view returns (uint256) {
        return redeemManager.getRedeemDemand();
    }

    function handler_withdrawalEventCount() external view returns (uint256) {
        return redeemManager.getWithdrawalEventCount();
    }

    function handler_rateMarkCount() external view returns (uint256) {
        return redeemManager.getRateMarkCount();
    }

    /// @notice Total LsETH ever queued: the end position of the last request, which never moves.
    function handler_totalRequestedHeight() external view returns (uint256) {
        uint256 count = redeemManager.getRedeemRequestCount();
        if (count == 0) return 0;
        RedeemQueueV2.RedeemRequest memory last = redeemManager.getRedeemRequestDetails(uint32(count - 1));
        return last.height + last.amount;
    }

    /// @notice The live pool rate, so the handler can size its next rate step relative to it rather
    ///         than redrawing from the whole band.
    function handler_poolRate() external view returns (uint256) {
        return _poolRate();
    }

    // ─── handler action wrappers (own the cheatcodes and the ghost accounting) ──

    /// @notice Opens a request and records its immutable end position for I3.
    /// @dev The push relies on ids staying dense and sequential, so that `ghost_endPositions[i]` is the
    ///      record for request `i`. That is not asserted here: an in-frame assertion would lose its
    ///      message per the note on `setUp`, and `invariant_RequestEndPositionIsImmutable` already
    ///      catches any divergence via its length check, with a message and outside the handler frame.
    /// @dev No rate is passed: `_requestRedeem` anchors the request at the live pool rate itself, which
    ///      is what makes the anchor directly comparable to the mark and settlement rates that follow.
    function handler_openRequest(uint256 actorIdx, uint256 amount) external {
        (uint32 id,) = _openRequestLoose(actors[actorIdx], amount);
        RedeemQueueV2.RedeemRequest memory request = redeemManager.getRedeemRequestDetails(id);
        ghost_endPositions.push(request.height + request.amount);
    }

    /// @notice Lands an oracle report that only moves the pool rate. The sole source of rate movement.
    function handler_moveRate(uint256 rate) external {
        uint256 bufferBefore = redeemManager.getBufferedExceedingEth();
        _reportRateLoose(rate);
        _recordExceedingEthPull(bufferBefore);
    }

    /// @notice Reports `stoppedEarningEth` of principal that crossed exit_epoch, valued at the live rate.
    /// @dev The ETH leg is what the fuzzer chose; the LsETH leg is River's own
    ///      `sharesFromUnderlyingBalance(stoppedEarningEth)`, flooring included, derived inside the
    ///      report. The resulting mark's locked rate is therefore the pool rate, never a number the
    ///      fuzzer picked independently of it.
    function handler_reportStoppedEarning(uint256 stoppedEarningEth) external {
        uint256 bufferBefore = redeemManager.getBufferedExceedingEth();
        _reportStoppedEarning(stoppedEarningEth);
        _recordExceedingEthPull(bufferBefore);
    }

    /// @notice Pushes a withdrawal event settling `lsETH` of demand, funded at the live pool rate.
    /// @dev `withdrawnEth / amount` is the pool rate for the same reason: River funds the event out of
    ///      `BalanceToRedeem` and converts the two legs with the very same views.
    /// @dev Enforces the zero-width carve-out declared on `RedemptionInvariantHandler.reportWithdraw`.
    ///      River derives the event's LsETH leg from the ETH it was funded with, so a dust settlement at
    ///      a pool rate above 1.0 would floor that leg to zero and push the very event this suite
    ///      excludes. Funding is raised to the least that settles a single wei of demand instead.
    function handler_reportWithdraw(uint256 lsETH) external {
        uint256 rate = _poolRate();
        uint256 exitedEth = applyRate(lsETH, rate);
        if (river.sharesFromUnderlyingBalance(exitedEth) == 0) {
            exitedEth = river.underlyingBalanceFromShares(1) + 1;
        }

        uint256 bufferBefore = redeemManager.getBufferedExceedingEth();
        _reportWithdrawEth(exitedEth, rate);
        _recordExceedingEthPull(bufferBefore);
    }

    /// @notice Records the exceeding eth the report just reclaimed, so I1 still balances.
    /// @dev `_pullRedeemManagerExceedingEth` runs inside every report and moves the staged buffer back
    ///      into River, so the buffer is no longer a running total of everything ever confiscated. The
    ///      conservation identity has to carry what River has already taken back as its own term.
    /// @dev A report can only ever DRAIN the buffer -- nothing on the report path adds to it, only a
    ///      claim does -- so the drop across the call is an exact measure of the pull, and stays correct
    ///      if the APR headroom ever bounds it to a partial one.
    function _recordExceedingEthPull(uint256 bufferBefore) internal {
        uint256 bufferAfter = redeemManager.getBufferedExceedingEth();
        if (bufferBefore > bufferAfter) {
            ghost_pulledExceedingEth += bufferBefore - bufferAfter;
        }
    }

    /// @notice Claims `id` against its satisfying withdrawal event, mirroring the walk beforehand so
    ///         every wei can be attributed to the event that supplied it.
    /// @dev Skips silently when the request is unsatisfied or already fully claimed; the handler only
    ///      counts the call when a claim executed.
    /// @dev A claim that resolved to a real withdrawal event and then REVERTED used to be invisible: the
    ///      revert unwound this whole frame, taking the ghost writes and the handler's own call counter
    ///      with it, and `fail_on_revert = false` meant the run still reported green. The call is now
    ///      made through `_tryClaim`, so a revert is recorded in `ghost_claimReverted` and asserted from
    ///      `afterInvariant`, outside the reverting frame.
    function handler_claim(uint256 idSeed, uint16 depth) external {
        uint32 id = uint32(idSeed);
        int64 resolved = _resolveOn(redeemManager, id);
        if (resolved < 0) return;
        uint32 startEventId = uint32(uint64(resolved));

        // Mirror FIRST: the walk depends on the pre-claim request state.
        MirrorClaim memory expected = _mirrorClaim(redeemManager, id, startEventId, depth);
        uint256 spanStart = redeemManager.getRedeemRequestDetails(id).height;

        uint256 bufferBefore = redeemManager.getBufferedExceedingEth();
        (bool ok, uint256 paid) = _tryClaim(id, startEventId, depth);
        if (!ok) {
            ghost_claimReverted += 1;
            return;
        }
        uint256 bufferDelta = redeemManager.getBufferedExceedingEth() - bufferBefore;

        // which side of `min(pro-rata event ETH, slice cap)` decided each slice. Recorded so a run
        // cannot pass while only ever exercising one of the two: an over-funded event makes the cap win
        // unconditionally, and then the event-side truncation is never the deciding term.
        ghost_capBoundSlices += expected.capBoundSteps;
        ghost_eventBoundSlices += expected.eventBoundSteps;

        // I1, per claim: every wei the touched events supplied is either paid or buffered. This is an
        // exact identity, not an approximation — the truncation happens upstream, when `gross` itself
        // is floored out of the event's ETH.
        if (paid + bufferDelta != expected.gross) {
            ghost_conservationMismatch = 1;
        }
        // I2: the payout can never exceed the sum of the caps of the slices it was assembled from.
        if (paid > expected.capSum) {
            ghost_capOverrun = paid - expected.capSum;
        }
        // Differential: the payout must equal the independently derived one, wei for wei.
        if (paid != expected.paid) {
            ghost_payoutMismatch = paid > expected.paid ? paid - expected.paid : expected.paid - paid;
        }

        // Attribute the claim's gross back to the events that funded it, so I1 can be re-checked in
        // its per-event form once an event's demand is fully consumed. The claimed span is read off
        // the request itself: `height` moves forward by exactly the LsETH matched.
        _attributeToEvents(startEventId, spanStart, redeemManager.getRedeemRequestDetails(id).height);

        ghost_totalPaid += paid;
        ghost_totalGross += expected.gross;
        ghost_totalCap += expected.capSum;
        ghost_totalMatched += expected.matched;
        ghost_claimCount += 1;
    }

    /// @notice Claims `id` from `withdrawalEventId` at `depth`, reporting whether the call reverted
    ///         instead of propagating the revert.
    /// @dev The `try` is what keeps a reverting claim observable. Kept out of `handler_claim` so that
    ///      function's stack stays inside the limit.
    function _tryClaim(uint32 id, uint32 withdrawalEventId, uint16 depth) internal returns (bool ok, uint256 received) {
        uint32[] memory ids = new uint32[](1);
        ids[0] = id;
        uint32[] memory eventIds = new uint32[](1);
        eventIds[0] = withdrawalEventId;

        address recipient = redeemManager.getRedeemRequestDetails(id).recipient;
        uint256 balanceBefore = recipient.balance;
        try redeemManager.claimRedeemRequests(ids, eventIds, true, depth) {
            return (true, recipient.balance - balanceBefore);
        } catch {
            return (false, 0);
        }
    }

    /// @notice Splits the LsETH span `[spanStart, spanEnd)` that a claim just consumed back across the
    ///         withdrawal events that funded it, accumulating the per-event ghost totals I1 needs.
    /// @dev Walks the same event boundaries `_claimRedeemRequest` recurses over. The depth budget is
    ///      not needed here: the span the claim actually consumed already encodes where the walk
    ///      stopped. Kept out of `handler_claim` purely to keep that function's stack inside the limit.
    function _attributeToEvents(uint32 startEventId, uint256 spanStart, uint256 spanEnd) internal {
        uint256 eventCount = redeemManager.getWithdrawalEventCount();
        uint32 eventId = startEventId;
        uint256 cursor = spanStart;

        while (cursor < spanEnd && eventId < eventCount) {
            WithdrawalStack.WithdrawalEvent memory withdrawalEvent = redeemManager.getWithdrawalEventDetails(eventId);
            uint256 eventEnd = withdrawalEvent.height + withdrawalEvent.amount;
            if (eventEnd <= cursor) {
                unchecked {
                    ++eventId;
                }
                continue;
            }
            uint256 matching = eventEnd - cursor;
            if (cursor + matching > spanEnd) matching = spanEnd - cursor;
            ghost_eventGross[eventId] += (matching * withdrawalEvent.withdrawnEth) / withdrawalEvent.amount;
            ghost_eventLsETH[eventId] += matching;
            ghost_eventSlices[eventId] += 1;
            cursor += matching;
            unchecked {
                ++eventId;
            }
        }
    }

    // ─── invariants ────────────────────────────────────────────────────────────

    /// Scenario: any interleaving of requests, rate moves, stopped-earning reports, withdrawal
    /// reports and depth-bounded claims.
    /// Expected: every wei a withdrawal event supplied is accounted for exactly once — paid to a
    /// recipient or parked in the exceeding-eth buffer — and once an event's whole LsETH span has
    /// been claimed, the wei left unaccounted is at most one per request slice matched against it.
    /// Why it matters: the exceeding-eth buffer is the protocol's only sink for the difference
    /// between what an exit returned and what a redeemer is owed. If the two sides do not add up,
    /// either a redeemer was overpaid out of someone else's exit or ETH was stranded in the
    /// RedeemManager with no owner.
    function invariant_ConservationPerWithdrawalEvent() public {
        assertEq(ghost_conservationMismatch, 0, "I1: paid + buffered != event ETH for some claim");

        // global form. Every wei a withdrawal event supplied is in exactly one of three places: paid to
        // a recipient, still staged in the exceeding-eth buffer, or already reclaimed into River by a
        // later oracle report. The third term is what the report path adds -- `_pullRedeemManagerExceedingEth`
        // runs inside every report, so the buffer alone stopped being a running total.
        assertEq(
            ghost_totalPaid + redeemManager.getBufferedExceedingEth() + ghost_pulledExceedingEth,
            ghost_totalGross,
            "I1: cumulative paid + buffered + reclaimed != cumulative event ETH"
        );

        // per-event form, with the truncation dust bound stated explicitly
        uint256 eventCount = redeemManager.getWithdrawalEventCount();
        for (uint32 i = 0; i < eventCount; ++i) {
            WithdrawalStack.WithdrawalEvent memory withdrawalEvent = redeemManager.getWithdrawalEventDetails(i);
            assertLe(ghost_eventGross[i], withdrawalEvent.withdrawnEth, "I1: event over-consumed");
            assertLe(ghost_eventLsETH[i], withdrawalEvent.amount, "I1: event LsETH over-consumed");
            if (ghost_eventLsETH[i] == withdrawalEvent.amount) {
                // each slice loses at most one wei to `(matching * withdrawnEth) / amount` flooring,
                // so a fully consumed event can retain at most `slices` wei
                assertLe(
                    withdrawalEvent.withdrawnEth - ghost_eventGross[i],
                    ghost_eventSlices[i],
                    "I1: fully claimed event leaks more than one wei of dust per slice"
                );
            }
        }
    }

    /// Scenario: claims of anchored and legacy requests over arbitrary mark geometry.
    /// Expected: the ETH a claim delivers never exceeds the sum of the caps of the slices it was
    /// assembled from, and it matches an independently derived payout wei for wei.
    /// Why it matters: the cap IS the feature. It is what converts "the redeemer keeps what their
    /// stake earned in the queue" into an enforceable ceiling; without it a rich withdrawal event
    /// would pay every request the settlement rate regardless of when its principal stopped earning.
    function invariant_PayoutNeverExceedsSliceCap() public {
        assertEq(ghost_capOverrun, 0, "I2: a claim paid more than its slice caps allow");
        assertEq(ghost_payoutMismatch, 0, "I2: payout diverged from the independent mirror");
        assertLe(ghost_totalPaid, ghost_totalCap, "I2: cumulative payout exceeds cumulative cap");
    }

    /// Scenario: any number of partial claims against any number of withdrawal events.
    /// Expected: for every request, `height + amount` equals the value recorded when it was opened.
    /// Why it matters: the end position is the anchor of the whole cumulative-LsETH axis. Withdrawal
    /// events, rate marks and the next request's start position are all located relative to it, so a
    /// claim that moved it would silently re-point every downstream lookup.
    function invariant_RequestEndPositionIsImmutable() public {
        uint256 count = redeemManager.getRedeemRequestCount();
        assertEq(count, ghost_endPositions.length, "I3: queue length drifted from the ghost record");
        for (uint32 i = 0; i < count; ++i) {
            RedeemQueueV2.RedeemRequest memory request = redeemManager.getRedeemRequestDetails(i);
            assertEq(request.height + request.amount, ghost_endPositions[i], "I3: request end position moved");
        }
    }

    /// Scenario: an arbitrary sequence of stopped-earning reports interleaved with settlement.
    /// Expected: marks are strictly ascending, pairwise disjoint, and the last one ends at or below
    /// the total LsETH ever requested.
    /// Why it matters: `_findRateMarkAtOrBefore` is a predecessor binary search. It is only correct
    /// on a sorted, non-overlapping stack; an overlap would let two marks both claim the same LsETH
    /// and let a redeemer be paid the higher of the two locked rates for it.
    function invariant_RateMarksAreAscendingAndDisjoint() public {
        uint256 markCount = redeemManager.getRateMarkCount();
        if (markCount == 0) return;
        uint256 previousEnd = 0;
        for (uint32 i = 0; i < markCount; ++i) {
            RateMarkStack.RateMark memory mark = redeemManager.getRateMarkDetails(i);
            assertGt(mark.amount, 0, "I4: zero-width mark pushed");
            assertGe(mark.height, previousEnd, "I4: marks overlap or are out of order");
            previousEnd = mark.height + mark.amount;
        }
        assertLe(previousEnd, this.handler_totalRequestedHeight(), "I4: marks extend past total requested demand");
    }

    /// Scenario: any interleaving of requests, settlement and stopped-earning reports.
    /// Expected: neither the settled height nor the mark cursor ever passes the total LsETH requested.
    /// Why it matters: both cursors are compared against `totalRequestedHeight` inside
    /// `reportStoppedEarning` to size a mark. If either could overshoot, the `markable` subtraction
    /// would be computing against a position that no request occupies and marks would be issued
    /// against demand that does not exist.
    function invariant_HeightCursorsBoundedByTotalDemand() public {
        uint256 totalRequested = this.handler_totalRequestedHeight();
        assertLe(_settledHeight(), totalRequested, "I5: settled height passed total requested demand");
        assertLe(_markCursor(), totalRequested, "I5: mark cursor passed total requested demand");
    }

    /// Scenario: the fixture upgrades over a non-empty pre-existing queue, so the floor is 17 ether.
    /// Expected: the floor never decreases, and no mark ever starts below it.
    /// Why it matters: the floor is what stops the first post-upgrade reports from spending their
    /// stopped-earning credit on pre-upgrade requests that cannot use it. A mark below the floor
    /// would be silently burnt credit — the first post-upgrade cohort would be short-changed by
    /// exactly that amount, with no error anywhere.
    function invariant_RateMarkFloorIsMonotonicAndRespected() public {
        uint256 floor = redeemManager.getRateMarkFloor();
        assertGe(floor, ghost_lastFloor, "I8: rate mark floor decreased");
        uint256 markCount = redeemManager.getRateMarkCount();
        for (uint32 i = 0; i < markCount; ++i) {
            assertGe(redeemManager.getRateMarkDetails(i).height, floor, "I8: mark starts below the floor");
        }
    }

    /// @notice Foundry runs this once per completed run. Guards against a run in which the handler
    ///         bounced off every guard and the invariants above passed vacuously.
    /// @dev The two `min(gross, cap)` branch counters are deliberately NOT asserted here. A single
    ///      32-call run is not guaranteed to walk the rate far enough in both directions to produce
    ///      both, so asserting it would be flaky. Both sides are proven reachable deterministically in
    ///      `test_HandlerActionsAreAllReachable`; here they are only checked for internal consistency
    ///      against the slice count, which can never be flaky.
    function afterInvariant() public {
        assertGt(handler.calls_total(), 0, "handler performed no work in this run");
        // a claim that resolved to a real withdrawal event must not revert. Recorded during the run
        // rather than asserted inside it, because an in-frame assertion would be rolled back with the
        // reverting call and never surface under `fail_on_revert = false`.
        assertEq(ghost_claimReverted, 0, "a claim reverted on an event that resolveRedeemRequests returned");
        // if claims happened at all, they must have moved LsETH; a claim that matched nothing would
        // make every conservation check above trivially true
        if (ghost_claimCount > 0) {
            assertGt(ghost_totalMatched, 0, "claims executed but matched no LsETH");
            assertGt(ghost_capBoundSlices + ghost_eventBoundSlices, 0, "claims executed but walked no slice");
        }
    }

    /// Scenario: drive every handler entry point in a deterministic order that reaches a paid claim on
    /// both sides of `min(pro-rata event ETH, slice cap)`, then evaluate every invariant explicitly.
    /// Expected: each action lands, claims pay real ETH, the cap binds on some slices and the event's
    /// ETH binds on others, and all six invariants hold.
    /// Why it matters: two separate blind spots close here. `fail_on_revert = false` means a handler
    /// that reverted on every call would still report 128 green runs, so each action needs a standing
    /// proof of reachability. And a suite that only ever over-funds its withdrawal events makes the cap
    /// the binding side of every payout, so the event-side truncation is never the deciding term — the
    /// `capBoundSlices` / `eventBoundSlices` assertions below are what stop that from going unnoticed.
    /// @dev The rate walk is written against the handler's own step bounds: `moveRate` draws from
    ///      `[current * 0.7, current * 1.1]`, so each literal below sits inside the window its
    ///      predecessor opens and `bound` returns it unchanged. 1.0 -> 1.1 -> 1.21 is an appreciating
    ///      pool; 1.21 -> 0.847 is a 30% slash, which is what puts a settlement rate BELOW a request
    ///      rate and makes the event the binding side.
    function test_HandlerActionsAreAllReachable() external {
        // ── an appreciating pool: 1.0 -> 1.1, then two requests anchored at 1.1 ──
        handler.moveRate(1.1e18);
        handler.openRequest(0, 100 ether); // id 2, [17, 117)
        handler.openRequest(1, 50 ether); //  id 3, [117, 167)
        assertEq(handler.calls_openRequest(), 2, "openRequest did not land");

        // 60 ETH of principal stops earning, valued at the live 1.1: the mark opens at the rate mark
        // floor of 17 ether, since everything below it is pre-upgrade demand
        handler.reportStoppedEarning(uint256(60 ether));
        assertGt(redeemManager.getRateMarkCount(), 0, "no rate mark was pushed");
        assertEq(redeemManager.getRateMarkDetails(0).height, 17 ether, "mark must open at the floor");

        // ── the pool appreciates again and settles a slice ABOVE every cap in play ──
        handler.moveRate(1.21e18);
        handler.reportWithdraw(20 ether);
        assertGt(redeemManager.getWithdrawalEventCount(), 0, "no withdrawal event was pushed");

        // the two legacy (anchor-less) requests sit first on the axis, so they are what a withdrawal
        // event settles first: claiming id 0 exercises the legacy cap branch, and at a settlement rate
        // of 1.21 against a request-time rate of 1.0 the CAP is what binds
        handler.claim(0, 8);
        assertGt(ghost_capBoundSlices, 0, "no slice was decided by the cap");

        // ── then a 30% slash, so the next event settles BELOW the 1.1 the requests anchored at ──
        handler.moveRate(0.847e18);
        handler.reportWithdraw(type(uint256).max);

        // id 2 is anchored and partly marked, so it exercises the slice-cap branch; it also straddles
        // the two events, so one of its slices is capped at 1.21 and the other under-funded at 0.847
        handler.claim(2, 8);
        // id 3 sits entirely above the mark and entirely inside the slashed event, so every one of its
        // slices is decided by the event's ETH rather than by its cap
        handler.claim(3, 8);
        assertEq(handler.calls_claim(), 3, "claim did not land");
        assertGt(ghost_claimCount, 0, "no claim executed");
        assertGt(ghost_totalPaid, 0, "claims paid no ETH");
        assertGt(ghost_totalMatched, 0, "claims matched no LsETH");

        // both sides of `min(gross, cap)` were exercised, which is the whole point of walking the rate
        // down as well as up
        assertGt(ghost_capBoundSlices, 0, "no slice was decided by the cap");
        assertGt(ghost_eventBoundSlices, 0, "no slice was decided by the withdrawal event's ETH");

        invariant_ConservationPerWithdrawalEvent();
        invariant_PayoutNeverExceedsSliceCap();
        invariant_RequestEndPositionIsImmutable();
        invariant_RateMarksAreAscendingAndDisjoint();
        invariant_HeightCursorsBoundedByTotalDemand();
        invariant_RateMarkFloorIsMonotonicAndRespected();
        afterInvariant();
    }
}

/// @title Redemption fulfillment stateless fuzz properties
/// @notice The properties that are cleaner as stateless fuzz than as stateful invariants, because
///         each needs two independently constructed worlds compared against each other.
/// @dev Extends the existing fuzz coverage in contracts/test/RedeemManager.1.t.sol rather than
///      restating it: `testFuzz_MarkedRequestPayoutRespectsCapAndConservesEth` pins the single-mark
///      single-event case, `testFuzz_SplitClaimNeverPaysMoreThanWholeClaim` pins an inequality across
///      differing event geometry. Everything below is a property those do not reach.
/// @dev The two worlds a differential property needs are two STATES of the one protocol deployment,
///      separated by a snapshot rollback, rather than two deployments. See
///      `RedemptionMirror._resetToPristineProtocol` for why.
contract RedemptionRateMarkFuzzTests is RedemptionMirror {
    /// @notice Parameters of a scenario replayed identically onto two pristine protocol states
    struct Scenario {
        address user;
        uint256 amount;
        uint256 requestRate;
        uint256 markAmount;
        uint256 markRate;
        uint256 rateA;
        uint256 rateB;
        uint256 rateC;
    }

    /// @notice The single redeemer every scenario below is built for.
    /// @dev Created in `setUp` rather than per run so it survives the snapshot rollback that separates
    ///      the two worlds: an allowlist grant issued after the snapshot would be undone by the
    ///      rollback and the second world's request would revert.
    address internal fuzzUser;

    function setUp() public override {
        super.setUp();

        fuzzUser = _generateAllowlistedUser(0);
        // An empty queue at upgrade time pins the rate mark floor at 0, so every request opened by a
        // scenario below is anchored and fully markable -- the state the old `_deployFreshPair` handed
        // back.
        _upgradeToV1_3();
        assertEq(redeemManager.getRateMarkFloor(), 0, "fixture: an empty queue must pin the floor at 0");
    }

    /// @dev Builds `s` onto a pristine protocol state: one anchored request, one rate mark over its
    ///      lower `markAmount`, and three withdrawal events settling it in thirds at three different
    ///      rates. Returns the pair and the request id.
    /// @dev The pool rate is MOVED before each action and every leg is then derived from it, rather
    ///      than each action being handed a rate of its own. That is what keeps the geometry reachable:
    ///      River computes a mark's locked rate as `stoppedEarningEth / sharesFromUnderlyingBalance(...)`
    ///      and an event's settlement rate as `withdrawnEth / amount`, both from the single live rate, so
    ///      a mark priced at 2.0 while the pool sits at 1.0 is a state the protocol cannot reach. Each
    ///      rate move here is its own oracle report, standing for however many it took the pool to walk
    ///      there -- the rates are unconstrained relative to each other, only relative to the action they
    ///      price.
    /// @dev The last event settles the REMAINING demand rather than a computed third. A report funds the
    ///      RedeemManager in ETH, and River converts back with `sharesFromUnderlyingBalance`, so the
    ///      round trip `floor(floor(lsETH * rate) / rate)` can lose a wei per event. Asking for a third
    ///      three times therefore leaves the request a few wei short of exhausted, which is a property of
    ///      the conversion rather than of the claim path the caller is testing. Over-funding the last
    ///      event puts `_reportWithdrawToRedeemManager` on its full-demand branch, where it clamps to the
    ///      demand exactly and skims the excess back to the deposit buffer.
    function _buildScenario(Scenario memory s) internal returns (RedeemManagerV1 manager, uint32 id) {
        manager = redeemManager;

        _reportRateLoose(s.requestRate);
        // deliberately NOT written back into `s`: the struct is memory, so a caller that replays the
        // same scenario onto a second world would otherwise hand it the first world's opened amount as
        // the target and build a geometry a wei or two different
        (uint32 openedId, uint256 opened) = _openRequestLoose(s.user, s.amount);
        id = openedId;

        if (s.markAmount > 0) {
            _reportRateLoose(s.markRate);
            _reportStoppedEarning(applyRate(s.markAmount, s.markRate));
        }

        uint256 first = opened / 3;
        uint256 second = opened / 3;
        _reportRateLoose(s.rateA);
        _reportWithdrawEth(applyRate(first, s.rateA), s.rateA);
        _reportRateLoose(s.rateB);
        _reportWithdrawEth(applyRate(second, s.rateB), s.rateB);
        _reportRateLoose(s.rateC);
        _reportWithdrawEth(applyRate(redeemManager.getRedeemDemand(), s.rateC) + 1, s.rateC);
        assertEq(redeemManager.getRedeemDemand(), 0, "scenario: the three events must settle the whole request");
    }

    /// Scenario: the identical request, mark stack and withdrawal-event geometry is claimed twice on
    /// two pristine protocol states — once in a single unbounded call, once in K calls whose recursion
    /// depths are fuzzed independently until the request is exhausted.
    /// Expected: the two totals are EQUAL, wei for wei, for every K and every depth sequence.
    /// Why it matters: `_depth` is the escape hatch a redeemer must use when their request has been
    /// pending across more oracle reports than fits in one transaction. If splitting the walk changed
    /// the payout by even a wei, that escape hatch would carry a price, and an old request would be
    /// worth less than a new one purely because of how it had to be claimed. The existing
    /// `testFuzz_SplitClaimNeverPaysMoreThanWholeClaim` only asserts `<=`, and across differing event
    /// geometry that is all that holds; holding the geometry fixed and splitting only the walk is the
    /// stronger statement.
    function testFuzz_SplitDepthClaimPaysExactlyTheWholeClaim(
        uint256 _amount,
        uint256 _requestRate,
        uint256 _markFraction,
        uint256 _markRate,
        uint256 _rateA,
        uint256 _rateB,
        uint256 _rateC,
        uint256 _depthSeed
    ) external {
        Scenario memory s;
        s.user = fuzzUser;
        // at least a gwei, so each of the three withdrawal events settles a span that survives the
        // ETH round trip rather than flooring away to nothing
        s.amount = bound(_amount, 1 gwei, 1_000 ether);
        s.requestRate = bound(_requestRate, 0.5e18, 2e18);
        s.markAmount = (s.amount * bound(_markFraction, 0, 1e18)) / 1e18;
        s.markRate = bound(_markRate, 0.5e18, 2e18);
        s.rateA = bound(_rateA, 0.5e18, 2e18);
        s.rateB = bound(_rateB, 0.5e18, 2e18);
        s.rateC = bound(_rateC, 0.5e18, 2e18);

        uint256 pristine = vm.snapshot();

        // ── world 1: one call, unbounded depth ──────────────────────────────────
        (RedeemManagerV1 whole, uint32 idWhole) = _buildScenario(s);
        uint256 receivedWhole = _claimWithDepth(idWhole, 0, type(uint16).max);
        assertEq(whole.getRedeemRequestDetails(idWhole).amount, 0, "whole claim did not exhaust the request");
        // read out of the first world before the rollback discards its storage
        uint256 bufferedWhole = whole.getBufferedExceedingEth();

        // ── world 2: the same protocol rolled back, then K calls each with its own fuzzed depth ──
        (, RedeemManagerV1 split) = _resetToPristineProtocol(pristine);
        uint32 idSplit;
        (split, idSplit) = _buildScenario(s);
        uint256 receivedSplit = 0;
        uint256 steps = 0;
        // three events means at most three steps are ever needed; the bound is a liveness guard, and
        // the assertion below proves the loop actually finished the request rather than timed out
        for (uint256 i = 0; i < 8; ++i) {
            int64 resolved = _resolveOn(split, idSplit);
            if (resolved < 0) break;
            uint16 depth = uint16(bound(uint256(keccak256(abi.encode(_depthSeed, i))), 0, 2));
            receivedSplit += _claimWithDepth(idSplit, uint32(uint64(resolved)), depth);
            steps += 1;
        }
        assertEq(split.getRedeemRequestDetails(idSplit).amount, 0, "split claim did not exhaust the request");
        assertGt(steps, 0, "split path performed no claim");

        assertEq(receivedSplit, receivedWhole, "I6: depth-split claim total differs from the whole claim");
        // the exceeding-eth buffers must agree too, otherwise the equality above could be bought by
        // shifting wei into the buffer instead of to the recipient
        assertEq(
            split.getBufferedExceedingEth(),
            bufferedWhole,
            "I6: depth-split claim buffered a different amount of exceeding ETH"
        );
    }

    /// Scenario: the same legacy (anchor-less) request, settled at the same rate, on two pristine
    /// protocol states — one where a rate mark covers its entire span, one with no marks at all.
    /// Expected: identical payout, and it equals the request-time ETH clamped by what the event
    /// supplied.
    /// Why it matters: the PRD excludes retroactive application. A pre-upgrade request has no anchor
    /// and must be paid under the original rules forever, even though marks are pushed onto a stack
    /// that physically overlaps its positions on the cumulative axis. This is the test that the
    /// `anchor.lsETHAtRequest == 0` branch really is a hard cutover and not merely a different
    /// default.
    function testFuzz_LegacyRequestPayoutIgnoresRateMarks(
        uint256 _amount,
        uint256 _requestRate,
        uint256 _markRate,
        uint256 _settlementRate
    ) external {
        uint256 amount = bound(_amount, 1 gwei, 1_000 ether);
        uint256 requestRate = bound(_requestRate, 0.5e18, 2e18);
        // marked strictly above the request rate, so a mark that WERE read would visibly raise the cap
        uint256 markRate = bound(_markRate, 2.5e18, 4e18);
        uint256 settlementRate = bound(_settlementRate, 0.5e18, 4e18);

        address user = fuzzUser;
        uint256 pristine = vm.snapshot();

        // ── world 1: a mark covers the whole request ────────────────────────────
        // each rate move is its own oracle report, landed before the action it prices, so the mark's
        // locked rate is the pre-report rate River derives and the event's settlement rate is the
        // post-report rate it funds at -- neither is a number this test chose for it
        _reportRateLoose(requestRate);
        (uint32 idMarked, uint256 openedMarked) = _openRequestLoose(user, amount);
        uint256 requestTimeEth = redeemManager.getRedeemRequestAnchor(idMarked).ethAtRequest;
        _stripAnchor(idMarked);
        _reportRateLoose(markRate);
        _reportStoppedEarning(applyRate(openedMarked, markRate));
        assertEq(redeemManager.getRateMarkCount(), 1, "the marked world must actually carry a mark");
        _reportRateLoose(settlementRate);
        _reportWithdrawEth(applyRate(openedMarked, settlementRate), settlementRate);
        uint256 receivedMarked = _claimWithDepth(idMarked, 0, type(uint16).max);

        // ── world 2: the same protocol rolled back, identical, minus the mark ───
        // the SAME fuzzed target is opened against the same pristine state at the same rate, so the two
        // worlds carry the same position to the wei
        _resetToPristineProtocol(pristine);
        _reportRateLoose(requestRate);
        (uint32 idPlain, uint256 openedPlain) = _openRequestLoose(user, amount);
        assertEq(openedPlain, openedMarked, "the two worlds must open the same position");
        _stripAnchor(idPlain);
        assertEq(redeemManager.getRateMarkCount(), 0, "the plain world must carry no mark");
        _reportRateLoose(settlementRate);
        uint256 withdrawnEth = _reportWithdrawEth(applyRate(openedPlain, settlementRate), settlementRate);
        uint256 receivedPlain = _claimWithDepth(idPlain, 0, type(uint16).max);

        assertEq(receivedMarked, receivedPlain, "I7: a legacy request's payout changed because a mark existed");
        // and it is exactly the original rule: request-time ETH, clamped by what the event supplied
        assertEq(
            receivedPlain,
            withdrawnEth < requestTimeEth ? withdrawnEth : requestTimeEth,
            "I7: legacy payout is not the original pro-rata cap"
        );
    }

    /// Scenario: an anchored request settled by a single, deliberately over-funded withdrawal event,
    /// with a fuzzed fraction of its span marked at a fuzzed locked rate.
    /// Expected: the ETH the request receives over its whole lifetime never exceeds its request-time
    /// value plus the appreciation the marks covering it actually locked in.
    /// Why it matters: this is the economic property the entire stopped-earning feature exists to
    /// guarantee. A redeemer should keep the yield their stake earned while it sat in the exit queue,
    /// and should stop earning at exactly the moment a native staker's principal would have — not a
    /// block later. If a redeemer could be paid more than `ethAtRequest + locked appreciation`, they
    /// would be out-earning a native staker at the expense of everyone still in the pool, funded out
    /// of the exceeding-eth that would otherwise return to River.
    /// @dev The settlement rate is DERIVED as a small step above `max(requestRate, markRate)` rather
    ///      than drawn from a rich band of its own. Both halves of that matter:
    ///        - Above the max of the two cap rates, so the cap is still the binding side of
    ///          `min(pro-rata event ETH, sliceCap)` on every run. An event that under-funds the request
    ///          satisfies the ceiling trivially and would leave the property untested.
    ///        - By a SMALL step, because the previous `[3.0, 6.0]` band over-funded every event by 3x or
    ///          more against a cap of at most 3.0. That made `gross >= cap` hold by construction on
    ///          every single input, so the two truncations never competed and the event side was never
    ///          within a wei of deciding the payout. A margin of 0-10% puts them back in contention.
    ///      It is also the only version of this scenario River can reach: the settlement rate is the
    ///      pool rate at the sweeping report, so pricing the event at 6.0 while the mark that preceded
    ///      it locked 3.0 describes a pool that doubled between two reports.
    function testFuzz_RedeemerNeverOutEarnsNativeStaker(
        uint256 _amount,
        uint256 _requestRate,
        uint256 _markFraction,
        uint256 _markRate,
        uint256 _settlementMargin
    ) external {
        uint256 amount = bound(_amount, 1 gwei, 1_000 ether);
        uint256 requestRate = bound(_requestRate, 0.5e18, 2e18);
        uint256 markedAmount = (amount * bound(_markFraction, 0, 1e18)) / 1e18;
        uint256 markRate = bound(_markRate, 0.5e18, 3e18);
        uint256 capRate = markRate > requestRate ? markRate : requestRate;
        uint256 settlementRate = capRate + (capRate * bound(_settlementMargin, 0, 1_000)) / 10_000;

        address user = fuzzUser;

        _reportRateLoose(requestRate);
        (uint32 id, uint256 openedAmount) = _openRequestLoose(user, amount);
        amount = openedAmount;
        RedeemRequestAnchor.Anchor memory anchor = redeemManager.getRedeemRequestAnchor(id);

        // the pool walks to `markRate`, and the delta is valued there by River's own conversion
        uint256 markedEth = 0;
        uint256 markedLsETH = 0;
        if (markedAmount > 0 && applyRate(markedAmount, markRate) > 0) {
            _reportRateLoose(markRate);
            _reportStoppedEarning(applyRate(markedAmount, markRate));
            if (redeemManager.getRateMarkCount() > 0) {
                markedEth = redeemManager.getRateMarkDetails(0).markedEth;
                // read the LsETH leg back rather than reusing `markedAmount`: River derives it with
                // `sharesFromUnderlyingBalance`, which floors, so the mark can be a wei narrower
                markedLsETH = redeemManager.getRateMarkDetails(0).amount;
            }
        }

        _reportRateLoose(settlementRate);
        uint256 withdrawnEth = _reportWithdrawEth(applyRate(amount, settlementRate), settlementRate);
        uint256 received = _claimWithDepth(id, 0, type(uint16).max);
        assertEq(redeemManager.getRedeemRequestDetails(id).amount, 0, "request must be fully claimed");

        // the native-staker ceiling: request-time value, plus only the appreciation the marks locked
        uint256 requestValueOfMarkedSpan =
            markedLsETH == 0 ? 0 : (markedLsETH * anchor.ethAtRequest) / anchor.lsETHAtRequest;
        uint256 lockedAppreciation = markedEth > requestValueOfMarkedSpan ? markedEth - requestValueOfMarkedSpan : 0;
        uint256 ceiling = anchor.ethAtRequest + lockedAppreciation;

        assertLe(received, ceiling, "I9: redeemer out-earned a native staker");
        // and the ceiling really is the binding constraint here, not the event's ETH
        assertLe(received, withdrawnEth, "I9: paid more than the withdrawal event supplied");
        assertEq(
            redeemManager.getBufferedExceedingEth(), withdrawnEth - received, "I9: unpaid event ETH was not buffered"
        );
    }

    /// Scenario: an anchored request spanning two rate marks separated by a gap, settled by two
    /// withdrawal events at different rates and claimed in one unbounded call.
    /// Expected: the payout equals, wei for wei, the independently derived per-slice
    /// `min(pro-rata event ETH, slice cap)` sum, and never exceeds the summed caps.
    /// Why it matters: the direct, stateless form of the cap ceiling over the geometry that actually
    /// exercises all three branches of the `_sliceCap` walk — gap, covered range, and stale
    /// predecessor mark — in a single claim.
    function testFuzz_ClaimNeverExceedsSliceCapAcrossMarkGaps(
        uint256 _amount,
        uint256 _requestRate,
        uint256 _firstMarkRate,
        uint256 _secondMarkRate,
        uint256 _settlementRateA,
        uint256 _settlementRateB
    ) external {
        // large enough that the quarter-splits below are all non-zero
        uint256 amount = bound(_amount, 4 gwei, 1_000 ether);
        uint256 requestRate = bound(_requestRate, 0.5e18, 2e18);
        uint256 firstMarkRate = bound(_firstMarkRate, 0.5e18, 3e18);
        uint256 secondMarkRate = bound(_secondMarkRate, 0.5e18, 3e18);
        uint256 settlementRateA = bound(_settlementRateA, 0.5e18, 3e18);
        uint256 settlementRateB = bound(_settlementRateB, 0.5e18, 3e18);

        address user = fuzzUser;

        _reportRateLoose(requestRate);
        (uint32 id, uint256 openedAmount) = _openRequestLoose(user, amount);
        amount = openedAmount;

        // mark [0, quarter). Marking always resumes at the cursor, so to leave a GAP the second mark
        // has to be pushed after a withdrawal event has advanced the settled height past the cursor —
        // which is exactly the "settled from the deposit buffer, never exited" case the stack's @dev
        // block describes as the source of permanent gaps.
        // Each action is preceded by the rate move that prices it, so both marks carry a locked rate
        // River would have derived and both events carry a settlement rate it would have funded at.
        uint256 quarter = amount / 4;
        _reportRateLoose(firstMarkRate);
        _reportStoppedEarning(applyRate(quarter, firstMarkRate));
        _reportRateLoose(settlementRateA);
        _reportWithdrawEth(applyRate(quarter * 2, settlementRateA), settlementRateA);
        _reportRateLoose(secondMarkRate);
        _reportStoppedEarning(applyRate(quarter, secondMarkRate));
        _reportRateLoose(settlementRateB);
        _reportWithdrawEth(applyRate(amount - quarter * 2, settlementRateB), settlementRateB);

        // the geometry the test exists for: two disjoint, non-contiguous marks
        assertEq(redeemManager.getRateMarkCount(), 2, "expected exactly two marks");
        RateMarkStack.RateMark memory first = redeemManager.getRateMarkDetails(0);
        RateMarkStack.RateMark memory second = redeemManager.getRateMarkDetails(1);
        assertGt(second.height, first.height + first.amount, "expected a gap between the two marks");

        MirrorClaim memory expected = _mirrorClaim(redeemManager, id, 0, type(uint16).max);
        uint256 received = _claimWithDepth(id, 0, type(uint16).max);

        assertEq(received, expected.paid, "I2: payout diverged from the independently derived slice math");
        assertLe(received, expected.capSum, "I2: payout exceeded the summed slice caps");
        assertEq(
            received + redeemManager.getBufferedExceedingEth(),
            expected.gross,
            "I2: paid + buffered != event ETH supplied"
        );
    }

    /// Scenario: the identical anchored request on two pristine protocol states, both of which drop to
    /// a fuzzed `markRate` STRICTLY BELOW the request rate and then fully recover before the sweep.
    /// World 1 lands a stopped-earning report at the depressed rate; world 2 does not.
    /// Expected: world 1 is paid STRICTLY LESS than world 2, and less than its own request-time value.
    /// The difference is exactly what world 1 diverted to the exceeding-eth buffer.
    /// Why it matters: this is the lower-bound half of the cap, which nothing else in this suite
    /// asserts. `I2` and `I9` are both ceilings — `paid <= capSum` and
    /// `received <= ethAtRequest + lockedAppreciation` — so a mark that RE-PRICES a slice DOWNWARDS is
    /// invisible to them. It is a supported outcome, not a bug: a mark locks the rate in force when
    /// the backing principal crossed exit_epoch, in both directions, so a redeemer marked during a
    /// drawdown forfeits any later recovery on the marked span (a `CoverageFundV1` payout included).
    /// Pinned here so the forfeiture cannot change silently in either direction — this test fails if a
    /// floor at the request-time rate is ever introduced, and so does the deterministic
    /// `SliceCapGeometryTests.testMarkBelowRequestRateRePricesSliceDownwards`.
    /// @dev The settlement rate is derived as a small step ABOVE the request rate rather than fuzzed,
    ///      for the same reason `testFuzz_RedeemerNeverOutEarnsNativeStaker` derives its own: the cap
    ///      has to be the binding side of `min(pro-rata event ETH, sliceCap)` in BOTH worlds, or the
    ///      comparison degenerates into two identically under-funded events. Above the request rate,
    ///      world 2 is pinned at `ethAtRequest` and world 1 at the mark, so the gap between them is
    ///      the forfeited recovery and nothing else.
    /// @dev `markRate` is drawn strictly below `requestRate` by construction rather than by rejection,
    ///      so no run is wasted and the property holds on every input.
    function testFuzz_MarkBelowRequestRateForfeitsRecovery(
        uint256 _amount,
        uint256 _requestRate,
        uint256 _drawdownBps,
        uint256 _recoveryMargin
    ) external {
        // large enough that the drawdown's eth leg survives `sharesFromUnderlyingBalance` flooring
        uint256 amount = bound(_amount, 1 gwei, 1_000 ether);
        uint256 requestRate = bound(_requestRate, 1e18, 2e18);
        // a 5% to 50% drawdown, so `markRate < requestRate` strictly, with no rejection sampling
        uint256 markRate = (requestRate * bound(_drawdownBps, 5_000, 9_500)) / 10_000;
        // recovery to just above the request rate, so the cap binds in both worlds
        uint256 settlementRate = requestRate + (requestRate * bound(_recoveryMargin, 0, 1_000)) / 10_000;

        address user = fuzzUser;
        uint256 pristine = vm.snapshot();

        // ── world 1: drawdown, mark at the depressed rate, then recovery ────────
        _reportRateLoose(requestRate);
        (uint32 idMarked, uint256 openedMarked) = _openRequestLoose(user, amount);
        uint256 requestTimeEth = redeemManager.getRedeemRequestAnchor(idMarked).ethAtRequest;
        _reportRateLoose(markRate);
        _reportStoppedEarning(applyRate(openedMarked, markRate));
        assertEq(redeemManager.getRateMarkCount(), 1, "the marked world must actually carry a mark");
        _reportRateLoose(settlementRate);
        _reportWithdrawEth(applyRate(openedMarked, settlementRate), settlementRate);
        // mirrored before the claim, so the payout is pinned exactly and not merely bounded
        MirrorClaim memory expected = _mirrorClaim(redeemManager, idMarked, 0, type(uint16).max);
        uint256 receivedMarked = _claimWithDepth(idMarked, 0, type(uint16).max);
        uint256 bufferedMarked = redeemManager.getBufferedExceedingEth();
        assertEq(receivedMarked, expected.paid, "marked payout diverged from the independent mirror");

        // ── world 2: the same protocol rolled back, same drawdown, no mark ──────
        _resetToPristineProtocol(pristine);
        _reportRateLoose(requestRate);
        (uint32 idPlain, uint256 openedPlain) = _openRequestLoose(user, amount);
        assertEq(openedPlain, openedMarked, "the two worlds must open the same position");
        // the pool takes the same excursion; the only difference is that no exit crosses exit_epoch
        _reportRateLoose(markRate);
        assertEq(redeemManager.getRateMarkCount(), 0, "the control world must carry no mark");
        _reportRateLoose(settlementRate);
        _reportWithdrawEth(applyRate(openedPlain, settlementRate), settlementRate);
        uint256 receivedPlain = _claimWithDepth(idPlain, 0, type(uint16).max);

        // the control is held at its request-time value: the drawdown alone costs it nothing, because
        // the pool recovered before the sweep
        assertEq(receivedPlain, requestTimeEth, "control: an unmarked request is capped at ethAtRequest");
        // the mark re-priced the slice downwards, so world 1 is paid strictly less
        assertLt(receivedMarked, receivedPlain, "a mark below the request rate must lower the payout");
        assertLt(receivedMarked, requestTimeEth, "the marked request forfeited part of its request-time value");
        // and the shortfall is not lost: it was diverted to the holders who did not redeem
        assertEq(
            bufferedMarked - redeemManager.getBufferedExceedingEth(),
            receivedPlain - receivedMarked,
            "the forfeited recovery must equal the extra ETH the marked world buffered"
        );
    }
}
