//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "./interfaces/IAllowlist.1.sol";
import "./interfaces/IRiver.1.sol";
import "./interfaces/IRedeemManager.1.sol";
import "./libraries/LibAllowlistMasks.sol";
import "./libraries/LibUint256.sol";
import "./Initializable.sol";

import "./state/shared/RiverAddress.sol";
import "./state/redeemManager/RedeemQueue.sol";
import "./state/redeemManager/WithdrawalStack.sol";
import "./state/redeemManager/BufferedExceedingEth.sol";
import "./state/redeemManager/RedeemDemand.sol";

/// @title Redeem Manager (v1)
/// @author Kiln
/// @notice This contract handles the redeem requests of all users
contract RedeemManagerV1 is Initializable, IRedeemManagerV1 {
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

    modifier onlyRedeemerOrRiver() {
        {
            IRiverV1 river = _river();
            if (msg.sender != address(river)) {
                IAllowlistV1(river.getAllowlist()).onlyAllowed(msg.sender, LibAllowlistMasks.REDEEM_MASK);
            }
        }
        _;
    }

    modifier onlyRedeemer() {
        {
            IRiverV1 river = _river();
            IAllowlistV1(river.getAllowlist()).onlyAllowed(msg.sender, LibAllowlistMasks.REDEEM_MASK);
        }
        _;
    }

    /// @inheritdoc IRedeemManagerV1
    function initializeRedeemManagerV1(address river) external init(0) {
        RiverAddress.set(river);
        emit SetRiver(river);
    }

    /// @inheritdoc IRedeemManagerV1
    function getRedeemRequestCount() external view returns (uint256) {
        return RedeemQueue.get().length;
    }

    /// @inheritdoc IRedeemManagerV1
    function getRedeemRequestDetails(uint32 redeemRequestId) external view returns (RedeemQueue.RedeemRequest memory) {
        return RedeemQueue.get()[redeemRequestId];
    }

    /// @inheritdoc IRedeemManagerV1
    function getWithdrawalEventCount() external view returns (uint256) {
        return WithdrawalStack.get().length;
    }

    /// @inheritdoc IRedeemManagerV1
    function getWithdrawalEventDetails(uint32 withdrawalEventId)
        external
        view
        returns (WithdrawalStack.WithdrawalEvent memory)
    {
        return WithdrawalStack.get()[withdrawalEventId];
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
    function resolveRedeemRequests(uint32[] calldata redeemRequestIds)
        external
        view
        returns (int64[] memory withdrawalEventIds)
    {
        withdrawalEventIds = new int64[](redeemRequestIds.length);
        WithdrawalStack.WithdrawalEvent memory lastWithdrawalEvent;
        WithdrawalStack.WithdrawalEvent[] storage withdrawalEvents = WithdrawalStack.get();
        uint256 withdrawalEventsLength = withdrawalEvents.length;
        if (withdrawalEventsLength > 0) {
            lastWithdrawalEvent = withdrawalEvents[withdrawalEventsLength - 1];
        }
        for (uint256 idx = 0; idx < redeemRequestIds.length; ++idx) {
            withdrawalEventIds[idx] = _resolveRedeemRequestId(redeemRequestIds[idx], lastWithdrawalEvent);
        }
    }

    /// @inheritdoc IRedeemManagerV1
    function requestRedeem(uint256 lsETHAmount, address recipient)
        external
        onlyRedeemerOrRiver
        returns (uint32 redeemRequestId)
    {
        return _requestRedeem(lsETHAmount, recipient);
    }

    /// @inheritdoc IRedeemManagerV1
    function requestRedeem(uint256 lsETHAmount) external onlyRedeemer returns (uint32 redeemRequestId) {
        return _requestRedeem(lsETHAmount, msg.sender);
    }

    /// @inheritdoc IRedeemManagerV1
    function claimRedeemRequests(
        uint32[] calldata redeemRequestIds,
        uint32[] calldata withdrawalEventIds,
        bool skipAlreadyClaimed,
        uint16 _depth
    ) external returns (uint8[] memory claimStatuses) {
        return _claimRedeemRequests(redeemRequestIds, withdrawalEventIds, skipAlreadyClaimed, _depth);
    }

    /// @inheritdoc IRedeemManagerV1
    function claimRedeemRequests(uint32[] calldata redeemRequestIds, uint32[] calldata withdrawalEventIds)
        external
        returns (uint8[] memory claimStatuses)
    {
        return _claimRedeemRequests(redeemRequestIds, withdrawalEventIds, true, type(uint16).max);
    }

    /// @inheritdoc IRedeemManagerV1
    function reportWithdraw(uint256 lsETHWithdrawable) external payable onlyRiver {
        uint256 redeemDemand = RedeemDemand.get();
        if (lsETHWithdrawable > redeemDemand) {
            revert WithdrawalExceedsRedeemDemand(lsETHWithdrawable, redeemDemand);
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
            WithdrawalStack.WithdrawalEvent({height: height, amount: lsETHWithdrawable, withdrawnEth: msgValue})
        );
        _setRedeemDemand(redeemDemand - lsETHWithdrawable);
        emit ReportedWithdrawal(height, lsETHWithdrawable, msgValue, withdrawalEventId);
    }

    /// @inheritdoc IRedeemManagerV1
    function pullExceedingEth(uint256 max) external onlyRiver {
        uint256 amountToSend = LibUint256.min(BufferedExceedingEth.get(), max);
        BufferedExceedingEth.set(BufferedExceedingEth.get() - amountToSend);
        _river().sendRedeemManagerExceedingFunds{value: amountToSend}();
    }

    /// @notice Internal utility to load and cast the River address
    /// @return The casted river address
    function _river() internal view returns (IRiverV1) {
        return IRiverV1(payable(RiverAddress.get()));
    }

    /// @notice Internal utility to verify if a redeem request and a withdrawal event are matching
    /// @param redeemRequest The loaded redeem request
    /// @param withdrawalEvent The load withdrawal event
    /// @return True if matching
    function _isMatch(
        RedeemQueue.RedeemRequest memory redeemRequest,
        WithdrawalStack.WithdrawalEvent memory withdrawalEvent
    ) internal pure returns (bool) {
        return (
            redeemRequest.height < withdrawalEvent.height + withdrawalEvent.amount
                && redeemRequest.height >= withdrawalEvent.height
        );
    }

    /// @notice Internal utility to perform a dichotomic search of the withdrawal event to use to claim the redeem request
    /// @param redeemRequest The redeem request to resolve
    /// @return The matching withdrawal event
    function _performDichotomicResolution(RedeemQueue.RedeemRequest memory redeemRequest)
        internal
        view
        returns (int64)
    {
        WithdrawalStack.WithdrawalEvent[] storage withdrawalEvents = WithdrawalStack.get();

        int64 max = int64(int256(WithdrawalStack.get().length - 1));

        if (_isMatch(redeemRequest, withdrawalEvents[uint64(max)])) {
            return max;
        }

        int64 min = 0;

        if (_isMatch(redeemRequest, withdrawalEvents[uint64(min)])) {
            return min;
        }

        // we start a dichotomic search between min and max
        while (min != max) {
            int64 mid = (min + max) / 2;

            // we identify and verify that the middle element is not matching
            WithdrawalStack.WithdrawalEvent memory midWithdrawalEvent = withdrawalEvents[uint64(mid)];
            if (_isMatch(redeemRequest, midWithdrawalEvent)) {
                return mid;
            }

            // depending on the position of the middle element, we update max or min to get our min max range
            // closer to our redeem request position
            if (redeemRequest.height < midWithdrawalEvent.height) {
                max = mid;
            } else {
                min = mid;
            }
        }
        return min;
    }

    /// @notice Internal utility to resolve a redeem request and retrieve its satisfying withdrawal event id, or identify possible errors
    /// @param redeemRequestId The redeem request id
    /// @param lastWithdrawalEvent The last withdrawal event loaded in memory
    /// @param withdrawalEventId The id of the withdrawal event matching the redeem request or error code
    function _resolveRedeemRequestId(uint32 redeemRequestId, WithdrawalStack.WithdrawalEvent memory lastWithdrawalEvent)
        internal
        view
        returns (int64 withdrawalEventId)
    {
        RedeemQueue.RedeemRequest[] storage redeemRequests = RedeemQueue.get();
        // if the redeem request id is >= than the size of requests, we know it's out of bounds and doesn't exist
        if (redeemRequestId >= redeemRequests.length) {
            return RESOLVE_OUT_OF_BOUNDS;
        }
        RedeemQueue.RedeemRequest memory redeemRequest = redeemRequests[redeemRequestId];
        // if the redeem request remaining amount is 0, we know that the request has been entirely claimed
        if (redeemRequest.amount == 0) {
            return RESOLVE_FULLY_CLAIMED;
        }
        // if there are no existing withdrawal events or if the height of the redeem request is higher than the height and
        // amount of the last withdrawal element, we know that the redeem request is not yet satisfied
        if (
            WithdrawalStack.get().length == 0
                || (lastWithdrawalEvent.height + lastWithdrawalEvent.amount) <= redeemRequest.height
        ) {
            return RESOLVE_UNSATISFIED;
        }
        // we know for sure that the redeem request has funds yet to be claimed and there is a withdrawal event we need to identify
        // that would allow the user to claim the redeem request
        return _performDichotomicResolution(redeemRequest);
    }

    /// @notice Perform a new redeem request for the specified recipient
    /// @param lsETHAmount The amount of LsETH to redeem
    /// @param recipient The recipient owning the request
    /// @return redeemRequestId The id of the newly created redeem request
    function _requestRedeem(uint256 lsETHAmount, address recipient) internal returns (uint32 redeemRequestId) {
        LibSanitize._notZeroAddress(recipient);
        if (lsETHAmount == 0) {
            revert InvalidZeroAmount();
        }
        if (!_river().transferFrom(msg.sender, address(this), lsETHAmount)) {
            revert TransferError();
        }
        RedeemQueue.RedeemRequest[] storage redeemRequests = RedeemQueue.get();
        redeemRequestId = uint32(redeemRequests.length);
        uint256 height = 0;
        if (redeemRequestId != 0) {
            RedeemQueue.RedeemRequest memory previousRedeemRequest = redeemRequests[redeemRequestId - 1];
            height = previousRedeemRequest.height + previousRedeemRequest.amount;
        }

        uint256 maxRedeemableEth = _river().underlyingBalanceFromShares(lsETHAmount);

        redeemRequests.push(
            RedeemQueue.RedeemRequest({
                height: height,
                amount: lsETHAmount,
                owner: recipient,
                maxRedeemableEth: maxRedeemableEth
            })
        );

        _setRedeemDemand(RedeemDemand.get() + lsETHAmount);

        emit RequestedRedeem(recipient, height, lsETHAmount, redeemRequestId);
    }

    /// @notice Internal structure used to optimize stack usage in _claimRedeemRequest
    struct ClaimRedeemRequestParameters {
        /// @custom:attribute The id of the redeem request to claim
        uint32 redeemRequestId;
        /// @custom:attribute The structure of the redeem request to claim
        RedeemQueue.RedeemRequest redeemRequest;
        /// @custom:attribute The id of the withdrawal event to use to claim the redeem request
        uint32 withdrawalEventId;
        /// @custom:attribute The structure of the withdrawal event to use to claim the redeem request
        WithdrawalStack.WithdrawalEvent withdrawalEvent;
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
    /// @param params The parameters of the claim redeem request call
    function _saveRedeemRequest(ClaimRedeemRequestParameters memory params) internal {
        RedeemQueue.RedeemRequest[] storage redeemRequests = RedeemQueue.get();
        redeemRequests[params.redeemRequestId].height = params.redeemRequest.height;
        redeemRequests[params.redeemRequestId].amount = params.redeemRequest.amount;
        redeemRequests[params.redeemRequestId].maxRedeemableEth = params.redeemRequest.maxRedeemableEth;
    }

    /// @notice Internal utility to claim a redeem request if possible
    /// @dev Will call itself recursively if the redeem requests overflows its matching withdrawal event
    /// @param params The parameters of the claim redeem request call
    function _claimRedeemRequest(ClaimRedeemRequestParameters memory params) internal {
        ClaimRedeemRequestInternalVariables memory vars;
        {
            uint256 withdrawalEventEndPosition = params.withdrawalEvent.height + params.withdrawalEvent.amount;

            // it can occur that the redeem request is overlapping the provided withdrawal event
            // the amount that is matched in the withdrawal event is adapted depending on this
            vars.matchingAmount =
                LibUint256.min(params.redeemRequest.amount, withdrawalEventEndPosition - params.redeemRequest.height);
            // we can now compute the equivalent eth amount based on the withdrawal event details
            vars.ethAmount = (vars.matchingAmount * params.withdrawalEvent.withdrawnEth) / params.withdrawalEvent.amount;

            // as each request has a maximum withdrawable amount, we verify that the eth amount is not exceeding this amount, pro rata
            // the amount that is matched
            uint256 maxRedeemableEthAmount =
                (vars.matchingAmount * params.redeemRequest.maxRedeemableEth) / params.redeemRequest.amount;

            if (maxRedeemableEthAmount < vars.ethAmount) {
                vars.exceedingEthAmount = vars.ethAmount - maxRedeemableEthAmount;
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
            params.redeemRequest.height += vars.matchingAmount;
            params.redeemRequest.amount -= vars.matchingAmount;
            params.redeemRequest.maxRedeemableEth -= vars.ethAmount;

            params.lsETHAmount += vars.matchingAmount;
            params.ethAmount += vars.ethAmount;

            // this event signals that an amount has been matched from a redeem request on a withdrawal event
            // this event can be triggered several times for the same redeem request, depending on its size and
            // how many withdrawal events it overlaps.
            emit SatisfiedRedeemRequest(
                params.redeemRequestId,
                params.withdrawalEventId,
                vars.matchingAmount,
                vars.ethAmount,
                params.redeemRequest.amount,
                vars.exceedingEthAmount
            );
        }

        // in the case where we haven't claimed all the redeem request AND that there are other withdrawal events
        // available next in the stack, we load the next withdrawal event and call this method recursively
        // also we stop the claim process if the claim depth is about to be 0
        if (
            params.redeemRequest.amount > 0 && params.withdrawalEventId + 1 < params.withdrawalEventCount
                && params.depth > 0
        ) {
            WithdrawalStack.WithdrawalEvent[] storage withdrawalEvents = WithdrawalStack.get();

            ++params.withdrawalEventId;
            params.withdrawalEvent = withdrawalEvents[params.withdrawalEventId];
            --params.depth;

            _claimRedeemRequest(params);
        } else {
            // if we end up here, we either claimed everything or we reached the end of the withdrawal event stack
            // in this case we save the current redeem request state to storage and return the status according to the
            // remaining claimable amount on the redeem request
            _saveRedeemRequest(params);
        }
    }

    /// @notice Internal utility to claim several redeem requests at once
    /// @param redeemRequestIds The list of redeem requests to claim
    /// @param withdrawalEventIds The list of withdrawal events to use for each redeem request. Should have the same length.
    /// @param skipAlreadyClaimed True if the system should skip redeem requests already claimed, otherwise will revert
    /// @param _depth The depth of the recursion to use when claiming a redeem request
    /// @return claimStatuses The claim statuses for each redeem request
    function _claimRedeemRequests(
        uint32[] calldata redeemRequestIds,
        uint32[] calldata withdrawalEventIds,
        bool skipAlreadyClaimed,
        uint16 _depth
    ) internal returns (uint8[] memory claimStatuses) {
        uint256 redeemRequestIdsLength = redeemRequestIds.length;
        if (redeemRequestIdsLength != withdrawalEventIds.length) {
            revert IncompatibleArrayLengths();
        }
        claimStatuses = new uint8[](redeemRequestIdsLength);

        RedeemQueue.RedeemRequest[] storage redeemRequests = RedeemQueue.get();
        WithdrawalStack.WithdrawalEvent[] storage withdrawalEvents = WithdrawalStack.get();

        ClaimRedeemRequestParameters memory params;
        params.withdrawalEventCount = uint32(withdrawalEvents.length);
        uint32 redeemRequestCount = uint32(redeemRequests.length);

        for (uint256 idx = 0; idx < redeemRequestIdsLength;) {
            // both ids are loaded into params
            params.redeemRequestId = redeemRequestIds[idx];
            params.withdrawalEventId = withdrawalEventIds[idx];

            // we start by checking that the id is not out of bounds for the redeem requests
            if (params.redeemRequestId >= redeemRequestCount) {
                revert RedeemRequestOutOfBounds(params.redeemRequestId);
            }

            // we check that the withdrawal event id is not out of bounds
            if (params.withdrawalEventId >= params.withdrawalEventCount) {
                revert WithdrawalEventOutOfBounds(params.withdrawalEventId);
            }

            // we load the redeem request in memory
            params.redeemRequest = redeemRequests[redeemRequestIds[idx]];

            // we check that the redeem request is not already claimed
            if (params.redeemRequest.amount == 0) {
                if (skipAlreadyClaimed) {
                    claimStatuses[idx] = CLAIM_SKIPPED;
                    unchecked {
                        ++idx;
                    }
                    continue;
                }
                revert RedeemRequestAlreadyClaimed(params.redeemRequestId);
            }

            // we load the withdrawal event in memory
            params.withdrawalEvent = withdrawalEvents[withdrawalEventIds[idx]];

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
                (bool success, bytes memory rdata) = params.redeemRequest.owner.call{value: params.ethAmount}("");
                if (!success) {
                    revert ClaimRedeemFailed(params.redeemRequest.owner, rdata);
                }
            }
            emit ClaimedRedeemRequest(
                redeemRequestIds[idx],
                params.redeemRequest.owner,
                params.ethAmount,
                params.lsETHAmount,
                params.redeemRequest.amount
            );

            unchecked {
                ++idx;
            }
        }
    }

    /// @notice Internal utility to set the redeem demand
    /// @param newValue The new value to set
    function _setRedeemDemand(uint256 newValue) internal {
        emit SetRedeemDemand(RedeemDemand.get(), newValue);
        RedeemDemand.set(newValue);
    }
}
