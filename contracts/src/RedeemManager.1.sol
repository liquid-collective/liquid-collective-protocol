//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "./interfaces/IAllowlist.1.sol";
import "./interfaces/IRiver.1.sol";
import "./interfaces/IRedeemManager.1.sol";
import "./libraries/LibAllowlistMasks.sol";
import "./Initializable.sol";

import "./state/shared/RiverAddress.sol";
import "./state/redeemManager/RedeemQueue.sol";
import "./state/redeemManager/WithdrawalStack.sol";
import "./state/redeemManager/BufferedExceedingEth.sol";

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

    modifier onlyRedeemer() {
        IAllowlistV1(_river().getAllowlist()).onlyAllowed(msg.sender, LibAllowlistMasks.REDEEM_MASK);
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
        onlyRedeemer
        returns (uint32 redeemRequestId)
    {
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

        emit RequestedRedeem(recipient, height, lsETHAmount, redeemRequestId);
    }

    /// @inheritdoc IRedeemManagerV1
    function claimRedeemRequests(
        uint32[] calldata redeemRequestIds,
        uint32[] calldata withdrawalEventIds,
        bool skipAlreadyClaimed
    ) external returns (uint8[] memory claimStatuses) {
        uint256 redeemRequestIdsLength = redeemRequestIds.length;
        if (redeemRequestIdsLength != withdrawalEventIds.length) {
            revert IncompatibleArrayLengths();
        }
        address[] memory accounts = new address[](redeemRequestIdsLength);
        claimStatuses = new uint8[](redeemRequestIdsLength);
        for (uint256 idx = 0; idx < redeemRequestIdsLength;) {
            (address recipient, uint256 amount, uint8 claimStatus) =
                _claimRedeemRequest(redeemRequestIds[idx], withdrawalEventIds[idx], skipAlreadyClaimed, false);
            claimStatuses[idx] = claimStatus;

            (bool success, bytes memory rdata) = recipient.call{value: amount}("");
            if (!success) {
                assembly {
                    revert(add(32, rdata), mload(rdata))
                }
            }
            emit ClaimedRedeemRequest(redeemRequestIds[idx], recipient, amount, claimStatus == CLAIM_FULLY_CLAIMED);

            accounts[idx] = recipient;
            unchecked {
                ++idx;
            }
        }
    }

    /// @inheritdoc IRedeemManagerV1
    function reportWithdraw(uint256 lsETHWithdrawable) external payable onlyRiver {
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

        emit ReportedWithdrawal(height, lsETHWithdrawable, msgValue, withdrawalEventId);
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

        while (min != max) {
            int64 mid = (min + max) / 2;

            WithdrawalStack.WithdrawalEvent memory midWithdrawalEvent = withdrawalEvents[uint64(mid)];
            if (_isMatch(redeemRequest, midWithdrawalEvent)) {
                return mid;
            }

            if (redeemRequest.height < midWithdrawalEvent.height) {
                max = mid;
            } else {
                min = mid;
            }
        }
        // we have eliminated all code paths that could lead to this line so we will never get to this return
        // statement but it's needed for the compiler warnings
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
                || (lastWithdrawalEvent.height + lastWithdrawalEvent.amount) < redeemRequest.height
        ) {
            return RESOLVE_UNSATISFIED;
        }
        // we know for sure that the redeem request has funds yet to be claimed and there is a withdrawal event we need to identify
        // that would allow the user to claim the redeem request
        return _performDichotomicResolution(redeemRequest);
    }

    /// @notice Internal utility to claim a redeem request if possible
    /// @dev Will call itself recursively if the redeem requests overflows its matching withdrawal event
    /// @param redeemRequestId The redeem request to claim
    /// @param withdrawalEventId Its matching withdrawal event, computed by performing an rpc call to resolveRedeemRequests
    /// @param skipAlreadyClaimed True if the method should skip redeem requests already claimed
    /// @param skipWithdrawalEventDoesNotExist True if the method should simply return if the withdrawal event is out of bounds
    /// @return The owner of the redeem request
    /// @return The amount of ETH to send to the owner
    function _claimRedeemRequest(
        uint32 redeemRequestId,
        uint32 withdrawalEventId,
        bool skipAlreadyClaimed,
        bool skipWithdrawalEventDoesNotExist
    ) internal returns (address, uint256, uint8) {
        RedeemQueue.RedeemRequest[] storage redeemRequests = RedeemQueue.get();
        // the provided redeem request id is >= than the total count of request, meaning that the provided id doesn't exist
        // we revert in this case
        if (redeemRequestId >= redeemRequests.length) {
            revert RedeemRequestOutOfBounds(redeemRequestId);
        }
        WithdrawalStack.WithdrawalEvent[] storage withdrawalEvents = WithdrawalStack.get();
        // same check is done with the withdrawal event
        // we revert only if the skipWithdrawalEventDoesNotExist flag is false
        // otherwise we return the CLAIM_PARTIALLY_CLAIMED status
        if (withdrawalEventId >= withdrawalEvents.length) {
            if (skipWithdrawalEventDoesNotExist) {
                return (address(0), 0, CLAIM_PARTIALLY_CLAIMED);
            }
            revert WithdrawalEventOutOfBounds(withdrawalEventId);
        }
        RedeemQueue.RedeemRequest memory redeemRequest = redeemRequests[redeemRequestId];
        // if the redeem request is already claimed and if the skipAlreadyClaimed flag is false, we revert
        // otherwise we return the CLAIM_SKIPPED status
        if (redeemRequest.amount == 0) {
            if (skipAlreadyClaimed) {
                return (address(0), 0, CLAIM_SKIPPED);
            }
            revert RedeemRequestAlreadyClaimed(redeemRequestId);
        }
        uint256 ethAmount = 0;
        uint256 matchingAmount = 0;
        {
            WithdrawalStack.WithdrawalEvent memory withdrawalEvent = withdrawalEvents[withdrawalEventId];
            // now that both entities are loaded in memory, we verify that they indeed match, otherwise we revert
            if (!_isMatch(redeemRequest, withdrawalEvent)) {
                revert DoesNotMatch(redeemRequestId, withdrawalEventId);
            }

            {
                uint256 requestEndPosition = redeemRequest.height + redeemRequest.amount;
                uint256 withdrawalEventEndPosition = withdrawalEvent.height + withdrawalEvent.amount;

                // it can occur that the redeem request is overlapping the provided withdrawal event
                // the amount that is matched in the withdrawal event is adapted depending on this
                if (requestEndPosition < withdrawalEventEndPosition) {
                    // we know that the request's end is inside the withdrawal event, so all the remaining amount is matched
                    matchingAmount = redeemRequest.amount;
                } else {
                    // we know that the request's end is outside of the withdrawal event, so only a portion amount is matched
                    matchingAmount = redeemRequest.amount - (requestEndPosition - withdrawalEventEndPosition);
                }
            }
            // we can now compute the equivalent eth amount based on the withdrawal event details
            ethAmount = (matchingAmount * withdrawalEvent.withdrawnEth) / withdrawalEvent.amount;
        }

        uint256 currentRequestAmount = redeemRequest.amount;

        {
            // as each request has a maximum withdrawable amount, we verify that the eth amount is not exceeding this amount, pro rata
            // the amount that is matched
            uint256 maxRedeemableEthAmount = (matchingAmount * redeemRequest.maxRedeemableEth) / currentRequestAmount;

            if (maxRedeemableEthAmount < ethAmount) {
                BufferedExceedingEth.set(BufferedExceedingEth.get() + (ethAmount - maxRedeemableEthAmount));
                ethAmount = maxRedeemableEthAmount;
            }
        }

        // this event signals that an amount has been matched from a redeem request on a withdrawal event
        // this event can be triggered several times for the same redeem request, depending on its size and
        // how many withdrawal events it overlaps.
        emit MatchedRedeemRequest(
            redeemRequestId, withdrawalEventId, matchingAmount, ethAmount, currentRequestAmount - matchingAmount
        );

        // height and amount are updated to reflect the amount that was matched.
        // we will always keep this invariant true oldRequest.height + oldRequest.amount == newRequest.height + newRequest.amount
        // this also means that if the request wasn't entirely matched, it will now be automatically be assigned to the next
        // withdrawal event in the queue, because height is updated based on the amount matched and is now equal to the height
        // of the next withdrawal event
        redeemRequests[redeemRequestId].height += matchingAmount;
        redeemRequests[redeemRequestId].amount = currentRequestAmount - matchingAmount;
        redeemRequests[redeemRequestId].maxRedeemableEth -= ethAmount;

        // in the case where we did not match all the amount, we call this method recursively with the same request id but
        // we increment the withdrawal event id. We also allow to skip if the withdrawal event does not exist, resulting in
        // a returned CLAIM_PARTIALLY_CLAIMED status if a withdrawal event id we need next in the stack does not exist yet.
        if (matchingAmount < redeemRequest.amount) {
            (, uint256 nextEthAmount, uint8 claimStatus) =
                _claimRedeemRequest(redeemRequestId, withdrawalEventId + 1, false, true);
            return (redeemRequest.owner, ethAmount + nextEthAmount, claimStatus);
        }

        // if we end up here, we have successfully claimed everything in the redeem request, and the CLAIM_FULLY_CLAIMED status is returned
        return (redeemRequest.owner, ethAmount, CLAIM_FULLY_CLAIMED);
    }
}
