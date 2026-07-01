//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "./LibBytes.sol";
import "./LibUint256.sol";

/// @title Lib Deposit Data
/// @author Alluvial Finance Inc.
/// @notice Computes the SSZ hash-tree-root of a beacon-chain DepositData container. Extracted from
///         ConsensusLayerDepositManagerV1 into a `public`-function library (deployed separately and
///         linked into River via delegatecall) to keep River's deployed bytecode under EIP-170.
/// @dev The merkleization is pure (only `sha256`); no storage is touched, so the delegatecall is used
///      solely to relocate the bytecode.
library LibDepositData {
    /// @notice Size of a BLS signature in bytes
    uint256 internal constant SIGNATURE_LENGTH = 96;

    /// @notice Recompute the SSZ hash-tree-root of the DepositData container exactly as the beacon
    ///         deposit contract does, so the deposit is accepted. The container has four leaves —
    ///         [pubkey, withdrawal_credentials, amount, signature] — each reduced to one 32-byte node
    ///         and then Merkleized as a 4-leaf binary tree.
    /// @param publicKey The 48-byte validator public key
    /// @param signature The 96-byte BLS signature
    /// @param depositAmountGwei The deposit amount in gwei (already converted from wei by the caller)
    /// @param withdrawalCredentials The withdrawal credentials applied to the deposit
    /// @return The DepositData SSZ hash-tree-root
    function depositDataRoot(
        bytes memory publicKey,
        bytes memory signature,
        uint256 depositAmountGwei,
        bytes32 withdrawalCredentials
    ) public pure returns (bytes32) {
        // pubkey: 48 bytes padded to 64 (two chunks) and hashed into a single node.
        bytes32 pubkeyRoot = sha256(bytes.concat(publicKey, bytes16(0)));

        // signature: 96 bytes = three 32-byte chunks. Hash the first 64 bytes (two chunks) and the
        // last 32 bytes padded to 64, then hash those two nodes together into the signature node.
        bytes32 signatureRoot = sha256(
            bytes.concat(
                sha256(LibBytes.slice(signature, 0, 64)),
                sha256(bytes.concat(LibBytes.slice(signature, 64, SIGNATURE_LENGTH - 64), bytes32(0)))
            )
        );

        // Final root: hash the left subtree (pubkeyRoot, withdrawal_credentials) with the right
        // subtree (amount, signatureRoot), where amount is the little-endian uint64 zero-padded to
        // 32 bytes — matching the deposit contract's leaf ordering.
        return sha256(
            bytes.concat(
                sha256(bytes.concat(pubkeyRoot, withdrawalCredentials)),
                sha256(bytes.concat(bytes32(LibUint256.toLittleEndian64(depositAmountGwei)), signatureRoot))
            )
        );
    }
}
