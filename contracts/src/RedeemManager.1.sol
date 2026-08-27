//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "./interfaces/IAllowlist.1.sol";
import "./interfaces/IRiver.1.sol";
import "./interfaces/IRedeemManager.1.sol";
import "./interfaces/IProtocolVersion.sol";
import "./libraries/LibAllowlistMasks.sol";
import "./libraries/LibUint256.sol";
import "./Initializable.sol";
import "openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";

import "./state/shared/RiverAddress.sol";
import "./state/redeemManager/RedeemQueue.1.sol";
import "./state/redeemManager/RedeemQueue.2.sol";
import "./state/redeemManager/WithdrawalStack.sol";
import "./state/redeemManager/BufferedExceedingEth.sol";
import "./state/redeemManager/RedeemDemand.sol";
import "./state/redeemManager/RateMarkStack.sol";
import "./state/redeemManager/RedeemRequestAnchor.sol";
import "./state/redeemManager/RateMarkFloor.sol";

/// @title Redeem Manager (v1)
/// @author Alluvial Finance Inc.
/// @notice This contract handles the redeem requests of all users
contract RedeemManagerV1 is Initializable, ReentrancyGuard, IRedeemManagerV1, IProtocolVersion {
    /// @notice Value returned when resolving a redeem request that is unsatisfied
    int64 internal constant RESOLVE_UNSATISFIED = -1;
    /// @notice Value returned when resolving a redeem request that is out of bounds
    int64 internal constant RESOLVE_OUT_OF_BOUNDS = -2;
    /// @notice Value returned when resolving a redeem request that is already claimed
    int64 internal constant RESOLVE_FULLY_CLAIMED = -3;

    /// @notice Status value returned when fully claiming a redeem request
    uint8 internal constant CLAIM_FULLY_CLAIMED = 0;
    /// @notice Status value returned when partially claiming a redeem request
    uint8 internal constant CLAIM_PARTIALLY_CLAIMED = 1;
    /// @notice Status value returned when a redeem request is already claimed and skipped during a claim
    uint8 internal constant CLAIM_SKIPPED = 2;

    modifier onlyRiver() {
        if (msg.sender != RiverAddress.get()) {
            revert LibErrors.Unauthorized(msg.sender);
        }
        _;
    }

    modifier onlyRedeemer() {
        {
            IRiverV1 river = _castedRiver();
            IAllowlistV1(river.getAllowlist()).onlyAllowed(msg.sender, LibAllowlistMasks.REDEEM_MASK);
        }
        _;
    }

    /// @notice Reverts if slashing containment mode is currently active
    /// @dev Makes an external view call to River. River must be initialized before any function
    ///      guarded by this modifier is callable; calls will revert with a non-contract error otherwise.
    modifier whenNotSlashingContainmentMode() {
        if (_castedRiver().getSlashingContainmentMode()) {
            revert SlashingContainmentModeEnabled();
        }
        _;
    }

    /// @inheritdoc IRedeemManagerV1
    function initializeRedeemManagerV1(address _river) external init(0) {
        RiverAddress.set(_river);
        emit SetRiver(_river);
    }

    function initializeRedeemManagerV1_2() external init(1) {
        _redeemQueueMigrationV1_2();
    }

    /// @inheritdoc IRedeemManagerV1
    function initializeRedeemManagerV1_3() external init(2) {
        // Pin the launch cutover for stopped-earning accrual at the end of the existing queue, so the
        // requests already pending at upgrade time neither accrue (they have no anchor) nor consume the
        // marks that the first post-upgrade cohort is owed.
        RedeemQueueV2.RedeemRequest[] storage redeemRequests = RedeemQueueV2.get();
        uint256 requestCount = redeemRequests.length;
        uint256 floor = 0;
        if (requestCount > 0) {
            RedeemQueueV2.RedeemRequest storage lastRequest = redeemRequests[requestCount - 1];
            floor = lastRequest.height + lastRequest.amount;
        }
        RateMarkFloor.set(floor);
        emit SetRateMarkFloor(floor);
    }

    function _redeemQueueMigrationV1_2() internal {
        RedeemQueueV1.RedeemRequest[] memory oldQueue = RedeemQueueV1.get();
        uint256 oldQueueLen = oldQueue.length;
        RedeemQueueV2.RedeemRequest[] storage newQueue = RedeemQueueV2.get();

        // Migrate from v1 to v2
        for (uint256 i = 0; i < oldQueueLen; ++i) {
            newQueue[i] = RedeemQueueV2.RedeemRequest({
                amount: oldQueue[i].amount,
                maxRedeemableEth: oldQueue[i].maxRedeemableEth,
                recipient: oldQueue[i].recipient,
                height: oldQueue[i].height,
                initiator: oldQueue[i].recipient
            });
        }
    }

    /// @inheritdoc IRedeemManagerV1
    function getRiver() external view returns (address) {
        return RiverAddress.get();
    }

    /// @inheritdoc IRedeemManagerV1
    function getRedeemRequestCount() external view returns (uint256) {
        return RedeemQueueV2.get().length;
    }

    /// @inheritdoc IRedeemManagerV1
    function getRedeemRequestDetails(uint32 _redeemRequestId)
        external
        view
        returns (RedeemQueueV2.RedeemRequest memory)
    {
        return RedeemQueueV2.get()[_redeemRequestId];
    }

    /// @inheritdoc IRedeemManagerV1
    function getWithdrawalEventCount() external view returns (uint256) {
        return WithdrawalStack.get().length;
    }

    /// @inheritdoc IRedeemManagerV1
    function getWithdrawalEventDetails(uint32 _withdrawalEventId)
        external
        view
        returns (WithdrawalStack.WithdrawalEvent memory)
    {
        return WithdrawalStack.get()[_withdrawalEventId];
    }

    /// @inheritdoc IRedeemManagerV1
    function getRateMarkFloor() external view returns (uint256) {
        return RateMarkFloor.get();
    }

    /// @inheritdoc IRedeemManagerV1
    function getRateMarkCount() external view returns (uint256) {
        return RateMarkStack.get().length;
    }

    /// @inheritdoc IRedeemManagerV1
    function getRateMarkDetails(uint32 _rateMarkId) external view returns (RateMarkStack.RateMark memory) {
        return RateMarkStack.get()[_rateMarkId];
    }

    /// @inheritdoc IRedeemManagerV1
    function getRedeemRequestAnchor(uint32 _redeemRequestId) external view returns (RedeemRequestAnchor.Anchor memory) {
        return RedeemRequestAnchor.get()[_redeemRequestId];
    }

    /// @inheritdoc IRedeemManagerV1
    function getBufferedExceedingEth() external view returns (uint256) {
        return BufferedExceedingEth.get();
    }

    /// @inheritdoc IRedeemManagerV1
    function getRedeemDemand() external view returns (uint256) {
        return RedeemDemand.get();
    }

    /// @inheritdoc IRedeemManagerV1
    function resolveRedeemRequests(uint32[] calldata _redeemRequestIds)
        external
        view
        returns (int64[] memory withdrawalEventIds)
    {
        withdrawalEventIds = new int64[](_redeemRequestIds.length);
        WithdrawalStack.WithdrawalEvent memory lastWithdrawalEvent;
        WithdrawalStack.WithdrawalEvent[] storage withdrawalEvents = WithdrawalStack.get();
        uint256 withdrawalEventsLength = withdrawalEvents.length;
        if (withdrawalEventsLength > 0) {
            unchecked {
                lastWithdrawalEvent = withdrawalEvents[withdrawalEventsLength - 1];
            }
        }
        for (uint256 idx = 0; idx < _redeemRequestIds.length; ++idx) {
            withdrawalEventIds[idx] = _resolveRedeemRequestId(_redeemRequestIds[idx], lastWithdrawalEvent);
        }
    }

    /// @inheritdoc IRedeemManagerV1
    function requestRedeem(uint256 _lsETHAmount, address _recipient, address _initiator)
        external
        onlyRiver
        returns (uint32 redeemRequestId)
    {
        return _requestRedeem(_lsETHAmount, _recipient, _initiator);
    }

    /// @inheritdoc IRedeemManagerV1
    function requestRedeem(uint256 _lsETHAmount, address _recipient)
        external
        whenNotSlashingContainmentMode
        onlyRedeemer
        returns (uint32 redeemRequestId)
    {
        IRiverV1 river = _castedRiver();
        if (IAllowlistV1(river.getAllowlist()).isDenied(_recipient)) {
            revert RecipientIsDenied();
        }
        return _requestRedeem(_lsETHAmount, _recipient, msg.sender);
    }

    /// @inheritdoc IRedeemManagerV1
    function requestRedeem(uint256 _lsETHAmount)
        external
        whenNotSlashingContainmentMode
        onlyRedeemer
        returns (uint32 redeemRequestId)
    {
        return _requestRedeem(_lsETHAmount, msg.sender, msg.sender);
    }

    /// @inheritdoc IRedeemManagerV1
    function claimRedeemRequests(
        uint32[] calldata redeemRequestIds,
        uint32[] calldata withdrawalEventIds,
        bool skipAlreadyClaimed,
        uint16 _depth
    ) external nonReentrant returns (uint8[] memory claimStatuses) {
        return _claimRedeemRequests(redeemRequestIds, withdrawalEventIds, skipAlreadyClaimed, _depth);
    }

    /// @inheritdoc IRedeemManagerV1
    function claimRedeemRequests(uint32[] calldata _redeemRequestIds, uint32[] calldata _withdrawalEventIds)
        external
        nonReentrant
        returns (uint8[] memory claimStatuses)
    {
        return _claimRedeemRequests(_redeemRequestIds, _withdrawalEventIds, true, type(uint16).max);
    }

    /// @inheritdoc IRedeemManagerV1
    function reportWithdraw(uint256 _lsETHWithdrawable) external payable onlyRiver {
        uint256 redeemDemand = RedeemDemand.get();
        if (_lsETHWithdrawable > redeemDemand) {
            revert WithdrawalExceedsRedeemDemand(_lsETHWithdrawable, redeemDemand);
        }
        WithdrawalStack.WithdrawalEvent[] storage withdrawalEvents = WithdrawalStack.get();
        uint32 withdrawalEventId = uint32(withdrawalEvents.length);
        uint256 height = 0;
        uint256 msgValue = msg.value;
        if (withdrawalEventId != 0) {
            WithdrawalStack.WithdrawalEvent memory previousWithdrawalEvent = withdrawalEvents[withdrawalEventId - 1];
            height = previousWithdrawalEvent.height + previousWithdrawalEvent.amount;
        }
        withdrawalEvents.push(
            WithdrawalStack.WithdrawalEvent({height: height, amount: _lsETHWithdrawable, withdrawnEth: msgValue})
        );
        unchecked {
            _setRedeemDemand(redeemDemand, redeemDemand - _lsETHWithdrawable);
        }
        emit ReportedWithdrawal(height, _lsETHWithdrawable, msgValue, withdrawalEventId);
    }

    /// @inheritdoc IRedeemManagerV1
    function reportStoppedEarning(uint256 _stoppedEarningEth, uint256 _stoppedEarningLsETH) external onlyRiver {
        // Nothing worth marking: a zero eth leg values the demand at nothing, a zero LsETH leg credits no
        // demand. The latter is what River passes on a degenerate pool. An early-out only — the division
        // below is guarded by `lsETHToMark == 0`, not here.
        if (_stoppedEarningEth == 0 || _stoppedEarningLsETH == 0) {
            return;
        }

        RedeemQueueV2.RedeemRequest[] storage redeemRequests = RedeemQueueV2.get();
        uint256 requestCount = redeemRequests.length;
        if (requestCount == 0) {
            return;
        }

        // The end position of a request is invariant across its lifetime (height rises and amount falls
        // by the same amount as it is claimed), so the last request's end position is the total LsETH
        // ever requested.
        RedeemQueueV2.RedeemRequest storage lastRequest = redeemRequests[requestCount - 1];
        uint256 totalRequestedHeight = lastRequest.height + lastRequest.amount;

        // Marks may only cover demand that is still unsettled. Once a withdrawal event has priced a
        // slice of demand, its payout is bounded by that event's ETH anyway, and crediting it here
        // would hand the redeemer pool appreciation earned after their principal stopped earning —
        // exactly the withdrawability/sweep-tail window the design excludes.
        uint256 markStart = _rateMarkCursor();
        uint256 settledHeight = _settledHeight();
        if (settledHeight > markStart) {
            markStart = settledHeight;
        }
        // never mark below the launch cutover: pre-upgrade requests cannot use a mark, so letting the
        // cursor cover them would silently burn credit owed to the first post-upgrade cohort
        uint256 floor = RateMarkFloor.get();
        if (floor > markStart) {
            markStart = floor;
        }

        uint256 reportedLsETH = _stoppedEarningLsETH;
        uint256 lsETHToMark = reportedLsETH;
        uint256 markable = totalRequestedHeight > markStart ? totalRequestedHeight - markStart : 0;
        if (lsETHToMark > markable) {
            lsETHToMark = markable;
            emit StoppedEarningExceededMarkableDemand(reportedLsETH, lsETHToMark);
        }
        // The only guard on the division below: past here `lsETHToMark >= 1`, so the divisor
        // `reportedLsETH >= lsETHToMark >= 1`. A zero reported leg cannot slip through — it makes
        // `lsETHToMark` zero and `0 > markable` never clamps. Also keeps mark heights strictly ascending
        // for `_findRateMarkAtOrBefore`.
        if (lsETHToMark == 0) {
            return;
        }

        // Priced at the rate River held BEFORE this report was applied, which is exactly the ratio of the
        // two arguments — the interval during which the principal stopped earning is excluded on purpose.
        // Marking the whole reported amount therefore needs no conversion at all; only the clamped case
        // divides, scaling the eth leg down in the same proportion so the locked rate is preserved.
        uint256 markedEth =
            lsETHToMark == reportedLsETH ? _stoppedEarningEth : (_stoppedEarningEth * lsETHToMark) / reportedLsETH;

        RateMarkStack.RateMark[] storage rateMarks = RateMarkStack.get();
        uint32 rateMarkId = uint32(rateMarks.length);
        rateMarks.push(RateMarkStack.RateMark({height: markStart, amount: lsETHToMark, markedEth: markedEth}));

        emit ReportedStoppedEarning(markStart, lsETHToMark, markedEth, rateMarkId);
    }

    /// @inheritdoc IRedeemManagerV1
    function pullExceedingEth(uint256 _max) external onlyRiver {
        uint256 bufferedExceedingEth = BufferedExceedingEth.get();
        uint256 amountToSend = LibUint256.min(bufferedExceedingEth, _max);
        if (amountToSend > 0) {
            BufferedExceedingEth.set(bufferedExceedingEth - amountToSend);
            _castedRiver().sendRedeemManagerExceedingFunds{value: amountToSend}();
        }
    }

    /// @notice Internal utility to load and cast the River address
    /// @return The casted river address
    function _castedRiver() internal view returns (IRiverV1) {
        return IRiverV1(payable(RiverAddress.get()));
    }

    /// @notice Internal utility returning the end position of the last rate mark
    /// @return The first LsETH position not yet covered by any rate mark
    function _rateMarkCursor() internal view returns (uint256) {
        RateMarkStack.RateMark[] storage rateMarks = RateMarkStack.get();
        uint256 length = rateMarks.length;
        if (length == 0) {
            return 0;
        }
        RateMarkStack.RateMark storage last = rateMarks[length - 1];
        return last.height + last.amount;
    }

    /// @notice Internal utility returning the end position of the last withdrawal event
    /// @return The amount of LsETH demand settled so far
    function _settledHeight() internal view returns (uint256) {
        WithdrawalStack.WithdrawalEvent[] storage withdrawalEvents = WithdrawalStack.get();
        uint256 length = withdrawalEvents.length;
        if (length == 0) {
            return 0;
        }
        WithdrawalStack.WithdrawalEvent storage last = withdrawalEvents[length - 1];
        return last.height + last.amount;
    }

    /// @notice Internal utility to find the last rate mark starting at or before a position
    /// @dev The rate mark stack is sorted strictly ascending by height and non-overlapping, but unlike
    ///      the withdrawal stack it is NOT contiguous, so `_performDichotomicResolution`'s contiguity
    ///      assumption does not hold here. This is a plain predecessor search; the caller must still
    ///      check whether the returned mark actually covers the position or whether it sits in a gap.
    /// @param _height The position to search for
    /// @return found True if any mark starts at or before `_height`
    /// @return index The index of that mark
    function _findRateMarkAtOrBefore(uint256 _height) internal view returns (bool found, uint256 index) {
        // Answers one question: which is the last mark that STARTS at or before `_height`?
        // It does not answer whether that mark reaches `_height`. The stack is not contiguous, so the mark
        // returned may end well below it — checking coverage is left to the caller.
        RateMarkStack.RateMark[] storage rateMarks = RateMarkStack.get();
        uint256 length = rateMarks.length;

        // Nothing starts early enough: either the stack is empty, or `_height` is below the very first
        // mark. Handled up front so that the search can treat index 0 as a valid candidate.
        if (length == 0 || rateMarks[0].height > _height) {
            return (false, 0);
        }

        // Binary search for the rightmost mark with `height <= _height`.
        uint256 low = 0;
        uint256 high = length - 1;
        while (low < high) {
            // Round up so `mid` is always greater than `low`.
            uint256 mid = (low + high + 1) / 2;
            if (rateMarks[mid].height <= _height) {
                // Valid candidate; try to move right.
                low = mid;
            } else {
                // Too far right; search left side.
                high = mid - 1;
            }
        }

        // `low` is the last mark that starts at or before `_height`.
        return (true, low);
    }

    /// @notice Internal utility computing the ETH payout cap for a slice of a redeem request
    /// @dev The cap is the request-time value of the slice, raised over any sub-range whose backing
    ///      principal has been marked as stopped earning. Sub-ranges in a mark gap stay at the
    ///      request-time rate, which is what makes a fill that involved no exit pay exactly
    ///      `rate_at_request`. The payout is still clamped against the withdrawal event's actual ETH by
    ///      the caller, so this only ever relaxes a ceiling and never promises ETH the protocol has not
    ///      received.
    /// @dev Iterations are bounded by the number of marks the slice spans, which is at most the number
    ///      of oracle reports the request has been pending across (marks are pushed at most once per
    ///      report). The claimant pays for their own request's span and cannot be charged for anyone
    ///      else's; use the `_depth` parameter of `claimRedeemRequests` to split a very old request.
    /// @param _anchor The immutable request-time valuation of the request
    /// @param _sliceStart The start position of the slice on the cumulative LsETH axis
    /// @param _sliceAmount The amount of LsETH in the slice
    /// @return cap The maximum ETH payable for this slice
    function _sliceCap(RedeemRequestAnchor.Anchor memory _anchor, uint256 _sliceStart, uint256 _sliceAmount)
        internal
        view
        returns (uint256 cap)
    {
        // MODEL: all LsETH ever queued for redemption forms a single ascending axis, oldest demand first.
        // This slice is one interval on that axis. Rate marks are ascending, disjoint intervals on the same
        // axis, each recording that the principal backing it stopped earning and the eth it was worth at
        // that moment. The function performs an ordered walk over the slice, splitting it at every mark
        // boundary and valuing each sub-range at the rate that applies to it: a mark's locked rate where
        // one covers it, the request-time rate everywhere else.
        RateMarkStack.RateMark[] storage rateMarks = RateMarkStack.get();
        uint256 markCount = rateMarks.length;

        // walk state: `sliceCursor` is the next position on the axis to value, `remainingAmount` the part
        // of the slice not yet accumulated into `cap`
        uint256 sliceCursor = _sliceStart;
        uint256 remainingAmount = _sliceAmount;

        // seek the entry point rather than scanning from the head of the stack: marks are ascending and
        // disjoint, so the only candidate that can cover `sliceCursor` is the last mark starting at or
        // before it
        (bool markFound, uint256 markIndex) = _findRateMarkAtOrBefore(sliceCursor);
        if (!markFound) {
            // the slice starts below every mark, so enter at the head of the stack: the uncovered-range
            // branch below values everything up to the first mark's start
            markIndex = 0;
        }

        while (remainingAmount > 0) {
            if (markIndex >= markCount) {
                // the walk has passed the last mark, so no mark can cover the remainder of the slice: it
                // is uncovered by construction and is valued in full at the request-time rate
                cap += (remainingAmount * _anchor.ethAtRequest) / _anchor.lsETHAtRequest;
                return cap;
            }

            // the candidate mark, covering the half-open interval [markStart, markEnd)
            RateMarkStack.RateMark storage mark = rateMarks[markIndex];
            uint256 markStart = mark.height;
            uint256 markAmount = mark.amount;
            uint256 markEnd = markStart + markAmount;

            // case 1 — `sliceCursor` lies in the uncovered range below the candidate mark
            if (sliceCursor < markStart) {
                // No mark over [sliceCursor, markStart) means no locked report rate applies there,
                // so that interval keeps the request-time rate.
                // Coverage does not imply ETH source (buffer ETH is fungible); advance to min(markStart, sliceEnd).
                uint256 unmarkedAmount = markStart - sliceCursor;
                if (unmarkedAmount > remainingAmount) {
                    unmarkedAmount = remainingAmount;
                }
                cap += (unmarkedAmount * _anchor.ethAtRequest) / _anchor.lsETHAtRequest;
                sliceCursor += unmarkedAmount;
                remainingAmount -= unmarkedAmount;
                // `markIndex` is deliberately not advanced: the candidate mark was not consumed and
                // remains the candidate for the new `sliceCursor`
                continue;
            }

            // case 2 — the candidate mark terminates at or below `sliceCursor` and so covers no part of
            // the slice
            if (sliceCursor >= markEnd) {
                // the seek only guarantees `markStart <= sliceCursor`; because the stack is not contiguous
                // the mark it returns may end below `sliceCursor`. Discard it and test the next one.
                unchecked {
                    // bounded by `markCount`, which is the length of a storage array
                    ++markIndex;
                }
                continue;
            }

            // case 3 — `sliceCursor` lies within [markStart, markEnd), the case the mark exists for: this
            // range stopped earning, so it is valued at the mark's locked rate, which is the mark's whole
            // `markedEth` per its whole `amount`, instead of the request-time rate. `markedAmount` below is
            // only the portion of that mark consumed here: up to the mark's end, or the end of the slice.
            uint256 markedAmount = markEnd - sliceCursor;
            if (markedAmount > remainingAmount) {
                markedAmount = remainingAmount;
            }
            cap += (markedAmount * mark.markedEth) / markAmount;
            sliceCursor += markedAmount;
            remainingAmount -= markedAmount;
            // the candidate mark is now consumed up to its end; continue from the next one
            unchecked {
                // bounded by `markCount`, which is the length of a storage array
                ++markIndex;
            }
        }
    }

    /// @notice Internal utility to verify if a redeem request and a withdrawal event are matching
    /// @param _redeemRequest The loaded redeem request
    /// @param _withdrawalEvent The load withdrawal event
    /// @return True if matching
    function _isMatch(
        RedeemQueueV2.RedeemRequest memory _redeemRequest,
        WithdrawalStack.WithdrawalEvent memory _withdrawalEvent
    ) internal pure returns (bool) {
        return (_redeemRequest.height < _withdrawalEvent.height + _withdrawalEvent.amount
                && _redeemRequest.height >= _withdrawalEvent.height);
    }

    /// @notice Internal utility to perform a dichotomic search of the withdrawal event to use to claim the redeem request
    /// @param _redeemRequest The redeem request to resolve
    /// @return The matching withdrawal event
    function _performDichotomicResolution(RedeemQueueV2.RedeemRequest memory _redeemRequest)
        internal
        view
        returns (int64)
    {
        WithdrawalStack.WithdrawalEvent[] storage withdrawalEvents = WithdrawalStack.get();

        int64 max = int64(int256(WithdrawalStack.get().length - 1));

        if (_isMatch(_redeemRequest, withdrawalEvents[uint64(max)])) {
            return max;
        }

        int64 min = 0;

        if (_isMatch(_redeemRequest, withdrawalEvents[uint64(min)])) {
            return min;
        }

        // we start a dichotomic search between min and max
        while (min != max) {
            int64 mid = (min + max) / 2;

            // we identify and verify that the middle element is not matching
            WithdrawalStack.WithdrawalEvent memory midWithdrawalEvent = withdrawalEvents[uint64(mid)];
            if (_isMatch(_redeemRequest, midWithdrawalEvent)) {
                return mid;
            }

            // depending on the position of the middle element, we update max or min to get our min max range
            // closer to our redeem request position
            if (_redeemRequest.height < midWithdrawalEvent.height) {
                max = mid;
            } else {
                min = mid;
            }
        }
        return min;
    }

    /// @notice Internal utility to resolve a redeem request and retrieve its satisfying withdrawal event id, or identify possible errors
    /// @param _redeemRequestId The redeem request id
    /// @param _lastWithdrawalEvent The last withdrawal event loaded in memory
    /// @return withdrawalEventId The id of the withdrawal event matching the redeem request or error code
    function _resolveRedeemRequestId(
        uint32 _redeemRequestId,
        WithdrawalStack.WithdrawalEvent memory _lastWithdrawalEvent
    ) internal view returns (int64 withdrawalEventId) {
        RedeemQueueV2.RedeemRequest[] storage redeemRequests = RedeemQueueV2.get();
        // if the redeem request id is >= than the size of requests, we know it's out of bounds and doesn't exist
        if (_redeemRequestId >= redeemRequests.length) {
            return RESOLVE_OUT_OF_BOUNDS;
        }
        RedeemQueueV2.RedeemRequest memory redeemRequest = redeemRequests[_redeemRequestId];
        // if the redeem request remaining amount is 0, we know that the request has been entirely claimed
        if (redeemRequest.amount == 0) {
            return RESOLVE_FULLY_CLAIMED;
        }
        // if there are no existing withdrawal events or if the height of the redeem request is higher than the height and
        // amount of the last withdrawal element, we know that the redeem request is not yet satisfied
        if (
            WithdrawalStack.get().length == 0
                || (_lastWithdrawalEvent.height + _lastWithdrawalEvent.amount) <= redeemRequest.height
        ) {
            return RESOLVE_UNSATISFIED;
        }
        // we know for sure that the redeem request has funds yet to be claimed and there is a withdrawal event we need to identify
        // that would allow the user to claim the redeem request
        return _performDichotomicResolution(redeemRequest);
    }

    /// @notice Perform a new redeem request for the specified recipient
    /// @param _lsETHAmount The amount of LsETH to redeem
    /// @param _recipient The recipient owning the request
    /// @param _initiator The initiator of the request
    /// @return redeemRequestId The id of the newly created redeem request
    function _requestRedeem(uint256 _lsETHAmount, address _recipient, address _initiator)
        internal
        returns (uint32 redeemRequestId)
    {
        LibSanitize._notZeroAddress(_recipient);
        if (_lsETHAmount == 0) {
            revert InvalidZeroAmount();
        }
        IRiverV1 river = _castedRiver();
        if (!river.transferFrom(msg.sender, address(this), _lsETHAmount)) {
            revert TransferError();
        }
        RedeemQueueV2.RedeemRequest[] storage redeemRequests = RedeemQueueV2.get();
        redeemRequestId = uint32(redeemRequests.length);
        uint256 height = 0;
        if (redeemRequestId != 0) {
            RedeemQueueV2.RedeemRequest memory previousRedeemRequest = redeemRequests[redeemRequestId - 1];
            height = previousRedeemRequest.height + previousRedeemRequest.amount;
        }

        uint256 maxRedeemableEth = river.underlyingBalanceFromShares(_lsETHAmount);

        redeemRequests.push(
            RedeemQueueV2.RedeemRequest({
                height: height,
                amount: _lsETHAmount,
                recipient: _recipient,
                initiator: _initiator,
                maxRedeemableEth: maxRedeemableEth
            })
        );

        // The immutable request-time valuation. maxRedeemableEth cannot serve this purpose because the
        // claim path decrements it by the ETH actually paid, so its implied per-LsETH rate drifts after
        // a partial claim below the request rate.
        RedeemRequestAnchor.get()[redeemRequestId] =
            RedeemRequestAnchor.Anchor({lsETHAtRequest: _lsETHAmount, ethAtRequest: maxRedeemableEth});

        uint256 redeemDemand = RedeemDemand.get();
        _setRedeemDemand(redeemDemand, redeemDemand + _lsETHAmount);

        emit RequestedRedeem(_recipient, height, _lsETHAmount, maxRedeemableEth, redeemRequestId);
    }

    /// @notice Internal structure used to optimize stack usage in _claimRedeemRequest
    struct ClaimRedeemRequestParameters {
        /// @custom:attribute The structure of the redeem request to claim
        RedeemQueueV2.RedeemRequest redeemRequest;
        /// @custom:attribute The structure of the withdrawal event to use to claim the redeem request
        WithdrawalStack.WithdrawalEvent withdrawalEvent;
        /// @custom:attribute The id of the redeem request to claim
        uint32 redeemRequestId;
        /// @custom:attribute The id of the withdrawal event to use to claim the redeem request
        uint32 withdrawalEventId;
        /// @custom:attribute The count of withdrawal events
        uint32 withdrawalEventCount;
        /// @custom:attribute The current depth of the recursive call
        uint16 depth;
        /// @custom:attribute The amount of LsETH redeemed/matched, needs to be reset to 0 for each call/before calling the recursive function
        uint256 lsETHAmount;
        /// @custom:attribute The amount of eth redeemed/matched, needs to be rest to 0 for each call/before calling the recursive function
        uint256 ethAmount;
    }

    /// @notice Internal structure used to optimize stack usage in _claimRedeemRequest
    struct ClaimRedeemRequestInternalVariables {
        /// @custom:attribute The eth amount claimed by the user
        uint256 ethAmount;
        /// @custom:attribute The amount of LsETH matched during this step
        uint256 matchingAmount;
        /// @custom:attribute The amount of eth redirected to the exceeding eth buffer
        uint256 exceedingEthAmount;
    }

    /// @notice Internal utility to save a redeem request to storage
    /// @param _params The parameters of the claim redeem request call
    function _saveRedeemRequest(ClaimRedeemRequestParameters memory _params) internal {
        // The element pointer is taken once: the queue lives at a raw keccak slot, so each
        // `redeemRequests[id]` would otherwise re-derive the element offset from scratch.
        RedeemQueueV2.RedeemRequest storage redeemRequest = RedeemQueueV2.get()[_params.redeemRequestId];
        redeemRequest.height = _params.redeemRequest.height;
        redeemRequest.amount = _params.redeemRequest.amount;
        redeemRequest.maxRedeemableEth = _params.redeemRequest.maxRedeemableEth;
    }

    /// @notice Internal utility to claim a redeem request if possible
    /// @dev Will call itself recursively if the redeem requests overflows its matching withdrawal event
    /// @param _params The parameters of the claim redeem request call
    function _claimRedeemRequest(ClaimRedeemRequestParameters memory _params) internal {
        ClaimRedeemRequestInternalVariables memory vars;
        {
            uint256 withdrawalEventEndPosition = _params.withdrawalEvent.height + _params.withdrawalEvent.amount;

            // it can occur that the redeem request is overlapping the provided withdrawal event
            // the amount that is matched in the withdrawal event is adapted depending on this
            vars.matchingAmount =
                LibUint256.min(_params.redeemRequest.amount, withdrawalEventEndPosition - _params.redeemRequest.height);
            // we can now compute the equivalent eth amount based on the withdrawal event details
            vars.ethAmount =
                (vars.matchingAmount * _params.withdrawalEvent.withdrawnEth) / _params.withdrawalEvent.amount;

            // as each request has a maximum withdrawable amount, we verify that the eth amount is not exceeding this amount, pro rata
            // the amount that is matched
            uint256 maxRedeemableEthAmount;
            {
                RedeemRequestAnchor.Anchor memory anchor = RedeemRequestAnchor.get()[_params.redeemRequestId];
                if (anchor.lsETHAtRequest == 0) {
                    // request predates the stopped-earning upgrade: original semantics, cap pro-rata on
                    // the remaining request-time ETH budget
                    maxRedeemableEthAmount =
                        (vars.matchingAmount * _params.redeemRequest.maxRedeemableEth) / _params.redeemRequest.amount;
                } else {
                    // the cap is the request-time value of the matched slice, raised over whatever part of
                    // it has been marked as having stopped earning
                    maxRedeemableEthAmount = _sliceCap(anchor, _params.redeemRequest.height, vars.matchingAmount);
                }
            }

            if (maxRedeemableEthAmount < vars.ethAmount) {
                unchecked {
                    vars.exceedingEthAmount = vars.ethAmount - maxRedeemableEthAmount;
                }
                BufferedExceedingEth.set(BufferedExceedingEth.get() + vars.exceedingEthAmount);
                vars.ethAmount = maxRedeemableEthAmount;
            }

            // height and amount are updated to reflect the amount that was matched.
            // we will always keep this invariant true oldRequest.height + oldRequest.amount == newRequest.height + newRequest.amount
            // this also means that if the request wasn't entirely matched, it will now be automatically be assigned to the next
            // withdrawal event in the queue, because height is updated based on the amount matched and is now equal to the height
            // of the next withdrawal event
            // the end position of a redeem request (height + amount) is an invariant that never changes throughout the lifetime of a request
            // this end position is used to define the starting position of the next redeem request
            unchecked {
                // `matchingAmount` is a `min()` against `redeemRequest.amount` above, so the
                // decrement cannot underflow; the end position it preserves is bounded by the total
                // LsETH ever queued, so the increment cannot overflow.
                _params.redeemRequest.height += vars.matchingAmount;
                _params.redeemRequest.amount -= vars.matchingAmount;
            }
            // Saturating. For a pre-upgrade request this is exact, because the cap above is derived from
            // this very field and so can never exceed it. For a marked request the payout may legitimately
            // exceed the request-time budget, and this subtraction is checked arithmetic — an unguarded
            // decrement would revert the entire claimRedeemRequests call with Panic(0x11). Post-upgrade the
            // field no longer bounds anything; the cap is recomputed from the anchor and the rate marks.
            _params.redeemRequest.maxRedeemableEth = _params.redeemRequest.maxRedeemableEth > vars.ethAmount
                ? _params.redeemRequest.maxRedeemableEth - vars.ethAmount
                : 0;

            _params.lsETHAmount += vars.matchingAmount;
            _params.ethAmount += vars.ethAmount;

            // this event signals that an amount has been matched from a redeem request on a withdrawal event
            // this event can be triggered several times for the same redeem request, depending on its size and
            // how many withdrawal events it overlaps.
            emit SatisfiedRedeemRequest(
                _params.redeemRequestId,
                _params.withdrawalEventId,
                vars.matchingAmount,
                vars.ethAmount,
                _params.redeemRequest.amount,
                vars.exceedingEthAmount
            );
        }

        // in the case where we haven't claimed all the redeem request AND that there are other withdrawal events
        // available next in the stack, we load the next withdrawal event and call this method recursively
        // also we stop the claim process if the claim depth is about to be 0
        if (
            _params.redeemRequest.amount > 0 && _params.withdrawalEventId + 1 < _params.withdrawalEventCount
                && _params.depth > 0
        ) {
            WithdrawalStack.WithdrawalEvent[] storage withdrawalEvents = WithdrawalStack.get();

            ++_params.withdrawalEventId;
            _params.withdrawalEvent = withdrawalEvents[_params.withdrawalEventId];
            --_params.depth;

            _claimRedeemRequest(_params);
        } else {
            // if we end up here, we either claimed everything or we reached the end of the withdrawal event stack
            // in this case we save the current redeem request state to storage and return the status according to the
            // remaining claimable amount on the redeem request
            _saveRedeemRequest(_params);
        }
    }

    /// @notice Internal utility to claim several redeem requests at once
    /// @param _redeemRequestIds The list of redeem requests to claim
    /// @param _withdrawalEventIds The list of withdrawal events to use for each redeem request. Should have the same length.
    /// @param _skipAlreadyClaimed True if the system should skip redeem requests already claimed, otherwise will revert
    /// @param _depth The depth of the recursion to use when claiming a redeem request
    /// @return claimStatuses The claim statuses for each redeem request
    function _claimRedeemRequests(
        uint32[] calldata _redeemRequestIds,
        uint32[] calldata _withdrawalEventIds,
        bool _skipAlreadyClaimed,
        uint16 _depth
    ) internal returns (uint8[] memory claimStatuses) {
        uint256 redeemRequestIdsLength = _redeemRequestIds.length;
        if (redeemRequestIdsLength != _withdrawalEventIds.length) {
            revert IncompatibleArrayLengths();
        }
        claimStatuses = new uint8[](redeemRequestIdsLength);

        RedeemQueueV2.RedeemRequest[] storage redeemRequests = RedeemQueueV2.get();
        WithdrawalStack.WithdrawalEvent[] storage withdrawalEvents = WithdrawalStack.get();

        ClaimRedeemRequestParameters memory params;
        params.withdrawalEventCount = uint32(withdrawalEvents.length);
        uint32 redeemRequestCount = uint32(redeemRequests.length);

        IAllowlistV1 allowList = IAllowlistV1(_castedRiver().getAllowlist());

        for (uint256 idx = 0; idx < redeemRequestIdsLength; ++idx) {
            // both ids are loaded into params
            params.redeemRequestId = _redeemRequestIds[idx];
            params.withdrawalEventId = _withdrawalEventIds[idx];

            // we start by checking that the id is not out of bounds for the redeem requests
            if (params.redeemRequestId >= redeemRequestCount) {
                revert RedeemRequestOutOfBounds(params.redeemRequestId);
            }

            // we check that the withdrawal event id is not out of bounds
            if (params.withdrawalEventId >= params.withdrawalEventCount) {
                revert WithdrawalEventOutOfBounds(params.withdrawalEventId);
            }

            // we load the redeem request in memory
            params.redeemRequest = redeemRequests[params.redeemRequestId];

            if (allowList.isDenied(params.redeemRequest.recipient)) {
                revert ClaimRecipientIsDenied();
            }
            // `isDenied` is a view over a single account, so when the initiator IS the recipient the
            // check above has already answered for it and the second call would be redundant. The
            // two errors stay distinguishable: this branch is only skipped when the addresses are
            // equal, in which case a denial would already have reverted as ClaimRecipientIsDenied.
            if (
                params.redeemRequest.initiator != params.redeemRequest.recipient
                    && allowList.isDenied(params.redeemRequest.initiator)
            ) {
                revert ClaimInitiatorIsDenied();
            }

            // we check that the redeem request is not already claimed
            if (params.redeemRequest.amount == 0) {
                if (_skipAlreadyClaimed) {
                    claimStatuses[idx] = CLAIM_SKIPPED;
                    continue;
                }
                revert RedeemRequestAlreadyClaimed(params.redeemRequestId);
            }

            // we load the withdrawal event in memory
            params.withdrawalEvent = withdrawalEvents[params.withdrawalEventId];

            // now that both entities are loaded in memory, we verify that they indeed match, otherwise we revert
            if (!_isMatch(params.redeemRequest, params.withdrawalEvent)) {
                revert DoesNotMatch(params.redeemRequestId, params.withdrawalEventId);
            }

            params.depth = _depth;
            params.ethAmount = 0;
            params.lsETHAmount = 0;

            _claimRedeemRequest(params);

            claimStatuses[idx] = params.redeemRequest.amount == 0 ? CLAIM_FULLY_CLAIMED : CLAIM_PARTIALLY_CLAIMED;

            {
                (bool success, bytes memory rdata) = params.redeemRequest.recipient.call{value: params.ethAmount}("");
                if (!success) {
                    revert ClaimRedeemFailed(params.redeemRequest.recipient, rdata);
                }
            }
            emit ClaimedRedeemRequest(
                params.redeemRequestId,
                params.redeemRequest.recipient,
                params.ethAmount,
                params.lsETHAmount,
                params.redeemRequest.amount
            );
        }
    }

    /// @notice Internal utility to set the redeem demand
    /// @dev The old value is passed in rather than re-read: both call sites already hold it in a
    ///      local to compute the new one, so reloading it here would only pay for a second SLOAD.
    /// @param _oldValue The current value, emitted as the previous demand
    /// @param _newValue The new value to set
    function _setRedeemDemand(uint256 _oldValue, uint256 _newValue) internal {
        emit SetRedeemDemand(_oldValue, _newValue);
        RedeemDemand.set(_newValue);
    }

    function version() external pure returns (string memory) {
        return "1.3.0";
    }
}
