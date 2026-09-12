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
import "./state/redeemManager/RedeemRequestAnchor.sol";
import "./state/redeemManager/RateMarkStart.sol";

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
    /// @dev Makes an external view call to River. River must be initialized before any function guarded
    ///      by this modifier is callable, or the call reverts with a non-contract error.
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

    function _redeemQueueMigrationV1_2() internal {
        RedeemQueueV1.RedeemRequest[] memory oldQueue = RedeemQueueV1.get();
        uint256 oldQueueLen = oldQueue.length;
        RedeemQueueV2.RedeemRequest[] storage newQueue = RedeemQueueV2.get();

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
    function findRedeemRequestIdAtHeight(uint256 _height) external view returns (bool found, uint32 redeemRequestId) {
        return _findRedeemRequestIdAtHeight(_height);
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
        // A zero LsETH leg also covers a pool holding no assets or no shares, where River's conversion
        // returns 0. Returning here is what makes the division below safe with no further guard.
        if (_stoppedEarningEth == 0 || _stoppedEarningLsETH == 0) {
            return;
        }

        RedeemQueueV2.RedeemRequest[] storage redeemRequests = RedeemQueueV2.get();
        uint256 requestCount = redeemRequests.length;
        if (requestCount == 0) {
            return;
        }

        // Claiming raises a request's height and lowers its amount by the same step, so its end position
        // never moves. The last request's end position is therefore the total LsETH ever requested.
        RedeemQueueV2.RedeemRequest storage lastRequest = redeemRequests[requestCount - 1];
        uint256 totalRequestedHeight = lastRequest.height + lastRequest.amount;

        // Marks may only cover demand that is still unsettled. A withdrawal event has already priced the
        // slice below `settledHeight`, and that event's ETH caps what it pays out regardless. Marking it
        // anyway would credit the redeemer with pool appreciation that accrued after their principal
        // stopped earning.
        uint256 markStart = RateMarkStart.get();
        uint256 settledHeight = _settledHeight();
        if (settledHeight > markStart) {
            markStart = settledHeight;
        }

        // find affected redeem requests, i.e. requests that overlap with markStart + lsETHToMark
        (, uint32 affectedRequestIndex) = _findRedeemRequestIdAtHeight(markStart);

        uint256 markEnd = markStart + _stoppedEarningLsETH;
        uint256 requestEnd = 0;
        while (affectedRequestIndex < requestCount) {
            RedeemQueueV2.RedeemRequest storage affectedRequest = redeemRequests[affectedRequestIndex];
            requestEnd = affectedRequest.height + affectedRequest.amount;

            if (markEnd <= affectedRequest.height) {
                break;
            }

            uint256 overlapStart = LibUint256.max(affectedRequest.height, markStart);
            uint256 overlapEnd = LibUint256.min(requestEnd, markEnd);
            uint256 overlapSize = overlapEnd - overlapStart;

            RedeemRequestAnchor.Anchor memory anchor = RedeemRequestAnchor.get()[affectedRequestIndex];
            // skip legacy requests
            if (anchor.lsETHAtRequest != 0) {
                affectedRequest.maxRedeemableEth = affectedRequest.maxRedeemableEth + overlapSize * _stoppedEarningEth
                    / _stoppedEarningLsETH - overlapSize * anchor.ethAtRequest / anchor.lsETHAtRequest;
            }

            ++affectedRequestIndex;
        }

        RateMarkStart.set(LibUint256.min(markEnd, requestEnd));

        // ToDo: ? emit only when a mark has some effect ?
        emit ReportedStoppedEarning();
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

    /// @notice Internal utility to find the redeem request whose current range covers a position
    /// @dev The redeem queue is ascending and gapless when first written: each request's height equals the
    ///      previous request's height + amount. Claiming preserves this order, since a request's height
    ///      only ever advances up to its own original end position, which is the next request's original
    ///      start, so it can never overtake that request's (possibly also advanced) height.
    /// @param _height The position to search for
    /// @return found True if some redeem request's current range contains `_height`
    /// @return redeemRequestId The id of that redeem request
    function _findRedeemRequestIdAtHeight(uint256 _height) internal view returns (bool found, uint32 redeemRequestId) {
        RedeemQueueV2.RedeemRequest[] storage redeemRequests = RedeemQueueV2.get();
        uint256 length = redeemRequests.length;

        // Either the queue is empty or `_height` sits below the first request, so nothing can cover it.
        if (length == 0 || redeemRequests[0].height > _height) {
            return (false, 0);
        }

        // Binary search for the rightmost request with `height <= _height`.
        uint256 low = 0;
        uint256 high = length - 1;
        while (low < high) {
            // Round up so `mid` is always greater than `low`.
            uint256 mid = (low + high + 1) / 2;
            if (redeemRequests[mid].height <= _height) {
                // Valid candidate; try to move right.
                low = mid;
            } else {
                // Too far right; search left side.
                high = mid - 1;
            }
        }

        RedeemQueueV2.RedeemRequest storage candidate = redeemRequests[low];
        if (_height >= candidate.height + candidate.amount) {
            // `_height` sits at or past the candidate's end, either in a gap left by a partial claim or
            // past the end of the queue. No request currently owns this position.
            return (false, 0);
        }

        return (true, uint32(low));
    }

    /// @notice Internal utility to verify if a redeem request and a withdrawal event are matching
    /// @param _redeemRequest The loaded redeem request
    /// @param _withdrawalEvent The loaded withdrawal event
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

        while (min != max) {
            int64 mid = (min + max) / 2;

            // Return as soon as the middle element matches.
            WithdrawalStack.WithdrawalEvent memory midWithdrawalEvent = withdrawalEvents[uint64(mid)];
            if (_isMatch(_redeemRequest, midWithdrawalEvent)) {
                return mid;
            }

            // Move whichever bound sits on the wrong side of the request, narrowing the range towards its
            // position.
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
        // An id at or past the end of the queue refers to a request that does not exist.
        if (_redeemRequestId >= redeemRequests.length) {
            return RESOLVE_OUT_OF_BOUNDS;
        }
        RedeemQueueV2.RedeemRequest memory redeemRequest = redeemRequests[_redeemRequestId];
        // A zero remaining amount means the request has been claimed in full.
        if (redeemRequest.amount == 0) {
            return RESOLVE_FULLY_CLAIMED;
        }
        // With no withdrawal events at all, or with the request starting at or past the end of the last
        // event, nothing has been withdrawn yet that could satisfy it.
        if (
            WithdrawalStack.get().length == 0
                || (_lastWithdrawalEvent.height + _lastWithdrawalEvent.amount) <= redeemRequest.height
        ) {
            return RESOLVE_UNSATISFIED;
        }
        // The request still has funds to claim and some event covers it, so find which one.
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

        // The request-time valuation, never mutated after this write. `maxRedeemableEth` cannot serve
        // this purpose, because the claim path decrements it by the ETH actually paid, leaving an implied
        // per-LsETH rate below the request rate once the request is partially claimed.
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
        /// @custom:attribute The request-time valuation of the request, zeroed `lsETHAtRequest` if pre-upgrade. Per request, so it is loaded once by the caller rather than at every recursion level
        RedeemRequestAnchor.Anchor anchor;
        /// @custom:attribute The cap earlier fills were credited with but did not pay out, needs to be reloaded for each call/before calling the recursive function. Carried in memory across the recursion and flushed once by `_saveRedeemRequest`
        uint32 redeemRequestId;
        /// @custom:attribute The id of the withdrawal event to use to claim the redeem request
        uint32 withdrawalEventId;
        /// @custom:attribute The count of withdrawal events
        uint32 withdrawalEventCount;
        /// @custom:attribute The current depth of the recursive call
        uint16 depth;
        /// @custom:attribute The amount of LsETH redeemed/matched, needs to be reset to 0 for each call/before calling the recursive function
        uint256 lsETHAmount;
        /// @custom:attribute The amount of eth redeemed/matched, needs to be reset to 0 for each call/before calling the recursive function
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
        // Take the element pointer once. The queue lives at a raw keccak slot, so each
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

            // A request can extend past the end of the provided withdrawal event, so match only the part
            // of it that falls inside the event.
            vars.matchingAmount =
                LibUint256.min(_params.redeemRequest.amount, withdrawalEventEndPosition - _params.redeemRequest.height);
            vars.ethAmount =
                (vars.matchingAmount * _params.withdrawalEvent.withdrawnEth) / _params.withdrawalEvent.amount;

            uint256 maxRedeemableEthAmount = _params.redeemRequest.maxRedeemableEth;

            if (maxRedeemableEthAmount < vars.ethAmount) {
                unchecked {
                    vars.exceedingEthAmount = vars.ethAmount - maxRedeemableEthAmount;
                }
                BufferedExceedingEth.set(BufferedExceedingEth.get() + vars.exceedingEthAmount);
                vars.ethAmount = maxRedeemableEthAmount;
            }

            // Height rises and amount falls by the matched amount, so `height + amount` never changes over
            // a request's lifetime. That end position is where the next request starts, and it also means
            // a partly matched request now begins exactly at the next withdrawal event's height.
            unchecked {
                // `matchingAmount` is a `min()` against `redeemRequest.amount` above, so the decrement
                // cannot underflow. The end position it preserves is bounded by the total LsETH ever
                // queued, so the increment cannot overflow.
                _params.redeemRequest.height += vars.matchingAmount;
                _params.redeemRequest.amount -= vars.matchingAmount;
            }

            _params.redeemRequest.maxRedeemableEth -= vars.ethAmount;
            _params.lsETHAmount += vars.matchingAmount;
            _params.ethAmount += vars.ethAmount;

            // A single request emits this once per withdrawal event it overlaps.
            emit SatisfiedRedeemRequest(
                _params.redeemRequestId,
                _params.withdrawalEventId,
                vars.matchingAmount,
                vars.ethAmount,
                _params.redeemRequest.amount,
                vars.exceedingEthAmount
            );
        }

        // With the request only partly claimed and another withdrawal event left in the stack, continue
        // into that event. A remaining depth of 0 stops the walk instead.
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
            // Either the request is fully claimed or the stack is exhausted. Persist the request state.
            // The caller reads the claim status off the remaining amount.
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
            params.redeemRequestId = _redeemRequestIds[idx];
            params.withdrawalEventId = _withdrawalEventIds[idx];

            if (params.redeemRequestId >= redeemRequestCount) {
                revert RedeemRequestOutOfBounds(params.redeemRequestId);
            }

            if (params.withdrawalEventId >= params.withdrawalEventCount) {
                revert WithdrawalEventOutOfBounds(params.withdrawalEventId);
            }

            params.redeemRequest = redeemRequests[params.redeemRequestId];

            if (allowList.isDenied(params.redeemRequest.recipient)) {
                revert ClaimRecipientIsDenied();
            }
            // `isDenied` is a view over a single account, so when the initiator equals the recipient the
            // check above has already answered for it. Skipping the second call keeps the two errors
            // distinguishable, because equal addresses would already have reverted as
            // ClaimRecipientIsDenied.
            if (
                params.redeemRequest.initiator != params.redeemRequest.recipient
                    && allowList.isDenied(params.redeemRequest.initiator)
            ) {
                revert ClaimInitiatorIsDenied();
            }

            if (params.redeemRequest.amount == 0) {
                if (_skipAlreadyClaimed) {
                    claimStatuses[idx] = CLAIM_SKIPPED;
                    continue;
                }
                revert RedeemRequestAlreadyClaimed(params.redeemRequestId);
            }

            params.withdrawalEvent = withdrawalEvents[params.withdrawalEventId];

            if (!_isMatch(params.redeemRequest, params.withdrawalEvent)) {
                revert DoesNotMatch(params.redeemRequestId, params.withdrawalEventId);
            }

            params.depth = _depth;
            params.ethAmount = 0;
            params.lsETHAmount = 0;
            params.anchor = RedeemRequestAnchor.get()[params.redeemRequestId];

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
    /// @dev The old value is passed in rather than re-read. Both call sites already hold it in a local to
    ///      compute the new one, so reloading it here would only pay for a second SLOAD.
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
