//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "./interfaces/IDepositContract.sol";
import "./interfaces/IValidatorCredentialsProvider.sol";
import "./state/DepositContractAddress.sol";
import "./state/ValidatorCredentialsProviderAddress.sol";
import "./state/WithdrawalCredentials.sol";

import "../../shared/libraries/BytesLib.sol";
import "../../shared/libraries/UintLib.sol";

contract DepositManagerV1 {
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

    function depositManagerInitializeV1(
        address _depositContractAddress,
        address _validatorCredentialsProviderAddress,
        bytes32 _withdrawalCredentials
    ) internal {
        DepositContractAddress.set(IDepositContract(_depositContractAddress));

        ValidatorCredentialsProviderAddress.set(
            IValidatorCredentialsProvider(_validatorCredentialsProviderAddress)
        );

        WithdrawalCredentials.set(_withdrawalCredentials);
    }

    function depositToETH2() external {
        uint256 validatorsToDeposit = address(this).balance / DEPOSIT_SIZE;

        if (validatorsToDeposit == 0) {
            revert NotEnoughFunds();
        }

        (
            bytes memory publicKeys,
            bytes memory signatures
        ) = ValidatorCredentialsProviderAddress.get().getValidatorKeys(
                validatorsToDeposit
            );

        if (publicKeys.length % PUBLIC_KEY_LENGTH != 0) {
            revert InconsistentPublicKeys();
        }

        if (signatures.length % SIGNATURE_LENGTH != 0) {
            revert InconsistentSignatures();
        }

        uint256 receivedPublicKeyCount = publicKeys.length / PUBLIC_KEY_LENGTH;

        if (receivedPublicKeyCount == 0) {
            revert NoAvailableValidatorKeys();
        }

        if (receivedPublicKeyCount > validatorsToDeposit) {
            revert InvalidPublicKeyCount();
        }

        uint256 receivedSignatureCount = signatures.length / SIGNATURE_LENGTH;

        if (receivedSignatureCount != receivedPublicKeyCount) {
            revert InvalidSignatureCount();
        }

        bytes32 withdrawalCredentials = WithdrawalCredentials.get();

        if (withdrawalCredentials == 0) {
            revert InvalidWithdrawalCredentials();
        }

        for (uint256 idx = 0; idx < receivedPublicKeyCount; idx += 1) {
            bytes memory publicKey = BytesLib.slice(
                publicKeys,
                PUBLIC_KEY_LENGTH * idx,
                PUBLIC_KEY_LENGTH
            );
            bytes memory signature = BytesLib.slice(
                signatures,
                SIGNATURE_LENGTH * idx,
                SIGNATURE_LENGTH
            );
            _depositPublicKey(publicKey, signature, withdrawalCredentials);
        }
    }

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
                sha256(
                    BytesLib.pad64(
                        BytesLib.slice(_signature, 64, SIGNATURE_LENGTH - 64)
                    )
                )
            )
        );

        bytes32 depositDataRoot = sha256(
            abi.encodePacked(
                sha256(abi.encodePacked(pubkeyRoot, _withdrawalCredentials)),
                sha256(
                    abi.encodePacked(
                        UintLib.toLittleEndian64(depositAmount),
                        signatureRoot
                    )
                )
            )
        );

        uint256 targetBalance = address(this).balance - value;

        DepositContractAddress.get().deposit{value: value}(
            _publicKey,
            abi.encodePacked(_withdrawalCredentials),
            _signature,
            depositDataRoot
        );
        require(
            address(this).balance == targetBalance,
            "EXPECTING_DEPOSIT_TO_HAPPEN"
        );
    }
}
