//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../interfaces/components/IConsensusLayerDepositManager.1.sol";
import "../interfaces/IAttestationVerifier.1.sol";
import "../interfaces/IDepositDataBuffer.sol";
import "../interfaces/IDepositExecutor.sol";
import "../interfaces/IOperatorRegistry.1.sol";

import "../libraries/LibErrors.sol";

import "../state/river/BalanceToDeposit.sol";
import "../state/river/CommittedBalance.sol";
import "../state/river/DepositContractAddress.sol";
import "../state/river/DepositExecutorAddress.sol";
import "../state/river/InFlightDeposit.sol";
import "../state/river/KeeperAddress.sol";
import "../state/river/TotalDepositedETH.sol";
import "../state/river/WithdrawalCredentials.sol";
import "../state/shared/AttestationVerifierAddress.sol";

/// @title Consensus Layer Deposit Manager (v1)
/// @author Alluvial Finance Inc.
/// @notice Handles interactions with the official deposit contract and orchestrates the
///         attestation-gated deposit flow. Attestation-quorum and BLS verification are
///         delegated to the AttestationVerifier sibling contract; this component owns
///         the keeper authorization, slashing-containment gating, ETH execution, and
///         the balance/in-flight bookkeeping.
abstract contract ConsensusLayerDepositManagerV1 is IConsensusLayerDepositManagerV1 {
    /// @notice Size of a BLS Signature in bytes
    uint256 public constant SIGNATURE_LENGTH = 96;
    /// @notice Canonical legacy validator deposit size (32 ETH); used by River for
    ///         pre-Pectra validator-count → ETH conversions.
    uint256 public constant DEPOSIT_SIZE = 32 ether;

    // -----------------------------------------------------------------------
    // Modifiers
    // -----------------------------------------------------------------------

    /// @notice Used in river
    modifier onlyKeeper() {
        if (msg.sender != KeeperAddress.get()) {
            revert OnlyKeeper();
        }
        _;
    }

    modifier onlyRiverAdmin() {
        if (msg.sender != _getRiverAdmin()) revert LibErrors.Unauthorized(msg.sender);
        _;
    }

    /// @notice Handler called to retrieve the internal River admin address
    function _getRiverAdmin() internal view virtual returns (address);

    /// @notice Handler called to increment the funded ETH for the operators
    /// @param _deltas The per-operator funding deltas (sorted by operatorIndex)
    function _incrementFundedETH(IOperatorsRegistryV1.OperatorFundingDelta[] memory _deltas) internal virtual;

    /// @notice Handler called to change the committed balance to deposit
    function _setCommittedBalance(uint256 newCommittedBalance) internal virtual;

    /// @notice Internal helper called to update operator funded ETH from a buffer-based batch.
    /// @dev Aggregates per-operator deltas across both initial deposits and top-ups.
    function _updateFundedETHFromBuffer(
        IDepositDataBuffer.Deposit[] memory deposits,
        IDepositDataBuffer.TopUp[] memory topUps
    ) internal virtual;

    /// @notice Handler to check if slashing containment mode is active
    function _getSlashingContainmentMode() internal view virtual returns (bool);

    // -----------------------------------------------------------------------
    // Initializers (called from River init)
    // -----------------------------------------------------------------------

    /// @notice Initializer to set the deposit contract address and the withdrawal credentials to use
    /// @param _depositContractAddress The address of the deposit contract
    /// @param _withdrawalCredentials The withdrawal credentials to apply to all deposits
    function initConsensusLayerDepositManagerV1(address _depositContractAddress, bytes32 _withdrawalCredentials)
        internal
    {
        DepositContractAddress.set(_depositContractAddress);
        emit SetDepositContractAddress(_depositContractAddress);

        if (bytes1(_withdrawalCredentials) != 0x02) {
            revert InvalidWithdrawalCredentialsPrefix();
        }

        WithdrawalCredentials.set(_withdrawalCredentials);
        emit SetWithdrawalCredentials(_withdrawalCredentials);
    }

    function _setKeeper(address _keeper) internal {
        KeeperAddress.set(_keeper);
        emit SetKeeper(_keeper);
    }

    // -----------------------------------------------------------------------
    // Views — River-side state only
    // -----------------------------------------------------------------------

    /// @inheritdoc IConsensusLayerDepositManagerV1
    function getCommittedBalance() external view returns (uint256) {
        return CommittedBalance.get();
    }

    /// @inheritdoc IConsensusLayerDepositManagerV1
    function getBalanceToDeposit() external view returns (uint256) {
        return BalanceToDeposit.get();
    }

    /// @inheritdoc IConsensusLayerDepositManagerV1
    function getWithdrawalCredentials() external view returns (bytes32) {
        return WithdrawalCredentials.get();
    }

    /// @inheritdoc IConsensusLayerDepositManagerV1
    function getTotalDepositedETH() external view returns (uint256) {
        return TotalDepositedETH.get();
    }

    /// @inheritdoc IConsensusLayerDepositManagerV1
    function getKeeper() external view returns (address) {
        return KeeperAddress.get();
    }

    /// @inheritdoc IConsensusLayerDepositManagerV1
    function getAttestationVerifier() external view returns (address) {
        return AttestationVerifierAddress.get();
    }

    /// @inheritdoc IConsensusLayerDepositManagerV1
    function removeExitedValidatorPubkeys(bytes[] calldata pubkeys) external onlyKeeper {
        IAttestationVerifierV1(AttestationVerifierAddress.get()).removeExitedValidatorPubkeys(pubkeys);
    }

    // -----------------------------------------------------------------------
    // Attestation-gated deposit entry point
    // -----------------------------------------------------------------------

    /// @inheritdoc IConsensusLayerDepositManagerV1
    function depositToConsensusLayerWithAttestation(
        bytes32 depositDataBufferId,
        bytes32 depositRootHash,
        bytes[] calldata signatures
    ) external {
        // 1. Keeper check
        if (msg.sender != KeeperAddress.get()) revert OnlyKeeper();
        // 2. Slashing containment mode check
        if (_getSlashingContainmentMode()) revert SlashingContainmentModeEnabled();

        // 3. Withdrawal credentials check
        bytes32 withdrawalCredentials = WithdrawalCredentials.get();
        if (withdrawalCredentials == 0) revert InvalidWithdrawalCredentials();

        // 4. Validate attestation quorum + BLS signatures; get the batch
        uint256 committedBalance = CommittedBalance.get();
        address depositContract = DepositContractAddress.get();
        IAttestationVerifierV1 verifier = IAttestationVerifierV1(AttestationVerifierAddress.get());
        (IDepositDataBuffer.DepositObject memory batch, uint256 totalAmount) = verifier.fetchAndValidateDeposits(
            depositDataBufferId, depositRootHash, signatures, depositContract, withdrawalCredentials, committedBalance
        );

        // 5. Mark the batch ID processed BEFORE any external interactions.
        verifier.markDepositDataBufferIdProcessed(depositDataBufferId);

        // 6. Update operator funded validator accounting
        _updateFundedETHFromBuffer(batch.deposits, batch.topUps);

        // 7. Execute initial deposits and top-ups through the stateless executor.
        IDepositExecutor(DepositExecutorAddress.get()).executeDeposits{value: totalAmount}(
            batch.deposits, batch.topUps, withdrawalCredentials, depositContract
        );

        // 8. Emit River-scoped deposit events and collect initial-deposit pubkeys for verifier bookkeeping.
        uint256 depositCount = batch.deposits.length;
        bytes[] memory newlyFundedPubkeys = new bytes[](depositCount);
        for (uint256 i = 0; i < depositCount; i++) {
            IDepositDataBuffer.Deposit memory d = batch.deposits[i];
            emit PubkeyFunded(depositDataBufferId, d.operatorIdx, d.pubkey, d.amount);
            newlyFundedPubkeys[i] = d.pubkey;
        }

        uint256 topUpCount = batch.topUps.length;
        for (uint256 i = 0; i < topUpCount; i++) {
            IDepositDataBuffer.TopUp memory t = batch.topUps[i];
            emit TopUp(depositDataBufferId, t.operatorIdx, t.pubkey, t.amount);
        }

        // 9. Bookkeeping writes BEFORE the external `recordNewlyFundedPubkeys` callback.
        _setCommittedBalance(committedBalance - totalAmount);

        uint256 currentInFlightETH = InFlightDeposit.get();
        InFlightDeposit.set(currentInFlightETH + totalAmount);
        emit SetInFlightETH(currentInFlightETH, currentInFlightETH + totalAmount);

        uint256 currentTotalDepositedETH = TotalDepositedETH.get();
        TotalDepositedETH.set(currentTotalDepositedETH + totalAmount);
        emit SetTotalDepositedETH(currentTotalDepositedETH, currentTotalDepositedETH + totalAmount);

        // 10. Record initial-deposit pubkeys so future top-ups against them pass the membership check.
        if (depositCount > 0) {
            verifier.recordNewlyFundedPubkeys(newlyFundedPubkeys);
        }
    }
}
