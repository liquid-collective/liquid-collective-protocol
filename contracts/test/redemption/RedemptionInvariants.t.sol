//SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.34;

import "forge-std/StdUtils.sol";

import "./RedemptionTestBase.sol";

import "../utils/LibImplementationUnbricker.sol";
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
    function handler_reportStoppedEarning(uint256 lsETH, uint256 markRate) external;
    function handler_reportWithdraw(uint256 lsETH, uint256 settlementRate) external;
    function handler_claim(uint256 idSeed, uint16 depth) external;

    function handler_requestCount() external view returns (uint256);
    function handler_redeemDemand() external view returns (uint256);
    function handler_withdrawalEventCount() external view returns (uint256);
    function handler_rateMarkCount() external view returns (uint256);
    function handler_totalRequestedHeight() external view returns (uint256);
}

/// @title Redemption fulfillment mirror
/// @notice Independent, getter-only re-derivation of `_sliceCap` and of one `claimRedeemRequests`
///         call, shared by the stateful handler and the stateless fuzz suite below.
/// @dev The contract's own walk binary-searches the mark stack; this mirror scans it linearly. That
///      is deliberate: a differential test is only worth running when the two sides are formulated
///      differently, so a bug in `_findRateMarkAtOrBefore`'s predecessor search cannot be reproduced
///      identically here and cancel out.
abstract contract RedemptionMirror is RedemptionTestBase {
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

            budget = budget > pay ? budget - pay : 0;
            cursor += matching;
            remaining -= matching;
            unchecked {
                ++eventId;
                --stepsLeft;
            }
        }
    }

    /// @notice Deploys a fresh, fully upgraded RiverMock + RedeemManagerV1 pair on this test's allowlist
    /// @dev The pair starts with an empty queue, so `initializeRedeemManagerV1_3` pins the rate mark
    ///      floor at 0 and every request opened afterwards is anchored.
    function _deployFreshPair() internal returns (RiverMock freshRiver, RedeemManagerV1 freshManager) {
        freshManager = new RedeemManagerV1();
        LibImplementationUnbricker.unbrick(vm, address(freshManager));
        freshRiver = new RiverMock(address(allowlist));
        freshManager.initializeRedeemManagerV1(address(freshRiver));
        // `initializeRedeemManagerV1` leaves the version at 1; mainnet is at 2 before this upgrade
        vm.store(address(freshManager), LibImplementationUnbricker.VERSION_SLOT, bytes32(uint256(2)));
        freshManager.initializeRedeemManagerV1_3();
    }

    /// @dev `RedemptionTestBase._openRequest` bound to an explicit pair.
    function _openRequestOn(RiverMock freshRiver, RedeemManagerV1 freshManager, address user, uint256 amount)
        internal
        returns (uint32 id)
    {
        freshRiver.sudoDeal(user, amount);
        vm.prank(user);
        freshRiver.approve(address(freshManager), amount);
        vm.prank(user);
        return freshManager.requestRedeem(amount, user);
    }

    /// @dev `RedemptionTestBase._reportWithdraw` bound to an explicit pair.
    function _reportWithdrawOn(RiverMock freshRiver, RedeemManagerV1 freshManager, uint256 lsETH, uint256 rate)
        internal
        returns (uint256 withdrawnEth)
    {
        withdrawnEth = applyRate(lsETH, rate);
        vm.deal(address(this), withdrawnEth);
        freshRiver.sudoReportWithdraw{value: withdrawnEth}(address(freshManager), lsETH);
    }

    /// @dev `RedemptionTestBase._claimWithDepth` bound to an explicit pair.
    function _claimOn(RedeemManagerV1 freshManager, uint32 id, uint32 withdrawalEventId, uint16 depth)
        internal
        returns (uint256 received)
    {
        uint32[] memory ids = new uint32[](1);
        ids[0] = id;
        uint32[] memory eventIds = new uint32[](1);
        eventIds[0] = withdrawalEventId;
        address recipient = freshManager.getRedeemRequestDetails(id).recipient;
        uint256 balanceBefore = recipient.balance;
        freshManager.claimRedeemRequests(ids, eventIds, true, depth);
        return recipient.balance - balanceBefore;
    }

    /// @dev `RedemptionTestBase._stripAnchor` bound to an explicit pair.
    function _stripAnchorOn(RedeemManagerV1 freshManager, uint32 id) internal {
        bytes32 anchorSlot =
            keccak256(abi.encode(uint256(id), bytes32(uint256(keccak256("river.state.redeemRequestAnchor")) - 1)));
        vm.store(address(freshManager), anchorSlot, bytes32(0));
        vm.store(address(freshManager), bytes32(uint256(anchorSlot) + 1), bytes32(0));
    }

    /// @dev Resolves `id` to the withdrawal event that currently satisfies it, or a negative code.
    function _resolveOn(RedeemManagerV1 freshManager, uint32 id) internal view returns (int64) {
        uint32[] memory ids = new uint32[](1);
        ids[0] = id;
        return freshManager.resolveRedeemRequests(ids)[0];
    }
}

/// @title Redemption fulfillment invariant handler
/// @notice The sole Foundry invariant target. Every entry point bounds its fuzzed inputs and then
///         delegates to the test contract, which holds `vm` and the ghost accounting.
/// @dev Bounding is what keeps `fail_on_revert = false` from hiding a broken handler: an action that
///      would revert (a withdrawal larger than outstanding demand, a claim of an unsatisfied request)
///      is either bounded into range or skipped explicitly, so the call counters below are a real
///      measure of work done rather than of calls attempted.
contract RedemptionInvariantHandler is StdUtils {
    /// @notice Ceiling on queue/stack growth, so the O(n) invariant sweeps stay cheap at depth 32
    uint256 private constant MAX_ENTRIES = 24;
    /// @notice Smallest request the fuzzer may open. Below ~1 gwei every rate multiplication floors
    ///         to 0 and the run degenerates into no-ops that prove nothing.
    uint256 private constant MIN_REQUEST = 1 gwei;
    uint256 private constant MAX_REQUEST = 1_000 ether;
    /// @notice Rate band. Wide enough to cross 1.0 in both directions (a marked rate below the
    ///         request rate must LOWER the cap), narrow enough that no product overflows.
    uint256 private constant MIN_RATE = 0.5e18;
    uint256 private constant MAX_RATE = 3e18;
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
        if (_test.handler_requestCount() >= MAX_ENTRIES) return;
        // Step 2: bound the redeemer and the size, then delegate.
        _test.handler_openRequest(bound(userSeed, 0, 2), bound(amountSeed, MIN_REQUEST, MAX_REQUEST));
        calls_openRequest++;
    }

    /// @notice Fuzzer entry point: moves the pool rate, which is what makes later requests anchor at a
    ///         different valuation than earlier ones and what makes a stopped-earning report meaningful.
    /// @param rateSeed Seed for the new rate, bounded to [0.5, 3.0] ETH per LsETH.
    function moveRate(uint256 rateSeed) external {
        _test.handler_moveRate(bound(rateSeed, MIN_RATE, MAX_RATE));
        calls_moveRate++;
    }

    /// @notice Fuzzer entry point: reports a stopped-earning slice with an explicitly chosen locked rate.
    /// @dev The LsETH leg is bounded independently of outstanding demand on purpose: over-reporting is
    ///      a supported case that `reportStoppedEarning` clamps against `totalRequestedHeight`, and the
    ///      clamp's proportional eth scaling is exactly the arithmetic invariant I4 has to survive.
    /// @param lsETHSeed Seed for the reported LsETH leg, bounded to [1 gwei, 2000 ether].
    /// @param rateSeed Seed for the locked rate, bounded to [0.5, 3.0] ETH per LsETH.
    function reportStoppedEarning(uint256 lsETHSeed, uint256 rateSeed) external {
        if (_test.handler_rateMarkCount() >= MAX_ENTRIES) return;
        _test.handler_reportStoppedEarning(
            bound(lsETHSeed, MIN_REQUEST, 2_000 ether), bound(rateSeed, MIN_RATE, MAX_RATE)
        );
        calls_reportStoppedEarning++;
    }

    /// @notice Fuzzer entry point: settles a slice of outstanding demand with a withdrawal event.
    /// @dev `reportWithdraw` reverts when the settled LsETH exceeds `RedeemDemand`, so the amount is
    ///      bounded by the live demand rather than by a constant — that is the difference between a
    ///      handler that exercises the claim path and one that only ever reverts.
    /// @param lsETHSeed Seed for the settled LsETH, bounded to [1, outstanding demand].
    /// @param rateSeed Seed for the settlement rate, bounded to [0.5, 3.0] ETH per LsETH.
    function reportWithdraw(uint256 lsETHSeed, uint256 rateSeed) external {
        if (_test.handler_withdrawalEventCount() >= MAX_ENTRIES) return;
        uint256 demand = _test.handler_redeemDemand();
        if (demand == 0) return;
        _test.handler_reportWithdraw(bound(lsETHSeed, 1, demand), bound(rateSeed, MIN_RATE, MAX_RATE));
        calls_reportWithdraw++;
    }

    /// @notice Fuzzer entry point: claims a request against whichever withdrawal event satisfies it.
    /// @dev The test contract skips (rather than reverts on) an unsatisfied or fully claimed request,
    ///      and only bumps this counter when a claim actually executed.
    /// @param idSeed Seed for the redeem request id, bounded to the live queue.
    /// @param depthSeed Seed for the recursion depth, bounded to [0, 4].
    function claim(uint256 idSeed, uint256 depthSeed) external {
        uint256 count = _test.handler_requestCount();
        if (count == 0) return;
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

    /// @custom:attribute Per withdrawal event: pro-rata ETH consumed by matched slices
    mapping(uint32 => uint256) internal ghost_eventGross;
    /// @custom:attribute Per withdrawal event: LsETH of its demand that has been claimed
    mapping(uint32 => uint256) internal ghost_eventLsETH;
    /// @custom:attribute Per withdrawal event: how many request slices were matched against it
    mapping(uint32 => uint256) internal ghost_eventSlices;

    /// @custom:attribute Per request id (index == id): the end position recorded at creation
    uint256[] internal ghost_endPositions;
    /// @custom:attribute The rate mark floor observed before the most recent handler action
    uint256 internal ghost_lastFloor;

    /// @dev Assertion failures raised inside a handler-driven call would be rolled back together with
    ///      that call under `fail_on_revert = false`, so violations are recorded into the ghost
    ///      counters above and asserted from the `invariant_` functions, which the fuzzer evaluates
    ///      outside the handler's call frame.
    function setUp() public override {
        super.setUp();

        actors[0] = _generateAllowlistedUser(1);
        actors[1] = _generateAllowlistedUser(2);
        actors[2] = _generateAllowlistedUser(3);

        // Two requests opened BEFORE the upgrade and then stripped of their anchors: this is exactly
        // what a live deployment's queue looks like at cutover. It pushes the rate mark floor to
        // 17 ether and keeps the legacy cap branch reachable from the fuzzed action set.
        river.sudoSetRate(1e18);
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

    // ─── handler action wrappers (own the cheatcodes and the ghost accounting) ──

    /// @notice Opens a request and records its immutable end position for I3.
    function handler_openRequest(uint256 actorIdx, uint256 amount) external {
        ghost_lastFloor = redeemManager.getRateMarkFloor();
        uint32 id = _openRequest(actors[actorIdx], amount);
        RedeemQueueV2.RedeemRequest memory request = redeemManager.getRedeemRequestDetails(id);
        assertEq(uint256(id), ghost_endPositions.length, "queue ids must stay dense and sequential");
        ghost_endPositions.push(request.height + request.amount);
    }

    /// @notice Moves the pool rate.
    function handler_moveRate(uint256 rate) external {
        ghost_lastFloor = redeemManager.getRateMarkFloor();
        river.sudoSetRate(rate);
    }

    /// @notice Reports a stopped-earning slice at an explicitly chosen locked rate.
    function handler_reportStoppedEarning(uint256 lsETH, uint256 markRate) external {
        ghost_lastFloor = redeemManager.getRateMarkFloor();
        river.sudoReportStoppedEarningAt(address(redeemManager), applyRate(lsETH, markRate), lsETH);
    }

    /// @notice Pushes a withdrawal event settling `lsETH` of demand funded at `settlementRate`.
    function handler_reportWithdraw(uint256 lsETH, uint256 settlementRate) external {
        ghost_lastFloor = redeemManager.getRateMarkFloor();
        _reportWithdraw(lsETH, settlementRate);
    }

    /// @notice Claims `id` against its satisfying withdrawal event, mirroring the walk beforehand so
    ///         every wei can be attributed to the event that supplied it.
    /// @dev Skips silently when the request is unsatisfied or already fully claimed; the handler only
    ///      counts the call when a claim executed.
    function handler_claim(uint256 idSeed, uint16 depth) external {
        ghost_lastFloor = redeemManager.getRateMarkFloor();

        uint32 id = uint32(idSeed);
        int64 resolved = _resolveOn(redeemManager, id);
        if (resolved < 0) return;
        uint32 startEventId = uint32(uint64(resolved));

        // Mirror FIRST: the walk depends on the pre-claim request state.
        MirrorClaim memory expected = _mirrorClaim(redeemManager, id, startEventId, depth);
        uint256 spanStart = redeemManager.getRedeemRequestDetails(id).height;

        uint256 bufferBefore = redeemManager.getBufferedExceedingEth();
        uint256 paid = _claimWithDepth(id, startEventId, depth);
        uint256 bufferDelta = redeemManager.getBufferedExceedingEth() - bufferBefore;

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

        // global form: nothing is ever pulled out of the buffer in this handler, so the two sides
        // must match exactly at all times
        assertEq(
            ghost_totalPaid + redeemManager.getBufferedExceedingEth(),
            ghost_totalGross,
            "I1: cumulative paid + buffered != cumulative event ETH"
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
    function afterInvariant() public {
        assertGt(handler.calls_total(), 0, "handler performed no work in this run");
        // if claims happened at all, they must have moved LsETH; a claim that matched nothing would
        // make every conservation check above trivially true
        if (ghost_claimCount > 0) {
            assertGt(ghost_totalMatched, 0, "claims executed but matched no LsETH");
        }
    }

    /// Scenario: drive every handler entry point once, in a deterministic order that reaches a paid
    /// claim, then evaluate every invariant explicitly.
    /// Expected: each action lands, a claim pays real ETH, and all six invariants hold.
    /// Why it matters: `fail_on_revert = false` means a handler that reverted on every call would
    /// still report 128 green runs. This test is the standing proof that each action is reachable
    /// and that the invariants are checked against non-trivial state.
    function test_HandlerActionsAreAllReachable() external {
        handler.moveRate(1.1e18);
        handler.openRequest(0, 100 ether);
        handler.openRequest(1, 50 ether);
        assertEq(handler.calls_openRequest(), 2, "openRequest did not land");

        handler.reportStoppedEarning(uint256(60 ether), 1.4e18);
        assertGt(redeemManager.getRateMarkCount(), 0, "no rate mark was pushed");

        handler.reportWithdraw(type(uint256).max, 1.6e18);
        assertGt(redeemManager.getWithdrawalEventCount(), 0, "no withdrawal event was pushed");

        // the two legacy (anchor-less) requests sit first on the axis, so they are what a withdrawal
        // event settles first: claiming id 0 exercises the legacy cap branch
        handler.claim(0, 8);
        // and an anchored, marked request exercises the slice-cap branch
        handler.claim(2, 8);
        assertEq(handler.calls_claim(), 2, "claim did not land");
        assertGt(ghost_claimCount, 0, "no claim executed");
        assertGt(ghost_totalPaid, 0, "claims paid no ETH");
        assertGt(ghost_totalMatched, 0, "claims matched no LsETH");

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
contract RedemptionRateMarkFuzzTests is RedemptionMirror {
    /// @notice Parameters of a scenario replayed identically onto two independent deployments
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

    function setUp() public override {
        super.setUp();
    }

    /// @dev Builds a fresh deployment carrying `s`: one anchored request, one rate mark over its
    ///      lower `markAmount`, and three withdrawal events settling it in thirds at three different
    ///      rates. Returns the pair and the request id.
    function _buildScenario(Scenario memory s) internal returns (RedeemManagerV1 manager, uint32 id) {
        RiverMock freshRiver;
        (freshRiver, manager) = _deployFreshPair();

        freshRiver.sudoSetRate(s.requestRate);
        id = _openRequestOn(freshRiver, manager, s.user, s.amount);

        if (s.markAmount > 0) {
            freshRiver.sudoReportStoppedEarningAt(address(manager), applyRate(s.markAmount, s.markRate), s.markAmount);
        }

        uint256 first = s.amount / 3;
        uint256 second = s.amount / 3;
        uint256 third = s.amount - first - second;
        _reportWithdrawOn(freshRiver, manager, first, s.rateA);
        _reportWithdrawOn(freshRiver, manager, second, s.rateB);
        _reportWithdrawOn(freshRiver, manager, third, s.rateC);
    }

    /// Scenario: the identical request, mark stack and withdrawal-event geometry is claimed twice on
    /// two independent deployments — once in a single unbounded call, once in K calls whose recursion
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
        s.user = _generateAllowlistedUser(0);
        // at least 3 so every one of the three withdrawal events settles a non-zero span
        s.amount = bound(_amount, 3, 1_000_000 ether);
        s.requestRate = bound(_requestRate, 0.5e18, 2e18);
        s.markAmount = (s.amount * bound(_markFraction, 0, 1e18)) / 1e18;
        s.markRate = bound(_markRate, 0.5e18, 2e18);
        s.rateA = bound(_rateA, 0.5e18, 2e18);
        s.rateB = bound(_rateB, 0.5e18, 2e18);
        s.rateC = bound(_rateC, 0.5e18, 2e18);

        // ── world 1: one call, unbounded depth ──────────────────────────────────
        (RedeemManagerV1 whole, uint32 idWhole) = _buildScenario(s);
        uint256 receivedWhole = _claimOn(whole, idWhole, 0, type(uint16).max);
        assertEq(whole.getRedeemRequestDetails(idWhole).amount, 0, "whole claim did not exhaust the request");

        // ── world 2: K calls, each with its own fuzzed depth ────────────────────
        (RedeemManagerV1 split, uint32 idSplit) = _buildScenario(s);
        uint256 receivedSplit = 0;
        uint256 steps = 0;
        // three events means at most three steps are ever needed; the bound is a liveness guard, and
        // the assertion below proves the loop actually finished the request rather than timed out
        for (uint256 i = 0; i < 8; ++i) {
            int64 resolved = _resolveOn(split, idSplit);
            if (resolved < 0) break;
            uint16 depth = uint16(bound(uint256(keccak256(abi.encode(_depthSeed, i))), 0, 2));
            receivedSplit += _claimOn(split, idSplit, uint32(uint64(resolved)), depth);
            steps += 1;
        }
        assertEq(split.getRedeemRequestDetails(idSplit).amount, 0, "split claim did not exhaust the request");
        assertGt(steps, 0, "split path performed no claim");

        assertEq(receivedSplit, receivedWhole, "I6: depth-split claim total differs from the whole claim");
        // the exceeding-eth buffers must agree too, otherwise the equality above could be bought by
        // shifting wei into the buffer instead of to the recipient
        assertEq(
            split.getBufferedExceedingEth(),
            whole.getBufferedExceedingEth(),
            "I6: depth-split claim buffered a different amount of exceeding ETH"
        );
    }

    /// Scenario: the same legacy (anchor-less) request, settled at the same rate, on two independent
    /// deployments — one where a rate mark covers its entire span, one with no marks at all.
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
        uint256 amount = bound(_amount, 1 gwei, 1_000_000 ether);
        uint256 requestRate = bound(_requestRate, 0.5e18, 2e18);
        // marked strictly above the request rate, so a mark that WERE read would visibly raise the cap
        uint256 markRate = bound(_markRate, 2.5e18, 4e18);
        uint256 settlementRate = bound(_settlementRate, 0.5e18, 4e18);

        address user = _generateAllowlistedUser(0);

        // ── world 1: a mark covers the whole request ────────────────────────────
        (RiverMock riverMarked, RedeemManagerV1 marked) = _deployFreshPair();
        riverMarked.sudoSetRate(requestRate);
        uint32 idMarked = _openRequestOn(riverMarked, marked, user, amount);
        uint256 requestTimeEth = marked.getRedeemRequestAnchor(idMarked).ethAtRequest;
        _stripAnchorOn(marked, idMarked);
        riverMarked.sudoReportStoppedEarningAt(address(marked), applyRate(amount, markRate), amount);
        assertEq(marked.getRateMarkCount(), 1, "the marked world must actually carry a mark");
        _reportWithdrawOn(riverMarked, marked, amount, settlementRate);
        uint256 receivedMarked = _claimOn(marked, idMarked, 0, type(uint16).max);

        // ── world 2: identical, minus the mark ──────────────────────────────────
        (RiverMock riverPlain, RedeemManagerV1 plain) = _deployFreshPair();
        riverPlain.sudoSetRate(requestRate);
        uint32 idPlain = _openRequestOn(riverPlain, plain, user, amount);
        _stripAnchorOn(plain, idPlain);
        assertEq(plain.getRateMarkCount(), 0, "the plain world must carry no mark");
        uint256 withdrawnEth = _reportWithdrawOn(riverPlain, plain, amount, settlementRate);
        uint256 receivedPlain = _claimOn(plain, idPlain, 0, type(uint16).max);

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
    function testFuzz_RedeemerNeverOutEarnsNativeStaker(
        uint256 _amount,
        uint256 _requestRate,
        uint256 _markFraction,
        uint256 _markRate,
        uint256 _settlementRate
    ) external {
        uint256 amount = bound(_amount, 1 gwei, 1_000_000 ether);
        uint256 requestRate = bound(_requestRate, 0.5e18, 2e18);
        uint256 markedAmount = (amount * bound(_markFraction, 0, 1e18)) / 1e18;
        uint256 markRate = bound(_markRate, 0.5e18, 3e18);
        // deliberately rich: the withdrawal event must not be what binds, otherwise the cap is never
        // the active constraint and the property is untested
        uint256 settlementRate = bound(_settlementRate, 3e18, 6e18);

        address user = _generateAllowlistedUser(0);
        (RiverMock freshRiver, RedeemManagerV1 manager) = _deployFreshPair();

        freshRiver.sudoSetRate(requestRate);
        uint32 id = _openRequestOn(freshRiver, manager, user, amount);
        RedeemRequestAnchor.Anchor memory anchor = manager.getRedeemRequestAnchor(id);

        uint256 markedEth = 0;
        if (markedAmount > 0 && applyRate(markedAmount, markRate) > 0) {
            freshRiver.sudoReportStoppedEarningAt(address(manager), applyRate(markedAmount, markRate), markedAmount);
            markedEth = manager.getRateMarkDetails(0).markedEth;
        }

        uint256 withdrawnEth = _reportWithdrawOn(freshRiver, manager, amount, settlementRate);
        uint256 received = _claimOn(manager, id, 0, type(uint16).max);
        assertEq(manager.getRedeemRequestDetails(id).amount, 0, "request must be fully claimed");

        // the native-staker ceiling: request-time value, plus only the appreciation the marks locked
        uint256 requestValueOfMarkedSpan =
            markedAmount == 0 ? 0 : (markedAmount * anchor.ethAtRequest) / anchor.lsETHAtRequest;
        uint256 lockedAppreciation = markedEth > requestValueOfMarkedSpan ? markedEth - requestValueOfMarkedSpan : 0;
        uint256 ceiling = anchor.ethAtRequest + lockedAppreciation;

        assertLe(received, ceiling, "I9: redeemer out-earned a native staker");
        // and the ceiling really is the binding constraint here, not the event's ETH
        assertLe(received, withdrawnEth, "I9: paid more than the withdrawal event supplied");
        assertEq(redeemManager.getBufferedExceedingEth(), 0, "fixture manager must be untouched");
        assertEq(manager.getBufferedExceedingEth(), withdrawnEth - received, "I9: unpaid event ETH was not buffered");
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
        uint256 amount = bound(_amount, 4 gwei, 1_000_000 ether);
        uint256 requestRate = bound(_requestRate, 0.5e18, 2e18);
        uint256 firstMarkRate = bound(_firstMarkRate, 0.5e18, 3e18);
        uint256 secondMarkRate = bound(_secondMarkRate, 0.5e18, 3e18);
        uint256 settlementRateA = bound(_settlementRateA, 0.5e18, 3e18);
        uint256 settlementRateB = bound(_settlementRateB, 0.5e18, 3e18);

        address user = _generateAllowlistedUser(0);
        (RiverMock freshRiver, RedeemManagerV1 manager) = _deployFreshPair();

        freshRiver.sudoSetRate(requestRate);
        uint32 id = _openRequestOn(freshRiver, manager, user, amount);

        // mark [0, quarter). Marking always resumes at the cursor, so to leave a GAP the second mark
        // has to be pushed after a withdrawal event has advanced the settled height past the cursor —
        // which is exactly the "settled from the deposit buffer, never exited" case the stack's @dev
        // block describes as the source of permanent gaps.
        uint256 quarter = amount / 4;
        freshRiver.sudoReportStoppedEarningAt(address(manager), applyRate(quarter, firstMarkRate), quarter);
        _reportWithdrawOn(freshRiver, manager, quarter * 2, settlementRateA);
        freshRiver.sudoReportStoppedEarningAt(address(manager), applyRate(quarter, secondMarkRate), quarter);
        _reportWithdrawOn(freshRiver, manager, amount - quarter * 2, settlementRateB);

        // the geometry the test exists for: two disjoint, non-contiguous marks
        assertEq(manager.getRateMarkCount(), 2, "expected exactly two marks");
        RateMarkStack.RateMark memory first = manager.getRateMarkDetails(0);
        RateMarkStack.RateMark memory second = manager.getRateMarkDetails(1);
        assertGt(second.height, first.height + first.amount, "expected a gap between the two marks");

        MirrorClaim memory expected = _mirrorClaim(manager, id, 0, type(uint16).max);
        uint256 received = _claimOn(manager, id, 0, type(uint16).max);

        assertEq(received, expected.paid, "I2: payout diverged from the independently derived slice math");
        assertLe(received, expected.capSum, "I2: payout exceeded the summed slice caps");
        assertEq(
            received + manager.getBufferedExceedingEth(), expected.gross, "I2: paid + buffered != event ETH supplied"
        );
    }
}
