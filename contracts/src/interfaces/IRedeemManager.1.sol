//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../state/redeemManager/RedeemQueue.2.sol";
import "../state/redeemManager/WithdrawalStack.sol";
import "../state/redeemManager/RateMarkStack.sol";
import "../state/redeemManager/RedeemRequestAnchor.sol";

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

    /// @notice Emitted when a rate mark is created, raising the payout cap of the covered redeem demand
    /// @param height The start position of the mark on the cumulative LsETH axis
    /// @param amount The amount of LsETH marked
    /// @param markedEth The ETH value of `amount` at the pool rate of this report
    /// @param id The id of the new rate mark
    event ReportedStoppedEarning(uint256 height, uint256 amount, uint256 markedEth, uint32 id);

    /// @notice Emitted when reported stopped-earning principal exceeded the markable redeem demand
    /// @dev Not an error. Most exits are not backing a redemption, so the common case is that the
    ///      reported principal is far larger than the pending demand and the surplus is simply not
    ///      attributable to any redeemer. Emitted so the excess is observable rather than silent.
    /// @param reportedLsETH The LsETH equivalent of the reported stopped-earning principal
    /// @param markedLsETH The portion that was actually marked
    event StoppedEarningExceededMarkableDemand(uint256 reportedLsETH, uint256 markedLsETH);

    /// @notice Emitted when the River address is set
    /// @param river The new river address
    event SetRiver(address river);

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

    /// @param _river The address of the River contract
    function initializeRedeemManagerV1(address _river) external;

    function initializeRedeemManagerV1_2() external;

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

    /// @notice Reports the principal that stopped earning on the consensus layer in this reporting interval
    /// @dev Called by River once per report, BEFORE `reportWithdraw`, so that demand settled in the same
    ///      report is marked before its shares are burned and removed from the redeem demand.
    /// @dev Must be called unconditionally whenever the delta is non-zero. River persists the cumulative
    ///      `validatorsStoppedEarningBalance` before this point, so a skipped call loses the delta for good.
    /// @dev The two arguments are the same amount denominated in ETH and in LsETH, both valued by River
    ///      from its pre-report snapshot — the pool valuation as it stood before the report was applied.
    ///      Their ratio is the rate the resulting mark locks, and it is passed in rather than read from
    ///      River here because by the time this runs River has already rebased and minted the interval's
    ///      fee, so a live read would return the very rewards the mark is meant to exclude.
    /// @param _stoppedEarningEth The ETH value of the principal that crossed exit_epoch in this interval
    /// @param _stoppedEarningLsETH The same amount in LsETH, valued at River's pre-report rate
    function reportStoppedEarning(uint256 _stoppedEarningEth, uint256 _stoppedEarningLsETH) external;

    /// @notice Retrieve the global count of rate marks
    function getRateMarkCount() external view returns (uint256);

    /// @notice Retrieve the details of a specific rate mark
    /// @param _rateMarkId The id of the rate mark
    /// @return The rate mark details
    function getRateMarkDetails(uint32 _rateMarkId) external view returns (RateMarkStack.RateMark memory);

    /// @notice Retrieve the immutable request-time valuation of a redeem request
    /// @dev A zero `lsETHAtRequest` means the request predates the stopped-earning upgrade and is paid
    ///      under the original rules.
    /// @param _redeemRequestId The id of the request
    /// @return The request-time anchor
    function getRedeemRequestAnchor(uint32 _redeemRequestId) external view returns (RedeemRequestAnchor.Anchor memory);

    /// @notice Pulls exceeding buffer eth
    /// @param _max The maximum amount that should be pulled
    function pullExceedingEth(uint256 _max) external;
}
