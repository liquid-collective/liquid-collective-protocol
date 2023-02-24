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
import "./state/redeemManager/Redeemers.sol";
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
    function listRedeemRequests(address account) external view returns (uint32[] memory redeemRequestIds) {
        mapping(address => Redeemers.Redeemer) storage redeemers = Redeemers.get();

        uint32[] memory resultList;
        uint32[] memory completeList = redeemers[account].redeemRequestIds;
        uint256 startIndex = redeemers[account].startIndex;

        /// Here we reuse the memory region of completeList and simply set resultList at startIndex in this memory region
        /// To do this we move the length value stored in 32 bytes up in the memory region and then we set the address
        /// of resultList to be this new updated length value
        assembly {
            let len := mload(completeList)
            let size := sub(len, startIndex)
            resultList := add(completeList, mul(4, startIndex))
            mstore(resultList, size)
        }

        return resultList;
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

        Redeemers.get()[recipient].redeemRequestIds.push(uint32(redeemRequestId));
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
            _sendRedeemRequestFunds(redeemRequestIds[idx], recipient, amount, claimStatus == CLAIM_FULLY_CLAIMED);
            accounts[idx] = recipient;
            unchecked {
                ++idx;
            }
        }

        for (uint256 idx = 0; idx < redeemRequestIdsLength;) {
            if (idx == 0 || accounts[idx] != address(0)) {
                address account = accounts[idx];
                _pruneRedeemerClaimedRequests(account);
                for (uint256 cleanIdx = idx + 1; cleanIdx < redeemRequestIdsLength;) {
                    if (accounts[cleanIdx] == account) {
                        accounts[cleanIdx] = address(0);
                    }
                    unchecked {
                        ++cleanIdx;
                    }
                }
            }

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
        if (redeemRequestId >= redeemRequests.length) {
            return RESOLVE_OUT_OF_BOUNDS;
        }
        RedeemQueue.RedeemRequest memory redeemRequest = redeemRequests[redeemRequestId];
        if (redeemRequest.amount == 0) {
            return RESOLVE_FULLY_CLAIMED;
        }
        if (
            WithdrawalStack.get().length == 0
                || (lastWithdrawalEvent.height + lastWithdrawalEvent.amount) < redeemRequest.height
        ) {
            return RESOLVE_UNSATISFIED;
        }
        return _performDichotomicResolution(redeemRequest);
    }

    /// @notice Internal utility to send rewards to a recipient
    /// @param recipient The address receiving the rewards
    /// @param amount The amount to send
    function _sendRedeemRequestFunds(uint32 redeemRequestId, address recipient, uint256 amount, bool fullyClaimed)
        internal
    {
        (bool success, bytes memory rdata) = recipient.call{value: amount}("");
        if (!success) {
            assembly {
                revert(add(32, rdata), mload(rdata))
            }
        }
        emit ClaimedRedeemRequest(redeemRequestId, recipient, amount, fullyClaimed);
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
        if (redeemRequestId >= redeemRequests.length) {
            revert RedeemRequestOutOfBounds(redeemRequestId);
        }
        WithdrawalStack.WithdrawalEvent[] storage withdrawalEvents = WithdrawalStack.get();
        if (withdrawalEventId >= withdrawalEvents.length) {
            if (skipWithdrawalEventDoesNotExist) {
                return (address(0), 0, CLAIM_PARTIALLY_CLAIMED);
            }
            revert WithdrawalEventOutOfBounds(withdrawalEventId);
        }
        RedeemQueue.RedeemRequest memory redeemRequest = redeemRequests[redeemRequestId];
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

            if (!_isMatch(redeemRequest, withdrawalEvent)) {
                revert DoesNotMatch(redeemRequestId, withdrawalEventId);
            }

            {
                uint256 requestEndPosition = redeemRequest.height + redeemRequest.amount;
                uint256 withdrawalEventEndPosition = withdrawalEvent.height + withdrawalEvent.amount;

                if (requestEndPosition < withdrawalEventEndPosition) {
                    matchingAmount = redeemRequest.amount;
                } else {
                    matchingAmount = redeemRequest.amount - (requestEndPosition - withdrawalEventEndPosition);
                }
            }

            ethAmount = (matchingAmount * withdrawalEvent.withdrawnEth) / withdrawalEvent.amount;
        }

        uint256 currentRequestAmount = redeemRequest.amount;

        {
            uint256 maxRedeemableEthAmount = (matchingAmount * redeemRequest.maxRedeemableEth) / currentRequestAmount;

            if (maxRedeemableEthAmount < ethAmount) {
                BufferedExceedingEth.set(BufferedExceedingEth.get() + (ethAmount - maxRedeemableEthAmount));
                ethAmount = maxRedeemableEthAmount;
            }
        }

        emit MatchedRedeemRequest(
            redeemRequestId, withdrawalEventId, matchingAmount, ethAmount, currentRequestAmount - matchingAmount
            );

        redeemRequests[redeemRequestId].height += matchingAmount;
        redeemRequests[redeemRequestId].amount = currentRequestAmount - matchingAmount;
        redeemRequests[redeemRequestId].maxRedeemableEth -= ethAmount;

        if (matchingAmount < redeemRequest.amount) {
            (, uint256 nextEthAmount, uint8 claimStatus) =
                _claimRedeemRequest(redeemRequestId, withdrawalEventId + 1, false, true);
            return (redeemRequest.owner, ethAmount + nextEthAmount, claimStatus);
        }

        return (redeemRequest.owner, ethAmount, CLAIM_FULLY_CLAIMED);
    }

    /// @notice Prunes the redeem request list of an account by recomputing the starting index
    /// @dev Pruning will increment the startIndex to the count of consecutive fully claimed requests from the beginning of the array
    /// @param account The account to prune
    function _pruneRedeemerClaimedRequests(address account) internal {
        mapping(address => Redeemers.Redeemer) storage redeemers = Redeemers.get();
        uint32[] storage accountRedeemRequests = redeemers[account].redeemRequestIds;
        uint256 requestCount = accountRedeemRequests.length;
        uint256 startIndex = redeemers[account].startIndex;
        uint256 idx = startIndex;
        RedeemQueue.RedeemRequest[] storage redeemRequests = RedeemQueue.get();
        for (; idx < requestCount && redeemRequests[accountRedeemRequests[idx]].amount == 0;) {
            unchecked {
                ++idx;
            }
        }
        if (idx != startIndex) {
            redeemers[account].startIndex = idx;
        }
    }
}
