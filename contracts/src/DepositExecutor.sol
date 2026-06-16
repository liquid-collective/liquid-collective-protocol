//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "./interfaces/IDepositContract.sol";
import "./interfaces/IDepositDataBuffer.sol";
import "./interfaces/IDepositExecutor.sol";

import "./libraries/LibBytes.sol";
import "./libraries/LibUint256.sol";

/// @title Deposit Executor
/// @author Alluvial Finance Inc.
/// @notice Stateless helper for executing beacon-chain deposits from attested River batches.
contract DepositExecutor is IDepositExecutor {
    uint256 internal constant SIGNATURE_LENGTH = 96;

    /// @inheritdoc IDepositExecutor
    function executeDeposits(
        IDepositDataBuffer.Deposit[] calldata deposits,
        IDepositDataBuffer.TopUp[] calldata topUps,
        bytes32 withdrawalCredentials,
        address depositContract
    ) external payable {
        uint256 spentValue;

        for (uint256 i = 0; i < deposits.length; i++) {
            IDepositDataBuffer.Deposit calldata d = deposits[i];
            spentValue += d.amount;
            _depositValidator(d.pubkey, d.signature, d.amount, withdrawalCredentials, depositContract);
        }

        uint256 topUpCount = topUps.length;
        if (topUpCount > 0) {
            bytes memory zeroSig = new bytes(SIGNATURE_LENGTH);
            for (uint256 i = 0; i < topUpCount; i++) {
                IDepositDataBuffer.TopUp calldata t = topUps[i];
                spentValue += t.amount;
                _depositValidator(t.pubkey, zeroSig, t.amount, withdrawalCredentials, depositContract);
            }
        }

        if (spentValue != msg.value) {
            revert InvalidDepositValue(spentValue, msg.value);
        }
    }

    /// @notice Deposits `_depositAmount` ETH to the official deposit contract.
    function _depositValidator(
        bytes memory _publicKey,
        bytes memory _signature,
        uint256 _depositAmount,
        bytes32 _withdrawalCredentials,
        address _depositContract
    ) internal {
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
