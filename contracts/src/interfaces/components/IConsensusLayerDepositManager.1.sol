//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../IDepositDataBuffer.sol";
import "../../libraries/BLS12_381.sol";

/// @title Consensus Layer Deposit Manager Interface (v1)
/// @author Alluvial Finance Inc.
/// @notice This interface exposes methods to handle the interactions with the official deposit contract.
///         Attestation-quorum + BLS validation now lives in IAttestationVerifierV1; this interface is
///         only the River-side execution surface.
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

    /// @notice Emitted after the attestation-based deposit flow succeeds
    event DepositsExecutedWithAttestation(
        bytes32 indexed depositDataBufferId, bytes32 indexed depositRootHash, uint256 totalAmount
    );

    /// @notice Emitted per operator when validator keys are funded during a deposit
    event FundedValidatorKeys(uint256 indexed operatorIndex, bytes[] publicKeys, bool deferred);

    /// @notice Emitted when the AttestationVerifier address is updated
    event SetAttestationVerifier(address indexed attestationVerifier);

    /// @notice The deposit size is invalid
    error InvalidDepositSize(uint256 depositSize);

    /// @notice The withdrawal credentials value is null
    error InvalidWithdrawalCredentials();

    /// @notice An error occured during the deposit
    error ErrorOnDeposit();

    /// @notice Not keeper
    error OnlyKeeper();

    /// @notice Deposits are blocked while slashing containment mode is active
    error SlashingContainmentModeEnabled();

    /// @notice The metadata field in a DepositObject is not a valid "operator:N" encoding
    error InvalidOperatorMetadata(bytes32 metadata);

    /// @notice The parsed operator index references an operator that does not exist
    error InvalidOperatorIndex(uint256 operatorIndex, uint256 operatorCount);

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

    /// @notice Returns the AttestationVerifier address River delegates BLS+quorum verification to
    function getAttestationVerifier() external view returns (address);

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
}
