//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "./interfaces/IAllowlist.1.sol";
import "./interfaces/IRiver.1.sol";
import "./interfaces/IRedeemManager.1.sol";
import "./libraries/LibAllowlistMasks.sol";
import "./Initializable.sol";

import "./state/shared/RiverAddress.sol";
import "./state/redeemManager/RedeemRequests.sol";
import "./state/redeemManager/WithdrawalEvents.sol";
import "./state/redeemManager/Redeemers.sol";

/// @title Redeem Manager (v1)
/// @author Kiln
/// @notice This contract handles the redeem requests of all users
contract RedeemManagerV1 is Initializable, IRedeemManagerV1 {
    /// @notice Internal value returned when resolving a redeem request that is unsatisfied
    int256 internal constant UNSATISFIED = -1;
    /// @notice Internal value returned when resolving a redeem request that is out of bounds
    int256 internal constant OUT_OF_BOUNDS = -2;
    /// @notice Internal value returned when resolving a redeem request that is already claimed
    int256 internal constant FULLY_CLAIMED = -3;

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
        return RedeemRequests.get().length;
    }

    /// @inheritdoc IRedeemManagerV1
    function getRedeemRequestDetails(uint256 redeemRequestId)
        external
        view
        returns (RedeemRequests.RedeemRequest memory)
    {
        return RedeemRequests.get()[redeemRequestId];
    }

    /// @inheritdoc IRedeemManagerV1
    function getWithdrawalEventCount() external view returns (uint256) {
        return WithdrawalEvents.get().length;
    }

    /// @inheritdoc IRedeemManagerV1
    function getWithdrawalEventDetails(uint256 withdrawalEventId)
        external
        view
        returns (WithdrawalEvents.WithdrawalEvent memory)
    {
        return WithdrawalEvents.get()[withdrawalEventId];
    }

    /// @inheritdoc IRedeemManagerV1
    function listRedeemRequests(address account) external view returns (uint256[] memory redeemRequestIds) {
        mapping(address => Redeemers.Redeemer) storage redeemers = Redeemers.get();

        uint256[] memory resultList;
        uint256[] memory completeList = redeemers[account].redeemRequestIds;
        uint256 startIndex = redeemers[account].startIndex;

        assembly {
            let len := mload(completeList)
            let size := sub(len, startIndex)
            resultList := add(completeList, mul(32, startIndex))
            mstore(resultList, size)
        }

        return resultList;
    }

    /// @inheritdoc IRedeemManagerV1
    function resolveRedeemRequests(uint256[] calldata redeemRequestIds)
        external
        view
        returns (int256[] memory withdrawalEventIds)
    {
        withdrawalEventIds = new int256[](redeemRequestIds.length);
        WithdrawalEvents.WithdrawalEvent memory lastWithdrawalEvent;
        WithdrawalEvents.WithdrawalEvent[] storage withdrawalEvents = WithdrawalEvents.get();
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
        returns (uint256 redeemRequestId)
    {
        LibSanitize._notZeroAddress(recipient);
        if (lsETHAmount == 0) {
            revert InvalidZeroAmount();
        }
        if (!_river().transferFrom(msg.sender, address(this), lsETHAmount)) {
            revert TransferError();
        }
        RedeemRequests.RedeemRequest[] storage redeemRequests = RedeemRequests.get();
        redeemRequestId = redeemRequests.length;
        uint256 height = 0;
        if (redeemRequestId != 0) {
            RedeemRequests.RedeemRequest memory previousRedeemRequest = redeemRequests[redeemRequestId - 1];
            height = previousRedeemRequest.height + previousRedeemRequest.size;
        }

        redeemRequests.push(RedeemRequests.RedeemRequest({height: height, size: lsETHAmount, owner: recipient}));

        Redeemers.get()[recipient].redeemRequestIds.push(redeemRequestId);
        emit CreatedRedeemRequest(recipient, height, lsETHAmount, redeemRequestId);
    }

    /// @inheritdoc IRedeemManagerV1
    function claimRewards(
        uint256[] calldata redeemRequestIds,
        uint256[] calldata withdrawalEventIds,
        bool skipAlreadyClaimed
    ) external {
        uint256 redeemRequestIdsLength = redeemRequestIds.length;
        if (redeemRequestIdsLength != withdrawalEventIds.length) {
            revert InvalidArrayLengths();
        }
        address[] memory accounts = new address[](redeemRequestIdsLength);
        for (uint256 idx = 0; idx < redeemRequestIdsLength;) {
            (address recipient, uint256 amount) =
                _claimRewards(redeemRequestIds[idx], withdrawalEventIds[idx], skipAlreadyClaimed, false);
            _sendRewards(recipient, amount);
            accounts[idx] = recipient;
            unchecked {
                ++idx;
            }
        }

        for (uint256 idx = 0; idx < redeemRequestIdsLength;) {
            if (idx == 0 || accounts[idx] != address(0)) {
                address account = accounts[idx];
                _pruneRedeemRequestsList(account);
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
        WithdrawalEvents.WithdrawalEvent[] storage withdrawalEvents = WithdrawalEvents.get();
        uint256 withdrawalEventId = withdrawalEvents.length;
        uint256 height = 0;
        uint256 msgValue = msg.value;
        if (withdrawalEventId != 0) {
            WithdrawalEvents.WithdrawalEvent memory previousWithdrawalEvent = withdrawalEvents[withdrawalEventId - 1];
            height = previousWithdrawalEvent.height + previousWithdrawalEvent.size;
        }
        withdrawalEvents.push(
            WithdrawalEvents.WithdrawalEvent({height: height, size: lsETHWithdrawable, ethAmount: msgValue})
        );

        emit CreatedWithdrawalEvent(height, lsETHWithdrawable, msgValue, withdrawalEventId);
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
    function _match(
        RedeemRequests.RedeemRequest memory redeemRequest,
        WithdrawalEvents.WithdrawalEvent memory withdrawalEvent
    ) internal pure returns (bool) {
        return (
            redeemRequest.height < withdrawalEvent.height + withdrawalEvent.size
                && redeemRequest.height >= withdrawalEvent.height
        );
    }

    /// @notice Internal Utility to verify if a redeem request and a withdrawal event id are matching
    /// @param redeemRequest The loaded redeem request
    /// @param withdrawalEventId The withdrawal event id
    /// @return True if matching
    function _getMatch(RedeemRequests.RedeemRequest memory redeemRequest, int256 withdrawalEventId)
        internal
        view
        returns (bool)
    {
        WithdrawalEvents.WithdrawalEvent memory we = WithdrawalEvents.get()[uint256(withdrawalEventId)];

        return _match(redeemRequest, we);
    }

    /// @notice Internal Utility to retrieve the distance between a withdrawal event and a redeem request, or if both are matching
    /// @dev If the withdrawal event is before the redeem request, the delta is negative, otherwise positive
    /// @dev Sign is used to identify which cursor to move in the dichotomic search
    /// @param redeemRequest The loaded redeem request
    /// @param withdrawalEventId The id of the withdrawal event
    /// @return The delta between both entities
    /// @return True if matching
    function _getDeltaOrMatch(RedeemRequests.RedeemRequest memory redeemRequest, int256 withdrawalEventId)
        internal
        view
        returns (int256, bool)
    {
        WithdrawalEvents.WithdrawalEvent memory we = WithdrawalEvents.get()[uint256(withdrawalEventId)];

        if (_match(redeemRequest, we)) {
            return (0, true);
        }

        if (redeemRequest.height < we.height) {
            return (int256(we.height) - int256(redeemRequest.height), false);
        }

        return (int256(we.height + we.size) - int256(redeemRequest.height), false);
    }

    /// @notice Internal utility to perform a dichotomic search of the withdrawal event to use to claim the redeem request
    /// @param redeemRequest The redeem request to resolve
    /// @return The matching withdrawal event
    function _performDichotomicResolution(RedeemRequests.RedeemRequest memory redeemRequest)
        internal
        view
        returns (int256)
    {
        int256 max = int256(WithdrawalEvents.get().length - 1);

        if (_getMatch(redeemRequest, max)) {
            return max;
        }

        int256 min = 0;

        if (_getMatch(redeemRequest, min)) {
            return min;
        }

        while (min != max) {
            int256 mid = (min + max) / 2;

            (int256 midDelta, bool found) = _getDeltaOrMatch(redeemRequest, mid);
            if (found) {
                return mid;
            }

            if (midDelta < 0) {
                min = mid;
            } else {
                max = mid;
            }
        }

        return min;
    }

    /// @notice Internal utility to resolve a redeem request and retrieve its satisfying withdrawal event id, or identify possible errors
    /// @param redeemRequestId The redeem request id
    /// @param lastWithdrawalEvent The last withdrawal event loaded in memory
    /// @param withdrawalEventId The id of the withdrawal event matching the redeem request or error code
    function _resolveRedeemRequestId(
        uint256 redeemRequestId,
        WithdrawalEvents.WithdrawalEvent memory lastWithdrawalEvent
    ) internal view returns (int256 withdrawalEventId) {
        RedeemRequests.RedeemRequest[] storage redeemRequests = RedeemRequests.get();
        if (redeemRequestId >= redeemRequests.length) {
            return OUT_OF_BOUNDS;
        }
        RedeemRequests.RedeemRequest memory redeemRequest = redeemRequests[redeemRequestId];
        if (redeemRequest.size == 0) {
            return FULLY_CLAIMED;
        }
        if (
            WithdrawalEvents.get().length == 0
                || (lastWithdrawalEvent.height + lastWithdrawalEvent.size) < redeemRequest.height
        ) {
            return UNSATISFIED;
        }
        return _performDichotomicResolution(redeemRequest);
    }

    /// @notice Internal utility to send rewards to a recipient
    /// @param recipient The address receiving the rewards
    /// @param amount The amount to send
    function _sendRewards(address recipient, uint256 amount) internal {
        (bool success, bytes memory rdata) = recipient.call{value: amount}("");
        if (!success) {
            assembly {
                revert(add(32, rdata), mload(rdata))
            }
        }
        emit SentRewards(recipient, amount);
    }

    /// @notice Internal utility to claim a redeem request if possible
    /// @dev Will call itself recursively if the redeem requests overflows its matching withdrawal event
    /// @param redeemRequestId The redeem request to claim
    /// @param withdrawalEventId Its matching withdrawal event, computed by performing an rpc call to resolveRedeemRequests
    /// @param skipAlreadyClaimed True if the method should skip redeem requests already claimed
    /// @param skipWithdrawalEventDoesNotExist True if the method should simply return if the withdrawal event is out of bounds
    /// @return The owner of the redeem request
    /// @return The amount of ETH to send to the owner
    function _claimRewards(
        uint256 redeemRequestId,
        uint256 withdrawalEventId,
        bool skipAlreadyClaimed,
        bool skipWithdrawalEventDoesNotExist
    ) internal returns (address, uint256) {
        RedeemRequests.RedeemRequest[] storage redeemRequests = RedeemRequests.get();
        if (redeemRequestId >= redeemRequests.length) {
            revert RedeemRequestIdOutOfBounds(redeemRequestId);
        }
        WithdrawalEvents.WithdrawalEvent[] storage withdrawalEvents = WithdrawalEvents.get();
        if (withdrawalEventId >= withdrawalEvents.length) {
            if (skipWithdrawalEventDoesNotExist) {
                return (address(0), 0);
            }
            revert WithdrawalEventIdOutOfBounds(withdrawalEventId);
        }
        RedeemRequests.RedeemRequest memory redeemRequest = redeemRequests[redeemRequestId];
        if (redeemRequest.size == 0) {
            if (skipAlreadyClaimed) {
                return (address(0), 0);
            }
            revert RedeemRequestAlreadyClaimed(redeemRequestId);
        }
        WithdrawalEvents.WithdrawalEvent memory withdrawalEvent = withdrawalEvents[withdrawalEventId];

        if (!_match(redeemRequest, withdrawalEvent)) {
            revert DoesNotMatch(redeemRequestId, withdrawalEventId);
        }

        uint256 matchingSize = 0;

        uint256 requestEndPosition = redeemRequest.height + redeemRequest.size;
        uint256 withdrawalEventEndPosition = withdrawalEvent.height + withdrawalEvent.size;

        if (requestEndPosition < withdrawalEventEndPosition) {
            matchingSize = redeemRequest.size;
        } else {
            matchingSize = redeemRequest.size - (requestEndPosition - withdrawalEventEndPosition);
        }

        uint256 ethAmount = (matchingSize * withdrawalEvent.ethAmount) / withdrawalEvent.size;

        redeemRequests[redeemRequestId].height += matchingSize;
        redeemRequests[redeemRequestId].size -= matchingSize;

        emit FilledRedeemRequest(redeemRequestId, withdrawalEventId, matchingSize, ethAmount);

        if (matchingSize < redeemRequest.size) {
            (, uint256 nextEthAmount) = _claimRewards(redeemRequestId, withdrawalEventId + 1, false, true);
            return (redeemRequest.owner, ethAmount + nextEthAmount);
        }

        return (redeemRequest.owner, ethAmount);
    }

    /// @notice Prunes the redeem request list of an account by recomputing the starting index
    /// @param account The account to prune
    function _pruneRedeemRequestsList(address account) internal {
        mapping(address => Redeemers.Redeemer) storage redeemers = Redeemers.get();
        uint256[] storage accountRedeemRequests = redeemers[account].redeemRequestIds;
        uint256 requestCount = accountRedeemRequests.length;
        uint256 startIndex = redeemers[account].startIndex;
        uint256 idx = startIndex;
        RedeemRequests.RedeemRequest[] storage redeemRequests = RedeemRequests.get();
        for (; idx < requestCount && redeemRequests[accountRedeemRequests[idx]].size == 0;) {
            unchecked {
                ++idx;
            }
        }
        if (idx != startIndex) {
            redeemers[account].startIndex = idx;
        }
    }
}
