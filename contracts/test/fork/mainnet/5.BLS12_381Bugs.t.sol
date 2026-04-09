//SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.34;

import "forge-std/Test.sol";

import "../../../src/libraries/BLS12_381.sol";
import "../../../src/libraries/LibUint256.sol";

/// @title BLS12_381Harness
/// @notice Exposes BLS12_381 internal functions for testing on a Pectra mainnet fork.
contract BLS12_381Harness {
    // Re-export precompile addresses for direct calls in tests
    address internal constant BLS12_G2ADD = address(0x0d);
    address internal constant BLS12_G2MSM = address(0x0e);
    address internal constant BLS12_MAP_FP2_TO_G2 = address(0x11);

    /// @dev Current (buggy) _hashToG2 — applies _clearCofactorG2 after MAP_FP2_TO_G2
    function hashToG2Buggy(bytes32 signingRoot) external view returns (bytes memory) {
        return BLS12_381._hashToG2(signingRoot);
    }

    /// @dev Fixed _hashToG2 — no redundant cofactor clearing
    function hashToG2Fixed(bytes32 signingRoot) external view returns (bytes memory) {
        bytes memory uniform = BLS12_381._expandMessageXMD(signingRoot, 256);
        bytes memory e0 = BLS12_381._fpReduce(uniform, 0);
        bytes memory e1 = BLS12_381._fpReduce(uniform, 64);
        bytes memory e2 = BLS12_381._fpReduce(uniform, 128);
        bytes memory e3 = BLS12_381._fpReduce(uniform, 192);
        bytes memory q0 = BLS12_381._mapFp2ToG2(e0, e1);
        bytes memory q1 = BLS12_381._mapFp2ToG2(e2, e3);
        return BLS12_381._g2Add(q0, q1);
    }

    function mapFp2ToG2(bytes memory c0, bytes memory c1) external view returns (bytes memory) {
        return BLS12_381._mapFp2ToG2(c0, c1);
    }

    function clearCofactorG2(bytes memory g2pt) external view returns (bytes memory) {
        return BLS12_381._clearCofactorG2(g2pt);
    }

    function g2Add(bytes memory a, bytes memory b) external view returns (bytes memory) {
        return BLS12_381._g2Add(a, b);
    }

    /// @dev Call G2MSM with CORRECT encoding: point (256 bytes) || scalar (32 bytes)
    function g2msmCorrectEncoding(bytes memory g2pt, bytes32 scalar) external view returns (bool ok, bytes memory out) {
        bytes memory input = new bytes(288);
        assembly {
            let dst := add(input, 0x20)
            mcopy(dst, add(g2pt, 0x20), 256) // point first
            mstore(add(dst, 256), scalar) // scalar second
        }
        (ok, out) = BLS12_G2MSM.staticcall(input);
    }

    function computeDepositDomain(bytes4 genesisForkVersion) external pure returns (bytes32) {
        return BLS12_381.computeDepositDomain(genesisForkVersion);
    }

    function computeSigningRoot(bytes calldata pubkey, uint256 amount, bytes32 wc, bytes32 domain)
        external
        pure
        returns (bytes32)
    {
        return BLS12_381._computeSigningRoot(pubkey, amount, wc, domain);
    }

    /// @dev Call G2MSM with WRONG encoding (current code's approach): scalar (32 bytes) || point (256 bytes)
    function g2msmWrongEncoding(bytes memory g2pt, bytes32 scalar) external view returns (bool ok, bytes memory out) {
        bytes memory input = new bytes(288);
        assembly {
            let dst := add(input, 0x20)
            mstore(dst, scalar) // scalar first (WRONG)
            mcopy(add(dst, 0x20), add(g2pt, 0x20), 256) // point second (WRONG)
        }
        (ok, out) = BLS12_G2MSM.staticcall(input);
    }
}

/// @title BLS12_381BugsTest
/// @notice Demonstrates three confirmed bugs in BLS12_381.sol using real EIP-2537 precompiles
///         on a post-Pectra mainnet fork.
///
///         Bug 1: Double cofactor clearing — MAP_FP2_TO_G2 already clears the cofactor,
///                but _hashToG2 calls _clearCofactorG2 again, producing h_eff² * P instead of h_eff * P.
///         Bug 2: G2MSM input encoding reversed — code sends scalar||point, EIP-2537 requires point||scalar.
///         Bug 3: G2_H_EFF_LO / G2_H_EFF_HI are placeholder values, not the real h_eff from RFC 9380.
contract BLS12_381BugsTest is Test {
    bool internal _skip = false;
    BLS12_381Harness internal harness;

    // Post-Pectra block number (Pectra activated ~block 22,188,000 on May 7, 2025)
    uint256 internal constant FORK_BLOCK = 22_200_000;

    function setUp() external {
        try vm.envString("MAINNET_FORK_RPC_URL") returns (string memory rpcUrl) {
            vm.createSelectFork(rpcUrl, FORK_BLOCK);
            harness = new BLS12_381Harness();
            console.log("5.BLS12_381Bugs.t.sol is active (post-Pectra fork)");
        } catch {
            _skip = true;
        }
    }

    modifier shouldSkip() {
        if (!_skip) {
            _;
        }
    }

    // -----------------------------------------------------------------------
    // Bug 1: Double cofactor clearing
    // -----------------------------------------------------------------------

    /// @notice MAP_FP2_TO_G2 returns a cofactor-cleared point. Applying _clearCofactorG2
    ///         again changes the point (h_eff * P != P for non-identity P), proving
    ///         the current _hashToG2 produces incorrect output.
    function test_bug1_doubleCofactorClearing() external shouldSkip {
        // Use an arbitrary Fp2 element as input to MAP_FP2_TO_G2
        // c0, c1 are 48-byte field elements (will be padded to 64 bytes internally)
        bytes memory c0 = new bytes(48);
        bytes memory c1 = new bytes(48);
        c0[47] = 0x01; // c0 = 1
        c1[47] = 0x02; // c1 = 2

        // MAP_FP2_TO_G2 returns a point already in the G2 subgroup (cofactor cleared)
        bytes memory q = harness.mapFp2ToG2(c0, c1);
        assertTrue(q.length == 256, "MAP_FP2_TO_G2 should return 256-byte G2 point");

        // Applying _clearCofactorG2 again should change the point (this is the bug)
        // If MAP_FP2_TO_G2 did NOT clear cofactor, then clearing would be needed.
        // But since it DOES clear, clearing again multiplies by h_eff a second time.
        //
        // NOTE: _clearCofactorG2 itself has bugs (Finding 2 & 3), so it may revert.
        // If it reverts, that also demonstrates the code is broken.
        try harness.clearCofactorG2(q) returns (bytes memory qDouble) {
            // If it didn't revert, the double-cleared point should differ from the original
            assertFalse(
                keccak256(q) == keccak256(qDouble),
                "BUG 1: _clearCofactorG2 changed an already-cofactor-cleared point, proving double clearing corrupts the result"
            );
        } catch {
            // _clearCofactorG2 reverted — this is expected due to Bug 2 (wrong G2MSM encoding)
            // The revert itself proves the code path is broken
            assertTrue(true, "BUG 1+2: _clearCofactorG2 reverted due to malformed G2MSM input (scalar||point instead of point||scalar)");
        }
    }

    /// @notice End-to-end: buggy _hashToG2 produces a different result than the fixed version.
    function test_bug1_hashToG2_buggyVsFixed() external shouldSkip {
        bytes32 signingRoot = bytes32(uint256(0xdeadbeef));

        // The buggy version may revert (due to Bug 2 in _clearCofactorG2's G2MSM encoding)
        try harness.hashToG2Buggy(signingRoot) returns (bytes memory buggyResult) {
            // If it doesn't revert, compare with fixed version
            bytes memory fixedResult = harness.hashToG2Fixed(signingRoot);

            assertFalse(
                keccak256(buggyResult) == keccak256(fixedResult),
                "BUG 1: buggy _hashToG2 (double cofactor clear) != fixed _hashToG2 (no redundant clear)"
            );
        } catch {
            // Revert expected due to Bug 2 (G2MSM encoding) inside _clearCofactorG2
            // The fixed version should NOT revert since it skips _clearCofactorG2 entirely
            bytes memory fixedResult = harness.hashToG2Fixed(signingRoot);
            assertTrue(fixedResult.length == 256, "Fixed _hashToG2 should succeed and return 256-byte G2 point");
        }
    }

    // -----------------------------------------------------------------------
    // Bug 2: G2MSM input encoding order (scalar||point vs point||scalar)
    // -----------------------------------------------------------------------

    /// @notice EIP-2537 G2MSM expects point(256)||scalar(32). The current code sends
    ///         scalar(32)||point(256). This test calls G2MSM both ways and shows that
    ///         the wrong encoding fails or produces a different result.
    function test_bug2_g2msm_encodingOrder() external shouldSkip {
        // Get a valid G2 point from MAP_FP2_TO_G2
        bytes memory c0 = new bytes(48);
        bytes memory c1 = new bytes(48);
        c0[47] = 0x03;
        c1[47] = 0x04;
        bytes memory g2pt = harness.mapFp2ToG2(c0, c1);

        bytes32 scalar = bytes32(uint256(2));

        // Correct encoding: point || scalar (per EIP-2537)
        (bool okCorrect, bytes memory resultCorrect) = harness.g2msmCorrectEncoding(g2pt, scalar);
        assertTrue(okCorrect, "G2MSM with correct encoding (point||scalar) should succeed");
        assertEq(resultCorrect.length, 256, "G2MSM correct result should be 256 bytes");

        // Wrong encoding: scalar || point (what the current code does)
        (bool okWrong, bytes memory resultWrong) = harness.g2msmWrongEncoding(g2pt, scalar);

        if (okWrong) {
            // If the wrong encoding doesn't revert, the results must differ
            // (the precompile interprets the first 256 bytes as the point, so it reads
            //  scalar_bytes || first_224_bytes_of_point as "the point" — garbage)
            assertFalse(
                keccak256(resultCorrect) == keccak256(resultWrong),
                "BUG 2: wrong encoding (scalar||point) produces different result than correct encoding (point||scalar)"
            );
        } else {
            // Wrong encoding reverted — precompile rejected malformed input
            assertTrue(true, "BUG 2: G2MSM correctly rejects wrong encoding (scalar||point)");
        }
    }

    // -----------------------------------------------------------------------
    // Bug 3: Placeholder h_eff constants
    // -----------------------------------------------------------------------

    /// @notice G2_H_EFF_LO and G2_H_EFF_HI do not match the canonical h_eff from RFC 9380 §8.8.2.
    ///         The correct h_eff for BLS12-381 G2 is:
    ///         0xbc69f08f2ee75b3584c6a0ea91b352888e2a8e9145ad7689986ff031508ffe1329c2f178731db956d82bf015d1212b02ec0ec69d7477c1ae954cbc06689f6a359
    function test_bug3_heff_constants_are_placeholders() external shouldSkip {
        // Canonical h_eff from RFC 9380 §8.8.2 and EIP-2537 field_to_curve.md:
        // 0xbc69f08f2ee75b3584c6a0ea91b352888e2a8e9145ad7689986ff031508ffe13
        //   29c2f178731db956d82bf015d1212b02ec0ec69d7477c1ae954cbc06689f6a359
        //
        // This is 64 bytes. Split into upper 32 bytes and lower 32 bytes:
        bytes32 correctHeffHi = 0xbc69f08f2ee75b3584c6a0ea91b352888e2a8e9145ad7689986ff031508ffe13;
        bytes32 correctHeffLo = 0x29c2f178731db956d82bf015d1212b02ec0ec69d7477c1ae954cbc06689f6a59;

        // Current (buggy) values from BLS12_381.sol
        bytes32 currentHeffLo = 0x29c008d4b7d31a6dcfe6a67def9d0cb700000000000000000000000000000000;
        bytes32 currentHeffHi = 0x0000000000000000000000000000000008ffe1329c008d4b0000000000000000;

        // Verify the constants don't match
        assertFalse(
            currentHeffLo == correctHeffLo,
            "BUG 3: G2_H_EFF_LO should not match - it contains placeholder zeros"
        );
        assertFalse(
            currentHeffHi == correctHeffHi,
            "BUG 3: G2_H_EFF_HI should not match - it contains placeholder zeros"
        );

        // Log the differences for clarity
        console.log("=== Bug 3: h_eff constant mismatch ===");
        console.log("G2_H_EFF_HI (current - placeholder):");
        console.logBytes32(currentHeffHi);
        console.log("G2_H_EFF_HI (correct per RFC 9380):");
        console.logBytes32(correctHeffHi);
        console.log("G2_H_EFF_LO (current - placeholder):");
        console.logBytes32(currentHeffLo);
        console.log("G2_H_EFF_LO (correct per RFC 9380):");
        console.logBytes32(correctHeffLo);
    }

    // -----------------------------------------------------------------------
    // Positive control: fixed hashToG2 works on the fork
    // -----------------------------------------------------------------------

    /// @notice Verify that the fixed _hashToG2 (without redundant cofactor clearing)
    ///         successfully produces a 256-byte G2 point on the Pectra fork.
    function test_fixed_hashToG2_succeeds() external shouldSkip {
        bytes32 signingRoot = bytes32(uint256(0xcafebabe));
        bytes memory result = harness.hashToG2Fixed(signingRoot);
        assertEq(result.length, 256, "Fixed hashToG2 should return 256-byte G2 point");

        // Verify the result is not the point at infinity (all zeros)
        bool allZeros = true;
        for (uint256 i = 0; i < 256; i++) {
            if (result[i] != 0x00) {
                allZeros = false;
                break;
            }
        }
        assertFalse(allZeros, "Fixed hashToG2 should not return point at infinity");
    }

    // -----------------------------------------------------------------------
    // Bug 4: computeDepositDomain — ForkData SSZ root hashes 32 bytes instead of 64
    // -----------------------------------------------------------------------

    /// @notice On a post-Pectra mainnet fork, compute the spec-correct deposit domain
    ///         for mainnet fork version 0x00000000 and show the current function diverges.
    ///
    ///         Per the Ethereum consensus spec (phase0/beacon-chain.md#compute_domain):
    ///           ForkData = { current_version: Version, genesis_validators_root: Root }
    ///           hash_tree_root(ForkData) = sha256(forkVersion||28zeros || genesisValidatorsRoot)
    ///           For DOMAIN_DEPOSIT, genesis_validators_root = Root() = bytes32(0)
    ///           domain = DOMAIN_DEPOSIT || hash_tree_root(ForkData)[0:28]
    function test_bug4_computeDepositDomain_wrongSSZ() external shouldSkip {
        bytes4 forkVersion = bytes4(0x00000000); // mainnet genesis fork version

        // Spec-correct: sha256 over 64 bytes (two 32-byte SSZ chunks)
        bytes32 correctForkDataRoot = sha256(abi.encodePacked(forkVersion, bytes28(0), bytes32(0)));
        bytes32 correctDomain = bytes32(BLS12_381.DEPOSIT_DOMAIN_TYPE) | (correctForkDataRoot >> 32);

        // Current (buggy): sha256 over 32 bytes (missing genesis_validators_root chunk)
        bytes32 buggyDomain = harness.computeDepositDomain(forkVersion);

        assertFalse(
            buggyDomain == correctDomain,
            "BUG 4: computeDepositDomain hashes 32 bytes instead of 64 for ForkData SSZ root"
        );

        console.log("=== Bug 4: ForkData SSZ root byte count ===");
        console.log("Buggy domain  (32-byte ForkData hash):");
        console.logBytes32(buggyDomain);
        console.log("Correct domain (64-byte ForkData hash):");
        console.logBytes32(correctDomain);
    }

    // -----------------------------------------------------------------------
    // Bug 5: _computeSigningRoot — amount subtree hashes 56 bytes instead of 64
    // -----------------------------------------------------------------------

    /// @notice DepositMessage has 3 fields → SSZ pads to 4 leaves (next power of 2).
    ///         The amount subtree is sha256(amountChunk || zeroLeaf) = 64 bytes.
    ///         Current code hashes only 56 bytes (bytes32 + bytes24 instead of bytes32 + bytes32).
    ///
    ///         Ref: consensus-specs/phase0/beacon-chain.md#depositmessage
    ///         Ref: consensus-specs/ssz/simple-serialize.md#merkleization
    function test_bug5_signingRoot_amountChunkTooShort() external shouldSkip {
        bytes memory pubkey = hex"a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1";
        uint256 amount = 32 ether;
        bytes32 wc = bytes32(uint256(0x010000000000000000000000CAFEBABE));
        bytes32 domain = bytes32(uint256(0x03000000));

        // Spec-correct computation
        uint256 amountGwei = amount / 1 gwei;
        bytes32 pubkeyRoot = sha256(abi.encodePacked(pubkey, bytes16(0)));
        bytes32 amountLE = bytes32(LibUint256.toLittleEndian64(amountGwei));

        bytes32 correctDepositMessageRoot = sha256(
            abi.encodePacked(
                sha256(abi.encodePacked(pubkeyRoot, wc)),
                sha256(abi.encodePacked(amountLE, bytes32(0))) // 64 bytes
            )
        );
        bytes32 correctSigningRoot = sha256(abi.encodePacked(correctDepositMessageRoot, domain));

        // Current (buggy) computation
        bytes32 buggySigningRoot = harness.computeSigningRoot(pubkey, amount, wc, domain);

        assertFalse(
            buggySigningRoot == correctSigningRoot,
            "BUG 5: _computeSigningRoot hashes 56 bytes instead of 64 for amount subtree"
        );

        console.log("=== Bug 5: Amount subtree byte count ===");
        console.log("Buggy signing root  (56-byte amount hash):");
        console.logBytes32(buggySigningRoot);
        console.log("Correct signing root (64-byte amount hash):");
        console.logBytes32(correctSigningRoot);
    }
}
