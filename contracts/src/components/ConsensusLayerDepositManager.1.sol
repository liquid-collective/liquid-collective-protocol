//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../interfaces/components/IConsensusLayerDepositManager.1.sol";
import "../interfaces/IAttestationVerifier.1.sol";
import "../interfaces/IDepositContract.sol";
import "../interfaces/IDepositDataBuffer.sol";
import "../interfaces/IOperatorRegistry.1.sol";

import "../libraries/LibBytes.sol";
import "../libraries/LibUint256.sol";
import "../libraries/LibErrors.sol";
import "../libraries/BLS12_381.sol";

import "../state/river/AttestationVerifierAddress.sol";
import "../state/river/BalanceToDeposit.sol";
import "../state/river/CommittedBalance.sol";
import "../state/river/DepositContractAddress.sol";
import "../state/river/InFlightDeposit.sol";
import "../state/river/KeeperAddress.sol";
import "../state/river/TotalDepositedETH.sol";
import "../state/river/WithdrawalCredentials.sol";

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

    /// @notice Internal helper called to update operator funded ETH from buffer-based deposits
    function _updateFundedETHFromBuffer(IDepositDataBuffer.DepositObject[] memory deposits) internal virtual;

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

        // 4. Validate attestation quorum + BLS signatures; get deposits
        uint256 committedBalance = CommittedBalance.get();
        address depositContract = DepositContractAddress.get();
        IAttestationVerifierV1 verifier = IAttestationVerifierV1(AttestationVerifierAddress.get());
        (IDepositDataBuffer.DepositObject[] memory deposits, uint256 totalAmount) = verifier.validate(
            depositDataBufferId, depositRootHash, signatures, depositContract, withdrawalCredentials, committedBalance
        );

        // 5. Update operator funded validator accounting
        _updateFundedETHFromBuffer(deposits);

        // 6. Execute deposits and split into top-ups (all-zero depositY) vs initial deposits.
        uint256 len = deposits.length;
        uint256 newlyFundedPubkeysCount = 0;
        for (uint256 i = 0; i < len; i++) {
            if (!BLS12_381.isZero(deposits[i].depositY)) newlyFundedPubkeysCount++;
        }
        bytes[] memory newlyFundedPubkeys = new bytes[](newlyFundedPubkeysCount);
        uint256 newlyFundedPubkeysCursor = 0;

        for (uint256 i = 0; i < len; i++) {
            _depositValidator(
                deposits[i].pubkey, deposits[i].signature, deposits[i].amount, withdrawalCredentials, depositContract
            );
            if (BLS12_381.isZero(deposits[i].depositY)) {
                emit TopUp(depositDataBufferId, deposits[i].operatorIdx, deposits[i].pubkey, deposits[i].amount);
            } else {
                emit PubkeyFunded(depositDataBufferId, deposits[i].operatorIdx, deposits[i].pubkey, deposits[i].amount);
                newlyFundedPubkeys[newlyFundedPubkeysCursor] = deposits[i].pubkey;
                newlyFundedPubkeysCursor++;
            }
        }

        // 7. Bookkeeping writes BEFORE the external `recordNewlyFundedPubkeys` callback.
        _setCommittedBalance(committedBalance - totalAmount);

        uint256 currentInFlightETH = InFlightDeposit.get();
        InFlightDeposit.set(currentInFlightETH + totalAmount);
        emit SetInFlightETH(currentInFlightETH, currentInFlightETH + totalAmount);

        uint256 currentTotalDepositedETH = TotalDepositedETH.get();
        TotalDepositedETH.set(currentTotalDepositedETH + totalAmount);
        emit SetTotalDepositedETH(currentTotalDepositedETH, currentTotalDepositedETH + totalAmount);

        // 8. Record initial-deposit pubkeys so future top-ups against them pass the membership check.
        if (newlyFundedPubkeysCount > 0) {
            verifier.recordNewlyFundedPubkeys(newlyFundedPubkeys);
        }
    }

    /// @notice Deposits _depositAmount ETH to the official Deposit contract
    /// @param _publicKey The public key of the validator
    /// @param _signature The signature provided by the operator
    /// @param _withdrawalCredentials The withdrawal credentials provided by River
    /// @param _depositContract The address of the deposit contract
    function _depositValidator(
        bytes memory _publicKey,
        bytes memory _signature,
        uint256 _depositAmount,
        bytes32 _withdrawalCredentials,
        address _depositContract
    ) internal {
        // `_depositAmount` bounds are enforced upstream in `AttestationVerifier.validate()`
        // (revert: InvalidDepositAmount). The attestation flow is the only caller.
        uint256 depositAmount = _depositAmount / 1 gwei;

        bytes32 pubkeyRoot = sha256(bytes.concat(_publicKey, bytes16(0)));
        bytes32 signatureRoot = sha256(
            bytes.concat(
                sha256(LibBytes.slice(_signature, 0, 64)),
                sha256(bytes.concat(LibBytes.slice(_signature, 64, SIGNATURE_LENGTH - 64), bytes32(0)))
            )
        );

        bytes32 depositDataRoot = sha256(
            bytes.concat(
                sha256(bytes.concat(pubkeyRoot, _withdrawalCredentials)),
                sha256(bytes.concat(bytes32(LibUint256.toLittleEndian64(depositAmount)), signatureRoot))
            )
        );

        uint256 targetBalance = address(this).balance - _depositAmount;

        IDepositContract(_depositContract).deposit{value: _depositAmount}(
            _publicKey, abi.encodePacked(_withdrawalCredentials), _signature, depositDataRoot
        );
        if (address(this).balance != targetBalance) {
            revert ErrorOnDeposit();
        }
    }
}
