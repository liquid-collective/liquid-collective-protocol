//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "../interfaces/IDepositContract.sol";

import "../libraries/BytesLib.sol";
import "../libraries/UintLib.sol";

import "../state/river/DepositContractAddress.sol";
import "../state/river/WithdrawalCredentials.sol";
import "../state/river/DepositedValidatorCount.sol";

/// @title Deposit Manager (v1)
/// @author Iulian Rotaru
/// @notice This contract handles the interactions with the official deposit contract, funding all validators
/// @dev _onValidatorKeyRequest must be overriden.
abstract contract DepositManagerV1 {
    error NotEnoughFunds();
    error InconsistentPublicKeys();
    error InconsistentSignatures();
    error NoAvailableValidatorKeys();
    error InvalidPublicKeyCount();
    error InvalidSignatureCount();
    error InvalidWithdrawalCredentials();

    uint256 public constant PUBLIC_KEY_LENGTH = 48;
    uint256 public constant SIGNATURE_LENGTH = 96;
    uint256 public constant DEPOSIT_SIZE = 32 ether;

    /// @notice Initializer to set the deposit contract address and the withdrawal credentials to use
    /// @param _depositContractAddress The address of the deposit contract
    /// @param _withdrawalCredentials The withdrawal credentials to apply to all deposits
    function depositManagerInitializeV1(address _depositContractAddress, bytes32 _withdrawalCredentials) internal {
        DepositContractAddress.set(IDepositContract(_depositContractAddress));

        WithdrawalCredentials.set(_withdrawalCredentials);
    }

    /// @notice Internal helper to retrieve validator keys ready to be funded
    /// @dev Must be overriden with an implementation that provides keyCount or less keys upon call
    /// @param _keyCount The amount of keys (or less) to return.
    function _onValidatorKeyRequest(uint256 _keyCount)
        internal
        virtual
        returns (bytes[] memory publicKeys, bytes[] memory signatures);

    /// @notice Deposits current balance to the Consensus Layer by batches of 32 ETH
    /// @param _maxCount The maximum amount of validator keys to fund
    function depositToConsensusLayer(uint256 _maxCount) external {
        uint256 validatorsToDeposit = UintLib.min(address(this).balance / DEPOSIT_SIZE, _maxCount);

        if (validatorsToDeposit == 0) {
            revert NotEnoughFunds();
        }

        (bytes[] memory publicKeys, bytes[] memory signatures) = _onValidatorKeyRequest(validatorsToDeposit);

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

        for (uint256 idx = 0; idx < receivedPublicKeyCount; idx += 1) {
            bytes memory publicKey = publicKeys[idx];

            if (publicKey.length != PUBLIC_KEY_LENGTH) {
                revert InconsistentPublicKeys();
            }

            bytes memory signature = signatures[idx];

            if (signature.length != SIGNATURE_LENGTH) {
                revert InconsistentSignatures();
            }

            _depositPublicKey(publicKey, signature, withdrawalCredentials);
        }

        DepositedValidatorCount.set(DepositedValidatorCount.get() + receivedPublicKeyCount);
    }

    /// @notice Deposits 32 ETH to the official Deposit contract
    /// @param _publicKey The public key of the validator
    /// @param _signature The signature provided by the operator
    /// @param _withdrawalCredentials The withdrawal credentials provided by River
    function _depositPublicKey(
        bytes memory _publicKey,
        bytes memory _signature,
        bytes32 _withdrawalCredentials
    ) internal {
        uint256 value = DEPOSIT_SIZE;

        uint256 depositAmount = value / 1000000000 wei;
        assert(depositAmount * 1000000000 wei == value);

        bytes32 pubkeyRoot = sha256(BytesLib.pad64(_publicKey));
        bytes32 signatureRoot = sha256(
            abi.encodePacked(
                sha256(BytesLib.slice(_signature, 0, 64)),
                sha256(BytesLib.pad64(BytesLib.slice(_signature, 64, SIGNATURE_LENGTH - 64)))
            )
        );

        bytes32 depositDataRoot = sha256(
            abi.encodePacked(
                sha256(abi.encodePacked(pubkeyRoot, _withdrawalCredentials)),
                sha256(abi.encodePacked(UintLib.toLittleEndian64(depositAmount), signatureRoot))
            )
        );

        uint256 targetBalance = address(this).balance - value;

        DepositContractAddress.get().deposit{value: value}(
            _publicKey,
            abi.encodePacked(_withdrawalCredentials),
            _signature,
            depositDataRoot
        );
        require(address(this).balance == targetBalance, "EXPECTING_DEPOSIT_TO_HAPPEN");
    }

    /// @notice Get the deposited validator count (the count of deposits made by the contract)
    function getDepositedValidatorCount() external view returns (uint256 depositedValidatorCount) {
        depositedValidatorCount = DepositedValidatorCount.get();
    }
}
