//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../interfaces/IDepositContract.sol";

import "../libraries/LibBytes.sol";
import "../libraries/LibUint256.sol";

/// @title Lib DepositValidation
/// @author Alluvial Finance Inc.
/// @notice This library validates the deposits before they are processed
library LibDepositValidation {
    /// @notice An error occurred during the deposit
    error ErrorOnDeposit();

    /// @notice Size of a BLS Signature in bytes
    uint256 public constant SIGNATURE_LENGTH = 96;

    /// @notice Deposits _depositAmount ETH to the official Deposit contract
    /// @param _publicKey The public key of the validator
    /// @param _signature The signature provided by the operator
    /// @param _depositAmount The deposit amount in wei (must be gwei-aligned; bounds are enforced upstream)
    /// @param _withdrawalCredentials The withdrawal credentials provided by River
    /// @param _depositContract The address of the deposit contract
    function depositValidator(
        bytes memory _publicKey,
        bytes memory _signature,
        uint256 _depositAmount,
        bytes32 _withdrawalCredentials,
        address _depositContract
    ) internal {
        // `_depositAmount` bounds are enforced upstream in `AttestationVerifier.fetchAndValidateDeposits()`
        // (revert: InvalidDepositAmount / InvalidTopUpAmount). The attestation flow is the only caller.
        // The beacon deposit contract works in gwei, so convert from wei here.
        uint256 depositAmount = _depositAmount / 1 gwei;

        // Recompute the SSZ hash-tree-root of the DepositData container exactly as the beacon deposit
        // contract does, so the deposit is accepted. The container has four leaves —
        // [pubkey, withdrawal_credentials, amount, signature] — each reduced to one 32-byte node and
        // then Merkleized as a 4-leaf binary tree.

        // pubkey: 48 bytes padded to 64 (two chunks) and hashed into a single node.
        bytes32 pubkeyRoot = sha256(bytes.concat(_publicKey, bytes16(0)));

        // signature: 96 bytes = three 32-byte chunks. Hash the first 64 bytes (two chunks) and the
        // last 32 bytes padded to 64, then hash those two nodes together into the signature node.
        bytes32 signatureRoot = sha256(
            bytes.concat(
                sha256(LibBytes.slice(_signature, 0, 64)),
                sha256(bytes.concat(LibBytes.slice(_signature, 64, SIGNATURE_LENGTH - 64), bytes32(0)))
            )
        );

        // Final root: hash the left subtree (pubkeyRoot, withdrawal_credentials) with the right
        // subtree (amount, signatureRoot), where amount is the little-endian uint64 zero-padded to
        // 32 bytes — matching the deposit contract's leaf ordering.
        bytes32 depositDataRoot = sha256(
            bytes.concat(
                sha256(bytes.concat(pubkeyRoot, _withdrawalCredentials)),
                sha256(bytes.concat(bytes32(LibUint256.toLittleEndian64(depositAmount)), signatureRoot))
            )
        );

        // Snapshot the expected post-deposit balance and assert exactly `_depositAmount` left this
        // contract on the call — a defensive check against a misbehaving/incorrect deposit contract.
        uint256 targetBalance = address(this).balance - _depositAmount;

        IDepositContract(_depositContract).deposit{value: _depositAmount}(
            _publicKey, abi.encodePacked(_withdrawalCredentials), _signature, depositDataRoot
        );
        if (address(this).balance != targetBalance) {
            revert ErrorOnDeposit();
        }
    }
}
