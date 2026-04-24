//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../IOperatorRegistry.1.sol";
import "../IDepositDataBuffer.sol";
import "../../libraries/BLS12_381.sol";

/// @title Consensus Layer Deposit Manager Interface (v1)
/// @author Alluvial Finance Inc.
/// @notice This interface exposes methods to handle the interactions with the official deposit contract
interface IConsensusLayerDepositManagerV1 {
    /// @notice The stored deposit contract address changed
    /// @param depositContract Address of the deposit contract
    event SetDepositContractAddress(address indexed depositContract);

    /// @notice The stored withdrawal credentials changed
    /// @param withdrawalCredentials The withdrawal credentials to use for deposits
    event SetWithdrawalCredentials(bytes32 withdrawalCredentials);

    /// @notice Emitted when the total deposited ETH is updated
    /// @param oldTotalDepositedETH The old total deposited ETH(wei) value
    /// @param newTotalDepositedETH The new total deposited ETH(wei) value
    event SetTotalDepositedETH(uint256 oldTotalDepositedETH, uint256 newTotalDepositedETH);

    /// @notice Emitted when the in flight ETH is updated
    /// @param oldInFlightETH The old in flight ETH(wei) value
    /// @param newInFlightETH The new in flight ETH(wei) value
    event SetInFlightETH(uint256 oldInFlightETH, uint256 newInFlightETH);

    /// @notice Emitted when the keeper address is updated
    /// @param keeper The new keeper address
    event SetKeeper(address indexed keeper);

    /// @notice The allocations array must not be empty
    error EmptyAllocations();

    /// @notice Not enough funds to deposit one validator
    error NotEnoughFunds();

    /// @notice The length of the BLS Public key is invalid during deposit
    error InconsistentPublicKey();

    /// @notice The length of the BLS Signature is invalid during deposit
    error InconsistentSignature();

    /// @notice The deposit size is invalid
    error InvalidDepositSize(uint256 depositSize);

    /// @notice The withdrawal credentials value is null
    error InvalidWithdrawalCredentials();

    /// @notice A deposit's withdrawal credentials do not match the configured value
    error WithdrawalCredentialsMismatch(uint256 depositIndex, bytes32 expected, bytes32 actual);

    /// @notice An error occured during the deposit
    error ErrorOnDeposit();

    /// @notice Invalid deposit root
    error InvalidDepositRoot();

    // @notice Not keeper
    error OnlyKeeper();

    /// @notice The amount of deposits requested exceeds the committed balance
    error ValidatorDepositsExceedCommittedBalance();

    // -----------------------------------------------------------------------
    // Attestation deposit errors / events
    // -----------------------------------------------------------------------

    /// @notice The metadata field in a DepositObject is not a valid "operator:N" encoding
    error InvalidOperatorMetadata(bytes32 metadata);

    /// @notice Emitted after the attestation-based deposit flow succeeds
    event DepositsExecutedWithAttestation(
        bytes32 indexed depositDataBufferId, bytes32 indexed depositRootHash, uint256 totalAmount
    );

    /// @notice Emitted per operator when validator keys are funded during a deposit
    event FundedValidatorKeys(uint256 indexed operatorIndex, bytes[] publicKeys, bool deferred);

    /// @notice Emitted when the DepositDataBuffer address is updated
    event SetDepositDataBuffer(address indexed depositDataBuffer);

    /// @notice Emitted when an attester is added or removed
    event SetAttester(address indexed attester, bool value);

    /// @notice Emitted when the attestation threshold is updated
    event SetAttestationThreshold(uint256 threshold);

    /// @notice Deposits are blocked while slashing containment mode is active
    error SlashingContainmentModeEnabled();

    /// @notice Returns the amount of ETH(wei) not yet committed for deposit
    /// @return The amount of ETH(wei) not yet committed for deposit
    function getBalanceToDeposit() external view returns (uint256);

    /// @notice Returns the amount of ETH(wei) committed for deposit
    /// @return The amount of ETH(wei) committed for deposit
    function getCommittedBalance() external view returns (uint256);

    /// @notice Retrieve the withdrawal credentials
    /// @return The withdrawal credentials
    function getWithdrawalCredentials() external view returns (bytes32);

    /// @notice Returns the total deposited ETH(wei)
    /// @return The total deposited ETH(wei)
    function getTotalDepositedETH() external view returns (uint256);

    /// @notice Get the keeper address
    /// @return The keeper address
    function getKeeper() external view returns (address);

    /// @notice Deposits current balance to the Consensus Layer based on explicit validator deposits allocations
    /// @dev Security: the keeper is fully trusted to supply correct validator public keys, signatures, and
    ///      operator assignments. The contract enforces deposit amount, balance limits, operator ordering, and
    ///      withdrawal credentials, but does not validate BLS key correctness or that keys belong to the claimed
    ///      operator. The keeper is also trusted to make deposits of the correct sizes.
    /// @param _allocations The allocations specifying the validator deposits to make
    /// @param _depositRoot The root of the deposit tree
    function depositToConsensusLayerWithDepositRoot(
        IOperatorsRegistryV1.ValidatorDeposit[] calldata _allocations,
        bytes32 _depositRoot
    ) external;

    /// @notice Deposit validators using pre-committed buffer data validated by an attester quorum.
    /// @param depositDataBufferId  Batch identifier in the DepositDataBuffer
    /// @param depositRootHash      Current deposit contract root hash co-signed by attesters
    /// @param signatures           EIP-712 signatures from attesters
    /// @param depositYs            Y-coordinates for BLS decompression, one per deposit
    function depositToConsensusLayerWithAttestation(
        bytes32 depositDataBufferId,
        bytes32 depositRootHash,
        bytes[] calldata signatures,
        BLS12_381.DepositY[] calldata depositYs
    ) external;

    /// @notice Returns the DepositDataBuffer contract address
    function getDepositDataBuffer() external view returns (address);

    /// @notice Returns the attestation threshold (minimum valid signatures for quorum)
    function getAttestationThreshold() external view returns (uint256);

    /// @notice Returns the number of registered attesters
    function getAttesterCount() external view returns (uint256);

    /// @notice Returns whether an address is a registered attester
    function getIsAttester(address attester) external view returns (bool);
}
