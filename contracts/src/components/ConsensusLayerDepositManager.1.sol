//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "../interfaces/IDepositContract.sol";

import "../libraries/LibBytes.sol";
import "../libraries/LibUint256.sol";

import "../state/river/DepositContractAddress.sol";
import "../state/river/WithdrawalCredentials.sol";
import "../state/river/DepositedValidatorCount.sol";
import "../state/river/EthToDeposit.sol";

import "../interfaces/components/IConsensusLayerDepositManager.1.sol";

/// @title Consensus Layer Deposit Manager (v1)
/// @author Kiln
/// @notice This contract handles the interactions with the official deposit contract, funding all validators
/// @dev _onValidatorKeyRequest must be overriden.
abstract contract ConsensusLayerDepositManagerV1 is IConsensusLayerDepositManagerV1 {
    uint256 public constant PUBLIC_KEY_LENGTH = 48;
    uint256 public constant SIGNATURE_LENGTH = 96;
    uint256 public constant DEPOSIT_SIZE = 32 ether;

    /// @notice Initializer to set the deposit contract address and the withdrawal credentials to use
    /// @param _depositContractAddress The address of the deposit contract
    /// @param _withdrawalCredentials The withdrawal credentials to apply to all deposits
    function initConsensusLayerDepositManagerV1(address _depositContractAddress, bytes32 _withdrawalCredentials)
        internal
    {
        DepositContractAddress.set(IDepositContract(_depositContractAddress));
        emit SetDepositContractAddress(_depositContractAddress);

        WithdrawalCredentials.set(_withdrawalCredentials);
        emit SetWithdrawalCredentials(_withdrawalCredentials);
    }

    /// @notice Retrieve the withdrawal credentials
    function getWithdrawalCredentials() external view returns (bytes32) {
        return WithdrawalCredentials.get();
    }

    /// @notice Internal helper to retrieve validator keys ready to be funded
    /// @dev Must be overriden with an implementation that provides keyCount or less keys upon call
    /// @param _keyCount The amount of keys (or less) to return.
    function _getNextValidators(uint256 _keyCount)
        internal
        virtual
        returns (bytes[] memory publicKeys, bytes[] memory signatures);

    /// @notice Deposits current balance to the Consensus Layer by batches of 32 ETH
    /// @param _maxCount The maximum amount of validator keys to fund
    function depositToConsensusLayer(uint256 _maxCount) external {
        uint256 currentBalance = address(this).balance; // merge unseen funds with active funds
        uint256 validatorsToDeposit = LibUint256.min(currentBalance / DEPOSIT_SIZE, _maxCount);

        if (validatorsToDeposit == 0) {
            revert NotEnoughFunds();
        }

        (bytes[] memory publicKeys, bytes[] memory signatures) = _getNextValidators(validatorsToDeposit);

        uint256 receivedPublicKeyCount = publicKeys.length;

        if (receivedPublicKeyCount == 0) {
            revert NoAvailableValidatorKeys();
        }

        if (receivedPublicKeyCount > validatorsToDeposit) {
            revert InvalidPublicKeyCount();
        }

        uint256 receivedSignatureCount = signatures.length;

        if (receivedSignatureCount != receivedPublicKeyCount) {
            revert InvalidSignatureCount();
        }

        bytes32 withdrawalCredentials = WithdrawalCredentials.get();

        if (withdrawalCredentials == 0) {
            revert InvalidWithdrawalCredentials();
        }

        for (uint256 idx = 0; idx < receivedPublicKeyCount;) {
            _depositValidator(publicKeys[idx], signatures[idx], withdrawalCredentials);
            unchecked {
                ++idx;
            }
        }
        EthToDeposit.set(currentBalance - DEPOSIT_SIZE * receivedPublicKeyCount);
        DepositedValidatorCount.set(DepositedValidatorCount.get() + receivedPublicKeyCount);
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

        DepositContractAddress.get().deposit{value: value}(
            _publicKey, abi.encodePacked(_withdrawalCredentials), _signature, depositDataRoot
        );
        if (address(this).balance != targetBalance) {
            revert ErrorOnDeposit();
        }
        emit FundedValidatorKey(_publicKey);
    }

    /// @notice Get the deposited validator count (the count of deposits made by the contract)
    function getDepositedValidatorCount() external view returns (uint256 depositedValidatorCount) {
        depositedValidatorCount = DepositedValidatorCount.get();
    }
}
