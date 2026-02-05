//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.20;

import "../interfaces/components/IConsensusLayerDepositManager.1.sol";
import "../interfaces/IOperatorRegistry.1.sol";
import "../interfaces/IDepositContract.sol";

import "../libraries/LibBytes.sol";
import "../libraries/LibUint256.sol";

import "../state/river/DepositContractAddress.sol";
import "../state/river/WithdrawalCredentials.sol";
import "../state/river/DepositedValidatorCount.sol";
import "../state/river/BalanceToDeposit.sol";
import "../state/river/CommittedBalance.sol";
import "../state/river/KeeperAddress.sol";

/// @title Consensus Layer Deposit Manager (v1)
/// @author Alluvial Finance Inc.
/// @notice This contract handles the interactions with the official deposit contract, funding all validators
/// @notice Whenever a deposit to the consensus layer is requested, this contract computed the amount of keys
/// @notice that could be deposited depending on the amount available in the contract. It then tries to retrieve
/// @notice validator keys by calling its internal virtual method _getNextValidators. This method should be
/// @notice overridden by the implementing contract to provide keys based on the allocation when invoked.
abstract contract ConsensusLayerDepositManagerV1 is IConsensusLayerDepositManagerV1 {
    /// @notice Size of a BLS Public key in bytes
    uint256 public constant PUBLIC_KEY_LENGTH = 48;
    /// @notice Size of a BLS Signature in bytes
    uint256 public constant SIGNATURE_LENGTH = 96;
    /// @notice Size of a deposit in ETH
    uint256 public constant DEPOSIT_SIZE = 32 ether;

    /// @notice Handler called to retrieve the internal River admin address
    /// @dev Must be Overridden
    function _getRiverAdmin() internal view virtual returns (address);

    /// @notice Handler called to change the committed balance to deposit
    /// @param newCommittedBalance The new committed balance value
    function _setCommittedBalance(uint256 newCommittedBalance) internal virtual;

    /// @notice Internal helper to retrieve validator keys based on node operator allocations
    /// @dev Must be overridden
    /// @param _allocations Node operator allocations
    /// @return publicKeys An array of fundable public keys
    /// @return signatures An array of signatures linked to the public keys
    function _getNextValidators(IOperatorsRegistryV1.OperatorAllocation[] memory _allocations)
        internal
        virtual
        returns (bytes[] memory publicKeys, bytes[] memory signatures);

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
    }

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
    function getDepositedValidatorCount() external view returns (uint256) {
        return DepositedValidatorCount.get();
    }

    /// @inheritdoc IConsensusLayerDepositManagerV1
    function getKeeper() external view returns (address) {
        return KeeperAddress.get();
    }

    /// @inheritdoc IConsensusLayerDepositManagerV1
    function depositToConsensusLayerWithDepositRoot(
        IOperatorsRegistryV1.OperatorAllocation[] calldata _allocations,
        bytes32 _depositRoot
    ) external {
        if (msg.sender != KeeperAddress.get()) {
            revert OnlyKeeper();
        }

        if (IDepositContract(DepositContractAddress.get()).get_deposit_root() != _depositRoot) {
            revert InvalidDepositRoot();
        }

        uint256 committedBalance = CommittedBalance.get();
        uint256 keyToDepositCount = committedBalance / DEPOSIT_SIZE;
        // Calculate total requested from allocations
        uint256 totalRequested = 0;
        for (uint256 i = 0; i < _allocations.length; ++i) {
            if (_allocations[i].validatorCount == 0) {
                revert IOperatorsRegistryV1.AllocationWithZeroValidatorCount();
            }
            totalRequested += _allocations[i].validatorCount;
        }

        //TODO maybe rename
        if (totalRequested > keyToDepositCount) {
            revert OperatorAllocationsExceedCommittedBalance();
        }

        // Get validator keys using provided allocations
        (bytes[] memory publicKeys, bytes[] memory signatures) = _getNextValidators(_allocations);

        uint256 receivedPublicKeyCount = publicKeys.length;

        if (receivedPublicKeyCount == 0) {
            revert NoAvailableValidatorKeys();
        }

        //!!! TODO what if allocation is less than keyToDepositCount?
        /// Should we still revert?
        if (receivedPublicKeyCount > keyToDepositCount) {
            revert InvalidPublicKeyCount();
        }

        bytes32 withdrawalCredentials = WithdrawalCredentials.get();

        if (withdrawalCredentials == 0) {
            revert InvalidWithdrawalCredentials();
        }

        for (uint256 idx = 0; idx < receivedPublicKeyCount; ++idx) {
            _depositValidator(publicKeys[idx], signatures[idx], withdrawalCredentials);
        }
        _setCommittedBalance(committedBalance - DEPOSIT_SIZE * receivedPublicKeyCount);
        uint256 currentDepositedValidatorCount = DepositedValidatorCount.get();
        DepositedValidatorCount.set(currentDepositedValidatorCount + receivedPublicKeyCount);
        emit SetDepositedValidatorCount(
            currentDepositedValidatorCount, currentDepositedValidatorCount + receivedPublicKeyCount
        );
    }

    /// @notice Deposits 32 ETH to the official Deposit contract
    /// @param _publicKey The public key of the validator
    /// @param _signature The signature provided by the operator
    /// @param _withdrawalCredentials The withdrawal credentials provided by River
    function _depositValidator(bytes memory _publicKey, bytes memory _signature, bytes32 _withdrawalCredentials)
        internal
    {
        if (_publicKey.length != PUBLIC_KEY_LENGTH) {
            revert InconsistentPublicKeys();
        }

        if (_signature.length != SIGNATURE_LENGTH) {
            revert InconsistentSignatures();
        }
        uint256 value = DEPOSIT_SIZE;

        uint256 depositAmount = value / 1 gwei;

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

        uint256 targetBalance = address(this).balance - value;

        IDepositContract(DepositContractAddress.get()).deposit{value: value}(
            _publicKey, abi.encodePacked(_withdrawalCredentials), _signature, depositDataRoot
        );
        if (address(this).balance != targetBalance) {
            revert ErrorOnDeposit();
        }
    }
}
