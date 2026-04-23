//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

/// @title Withdraw Interface (V1)
/// @author Alluvial Finance Inc.
/// @notice This contract is in charge of holding the exit and skimming funds and allow river to pull these funds
interface IWithdrawV1 {
    /// @notice Request to consolidate multiple source pubkeys into a single target pubkey
    /// @param srcPubkeys Source validator pubkeys (48 bytes each)
    /// @param targetPubkey Target validator pubkey (48 bytes)
    struct ConsolidationRequest {
        bytes[] srcPubkeys;
        bytes targetPubkey;
    }

    /// @notice Emitted when the linked River address is changed
    /// @param river The new River address
    event SetRiver(address river);

    /// @notice Emitted when a Pectra withdrawal is requested for a validator
    /// @param pubkey Validator pubkey (48 bytes)
    /// @param amount Amount to withdraw (gwei)
    /// @param fee Fee paid to the EL withdrawal contract
    event WithdrawalRequested(bytes pubkey, uint64 amount, uint256 fee);

    /// @notice Emitted when a Pectra consolidation is requested
    /// @param srcPubkey Source validator pubkey (48 bytes)
    /// @param targetPubkey Target validator pubkey (48 bytes)
    /// @param fee Fee paid to the EL consolidation contract
    event ConsolidationRequested(bytes srcPubkey, bytes targetPubkey, uint256 fee);

    /// @notice Emitted when excess fee refund could not be sent to the recipient
    /// @param recipient Intended excess fee recipient
    /// @param amount Amount that could not be sent
    event UnsentExcessFee(address recipient, uint256 amount);

    /// @notice Thrown when pubkeys and amounts array lengths differ
    error LengthMismatch(uint256 pubkeysLength, uint256 amountLength);

    /// @notice Thrown when the EL contract call (withdrawal or consolidation) fails
    error RequestFailed();

    /// @notice Thrown when reading the current fee from the EL contract fails
    error FeeReadFailed();

    /// @notice Thrown when the EL contract fee exceeds the maximum allowed
    /// @param fee Current fee
    /// @param maxAllowedFee Maximum allowed fee
    error FeeTooHigh(uint256 fee, uint256 maxAllowedFee);

    /// @notice Thrown when msg.value is insufficient to cover total fees
    /// @param value Value sent
    /// @param totalFee Total fee required
    error InsufficientValueForFee(uint256 value, uint256 totalFee);

    /// @notice Thrown when a pubkey is not exactly 48 bytes
    /// @param length Actual length
    error InvalidPubkeyLength(uint256 length);

    /// @param _river The address of the River contract
    function initializeWithdrawV1(address _river) external;

    /// @notice Initialize Pectra EL contract addresses (callable once after initializeWithdrawV1)
    /// @param _withdrawalContractAddress The Pectra EL withdrawal contract address
    /// @param _consolidationContractAddress The Pectra EL consolidation contract address
    /// @param _operatorsRegistry The OperatorsRegistry address
    function initWithdrawV1_1(
        address _withdrawalContractAddress,
        address _consolidationContractAddress,
        address _operatorsRegistry
    ) external;

    /// @notice Retrieve the withdrawal credentials to use
    /// @return The withdrawal credentials
    function getCredentials() external view returns (bytes32);

    /// @notice Retrieve the linked River address
    /// @return The River address
    function getRiver() external view returns (address);

    /// @notice Callable by River, sends the specified amount of ETH to River
    /// @param _amount The amount to pull
    function pullEth(uint256 _amount) external;

    /// @notice Request withdrawals from validators (Pectra). Callable only by River. Fee paid via msg.value; excess refunded to excessFeeRecipient.
    /// @param pubkeys Validator pubkeys (48 bytes each)
    /// @param amount Withdrawal amount per validator (gwei)
    /// @param maxFeePerWithdrawal Maximum fee per withdrawal to accept
    /// @param excessFeeRecipient Address to receive any excess msg.value
    function withdraw(
        bytes[] calldata pubkeys,
        uint64[] calldata amount,
        uint256 maxFeePerWithdrawal,
        address excessFeeRecipient
    ) external payable;

    /// @notice Request consolidations (Pectra). Callable only by River. Fee paid via msg.value; excess refunded to excessFeeRecipient.
    /// @param requests Consolidation requests (each: src pubkeys -> target pubkey)
    /// @param maxFeePerConsolidation Maximum fee per consolidation to accept
    /// @param excessFeeRecipient Address to receive any excess msg.value
    function consolidate(
        ConsolidationRequest[] calldata requests,
        uint256 maxFeePerConsolidation,
        address excessFeeRecipient
    ) external payable;
}
