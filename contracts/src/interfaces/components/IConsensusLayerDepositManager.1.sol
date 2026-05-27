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

    /// @notice Emitted once per initial-deposit entry as it is executed against the deposit contract.
    ///         Carries the full raw pubkey, the operator that funded it, the amount deposited, and
    ///         the originating buffer id so consumers can correlate per-validator events with the
    ///         attested batch they belong to.
    /// @param depositDataBufferId The id of the deposit-data buffer batch
    /// @param operatorIdx The operator that funded this initial deposit
    /// @param pubkey The 48-byte BLS pubkey of the validator
    /// @param amount The wei amount deposited
    event PubkeyFunded(bytes32 indexed depositDataBufferId, uint256 indexed operatorIdx, bytes pubkey, uint256 amount);

    /// @notice Emitted once per top-up entry as it is executed against the deposit contract.
    ///         Symmetric to `PubkeyFunded` but for top-ups (entries with all-zero `depositY`,
    ///         whose pubkey must already be bound to `operatorIdx` in the ValidatorPubkeyLookup).
    /// @param depositDataBufferId The id of the deposit-data buffer batch
    /// @param operatorIdx The operator the top-up is credited to (must match the originally-bound operator)
    /// @param pubkey The 48-byte BLS pubkey of the validator
    /// @param amount The wei amount topped up
    event TopUp(bytes32 indexed depositDataBufferId, uint256 indexed operatorIdx, bytes pubkey, uint256 amount);

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

    /// @notice Deposit validators using pre-committed buffer data validated by a deposit-committee attester quorum.
    /// @dev Per-deposit Y-coordinates for BLS decompression are carried inside each
    ///      `IDepositDataBuffer.DepositObject` (the `depositY` field). An all-zero `depositY`
    ///      classifies the entry as a top-up; a non-zero one as an initial deposit.
    /// @param depositDataBufferId  Batch identifier in the DepositDataBuffer
    /// @param depositRootHash      Current deposit contract root hash co-signed by deposit-committee attesters
    /// @param signatures           EIP-712 signatures from deposit-committee attesters
    function depositToConsensusLayerWithAttestation(
        bytes32 depositDataBufferId,
        bytes32 depositRootHash,
        bytes[] calldata signatures
    ) external;
}
