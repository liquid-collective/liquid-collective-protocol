//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../state/redeemManager/RedeemQueue.2.sol";
import "../state/redeemManager/WithdrawalStack.sol";
import "../state/redeemManager/MaxRedeemableETHLockedStack.sol";

/// @title Redeem Manager Interface (v1)
/// @author Alluvial Finance Inc.
/// @notice This contract handles the redeem requests of all users
interface IRedeemManagerV1 {
    /// @notice Emitted when a redeem request is created
    /// @param recipient The recipient of the redeem request
    /// @param height The height of the redeem request in LsETH
    /// @param amount The amount of the redeem request in LsETH
    /// @param maxRedeemableEth The maximum amount of eth that can be redeemed from this request
    /// @param id The id of the new redeem request
    event RequestedRedeem(
        address indexed recipient, uint256 height, uint256 amount, uint256 maxRedeemableEth, uint32 id
    );

    /// @notice Emitted when a withdrawal event is created
    /// @param height The height of the withdrawal event in LsETH
    /// @param amount The amount of the withdrawal event in LsETH
    /// @param ethAmount The amount of eth to distrubute to claimers
    /// @param id The id of the withdrawal event
    event ReportedWithdrawal(uint256 height, uint256 amount, uint256 ethAmount, uint32 id);

    /// @notice Emitted when a redeem request has been satisfied and filled (even partially) from a withdrawal event
    /// @param redeemRequestId The id of the redeem request
    /// @param withdrawalEventId The id of the withdrawal event used to fill the request
    /// @param lsEthAmountSatisfied The amount of LsETH filled
    /// @param ethAmountSatisfied The amount of ETH filled
    /// @param lsEthAmountRemaining The amount of LsETH remaining
    /// @param ethAmountExceeding The amount of eth added to the exceeding buffer
    event SatisfiedRedeemRequest(
        uint32 indexed redeemRequestId,
        uint32 indexed withdrawalEventId,
        uint256 lsEthAmountSatisfied,
        uint256 ethAmountSatisfied,
        uint256 lsEthAmountRemaining,
        uint256 ethAmountExceeding
    );

    /// @notice Emitted when a redeem request claim has been processed and matched at least once and funds are sent to the recipient
    /// @param redeemRequestId The id of the redeem request
    /// @param recipient The address receiving the redeem request funds
    /// @param ethAmount The amount of eth retrieved
    /// @param lsEthAmount The total amount of LsETH used to redeem the eth
    /// @param remainingLsEthAmount The amount of LsETH remaining
    event ClaimedRedeemRequest(
        uint32 indexed redeemRequestId,
        address indexed recipient,
        uint256 ethAmount,
        uint256 lsEthAmount,
        uint256 remainingLsEthAmount
    );

    /// @notice Emitted when the redeem demand is set
    /// @param oldRedeemDemand The old redeem demand
    /// @param newRedeemDemand The new redeem demand
    event SetRedeemDemand(uint256 oldRedeemDemand, uint256 newRedeemDemand);

    /// @notice Emitted when the River address is set
    /// @param river The new river address
    event SetRiver(address river);

    /// @notice Emitted when a MaxRedeemableETH lock event is appended to the stack
    /// @dev Exactly one of fromFullExits / fromPartialWithdrawals / fromRebalancing is non-zero per emission
    /// @param id The id of the new lock event
    /// @param height The cumulative LsETH height at which the lock event starts
    /// @param amount The LsETH-equivalent of the locked slice
    /// @param lockedEth The new maxRedeemableEth cap for the slice (rate at lock time × amount)
    /// @param fromFullExits The portion of `lockedEth` sourced from full validator exits (`exit_epoch`)
    /// @param fromPartialWithdrawals The portion of `lockedEth` sourced from partial withdrawals (PendingPartialWithdrawal.withdrawable_epoch)
    /// @param fromRebalancing The portion of `lockedEth` sourced from BalanceToDeposit → BalanceToRedeem rebalancing
    event MaxRedeemableETHLocked(
        uint32 indexed id,
        uint256 height,
        uint256 amount,
        uint256 lockedEth,
        uint256 fromFullExits,
        uint256 fromPartialWithdrawals,
        uint256 fromRebalancing
    );


    /// @notice Thrown When a zero value is provided
    error InvalidZeroAmount();

    /// @notice Thrown when a transfer error occured with LsETH
    error TransferError();

    /// @notice Thrown when the provided arrays don't have matching lengths
    error IncompatibleArrayLengths();

    /// @notice Thrown when the provided redeem request id is out of bounds
    /// @param id The redeem request id
    error RedeemRequestOutOfBounds(uint256 id);

    /// @notice Thrown when the withdrawal request id if out of bounds
    /// @param id The withdrawal event id
    error WithdrawalEventOutOfBounds(uint256 id);

    /// @notice Thrown when	the redeem request id is already claimed
    /// @param id The redeem request id
    error RedeemRequestAlreadyClaimed(uint256 id);

    /// @notice Thrown when the redeem request and withdrawal event are not matching during claim
    /// @param redeemRequestId The provided redeem request id
    /// @param withdrawalEventId The provided associated withdrawal event id
    error DoesNotMatch(uint256 redeemRequestId, uint256 withdrawalEventId);

    /// @notice Thrown when the provided withdrawal event exceeds the redeem demand
    /// @param withdrawalAmount The amount of the withdrawal event
    /// @param redeemDemand The current redeem demand
    error WithdrawalExceedsRedeemDemand(uint256 withdrawalAmount, uint256 redeemDemand);

    /// @notice Thrown when the payment after a claim failed
    /// @param recipient The recipient of the payment
    /// @param rdata The revert data
    error ClaimRedeemFailed(address recipient, bytes rdata);

    /// @notice Thrown when the claim recipient is denied
    error ClaimRecipientIsDenied();

    /// @notice Thrown when the claim initiator is denied
    error ClaimInitiatorIsDenied();

    /// @notice Thrown when the recipient of redeemRequest is denied
    error RecipientIsDenied();

    /// @notice Thrown when an action is blocked because slashing containment mode is active
    error SlashingContainmentModeEnabled();

    /// @notice Thrown when a lock attempt would push MaxRedeemableETHLockedDemand above RedeemDemand
    /// @param attemptedLock The LsETH amount the caller tried to lock
    /// @param unlockedHead The remaining LsETH in the queue that hasn't been locked yet
    error LockExceedsRedeemDemand(uint256 attemptedLock, uint256 unlockedHead);

    /// @param _river The address of the River contract
    function initializeRedeemManagerV1(address _river) external;

    function initializeRedeemManagerV1_2() external;

    /// @notice Initializes V1_3 — bootstraps NextLockHeight to the current RedeemDemand so the first
    ///         post-upgrade MaxRedeemableETHLockedEvent sits behind all pre-upgrade requests
    function initializeRedeemManagerV1_3() external;

    /// @notice Retrieve River address
    /// @return The address of River
    function getRiver() external view returns (address);

    /// @notice Retrieve the global count of redeem requests
    function getRedeemRequestCount() external view returns (uint256);

    /// @notice Retrieve the details of a specific redeem request
    /// @param _redeemRequestId The id of the request
    /// @return The redeem request details
    function getRedeemRequestDetails(uint32 _redeemRequestId) external view returns (RedeemQueueV2.RedeemRequest memory);

    /// @notice Retrieve the global count of withdrawal events
    function getWithdrawalEventCount() external view returns (uint256);

    /// @notice Retrieve the details of a specific withdrawal event
    /// @param _withdrawalEventId The id of the withdrawal event
    /// @return The withdrawal event details
    function getWithdrawalEventDetails(uint32 _withdrawalEventId)
        external
        view
        returns (WithdrawalStack.WithdrawalEvent memory);

    /// @notice Retrieve the amount of redeemed LsETH pending to be supplied with withdrawn ETH
    /// @return The amount of eth in the buffer
    function getBufferedExceedingEth() external view returns (uint256);

    /// @notice Retrieve the amount of LsETH waiting to be exited
    /// @return The amount of LsETH waiting to be exited
    function getRedeemDemand() external view returns (uint256);

    /// @notice Resolves the provided list of redeem request ids
    /// @dev The result is an array of equal length with ids or error code
    /// @dev -1 means that the request is not satisfied yet
    /// @dev -2 means that the request is out of bounds
    /// @dev -3 means that the request has already been claimed
    /// @dev This call was created to be called by an off-chain interface, the output could then be used to perform the claimRewards call in a regular transaction
    /// @param _redeemRequestIds The list of redeem requests to resolve
    /// @return withdrawalEventIds The list of withdrawal events matching every redeem request (or error codes)
    function resolveRedeemRequests(uint32[] calldata _redeemRequestIds)
        external
        view
        returns (int64[] memory withdrawalEventIds);

    /// @notice Creates a redeem request
    /// @param _lsETHAmount The amount of LsETH to redeem
    /// @param _recipient The recipient owning the redeem request
    /// @param _initiator The initiator of the request
    /// @return redeemRequestId The id of the redeem request
    function requestRedeem(uint256 _lsETHAmount, address _recipient, address _initiator)
        external
        returns (uint32 redeemRequestId);

    /// @notice Creates a redeem request
    /// @param _lsETHAmount The amount of LsETH to redeem
    /// @param _recipient The recipient owning the redeem request
    /// @return redeemRequestId The id of the redeem request
    function requestRedeem(uint256 _lsETHAmount, address _recipient) external returns (uint32 redeemRequestId);

    /// @notice Creates a redeem request using msg.sender as recipient
    /// @param _lsETHAmount The amount of LsETH to redeem
    /// @return redeemRequestId The id of the redeem request
    function requestRedeem(uint256 _lsETHAmount) external returns (uint32 redeemRequestId);

    /// @notice Claims the rewards of the provided redeem request ids
    /// @param _redeemRequestIds The list of redeem requests to claim
    /// @param _withdrawalEventIds The list of withdrawal events to use for every redeem request claim
    /// @param _skipAlreadyClaimed True if the call should not revert on claiming of already claimed requests
    /// @param _depth The maximum recursive depth for the resolution of the redeem requests
    /// @return claimStatuses The list of claim statuses. 0 for fully claimed, 1 for partially claimed, 2 for skipped
    function claimRedeemRequests(
        uint32[] calldata _redeemRequestIds,
        uint32[] calldata _withdrawalEventIds,
        bool _skipAlreadyClaimed,
        uint16 _depth
    ) external returns (uint8[] memory claimStatuses);

    /// @notice Claims the rewards of the provided redeem request ids
    /// @param _redeemRequestIds The list of redeem requests to claim
    /// @param _withdrawalEventIds The list of withdrawal events to use for every redeem request claim
    /// @return claimStatuses The list of claim statuses. 0 for fully claimed, 1 for partially claimed, 2 for skipped
    function claimRedeemRequests(uint32[] calldata _redeemRequestIds, uint32[] calldata _withdrawalEventIds)
        external
        returns (uint8[] memory claimStatuses);

    /// @notice Reports a withdraw event from River
    /// @param _lsETHWithdrawable The amount of LsETH that can be redeemed due to this new withdraw event
    function reportWithdraw(uint256 _lsETHWithdrawable) external payable;

    /// @notice Pulls exceeding buffer eth
    /// @param _max The maximum amount that should be pulled
    function pullExceedingEth(uint256 _max) external;

    /// @notice Appends a MaxRedeemableETHLockedEvent for an LsETH slice at a frozen ETH cap
    /// @dev Called by River as part of an oracle report. Does not burn LsETH or transfer ETH;
    ///      strictly updates the per-slice maxRedeemableEth cap. Reverts if the lock would push
    ///      MaxRedeemableETHLockedDemand above RedeemDemand.
    /// @param _lsETHToLock LsETH amount being locked (slice size)
    /// @param _lockedEth The new maxRedeemableEth cap for this slice (ETH-denominated)
    /// @param _fromFullExits Breakdown: portion sourced from full validator exits
    /// @param _fromPartialWithdrawals Breakdown: portion sourced from partial withdrawals
    /// @param _fromRebalancing Breakdown: portion sourced from BalanceToDeposit → BalanceToRedeem rebalancing
    function lockMaxRedeemableETH(
        uint256 _lsETHToLock,
        uint256 _lockedEth,
        uint256 _fromFullExits,
        uint256 _fromPartialWithdrawals,
        uint256 _fromRebalancing
    ) external;

    /// @notice Compute the aggregate effective cap (ETH) that bounds payout for the next `_lsETHDemand` LsETH of the queue
    /// @dev Walks the head of MaxRedeemableETHLockedStack, summing `lockedEth` for the lock-covered portion;
    ///      falls back to summing per-request maxRedeemableEth for any uncovered tail (pre-upgrade requests).
    ///      Used by River at _reportWithdrawToRedeemManager to apply min(currentRate × demand, capForDemand).
    /// @param _lsETHDemand The LsETH demand being considered
    /// @return The aggregate ETH cap for that demand
    function getEffectiveCapForDemand(uint256 _lsETHDemand) external view returns (uint256);

    /// @notice Retrieve the global count of MaxRedeemableETH lock events
    function getMaxRedeemableETHLockedEventCount() external view returns (uint256);

    /// @notice Retrieve the details of a specific MaxRedeemableETH lock event
    /// @param _lockEventId The id of the lock event
    /// @return The lock event details
    function getMaxRedeemableETHLockedEventDetails(uint32 _lockEventId)
        external
        view
        returns (MaxRedeemableETHLockedStack.MaxRedeemableETHLockedEvent memory);

    /// @notice Retrieve the LsETH currently covered by a lock event but not yet by a withdrawal event
    /// @dev Computed dynamically as `NextLockHeight - max(head, firstLockHeight)` — there is no
    ///      stored counter; the value reflects the live state of the queue head, the first lock
    ///      event's position, and the cumulative lock heights.
    function getMaxRedeemableETHLockedDemand() external view returns (uint256);

    /// @notice Retrieve the height that will be used by the next appended lock event
    function getNextLockHeight() external view returns (uint256);
}
