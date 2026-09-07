//SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.34;

import "forge-std/StdUtils.sol";

import "./RedemptionReportBase.sol";

import "../../src/state/redeemManager/WithdrawalStack.sol";
import "../../src/state/redeemManager/RateMarkStack.sol";
import "../../src/state/redeemManager/RedeemRequestAnchor.sol";

/// @notice The external surface the stateful handler drives. The handler has no cheatcode access, so
///         every action needing `vm` is delegated back to the test contract, which owns the ghosts.
/// @dev Mirrors the `IAccountingActions` idiom of contracts/test/accounting/invariant/AccountingHandler.sol.
interface IRedemptionActions {
    function handler_openRequest(uint256 userSeed, uint256 amount) external;
    function handler_moveRate(uint256 rate) external;
    function handler_reportStoppedEarning(uint256 stoppedEarningEth) external;
    function handler_reportWithdraw(uint256 lsETH) external;
    function handler_claim(uint256 idSeed, uint16 depth) external returns (bool claimed);

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
/// @dev The contract's own walk binary-searches the mark stack; this mirror scans it linearly, so a
///      bug in the predecessor search cannot be reproduced identically here and cancel out.
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
    /// @dev Anchored requests only: the legacy branch depends on the decrementing ETH budget rather
    ///      than on the mark stack, and so lives in `_mirrorClaim`.
    function _mirrorSliceCap(
        RedeemManagerV1 manager,
        RedeemRequestAnchor.Anchor memory anchor,
        uint256 sliceStart,
        uint256 sliceAmount
    ) internal view returns (uint256 cap) {
        uint256 markCount = manager.getRateMarkCount();
        uint256 cursor = sliceStart;
        uint256 remaining = sliceAmount;

        // linear predecessor scan: drop every mark terminating at or below the slice start, leaving a
        // survivor that either starts above the cursor (a gap) or contains it
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
                // past the last mark, so the remainder takes the request-time rate
                cap += (remaining * anchor.ethAtRequest) / anchor.lsETHAtRequest;
                return cap;
            }
            RateMarkStack.RateMark memory mark = manager.getRateMarkDetails(uint32(idx));
            if (cursor < mark.height) {
                // a gap: LsETH here never stopped earning, so it keeps the request-time rate
                uint256 unmarked = mark.height - cursor;
                if (unmarked > remaining) unmarked = remaining;
                cap += (unmarked * anchor.ethAtRequest) / anchor.lsETHAtRequest;
                cursor += unmarked;
                remaining -= unmarked;
                continue;
            }
            // covered, so the mark's locked rate applies over the covered portion only
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
        // the legacy cap reads the decrementing ETH budget, which the claim path mutates between
        // recursion frames, so the mirror carries it too
        uint256 budget = request.maxRedeemableEth;
        // one step, then recursion only while `depth > 0`
        uint256 stepsLeft = uint256(depth) + 1;
        uint32 eventId = startEventId;

        while (stepsLeft > 0 && remaining > 0 && eventId < eventCount) {
            WithdrawalStack.WithdrawalEvent memory withdrawalEvent = manager.getWithdrawalEventDetails(eventId);
            uint256 eventEnd = withdrawalEvent.height + withdrawalEvent.amount;
            // a caller passing a non-matching event would revert on-chain anyway
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
            // which side of `min(gross, cap)` decided this slice, counted per slice rather than per
            // claim: one claim routinely walks an over-funding event and an under-funding one
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

    /// @notice Rolls the protocol back to `snapshotId`, so a scenario can be replayed onto a pristine
    ///         deployment without redeploying River, Oracle, OperatorsRegistry and AttestationVerifier
    ///         once per fuzz run per world.
    /// @dev Anything needed from the world being left must be read BEFORE this call: only values
    ///      already in memory survive the rollback.
    function _resetToPristineProtocol(uint256 snapshotId)
        internal
        returns (RedemptionRiverV1 freshRiver, RedeemManagerV1 freshManager)
    {
        assertTrue(vm.revertToState(snapshotId), "failed to roll the protocol back to its pristine state");
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
/// @dev Bounding keeps `fail_on_revert = false` from hiding a broken handler: an action that would
///      revert is bounded or skipped, so the counters measure work done, not calls attempted.
/// @dev RATE COHERENCE. `moveRate` is the only action that moves the rate; every other prices itself
///      against the live one. River derives both legs of a stopped-earning report and of an event from
///      one rate (LibOracleReporting L217-219, L588-613), so fuzzing a mark rate and a settlement rate
///      independently would sample mostly unreachable states -- and would miss the case that matters,
///      where the three rates sit within a few percent and the `min()` turns on which truncation
///      lands lower.
contract RedemptionInvariantHandler is StdUtils {
    /// @notice Ceiling on queue/stack growth, so the O(n) invariant sweeps stay cheap at depth 32
    uint256 private constant MAX_ENTRIES = 24;
    /// @notice Below ~1 gwei every rate multiplication floors to 0 and the run degenerates into no-ops
    uint256 private constant MIN_REQUEST = 1 gwei;
    uint256 private constant MAX_REQUEST = 1_000 ether;
    /// @notice Absolute rate band: wide enough to cross 1.0 in both directions, since a marked rate
    ///         below the request rate must LOWER the cap, and narrow enough that no product overflows.
    uint256 private constant MIN_RATE = 0.5e18;
    uint256 private constant MAX_RATE = 3e18;
    /// @notice Per-report rate step, taken as a fraction of the LIVE rate rather than redrawn from the
    ///         band: one report can mass-slash or pay an unusually large reward, but it cannot teleport
    ///         from 0.5 to 3.0. Bounding the step keeps request, mark and settlement rates close enough
    ///         together for the two truncations to compete.
    uint256 private constant RATE_STEP_DOWN_BPS = 7_000; // -30% in a single report
    uint256 private constant RATE_STEP_UP_BPS = 11_000; // +10% in a single report
    /// @notice Recursion depth band, small on purpose: a truncated walk leaves a request half-settled
    ///         for the next action to resume, which is the interesting case.
    uint256 private constant MAX_DEPTH = 4;

    IRedemptionActions private _test;

    // ─── call counters (used by afterInvariant to prove the run was not vacuous) ─────

    uint256 public calls_openRequest;
    uint256 public calls_moveRate;
    uint256 public calls_reportStoppedEarning;
    uint256 public calls_reportWithdraw;
    uint256 public calls_claim;
    /// @notice Actions that bounced off a guard without reaching the protocol, a claim finding nothing
    ///         satisfied included. Asserted zero over the deterministic sequence below, so it has a
    ///         consumer.
    uint256 public calls_skipped;

    constructor(IRedemptionActions test_) {
        _test = test_;
    }

    /// @notice Total number of handler actions that actually reached the protocol.
    function calls_total() external view returns (uint256) {
        return calls_openRequest + calls_moveRate + calls_reportStoppedEarning + calls_reportWithdraw + calls_claim;
    }

    /// @notice Opens a redeem request for one of three allowlisted redeemers -- enough to interleave
    ///         ownership without making the recipient-balance bookkeeping ambiguous.
    /// @dev No rate is passed: `_requestRedeem` anchors the request at the live pool rate.
    function openRequest(uint256 userSeed, uint256 amountSeed) external {
        if (_test.handler_requestCount() >= MAX_ENTRIES) {
            calls_skipped++;
            return;
        }
        _test.handler_openRequest(bound(userSeed, 0, 2), bound(amountSeed, MIN_REQUEST, MAX_REQUEST));
        calls_openRequest++;
    }

    /// @notice Lands an oracle report that only moves the pool rate, bounded to one report's worth of
    ///         movement and clamped to the absolute band. The sole source of rate movement.
    function moveRate(uint256 rateSeed) external {
        uint256 current = _test.handler_poolRate();
        uint256 low = (current * RATE_STEP_DOWN_BPS) / 10_000;
        uint256 high = (current * RATE_STEP_UP_BPS) / 10_000;
        if (low < MIN_RATE) low = MIN_RATE;
        if (high > MAX_RATE) high = MAX_RATE;
        // the clamps can cross once the walk is pinned against a band edge
        if (low > high) low = high;
        _test.handler_moveRate(bound(rateSeed, low, high));
        calls_moveRate++;
    }

    /// @notice Reports a stopped-earning delta. The fuzzer chooses the ETH leg, as River does; the
    ///         LsETH leg is derived from the live rate because River derives it too.
    /// @dev The eth leg is bounded independently of outstanding demand on purpose: over-reporting is
    ///      supported, clamped against `totalRequestedHeight`, and that clamp's proportional eth scaling
    ///      is the arithmetic I4 has to survive.
    function reportStoppedEarning(uint256 ethSeed) external {
        if (_test.handler_rateMarkCount() >= MAX_ENTRIES) {
            calls_skipped++;
            return;
        }
        _test.handler_reportStoppedEarning(bound(ethSeed, MIN_REQUEST, 2_000 ether));
        calls_reportStoppedEarning++;
    }

    /// @notice Settles a slice of outstanding demand with a withdrawal event funded at the live rate.
    /// @dev Bounded by the live demand rather than a constant, since `reportWithdraw` reverts above
    ///      `RedeemDemand`.
    /// @dev CARVE-OUT: never produces a zero-width event, which is reachable and bricks a spanning claim
    ///      with Panic(0x12) -- owned by
    ///      `RedemptionRoundingAndCapsTests.testZeroWidthWithdrawalEventBricksSpanningClaim`. Excluded
    ///      because under `fail_on_revert = false` the revert would roll the handler call back and be
    ///      invisible, so this suite is no evidence against that finding. Enforced in
    ///      `handler_reportWithdraw`.
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

    /// @notice Claims a request against whichever withdrawal event satisfies it.
    /// @dev `calls_claim` is bumped only when `handler_claim` reports that a claim executed -- the test
    ///      contract returns rather than reverts when nothing is satisfied -- because `afterInvariant`
    ///      asserts `calls_claim == ghost_claimCount`.
    function claim(uint256 idSeed, uint256 depthSeed) external {
        uint256 count = _test.handler_requestCount();
        if (count == 0) {
            calls_skipped++;
            return;
        }
        if (!_test.handler_claim(bound(idSeed, 0, count - 1), uint16(bound(depthSeed, 0, MAX_DEPTH)))) {
            calls_skipped++;
            return;
        }
        calls_claim++;
    }
}

/// @title Redemption fulfillment stateful invariants
/// @notice Encodes the properties that must hold after every interleaving of open / rate move /
///         stopped-earning report / withdrawal report / claim.
/// @dev Two pre-upgrade (anchor-less) requests are queued before `initializeRedeemManagerV1_3` runs,
///      which makes the floor non-zero -- so I8 is a real check -- and keeps the legacy cap branch in
///      the fuzzed state space.
/// @dev No payout floor is asserted: every cap property here is a one-sided ceiling, so a mark
///      re-pricing a slice downwards satisfies all six. The lower bound is owned by
///      `testFuzz_MarkBelowRequestRateForfeitsRecovery` and
///      `SliceCapGeometryTests.testMarkBelowRequestRateRePricesSliceDownwards`.
contract RedemptionInvariantsTest is RedemptionMirror {
    RedemptionInvariantHandler internal handler;

    /// @notice The three redeemers the handler may open requests for
    address[3] internal actors;

    // ─── ghost state ────────────────────────────────────────────────────────────

    // the `MirrorClaim` fields, accumulated across every claim that executed
    uint256 internal ghost_totalPaid;
    uint256 internal ghost_totalGross;
    uint256 internal ghost_totalCap;
    uint256 internal ghost_totalMatched;
    uint256 internal ghost_claimCount;

    /// @custom:attribute Non-zero iff some claim paid more than its own caps allowed (I2)
    uint256 internal ghost_capOverrun;
    /// @custom:attribute Non-zero iff paid + buffered != gross for some claim (I1, per-claim form)
    uint256 internal ghost_conservationMismatch;
    /// @custom:attribute Non-zero iff the payout diverged from the independent mirror
    uint256 internal ghost_payoutMismatch;
    /// @custom:attribute Number of claims that reverted despite resolving to a real withdrawal event
    uint256 internal ghost_claimReverted;

    /// @custom:attribute Exceeding eth that reports have already reclaimed into River -- the third term
    ///                   the conservation identity needs, since what was confiscated is either still
    ///                   staged or already back with the holders
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
    /// @custom:attribute The rate mark floor as pinned at upgrade time, captured once in `setUp`
    /// @dev Must not be refreshed per action, or I8's `assertGe(floor, ghost_lastFloor)` compares the
    ///      floor to itself: `RateMarkFloor.set` is only called from `initializeRedeemManagerV1_3`,
    ///      which runs in `setUp`, so the monotonicity half could never fail.
    uint256 internal ghost_lastFloor;

    /// @dev Violations are recorded into the ghost counters above and asserted from the `invariant_`
    ///      functions rather than in place. An in-frame assertion would not be lost -- ds-test's
    ///      `fail()` writes outside the EVM journal -- but the diagnosis would be: it surfaces as
    ///      `[FAIL: <empty revert data>]` on every invariant at once, message gone.
    function setUp() public override {
        super.setUp();

        actors[0] = _generateAllowlistedUser(1);
        actors[1] = _generateAllowlistedUser(2);
        actors[2] = _generateAllowlistedUser(3);

        // two requests opened BEFORE the upgrade and stripped of their anchors, as a live deployment's
        // queue looks at cutover: the floor lands at 17 ether and the legacy cap branch stays reachable
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

        // one event over the lower 5 ether of the legacy queue, so a claim pays from the fuzzer's first
        // call: without it a run must draw open -> withdrawal report -> claim in that order before a wei
        // moves, and a run missing that ordering satisfies all six invariants vacuously -- which was the
        // common case, not a corner. Partial on purpose, so `RedeemDemand` stays non-zero and request 0
        // stays half-settled for the legacy branch.
        _reportWithdraw(5 ether, 1e18);

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

    /// @notice Total LsETH ever queued: the last request's end position, which never moves.
    function handler_totalRequestedHeight() external view returns (uint256) {
        uint256 count = redeemManager.getRedeemRequestCount();
        if (count == 0) return 0;
        RedeemQueueV2.RedeemRequest memory last = redeemManager.getRedeemRequestDetails(uint32(count - 1));
        return last.height + last.amount;
    }

    /// @notice The live pool rate, so the handler can size its next step relative to it.
    function handler_poolRate() external view returns (uint256) {
        return _poolRate();
    }

    // ─── handler action wrappers (own the cheatcodes and the ghost accounting) ──

    /// @notice Opens a request and records its immutable end position for I3.
    /// @dev Relies on ids staying dense and sequential, so `ghost_endPositions[i]` is request `i`. Not
    ///      asserted here -- an in-frame assertion would lose its message per the note on `setUp`, and
    ///      `invariant_RequestEndPositionIsImmutable` catches divergence via its length check.
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

    /// @notice Reports `stoppedEarningEth` of principal that crossed exit_epoch, at the live rate.
    /// @dev Only the ETH leg is the fuzzer's; the LsETH leg is River's own
    ///      `sharesFromUnderlyingBalance`, flooring included, so the mark's locked rate is the pool
    ///      rate rather than a number the fuzzer picked independently of it.
    function handler_reportStoppedEarning(uint256 stoppedEarningEth) external {
        uint256 bufferBefore = redeemManager.getBufferedExceedingEth();
        _reportStoppedEarning(stoppedEarningEth);
        _recordExceedingEthPull(bufferBefore);
    }

    /// @notice Pushes a withdrawal event settling `lsETH` of demand, funded at the live pool rate, so
    ///         `withdrawnEth / amount` is that rate: River converts both legs with the same views.
    /// @dev Enforces the zero-width carve-out declared on `RedemptionInvariantHandler.reportWithdraw`
    ///      by raising dust funding to the least that settles a single wei of demand.
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
    /// @dev A report can only drain the buffer -- only a claim adds to it -- so the drop across the call
    ///      measures the pull exactly, and stays correct if APR headroom ever makes it partial.
    function _recordExceedingEthPull(uint256 bufferBefore) internal {
        uint256 bufferAfter = redeemManager.getBufferedExceedingEth();
        if (bufferBefore > bufferAfter) {
            ghost_pulledExceedingEth += bufferBefore - bufferAfter;
        }
    }

    /// @notice Claims `id` against its satisfying withdrawal event, mirroring the walk beforehand so
    ///         every wei can be attributed to the event that supplied it. Returns whether a claim
    ///         executed, so `calls_claim` means exactly that; both early returns are skips.
    /// @dev Goes through `_tryClaim` so a claim that resolved to a real event and then reverted stays
    ///      visible: an uncaught revert would unwind this frame with the ghost writes and the counter,
    ///      and `fail_on_revert = false` would still report green. Reverts land in
    ///      `ghost_claimReverted`, asserted from `afterInvariant`.
    function handler_claim(uint256 idSeed, uint16 depth) external returns (bool claimed) {
        (bool found, uint32 id, uint32 startEventId) = _firstResolvableFrom(idSeed);
        if (!found) return false;

        // mirror FIRST: the walk depends on the pre-claim request state
        MirrorClaim memory expected = _mirrorClaim(redeemManager, id, startEventId, depth);
        uint256 spanStart = redeemManager.getRedeemRequestDetails(id).height;

        uint256 bufferBefore = redeemManager.getBufferedExceedingEth();
        (bool ok, uint256 paid) = _tryClaim(id, startEventId, depth);
        if (!ok) {
            ghost_claimReverted += 1;
            return false;
        }
        uint256 bufferDelta = redeemManager.getBufferedExceedingEth() - bufferBefore;

        // recorded so a run cannot pass while only ever exercising one side of the `min()`
        ghost_capBoundSlices += expected.capBoundSteps;
        ghost_eventBoundSlices += expected.eventBoundSteps;

        // I1, per claim: every wei the touched events supplied is paid or buffered. Exact, not
        // approximate -- the truncation happens upstream, where `gross` is floored out of the event.
        if (paid + bufferDelta != expected.gross) {
            ghost_conservationMismatch = 1;
        }
        if (paid > expected.capSum) {
            ghost_capOverrun = paid - expected.capSum;
        }
        if (paid != expected.paid) {
            ghost_payoutMismatch = paid > expected.paid ? paid - expected.paid : expected.paid - paid;
        }

        // attribute the gross back to the funding events, so I1 can be re-checked per event once one
        // is fully consumed. The span is read off the request: `height` moves by the LsETH matched.
        _attributeToEvents(startEventId, spanStart, redeemManager.getRedeemRequestDetails(id).height);

        ghost_totalPaid += paid;
        ghost_totalGross += expected.gross;
        ghost_totalCap += expected.capSum;
        ghost_totalMatched += expected.matched;
        ghost_claimCount += 1;
        return true;
    }

    /// @notice The first request at or after `idSeed`, wrapping once, that a withdrawal event
    ///         currently satisfies, with the id of that event.
    /// @dev A claim landing on an unsatisfied request wastes one of the run's 32 actions, so those
    ///      draws are redirected. The seed still chooses among the satisfied requests, preserving the
    ///      interleaving the fuzzer explores.
    function _firstResolvableFrom(uint256 idSeed)
        internal
        view
        returns (bool found, uint32 id, uint32 withdrawalEventId)
    {
        uint256 count = redeemManager.getRedeemRequestCount();
        for (uint256 offset = 0; offset < count; ++offset) {
            uint32 candidate = uint32((idSeed + offset) % count);
            int64 resolved = _resolveOn(redeemManager, candidate);
            if (resolved >= 0) {
                return (true, candidate, uint32(uint64(resolved)));
            }
        }
        return (false, 0, 0);
    }

    /// @notice Claims `id` from `withdrawalEventId` at `depth`, reporting a revert rather than
    ///         propagating it. Split out to keep `handler_claim`'s stack inside the limit.
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

    /// @notice Splits the consumed span `[spanStart, spanEnd)` back across the events that funded it,
    ///         accumulating the per-event ghost totals I1 needs.
    /// @dev Walks the same boundaries `_claimRedeemRequest` recurses over. No depth budget is needed:
    ///      the consumed span already encodes where the walk stopped.
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

    /// Expected: every wei a withdrawal event supplied is accounted for once -- paid or buffered -- and
    /// a fully claimed event leaves at most one wei per matched slice unaccounted.
    /// Why it matters: the buffer is the only sink for the difference between what an exit returned and
    /// what a redeemer is owed, so if the sides do not add up, either a redeemer was overpaid out of
    /// someone else's exit or ETH is stranded with no owner.
    function invariant_ConservationPerWithdrawalEvent() public {
        assertEq(ghost_conservationMismatch, 0, "I1: paid + buffered != event ETH for some claim");

        // global form: paid to a recipient, still staged, or already reclaimed into River
        assertEq(
            ghost_totalPaid + redeemManager.getBufferedExceedingEth() + ghost_pulledExceedingEth,
            ghost_totalGross,
            "I1: cumulative paid + buffered + reclaimed != cumulative event ETH"
        );

        uint256 eventCount = redeemManager.getWithdrawalEventCount();
        for (uint32 i = 0; i < eventCount; ++i) {
            WithdrawalStack.WithdrawalEvent memory withdrawalEvent = redeemManager.getWithdrawalEventDetails(i);
            assertLe(ghost_eventGross[i], withdrawalEvent.withdrawnEth, "I1: event over-consumed");
            assertLe(ghost_eventLsETH[i], withdrawalEvent.amount, "I1: event LsETH over-consumed");
            if (ghost_eventLsETH[i] == withdrawalEvent.amount) {
                // each slice loses at most one wei to `(matching * withdrawnEth) / amount` flooring
                assertLe(
                    withdrawalEvent.withdrawnEth - ghost_eventGross[i],
                    ghost_eventSlices[i],
                    "I1: fully claimed event leaks more than one wei of dust per slice"
                );
            }
        }
    }

    /// Expected: over anchored and legacy requests alike, the ETH a claim delivers never exceeds the
    /// summed caps of its slices, and matches an independently derived payout wei for wei.
    /// Why it matters: the cap is the feature -- it turns "the redeemer keeps what their stake earned in
    /// the queue" into an enforceable ceiling, without which a rich event would pay every request the
    /// settlement rate regardless of when its principal stopped earning.
    function invariant_PayoutNeverExceedsSliceCap() public {
        assertEq(ghost_capOverrun, 0, "I2: a claim paid more than its slice caps allow");
        assertEq(ghost_payoutMismatch, 0, "I2: payout diverged from the independent mirror");
        assertLe(ghost_totalPaid, ghost_totalCap, "I2: cumulative payout exceeds cumulative cap");
    }

    /// Expected: under any number of partial claims, every request's `height + amount` equals the value
    /// recorded when it was opened.
    /// Why it matters: events, marks and the next request's start position are all located relative to
    /// that end position, so a claim moving it would silently re-point every downstream lookup.
    function invariant_RequestEndPositionIsImmutable() public {
        uint256 count = redeemManager.getRedeemRequestCount();
        assertEq(count, ghost_endPositions.length, "I3: queue length drifted from the ghost record");
        for (uint32 i = 0; i < count; ++i) {
            RedeemQueueV2.RedeemRequest memory request = redeemManager.getRedeemRequestDetails(i);
            assertEq(request.height + request.amount, ghost_endPositions[i], "I3: request end position moved");
        }
    }

    /// Expected: marks stay strictly ascending and pairwise disjoint, the last ending at or below the
    /// total LsETH ever requested.
    /// Why it matters: `_findRateMarkAtOrBefore` is a predecessor binary search, correct only on a
    /// sorted non-overlapping stack; an overlap would let two marks claim the same LsETH and pay the
    /// higher of the two locked rates.
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

    /// Expected: neither the settled height nor the mark cursor passes the total LsETH requested.
    /// Why it matters: `reportStoppedEarning` sizes a mark by comparing both cursors against
    /// `totalRequestedHeight`, so an overshoot would compute `markable` against a position no request
    /// occupies and issue marks against demand that does not exist.
    function invariant_HeightCursorsBoundedByTotalDemand() public {
        uint256 totalRequested = this.handler_totalRequestedHeight();
        assertLe(_settledHeight(), totalRequested, "I5: settled height passed total requested demand");
        assertLe(_markCursor(), totalRequested, "I5: mark cursor passed total requested demand");
    }

    /// Expected: with the fixture upgrading over a non-empty queue, the floor never decreases and no
    /// mark starts below it.
    /// Why it matters: the floor stops the first post-upgrade reports from spending their credit on
    /// requests that cannot use it, so a mark below it is silently burnt credit -- the first
    /// post-upgrade cohort short-changed by that amount, with no error anywhere.
    function invariant_RateMarkFloorIsMonotonicAndRespected() public {
        uint256 floor = redeemManager.getRateMarkFloor();
        assertGe(floor, ghost_lastFloor, "I8: rate mark floor decreased");
        uint256 markCount = redeemManager.getRateMarkCount();
        for (uint32 i = 0; i < markCount; ++i) {
            assertGe(redeemManager.getRateMarkDetails(i).height, floor, "I8: mark starts below the floor");
        }
    }

    /// @notice Runs once per completed run, guarding against one where the handler bounced off every
    ///         guard and the invariants passed vacuously.
    /// @dev `ghost_claimCount > 0` is not asserted, for an arithmetic reason: across five selectors a
    ///      32-call run misses `claim` with probability (4/5)^32 ~= 0.08%, one campaign in ten over 128
    ///      runs, and Foundry offers no cross-run aggregation. Vacuity is attacked by construction
    ///      instead, in `setUp` and `_firstResolvableFrom`. The `min(gross, cap)` branch counters are
    ///      likewise unasserted, being proven reachable in `test_HandlerActionsAreAllReachable`.
    function afterInvariant() public {
        assertGt(handler.calls_total(), 0, "handler performed no work in this run");
        // recorded during the run rather than asserted inside it: an in-frame assertion would be rolled
        // back with the reverting call and never surface under `fail_on_revert = false`
        assertEq(ghost_claimReverted, 0, "a claim reverted on an event that resolveRedeemRequests returned");

        assertEq(handler.calls_claim(), ghost_claimCount, "calls_claim disagrees with the number of claims executed");

        if (ghost_claimCount > 0) {
            assertGt(ghost_totalMatched, 0, "claims executed but matched no LsETH");
            assertGt(ghost_capBoundSlices + ghost_eventBoundSlices, 0, "claims executed but walked no slice");
        }
    }

    /// Expected: driven in a deterministic order, each action lands, claims pay real ETH, the cap binds
    /// on some slices and the event's ETH on others, and all six invariants hold.
    /// Why it matters: two blind spots. Under `fail_on_revert = false` a handler reverting on every call
    /// would still report 128 green runs, so each action needs a standing proof of reachability; and a
    /// suite that only over-funds its events never lets the event-side truncation decide a payout.
    /// @dev The rate literals are written against `moveRate`'s step bounds of
    ///      `[current * 0.7, current * 1.1]`, so each sits inside the window its predecessor opens and
    ///      `bound` returns it unchanged.
    function test_HandlerActionsAreAllReachable() external {
        // ── an appreciating pool: 1.0 -> 1.1, then two requests anchored at 1.1 ──
        handler.moveRate(1.1e18);
        handler.openRequest(0, 100 ether); // id 2, [17, 117)
        handler.openRequest(1, 50 ether); //  id 3, [117, 167)
        assertEq(handler.calls_openRequest(), 2, "openRequest did not land");

        // the mark opens at the floor of 17 ether, everything below it being pre-upgrade demand
        handler.reportStoppedEarning(uint256(60 ether));
        assertGt(redeemManager.getRateMarkCount(), 0, "no rate mark was pushed");
        assertEq(redeemManager.getRateMarkDetails(0).height, 17 ether, "mark must open at the floor");

        // ── the pool appreciates again and settles a slice ABOVE every cap in play ──
        handler.moveRate(1.21e18);
        handler.reportWithdraw(20 ether);
        assertGt(redeemManager.getWithdrawalEventCount(), 0, "no withdrawal event was pushed");

        // the legacy requests sit first on the axis, so claiming id 0 exercises the legacy cap branch,
        // and at 1.21 against a request-time 1.0 the cap binds
        handler.claim(0, 8);
        assertGt(ghost_capBoundSlices, 0, "no slice was decided by the cap");

        // ── then a 30% slash, so the next event settles BELOW the 1.1 the requests anchored at ──
        handler.moveRate(0.847e18);
        handler.reportWithdraw(type(uint256).max);

        // id 2 is anchored and partly marked, and straddles the two events: one slice capped at 1.21,
        // the other under-funded at 0.847
        handler.claim(2, 8);
        // id 3 sits above the mark and inside the slashed event, so its slices are event-decided
        handler.claim(3, 8);
        assertEq(handler.calls_claim(), 3, "claim did not land");
        // the counter has to mean "a claim executed" rather than "attempted", and every action here was
        // chosen to do real work, so nothing may have bounced off a guard either
        assertEq(handler.calls_claim(), ghost_claimCount, "calls_claim counted a claim that did nothing");
        assertEq(handler.calls_skipped(), 0, "an action in the deterministic sequence bounced off a guard");
        assertGt(ghost_claimCount, 0, "no claim executed");
        assertGt(ghost_totalPaid, 0, "claims paid no ETH");
        assertGt(ghost_totalMatched, 0, "claims matched no LsETH");

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
/// @notice Properties cleaner as stateless fuzz than as stateful invariants, each needing two worlds
///         compared against each other -- two states of one deployment, separated by a rollback.
/// @dev Extends contracts/test/RedeemManager.1.t.sol rather than restating it:
///      `testFuzz_MarkedRequestPayoutRespectsCapAndConservesEth` pins the single-mark single-event case
///      and `testFuzz_SplitClaimNeverPaysMoreThanWholeClaim` an inequality across differing geometry.
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

    /// @notice The single redeemer every scenario below is built for, created in `setUp` so it survives
    ///         the rollback: a grant issued after the snapshot would be undone and the second world's
    ///         request revert.
    address internal fuzzUser;

    function setUp() public override {
        super.setUp();

        fuzzUser = _generateAllowlistedUser(0);
        // an empty queue at upgrade time pins the floor at 0, so every request below is anchored and
        // fully markable
        _upgradeToV1_3();
        assertEq(redeemManager.getRateMarkFloor(), 0, "fixture: an empty queue must pin the floor at 0");
    }

    /// @dev Builds `s` onto a pristine protocol state: one anchored request, one mark over its lower
    ///      `markAmount`, and three events settling it in thirds at three rates.
    /// @dev Every leg is derived from the live rate, moved beforehand, since River computes a mark's
    ///      locked rate and an event's settlement rate from it -- a mark priced at 2.0 against a 1.0
    ///      pool is unreachable. Each rate move stands for however many reports it took to walk there.
    /// @dev The last event settles the remaining demand rather than a computed third: the ETH round trip
    ///      `floor(floor(lsETH * rate) / rate)` can lose a wei per event, so three thirds would leave
    ///      the request short of exhausted. Over-funding puts `_reportWithdrawToRedeemManager` on its
    ///      full-demand branch, which clamps to the demand exactly and skims the excess back.
    function _buildScenario(Scenario memory s) internal returns (RedeemManagerV1 manager, uint32 id) {
        manager = redeemManager;

        _reportRateLoose(s.requestRate);
        // not written back into `s`: a caller replaying onto a second world would otherwise pass the
        // first world's opened amount as the target and build a geometry a wei or two different
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

    /// Scenario: identical request, mark stack and event geometry claimed on two pristine states -- once
    /// in a single unbounded call, once in K calls at independently fuzzed depths.
    /// Expected: the totals are equal wei for wei, for every K and every depth sequence.
    /// Why it matters: `_depth` is the escape hatch for a request pending across more reports than fit
    /// in one transaction, so if splitting changed the payout an old request would be worth less than a
    /// new one purely for how it had to be claimed. Stronger than
    /// `testFuzz_SplitClaimNeverPaysMoreThanWholeClaim`, which can only assert `<=`.
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
        // at least a gwei, so each event settles a span that survives the ETH round trip
        s.amount = bound(_amount, 1 gwei, 1_000 ether);
        s.requestRate = bound(_requestRate, 0.5e18, 2e18);
        s.markAmount = (s.amount * bound(_markFraction, 0, 1e18)) / 1e18;
        s.markRate = bound(_markRate, 0.5e18, 2e18);
        s.rateA = bound(_rateA, 0.5e18, 2e18);
        s.rateB = bound(_rateB, 0.5e18, 2e18);
        s.rateC = bound(_rateC, 0.5e18, 2e18);

        uint256 pristine = vm.snapshotState();

        // ── world 1: one call, unbounded depth ──
        (RedeemManagerV1 whole, uint32 idWhole) = _buildScenario(s);
        uint256 receivedWhole = _claimWithDepth(idWhole, 0, type(uint16).max);
        assertEq(whole.getRedeemRequestDetails(idWhole).amount, 0, "whole claim did not exhaust the request");
        // read before the rollback discards this world's storage
        uint256 bufferedWhole = whole.getBufferedExceedingEth();

        // ── world 2: the same protocol rolled back, then K depth-bounded calls ──
        (, RedeemManagerV1 split) = _resetToPristineProtocol(pristine);
        uint32 idSplit;
        (split, idSplit) = _buildScenario(s);
        uint256 receivedSplit = 0;
        uint256 steps = 0;
        // three events means at most three steps, so the bound is a liveness guard; the assertion below
        // proves the loop finished the request rather than timing out
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
        // the buffers must agree too, or the equality above could be bought by shifting wei into the
        // buffer rather than to the recipient
        assertEq(
            split.getBufferedExceedingEth(),
            bufferedWhole,
            "I6: depth-split claim buffered a different amount of exceeding ETH"
        );
    }

    /// Scenario: the same legacy (anchor-less) request settled at the same rate on two pristine states,
    /// one with a mark over its entire span and one with no marks at all.
    /// Expected: identical payout, equal to the request-time ETH clamped by what the event supplied.
    /// Why it matters: the PRD excludes retroactive application, so a pre-upgrade request is paid under
    /// the original rules forever even though marks are pushed onto a stack that physically overlaps its
    /// positions -- `anchor.lsETHAtRequest == 0` is a hard cutover, not a different default.
    function testFuzz_LegacyRequestPayoutIgnoresRateMarks(
        uint256 _amount,
        uint256 _requestRate,
        uint256 _markRate,
        uint256 _settlementRate
    ) external {
        uint256 amount = bound(_amount, 1 gwei, 1_000 ether);
        uint256 requestRate = bound(_requestRate, 0.5e18, 2e18);
        // strictly above the request rate, so a mark that WERE read would visibly raise the cap
        uint256 markRate = bound(_markRate, 2.5e18, 4e18);
        uint256 settlementRate = bound(_settlementRate, 0.5e18, 4e18);

        address user = fuzzUser;
        uint256 pristine = vm.snapshotState();

        // ── world 1: a mark covers the whole request ──
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

        // ── world 2: the same protocol rolled back, identical minus the mark ──
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
        assertEq(
            receivedPlain,
            withdrawnEth < requestTimeEth ? withdrawnEth : requestTimeEth,
            "I7: legacy payout is not the original pro-rata cap"
        );
    }

    /// Expected: over a fuzzed marked fraction and a single over-funded event, the ETH a request
    /// receives never exceeds `ethAtRequest + locked appreciation`.
    /// Why it matters: the economic property the whole feature exists to guarantee -- paid more, a
    /// redeemer out-earns a native staker at the expense of everyone still in the pool, out of
    /// exceeding-eth that would otherwise return to River.
    /// @dev The settlement rate is a small step above `max(requestRate, markRate)` rather than its own
    ///      draw: above, so the cap binds on every run, since an under-funding event satisfies the
    ///      ceiling trivially; and only slightly, since 3x over-funding makes `gross >= cap` hold by
    ///      construction and the truncations never compete.
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

        // the delta is valued at `markRate` by River's own conversion
        uint256 markedEth = 0;
        uint256 markedLsETH = 0;
        if (markedAmount > 0 && applyRate(markedAmount, markRate) > 0) {
            _reportRateLoose(markRate);
            _reportStoppedEarning(applyRate(markedAmount, markRate));
            if (redeemManager.getRateMarkCount() > 0) {
                markedEth = redeemManager.getRateMarkDetails(0).markedEth;
                // read back rather than reusing `markedAmount`: River floors it, so the mark can be a
                // wei narrower
                markedLsETH = redeemManager.getRateMarkDetails(0).amount;
            }
        }

        _reportRateLoose(settlementRate);
        uint256 withdrawnEth = _reportWithdrawEth(applyRate(amount, settlementRate), settlementRate);
        uint256 received = _claimWithDepth(id, 0, type(uint16).max);
        assertEq(redeemManager.getRedeemRequestDetails(id).amount, 0, "request must be fully claimed");

        // the native-staker ceiling: request-time value plus only the appreciation the marks locked
        uint256 requestValueOfMarkedSpan =
            markedLsETH == 0 ? 0 : (markedLsETH * anchor.ethAtRequest) / anchor.lsETHAtRequest;
        uint256 lockedAppreciation = markedEth > requestValueOfMarkedSpan ? markedEth - requestValueOfMarkedSpan : 0;
        uint256 ceiling = anchor.ethAtRequest + lockedAppreciation;

        assertLe(received, ceiling, "I9: redeemer out-earned a native staker");
        assertLe(received, withdrawnEth, "I9: paid more than the withdrawal event supplied");
        assertEq(
            redeemManager.getBufferedExceedingEth(), withdrawnEth - received, "I9: unpaid event ETH was not buffered"
        );
    }

    /// Scenario: an anchored request spanning two marks separated by a gap, settled by two events at
    /// different rates and claimed in one unbounded call.
    /// Expected: the payout equals the independently derived per-slice `min(event ETH, cap)` sum wei for
    /// wei, and never exceeds the summed caps.
    /// Why it matters: the stateless form of the ceiling over the geometry that exercises all three
    /// branches of the `_sliceCap` walk -- gap, covered range, stale predecessor mark -- in one claim.
    function testFuzz_ClaimNeverExceedsSliceCapAcrossMarkGaps(
        uint256 _amount,
        uint256 _requestRate,
        uint256 _firstMarkRate,
        uint256 _secondMarkRate,
        uint256 _settlementRateA,
        uint256 _settlementRateB
    ) external {
        // large enough that the quarter-splits below are non-zero
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

        // marking resumes at the cursor, so leaving a gap needs the second mark pushed after an event
        // has advanced the settled height past it -- the "settled from the deposit buffer, never
        // exited" case the RateMarkStack header names as the source of permanent gaps
        uint256 quarter = amount / 4;
        _reportRateLoose(firstMarkRate);
        _reportStoppedEarning(applyRate(quarter, firstMarkRate));
        _reportRateLoose(settlementRateA);
        _reportWithdrawEth(applyRate(quarter * 2, settlementRateA), settlementRateA);
        _reportRateLoose(secondMarkRate);
        _reportStoppedEarning(applyRate(quarter, secondMarkRate));
        _reportRateLoose(settlementRateB);
        _reportWithdrawEth(applyRate(amount - quarter * 2, settlementRateB), settlementRateB);

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

    /// Scenario: the identical anchored request on two pristine states, both dropping below the request
    /// rate and fully recovering before the sweep; only world 1 marks at the depressed rate.
    /// Expected: world 1 paid strictly less than world 2 and than its own request-time value, by exactly
    /// what it diverted to the buffer.
    /// Why it matters: the lower-bound half of the cap, invisible to the ceilings I2 and I9. A redeemer
    /// marked during a drawdown forfeits any later recovery on the marked span, a `CoverageFundV1`
    /// payout included; pinned here and in
    /// `SliceCapGeometryTests.testMarkBelowRequestRateRePricesSliceDownwards` so the forfeiture cannot
    /// change silently either way.
    /// @dev The settlement rate steps just above the request rate for the reason given on
    ///      `testFuzz_RedeemerNeverOutEarnsNativeStaker`: the cap must bind in both worlds, pinning
    ///      world 2 at `ethAtRequest` and world 1 at the mark, so the gap is the forfeited recovery and
    ///      nothing else.
    function testFuzz_MarkBelowRequestRateForfeitsRecovery(
        uint256 _amount,
        uint256 _requestRate,
        uint256 _drawdownBps,
        uint256 _recoveryMargin
    ) external {
        // large enough that the drawdown's eth leg survives flooring
        uint256 amount = bound(_amount, 1 gwei, 1_000 ether);
        uint256 requestRate = bound(_requestRate, 1e18, 2e18);
        // a 5% to 50% drawdown, so `markRate < requestRate` strictly
        uint256 markRate = (requestRate * bound(_drawdownBps, 5_000, 9_500)) / 10_000;
        // recovery to just above the request rate, so the cap binds in both worlds
        uint256 settlementRate = requestRate + (requestRate * bound(_recoveryMargin, 0, 1_000)) / 10_000;

        address user = fuzzUser;
        uint256 pristine = vm.snapshotState();

        // ── world 1: drawdown, mark at the depressed rate, then recovery ──
        _reportRateLoose(requestRate);
        (uint32 idMarked, uint256 openedMarked) = _openRequestLoose(user, amount);
        uint256 requestTimeEth = redeemManager.getRedeemRequestAnchor(idMarked).ethAtRequest;
        _reportRateLoose(markRate);
        _reportStoppedEarning(applyRate(openedMarked, markRate));
        assertEq(redeemManager.getRateMarkCount(), 1, "the marked world must actually carry a mark");
        _reportRateLoose(settlementRate);
        _reportWithdrawEth(applyRate(openedMarked, settlementRate), settlementRate);
        // mirrored before the claim, so the payout is pinned exactly rather than bounded
        MirrorClaim memory expected = _mirrorClaim(redeemManager, idMarked, 0, type(uint16).max);
        uint256 receivedMarked = _claimWithDepth(idMarked, 0, type(uint16).max);
        uint256 bufferedMarked = redeemManager.getBufferedExceedingEth();
        assertEq(receivedMarked, expected.paid, "marked payout diverged from the independent mirror");

        // ── world 2: the same protocol rolled back, same drawdown, no mark ──
        _resetToPristineProtocol(pristine);
        _reportRateLoose(requestRate);
        (uint32 idPlain, uint256 openedPlain) = _openRequestLoose(user, amount);
        assertEq(openedPlain, openedMarked, "the two worlds must open the same position");
        // the same excursion, but with no exit crossing exit_epoch
        _reportRateLoose(markRate);
        assertEq(redeemManager.getRateMarkCount(), 0, "the control world must carry no mark");
        _reportRateLoose(settlementRate);
        _reportWithdrawEth(applyRate(openedPlain, settlementRate), settlementRate);
        uint256 receivedPlain = _claimWithDepth(idPlain, 0, type(uint16).max);

        // the control is held at its request-time value: the drawdown alone costs it nothing
        assertEq(receivedPlain, requestTimeEth, "control: an unmarked request is capped at ethAtRequest");
        assertLt(receivedMarked, receivedPlain, "a mark below the request rate must lower the payout");
        assertLt(receivedMarked, requestTimeEth, "the marked request forfeited part of its request-time value");
        // and the shortfall is not lost, only diverted to the holders who did not redeem
        assertEq(
            bufferedMarked - redeemManager.getBufferedExceedingEth(),
            receivedPlain - receivedMarked,
            "the forfeited recovery must equal the extra ETH the marked world buffered"
        );
    }
}
