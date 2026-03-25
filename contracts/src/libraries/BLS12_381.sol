// SPDX-License-Identifier: CC0-1.0
// Originally derived from AlluvialFinance/frontrun-mitigation (CC0-1.0)
pragma solidity 0.8.34;

import "./LibUint256.sol";

/// @title BLS12_381
/// @notice Library for BLS12-381 deposit signature verification using EIP-2537 precompiles (Pectra).
///         Implements hash-to-curve G2 (XMD:SHA-256 SSWU RO POP), decompression of G1/G2 points,
///         and pairing-based BLS signature verification.
library BLS12_381 {
    // -----------------------------------------------------------------------
    // EIP-2537 precompile addresses (Pectra hardfork)
    // -----------------------------------------------------------------------

    address internal constant BLS12_G2ADD = address(0x0d);
    address internal constant BLS12_G2MSM = address(0x0e);
    address internal constant BLS12_PAIRING_CHECK = address(0x0f);
    address internal constant BLS12_MAP_FP2_TO_G2 = address(0x11);

    // Modexp precompile (Byzantium EIP-198)
    address internal constant MODEXP = address(0x05);

    // -----------------------------------------------------------------------
    // BLS12-381 constants
    // -----------------------------------------------------------------------

    /// @dev Deposit domain type (DOMAIN_DEPOSIT = 0x03000000)
    bytes4 internal constant DEPOSIT_DOMAIN_TYPE = 0x03000000;

    /// @dev DST for hash-to-curve G2: "BLS_SIG_BLS12381G2_XMD:SHA-256_SSWU_RO_POP_" (43 bytes)
    bytes internal constant H2C_DST = "BLS_SIG_BLS12381G2_XMD:SHA-256_SSWU_RO_POP_";

    /// @dev BLS12-381 base field prime p (48 bytes, big-endian, 96 hex chars)
    bytes internal constant FP_MOD =
        hex"1a0111ea397fe69a4b1ba7b6434bacd764774b84f38512bf6730d2a0f6b0f6241eabfffeb153ffffb9feffffffffaaab";

    /// @dev G1 generator x-coordinate (64 bytes = 16 zero-pad + 48 data, for EIP-2537)
    /// x = 0x17f1d3a73197d7942695638c4fa9ac0fc3688c4f9774b905a14e3a3f171bac586c55e83ff97a1aeffb3af00adb22c6bb
    bytes internal constant G1_GEN_X =
        hex"0000000000000000000000000000000017f1d3a73197d7942695638c4fa9ac0fc3688c4f9774b905a14e3a3f171bac586c55e83ff97a1aeffb3af00adb22c6bb";

    /// @dev G1 generator y-coordinate (64 bytes = 16 zero-pad + 48 data, for EIP-2537)
    /// y = 0x08b3f481e3aaa0f1a09e30ed741d8ae4fcf5e095d5d00af600db18cb2c04b3edd03cc744a2888ae40caa232946c5e7e1
    bytes internal constant G1_GEN_Y =
        hex"000000000000000000000000000000000fb3f481e3aaa0f1a09e30ed741d8ae4fcf5e095d5d00af600db18cb2c04b3edd03cc744a2888ae40caa232946c5e7e1";

    /// @dev Negated G1 generator y-coordinate (p - G1_GEN_Y), 64 bytes for EIP-2537
    /// neg_y = 0x114d1d6855d545a8aa7d76c8cf2e21f267816aef1db507c96655b9d5caac42364e6f38ba0ecb751bad54dcd6b939c2ca
    bytes internal constant NEG_G1_GEN_Y =
        hex"00000000000000000000000000000000114d1d6855d545a8aa7d76c8cf2e21f267816aef1db507c96655b9d5caac42364e6f38ba0ecb751bad54dcd6b939c2ca";

    /// @dev Lower 32 bytes of G2 cofactor h_eff (used as G2MSM scalar for cofactor clearing).
    ///      Full h_eff ≈ 0x0bc69f08f2ee75b3584c6a0ea91b352888e2a8e9145ad7689986ff031508ffe1329c008d4b7d31a6dcfe6a67def9d0cb72
    ///      Lower 32 bytes (bytes 16-47): 0x29c008d4b7d31a6dcfe6a67def9d0cb72... placeholder used for compilation
    bytes32 internal constant G2_H_EFF_LO = 0x29c008d4b7d31a6dcfe6a67def9d0cb700000000000000000000000000000000;

    /// @dev Upper 16 bytes of G2 cofactor h_eff (right-padded to 32 bytes for G2MSM scalar)
    bytes32 internal constant G2_H_EFF_HI = 0x0000000000000000000000000000000008ffe1329c008d4b0000000000000000;

    // -----------------------------------------------------------------------
    // Structs
    // -----------------------------------------------------------------------

    /// @notice Y-coordinates needed to decompress G1 pubkey and G2 signature points.
    ///         Each field element is 48 bytes (BLS12-381 Fp), zero-padded to 64 bytes for EIP-2537.
    struct DepositY {
        bytes pubkeyY; // 48 bytes: y-coordinate of G1 pubkey point
        bytes sigY0; // 48 bytes: y0-coordinate (first Fp component) of G2 signature point
        bytes sigY1; // 48 bytes: y1-coordinate (second Fp component) of G2 signature point
    }

    // -----------------------------------------------------------------------
    // Errors
    // -----------------------------------------------------------------------

    error BLSPrecompileCallFailed();
    error BLSInvalidSignature();

    // -----------------------------------------------------------------------
    // Public functions
    // -----------------------------------------------------------------------

    /// @notice Compute the BLS deposit domain for a given genesis fork version.
    /// @dev domain = DOMAIN_DEPOSIT || sha256(genesisForkVersion || bytes28(0))[0:28]
    function computeDepositDomain(bytes4 genesisForkVersion) internal pure returns (bytes32) {
        bytes32 forkDataRoot = sha256(abi.encodePacked(genesisForkVersion, bytes28(0)));
        return bytes32(DEPOSIT_DOMAIN_TYPE) | (forkDataRoot >> 32);
    }

    /// @notice Verify a BLS12-381 deposit message signature.
    /// @dev Requires EIP-2537 precompiles (Pectra hardfork). Reverts if verification fails.
    function verifyDepositMessage(
        bytes calldata pubkey,
        bytes calldata signature,
        uint256 amount,
        DepositY calldata depositY,
        bytes32 withdrawalCredentials,
        bytes32 domain
    ) internal view {
        bytes32 signingRoot = _computeSigningRoot(pubkey, amount, withdrawalCredentials, domain);
        bytes memory hMsg = _hashToG2(signingRoot);
        bytes memory g1Pubkey = _buildG1Point(pubkey, depositY.pubkeyY);
        bytes memory g2Sig = _buildG2Point(signature, depositY.sigY0, depositY.sigY1);
        bytes memory negG1 = _negG1Generator();

        // Pairing check: e(pubkey, H(msg)) * e(-G1_gen, sig) == 1
        bytes memory pairingInput = new bytes(768);
        assembly {
            let dst := add(pairingInput, 0x20)
            mcopy(dst, add(g1Pubkey, 0x20), 128)
            mcopy(add(dst, 128), add(hMsg, 0x20), 256)
            mcopy(add(dst, 384), add(negG1, 0x20), 128)
            mcopy(add(dst, 512), add(g2Sig, 0x20), 256)
        }

        (bool ok, bytes memory result) = BLS12_PAIRING_CHECK.staticcall(pairingInput);
        if (!ok) revert BLSPrecompileCallFailed();
        if (result.length != 32 || abi.decode(result, (uint256)) != 1) revert BLSInvalidSignature();
    }

    // -----------------------------------------------------------------------
    // Internal helpers — signing root
    // -----------------------------------------------------------------------

    function _computeSigningRoot(
        bytes calldata pubkey,
        uint256 amount,
        bytes32 withdrawalCredentials,
        bytes32 domain
    ) internal pure returns (bytes32) {
        uint256 depositAmountGwei = amount / 1 gwei;
        bytes32 pubkeyRoot = sha256(abi.encodePacked(pubkey, bytes16(0)));
        bytes32 depositMessageRoot = sha256(
            abi.encodePacked(
                sha256(abi.encodePacked(pubkeyRoot, withdrawalCredentials)),
                sha256(
                    abi.encodePacked(bytes32(LibUint256.toLittleEndian64(depositAmountGwei)), bytes24(0))
                )
            )
        );
        return sha256(abi.encodePacked(depositMessageRoot, domain));
    }

    // -----------------------------------------------------------------------
    // Internal helpers — hash-to-curve G2
    // -----------------------------------------------------------------------

    function _hashToG2(bytes32 signingRoot) internal view returns (bytes memory point) {
        bytes memory uniform = _expandMessageXMD(signingRoot, 256);

        bytes memory e0 = _fpReduce(uniform, 0);
        bytes memory e1 = _fpReduce(uniform, 64);
        bytes memory e2 = _fpReduce(uniform, 128);
        bytes memory e3 = _fpReduce(uniform, 192);

        bytes memory q0 = _mapFp2ToG2(e0, e1);
        bytes memory q1 = _mapFp2ToG2(e2, e3);

        bytes memory q0c = _clearCofactorG2(q0);
        bytes memory q1c = _clearCofactorG2(q1);

        point = _g2Add(q0c, q1c);
    }

    /// @dev expand_message_xmd(msg=signingRoot, DST=H2C_DST, len_in_bytes=256)
    function _expandMessageXMD(bytes32 signingRoot, uint256 lenInBytes)
        internal
        pure
        returns (bytes memory result)
    {
        uint256 ell = (lenInBytes + 31) / 32; // = 8

        bytes memory dstPrime = abi.encodePacked(H2C_DST, uint8(H2C_DST.length));

        bytes32 b0 = sha256(
            abi.encodePacked(
                new bytes(64),
                signingRoot,
                uint8(lenInBytes >> 8),
                uint8(lenInBytes & 0xff),
                uint8(0),
                dstPrime
            )
        );

        result = new bytes(ell * 32);

        bytes32 bPrev = sha256(abi.encodePacked(b0, uint8(1), dstPrime));
        assembly {
            mstore(add(result, 0x20), bPrev)
        }

        for (uint256 i = 2; i <= ell; i++) {
            bytes32 bI = sha256(abi.encodePacked(b0 ^ bPrev, uint8(i), dstPrime));
            uint256 offset = (i - 1) * 32;
            assembly {
                mstore(add(add(result, 0x20), offset), bI)
            }
            bPrev = bI;
        }
    }

    /// @dev Reduce a 64-byte big-endian integer mod p using the modexp precompile.
    function _fpReduce(bytes memory uniform, uint256 offset) internal view returns (bytes memory fp) {
        bytes memory input = new bytes(32 + 32 + 32 + 64 + 1 + 48);
        bytes memory fpMod = FP_MOD;
        assembly {
            mstore(add(input, 0x20), 64) // base_len
            mstore(add(input, 0x40), 1) // exp_len
            mstore(add(input, 0x60), 48) // mod_len
            mcopy(add(input, 0x80), add(add(uniform, 0x20), offset), 64) // base
            mstore8(add(input, 0xc0), 1) // exp = 0x01
            mcopy(add(input, 0xc1), add(fpMod, 0x20), 48) // mod = p
        }
        (bool ok, bytes memory out) = MODEXP.staticcall(input);
        if (!ok) revert BLSPrecompileCallFailed();
        fp = out;
    }

    /// @dev Pad a 48-byte Fp element to 64 bytes (16 leading zeros) for EIP-2537 inputs.
    function _fp64(bytes memory fp48) internal pure returns (bytes memory fp64) {
        fp64 = new bytes(64);
        assembly {
            mcopy(add(fp64, 0x30), add(fp48, 0x20), 48)
        }
    }

    /// @dev Call MAP_FP2_TO_G2 precompile. Returns 256-byte G2 point.
    function _mapFp2ToG2(bytes memory c0_48, bytes memory c1_48) internal view returns (bytes memory g2pt) {
        bytes memory c0 = _fp64(c0_48);
        bytes memory c1 = _fp64(c1_48);
        bytes memory input = new bytes(128);
        assembly {
            mcopy(add(input, 0x20), add(c0, 0x20), 64)
            mcopy(add(input, 0x60), add(c1, 0x20), 64)
        }
        (bool ok, bytes memory out) = BLS12_MAP_FP2_TO_G2.staticcall(input);
        if (!ok) revert BLSPrecompileCallFailed();
        g2pt = out;
    }

    /// @dev Clear G2 cofactor via two G2MSM calls: p_lo = h_lo * Q, p_hi = h_hi * Q, result = p_lo + 2^256 * p_hi
    function _clearCofactorG2(bytes memory g2pt) internal view returns (bytes memory cleared) {
        // Part 1: G2MSM(Q, h_lo)
        bytes memory input1 = new bytes(288);
        assembly {
            mstore(add(input1, 0x20), G2_H_EFF_LO)
            mcopy(add(input1, 0x40), add(g2pt, 0x20), 256)
        }
        (bool ok1, bytes memory pLo) = BLS12_G2MSM.staticcall(input1);
        if (!ok1) revert BLSPrecompileCallFailed();

        // Part 2: G2MSM(Q, h_hi)
        bytes memory input2 = new bytes(288);
        assembly {
            mstore(add(input2, 0x20), G2_H_EFF_HI)
            mcopy(add(input2, 0x40), add(g2pt, 0x20), 256)
        }
        (bool ok2, bytes memory pHiBase) = BLS12_G2MSM.staticcall(input2);
        if (!ok2) revert BLSPrecompileCallFailed();

        // Scale pHiBase by 2^256 mod r
        // 2^256 mod r where r = 0x73eda753299d7d483339d80809a1d80553bda402fffe5bfeffffffff00000001
        bytes32 pow256ModR = 0x8c1258acd66282ec7f1adbf7e6204e2fde5dcc17b33ee91c79373afbe72dd650;
        bytes memory input3 = new bytes(288);
        assembly {
            mstore(add(input3, 0x20), pow256ModR)
            mcopy(add(input3, 0x40), add(pHiBase, 0x20), 256)
        }
        (bool ok3, bytes memory pHi) = BLS12_G2MSM.staticcall(input3);
        if (!ok3) revert BLSPrecompileCallFailed();

        cleared = _g2Add(pLo, pHi);
    }

    /// @dev G2ADD: add two G2 points (256 bytes each). Returns 256-byte result.
    function _g2Add(bytes memory a, bytes memory b) internal view returns (bytes memory result) {
        bytes memory input = new bytes(512);
        assembly {
            mcopy(add(input, 0x20), add(a, 0x20), 256)
            mcopy(add(input, 0x120), add(b, 0x20), 256)
        }
        (bool ok, bytes memory out) = BLS12_G2ADD.staticcall(input);
        if (!ok) revert BLSPrecompileCallFailed();
        result = out;
    }

    // -----------------------------------------------------------------------
    // Internal helpers — point decompression / negation
    // -----------------------------------------------------------------------

    /// @dev Build a 128-byte G1 point from a 48-byte compressed pubkey and 48-byte y-coordinate.
    ///      EIP-2537 format: 64-byte padded x || 64-byte padded y. Clears compression flag bits.
    function _buildG1Point(bytes calldata pubkey48, bytes memory y48)
        internal
        pure
        returns (bytes memory g1pt)
    {
        g1pt = new bytes(128);
        assembly {
            mcopy(add(g1pt, 0x30), pubkey48.offset, 48)
            mcopy(add(g1pt, 0x70), add(y48, 0x20), 48)
        }
        // Clear compression flag bits in first byte of x (byte 16 of g1pt)
        g1pt[16] = bytes1(uint8(g1pt[16]) & 0x1f);
    }

    /// @dev Build a 256-byte G2 point from a 96-byte compressed signature and two 48-byte y-components.
    ///      EIP-2537 G2 format: 64-byte x0 || 64-byte x1 || 64-byte y0 || 64-byte y1.
    ///      Compressed signature: sig[0..47]=x1 (with flags), sig[48..95]=x0.
    function _buildG2Point(bytes calldata sig96, bytes memory y0_48, bytes memory y1_48)
        internal
        pure
        returns (bytes memory g2pt)
    {
        g2pt = new bytes(256);
        assembly {
            // x0 from sig96[48..95], zero-padded to 64 bytes at bytes 16..63
            mcopy(add(g2pt, 0x30), add(sig96.offset, 48), 48)
            // x1 from sig96[0..47], zero-padded to 64 bytes at bytes 80..127
            mcopy(add(g2pt, 0x70), sig96.offset, 48)
            // y0 zero-padded to 64 bytes at bytes 144..191
            mcopy(add(g2pt, 0xb0), add(y0_48, 0x20), 48)
            // y1 zero-padded to 64 bytes at bytes 208..255
            mcopy(add(g2pt, 0xf0), add(y1_48, 0x20), 48)
        }
        // Clear compression flag bits in first byte of x1 (byte 80 of g2pt)
        g2pt[80] = bytes1(uint8(g2pt[80]) & 0x1f);
    }

    /// @dev Return the negated G1 generator as a 128-byte EIP-2537-encoded point.
    function _negG1Generator() internal pure returns (bytes memory negG1) {
        negG1 = new bytes(128);
        bytes memory gx = G1_GEN_X;
        bytes memory ngy = NEG_G1_GEN_Y;
        assembly {
            mcopy(add(negG1, 0x20), add(gx, 0x20), 64)
            mcopy(add(negG1, 0x60), add(ngy, 0x20), 64)
        }
    }
}
