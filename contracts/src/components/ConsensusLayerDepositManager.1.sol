//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../interfaces/components/IConsensusLayerDepositManager.1.sol";
import "../interfaces/IDepositContract.sol";

import "../libraries/LibBytes.sol";
import "../libraries/LibUint256.sol";

import "../state/river/DepositContractAddress.sol";
import "../state/river/WithdrawalCredentials.sol";
import "../state/river/DepositedBalance.sol";
import "../state/river/ActivatedDepositedBalance.sol";
import "../state/river/BalanceToDeposit.sol";
import "../state/river/CommittedBalance.sol";
import "../state/river/KeeperAddress.sol";

/// @title Consensus Layer Deposit Manager (v1)
/// @author Alluvial Finance Inc.
/// @notice This contract handles the interactions with the official deposit contract, funding validators
/// @notice The keeper provides pubkeys, signatures, and amounts directly for each deposit
abstract contract ConsensusLayerDepositManagerV1 is IConsensusLayerDepositManagerV1 {
    /// @notice Size of a BLS Public key in bytes
    uint256 public constant PUBLIC_KEY_LENGTH = 48;
    /// @notice Size of a BLS Signature in bytes
    uint256 public constant SIGNATURE_LENGTH = 96;
    /// @notice Minimum deposit amount (32 ETH)
    uint256 public constant MIN_DEPOSIT_SIZE = 32 ether;
    /// @notice Maximum deposit amount (2048 ETH)
    uint256 public constant MAX_DEPOSIT_SIZE = 2048 ether;

    /// @notice Handler called to retrieve the internal River admin address
    /// @dev Must be Overridden
    function _getRiverAdmin() internal view virtual returns (address);

    /// @notice Handler called to change the committed balance to deposit
    /// @param newCommittedBalance The new committed balance value
    function _setCommittedBalance(uint256 newCommittedBalance) internal virtual;

    /// @notice Handler called after deposits to update operator funded balances
    /// @param _deposits The deposits that were made
    function _onDepositsComplete(ValidatorDeposit[] calldata _deposits) internal virtual;

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
    function getDepositedBalance() external view returns (uint256) {
        return DepositedBalance.get();
    }

    /// @inheritdoc IConsensusLayerDepositManagerV1
    function getActivatedDepositedBalance() external view returns (uint256) {
        return ActivatedDepositedBalance.get();
    }

    /// @inheritdoc IConsensusLayerDepositManagerV1
    function getKeeper() external view returns (address) {
        return KeeperAddress.get();
    }

    /// @inheritdoc IConsensusLayerDepositManagerV1
    function depositToConsensusLayer(
        ValidatorDeposit[] calldata _deposits,
        bytes32 _depositRoot
    ) external {
        if (msg.sender != KeeperAddress.get()) {
            revert OnlyKeeper();
        }

        if (_deposits.length == 0) {
            revert EmptyDepositsArray();
        }

        if (IDepositContract(DepositContractAddress.get()).get_deposit_root() != _depositRoot) {
            revert InvalidDepositRoot();
        }

        bytes32 withdrawalCredentials = WithdrawalCredentials.get();
        if (withdrawalCredentials == 0) {
            revert InvalidWithdrawalCredentials();
        }

        uint256 committedBalance = CommittedBalance.get();
        uint256 totalDepositAmount = 0;

        for (uint256 idx = 0; idx < _deposits.length; ++idx) {
            uint256 amount = _deposits[idx].depositAmount;

            if (amount < MIN_DEPOSIT_SIZE) {
                revert DepositAmountTooLow(amount, MIN_DEPOSIT_SIZE);
            }
            if (amount > MAX_DEPOSIT_SIZE) {
                revert DepositAmountTooHigh(amount, MAX_DEPOSIT_SIZE);
            }
            if (amount % 1 gwei != 0) {
                revert DepositAmountNotGweiAligned(amount);
            }

            _depositValidator(
                _deposits[idx].pubkey,
                _deposits[idx].signature,
                withdrawalCredentials,
                amount
            );

            totalDepositAmount += amount;
        }

        if (totalDepositAmount > committedBalance) {
            revert DepositsExceedCommittedBalance(totalDepositAmount, committedBalance);
        }

        _setCommittedBalance(committedBalance - totalDepositAmount);

        uint256 currentDepositedBalance = DepositedBalance.get();
        DepositedBalance.set(currentDepositedBalance + totalDepositAmount);
        emit SetDepositedBalance(currentDepositedBalance, currentDepositedBalance + totalDepositAmount);

        _onDepositsComplete(_deposits);
    }

    /// @notice Deposits ETH to the official Deposit contract
    /// @param _publicKey The public key of the validator
    /// @param _signature The signature provided by the operator
    /// @param _withdrawalCredentials The withdrawal credentials provided by River
    /// @param _depositAmount The amount of ETH to deposit
    function _depositValidator(
        bytes memory _publicKey,
        bytes memory _signature,
        bytes32 _withdrawalCredentials,
        uint256 _depositAmount
    ) internal {
        if (_publicKey.length != PUBLIC_KEY_LENGTH) {
            revert InconsistentPublicKeys();
        }

        if (_signature.length != SIGNATURE_LENGTH) {
            revert InconsistentSignatures();
        }

        uint256 depositAmountGwei = _depositAmount / 1 gwei;

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
                sha256(bytes.concat(bytes32(LibUint256.toLittleEndian64(depositAmountGwei)), signatureRoot))
            )
        );

        uint256 targetBalance = address(this).balance - _depositAmount;

        IDepositContract(DepositContractAddress.get()).deposit{value: _depositAmount}(
            _publicKey, abi.encodePacked(_withdrawalCredentials), _signature, depositDataRoot
        );
        if (address(this).balance != targetBalance) {
            revert ErrorOnDeposit();
        }
    }
}
