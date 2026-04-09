//SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.34;

import "forge-std/Test.sol";

import "../../../src/libraries/BLS12_381.sol";

/// @title BLS12_381McopyHarness
/// @notice Exposes _buildG1Point and _buildG2Point for testing the mcopy-vs-calldatacopy bug.
///         Also provides a fixed version using calldatacopy for comparison.
contract BLS12_381McopyHarness {
    /// @dev Expose the buggy _buildG1Point (uses mcopy for calldata source)
    function buildG1Point(bytes calldata pubkey48, bytes memory y48) external pure returns (bytes memory) {
        return BLS12_381._buildG1Point(pubkey48, y48);
    }

    /// @dev Expose the buggy _buildG2Point (uses mcopy for calldata source)
    function buildG2Point(bytes calldata sig96, bytes memory y0_48, bytes memory y1_48)
        external
        pure
        returns (bytes memory)
    {
        return BLS12_381._buildG2Point(sig96, y0_48, y1_48);
    }

    /// @dev Fixed _buildG1Point using calldatacopy instead of mcopy for the calldata parameter.
    ///      This reads the pubkey bytes from calldata correctly.
    function buildG1PointFixed(bytes calldata pubkey48, bytes memory y48) external pure returns (bytes memory g1pt) {
        g1pt = new bytes(128);
        assembly {
            // FIXED: use calldatacopy to read from calldata
            calldatacopy(add(g1pt, 0x30), pubkey48.offset, 48)
            // y48 is memory — mcopy is correct here
            mcopy(add(g1pt, 0x70), add(y48, 0x20), 48)
        }
        // Validate compression flags before clearing
        uint8 flags = uint8(g1pt[16]) & 0xe0;
        if (flags != 0x80 && flags != 0xa0) revert("InvalidBLSCompressionFlags");
        g1pt[16] = bytes1(uint8(g1pt[16]) & 0x1f);
    }

    /// @dev Fixed _buildG2Point using calldatacopy instead of mcopy for the calldata parameter.
    function buildG2PointFixed(bytes calldata sig96, bytes memory y0_48, bytes memory y1_48)
        external
        pure
        returns (bytes memory g2pt)
    {
        g2pt = new bytes(256);
        assembly {
            // FIXED: use calldatacopy for sig96 (calldata) copies
            calldatacopy(add(g2pt, 0x30), add(sig96.offset, 48), 48)
            calldatacopy(add(g2pt, 0x70), sig96.offset, 48)
            // y0_48 and y1_48 are memory — mcopy is correct
            mcopy(add(g2pt, 0xb0), add(y0_48, 0x20), 48)
            mcopy(add(g2pt, 0xf0), add(y1_48, 0x20), 48)
        }
        // Validate compression flags on x1 before clearing
        uint8 flags = uint8(g2pt[80]) & 0xe0;
        if (flags != 0x80 && flags != 0xa0) revert("InvalidBLSCompressionFlags");
        g2pt[80] = bytes1(uint8(g2pt[80]) & 0x1f);
    }
}

/// @title BLS12_381McopyBugTest
/// @notice Demonstrates that _buildG1Point and _buildG2Point use mcopy (memory-to-memory)
///         to copy from calldata parameters, reading garbage from memory instead of the actual
///         pubkey/signature bytes. Also demonstrates missing compression flag validation.
///
///         Root cause: mcopy (EIP-5656) operates on memory offsets only.
///         pubkey48.offset / sig96.offset return calldata offsets, but mcopy interprets
///         them as memory addresses. The correct opcode is calldatacopy.
///
///         References:
///         - EIP-5656 (mcopy): memory[dst:dst+len] := memory[src:src+len]
///         - EVM CALLDATACOPY (0x37): memory[dst:dst+len] := calldata[src:src+len]
///         - Solidity docs: .offset on calldata vars returns the calldata byte offset
contract BLS12_381McopyBugTest is Test {
    bool internal _skip = false;
    BLS12_381McopyHarness internal harness;

    // Post-Pectra block (Pectra activated ~block 22,188,000 on May 7, 2025)
    uint256 internal constant FORK_BLOCK = 22_200_000;

    // Known BLS12-381 G1 generator x-coordinate (48 bytes, compressed with flag)
    // Raw x = 0x17f1d3a73197d7942695638c4fa9ac0fc3688c4f9774b905a14e3a3f171bac586c55e83ff97a1aeffb3af00adb22c6bb
    // With compression flag (0x80 OR'd onto MSB): 0x97...
    bytes internal constant KNOWN_PUBKEY_48 =
        hex"97f1d3a73197d7942695638c4fa9ac0fc3688c4f9774b905a14e3a3f171bac586c55e83ff97a1aeffb3af00adb22c6bb";

    // Known y-coordinate for the G1 generator (48 bytes)
    bytes internal constant KNOWN_Y_48 =
        hex"08b3f481e3aaa0f1a09e30ed741d8ae4fcf5e095d5d00af600db18cb2c04b3edd03cc744a2888ae40caa232946c5e7e1";

    // A known 96-byte signature (arbitrary but deterministic for testing)
    // First 48 bytes = x1 (with compression flag 0x80), next 48 bytes = x0
    bytes internal constant KNOWN_SIG_96 =
        hex"a666d31d7e6561f6de3a290798e0361b8e068734ab4daca76e1a5973b38789f26b4e4b940cca0b04e1ca390a53d42010"
        hex"b506b8ce2e6eb2ad7960f0a55bd72c0df7f22fb12e05ebd2c5ebf2d1c547f8e4cfb13db7e30a50a3e5e74913bdc1e0ba";

    // y0 and y1 for the G2 point (48 bytes each, arbitrary deterministic values)
    bytes internal constant KNOWN_SIG_Y0 =
        hex"0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000aa";
    bytes internal constant KNOWN_SIG_Y1 =
        hex"0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000bb";

    function setUp() external {
        try vm.envString("MAINNET_FORK_RPC_URL") returns (string memory rpcUrl) {
            vm.createSelectFork(rpcUrl, FORK_BLOCK);
            harness = new BLS12_381McopyHarness();
            console.log("6.BLS12_381McopyBug.t.sol is active (post-Pectra fork)");
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
    // Bug 4: mcopy reads from memory instead of calldata in _buildG1Point
    // -----------------------------------------------------------------------

    /// @notice _buildG1Point uses mcopy with pubkey48.offset as source.
    ///         Since mcopy is memory-to-memory, it reads from memory[pubkey48.offset]
    ///         instead of calldata[pubkey48.offset]. The output x-coordinate will NOT
    ///         match the input pubkey.
    function test_bug4_buildG1Point_mcopy_reads_memory_not_calldata() external shouldSkip {
        bytes memory y48 = new bytes(48);
        y48[47] = 0x01; // arbitrary y-coord

        // Call the buggy version
        bytes memory g1pt = harness.buildG1Point(KNOWN_PUBKEY_48, y48);
        assertEq(g1pt.length, 128, "G1 point should be 128 bytes");

        // Extract the x-coordinate from g1pt[16..63] (48 bytes, with flag bits already cleared)
        bytes memory xFromOutput = new bytes(48);
        for (uint256 i = 0; i < 48; i++) {
            xFromOutput[i] = g1pt[16 + i];
        }

        // Build what the correct x-coordinate should be:
        // KNOWN_PUBKEY_48 with flag bits cleared on first byte (& 0x1f)
        bytes memory expectedX = new bytes(48);
        for (uint256 i = 0; i < 48; i++) {
            expectedX[i] = KNOWN_PUBKEY_48[i];
        }
        expectedX[0] = bytes1(uint8(expectedX[0]) & 0x1f); // clear flags

        // THE BUG: mcopy read from memory, not calldata, so x won't match
        bool xMatches = keccak256(xFromOutput) == keccak256(expectedX);

        console.log("=== Bug 4: _buildG1Point mcopy-vs-calldatacopy ===");
        console.log("Expected x-coordinate (first 4 bytes):");
        console.logBytes4(bytes4(expectedX[0]) | (bytes4(expectedX[1]) >> 8) | (bytes4(expectedX[2]) >> 16) | (bytes4(expectedX[3]) >> 24));
        console.log("Actual x-coordinate from buggy _buildG1Point (first 4 bytes):");
        console.logBytes4(bytes4(xFromOutput[0]) | (bytes4(xFromOutput[1]) >> 8) | (bytes4(xFromOutput[2]) >> 16) | (bytes4(xFromOutput[3]) >> 24));

        assertFalse(
            xMatches,
            "BUG 4: _buildG1Point x-coordinate should NOT match input pubkey because mcopy reads from memory, not calldata"
        );
    }

    // -----------------------------------------------------------------------
    // Bug 4b: mcopy reads from memory instead of calldata in _buildG2Point
    // -----------------------------------------------------------------------

    /// @notice _buildG2Point uses mcopy with sig96.offset as source for both x0 and x1.
    ///         Same root cause as Bug 4: mcopy reads from memory, not calldata.
    function test_bug4b_buildG2Point_mcopy_reads_memory_not_calldata() external shouldSkip {
        bytes memory y0 = new bytes(48);
        bytes memory y1 = new bytes(48);
        y0[47] = 0x01;
        y1[47] = 0x02;

        // Call the buggy version
        bytes memory g2pt = harness.buildG2Point(KNOWN_SIG_96, y0, y1);
        assertEq(g2pt.length, 256, "G2 point should be 256 bytes");

        // Extract x0 from g2pt[16..63] — should be sig96[48..95]
        bytes memory x0FromOutput = new bytes(48);
        for (uint256 i = 0; i < 48; i++) {
            x0FromOutput[i] = g2pt[16 + i];
        }

        // Expected x0 = sig96[48..95]
        bytes memory expectedX0 = new bytes(48);
        for (uint256 i = 0; i < 48; i++) {
            expectedX0[i] = KNOWN_SIG_96[48 + i];
        }

        // Extract x1 from g2pt[80..127] — should be sig96[0..47] with flags cleared
        bytes memory x1FromOutput = new bytes(48);
        for (uint256 i = 0; i < 48; i++) {
            x1FromOutput[i] = g2pt[80 + i];
        }

        // Expected x1 = sig96[0..47] with flags cleared
        bytes memory expectedX1 = new bytes(48);
        for (uint256 i = 0; i < 48; i++) {
            expectedX1[i] = KNOWN_SIG_96[i];
        }
        expectedX1[0] = bytes1(uint8(expectedX1[0]) & 0x1f); // clear flags

        bool x0Matches = keccak256(x0FromOutput) == keccak256(expectedX0);
        bool x1Matches = keccak256(x1FromOutput) == keccak256(expectedX1);

        console.log("=== Bug 4b: _buildG2Point mcopy-vs-calldatacopy ===");
        console.log("x0 matches expected from calldata:", x0Matches);
        console.log("x1 matches expected from calldata:", x1Matches);

        // At least one (likely both) will NOT match because mcopy reads memory, not calldata
        assertFalse(
            x0Matches && x1Matches,
            "BUG 4b: _buildG2Point x0/x1 should NOT match input sig because mcopy reads from memory, not calldata"
        );
    }

    // -----------------------------------------------------------------------
    // Positive control: fixed version using calldatacopy produces correct output
    // -----------------------------------------------------------------------

    /// @notice The fixed _buildG1Point uses calldatacopy and correctly reads the pubkey
    ///         from calldata. The output x-coordinate matches the input pubkey (with flags cleared).
    function test_fixed_buildG1Point_calldatacopy_reads_correctly() external shouldSkip {
        bytes memory y48 = new bytes(48);
        y48[47] = 0x01;

        // Call the fixed version
        bytes memory g1pt = harness.buildG1PointFixed(KNOWN_PUBKEY_48, y48);
        assertEq(g1pt.length, 128, "G1 point should be 128 bytes");

        // Extract x-coordinate from g1pt[16..63]
        bytes memory xFromOutput = new bytes(48);
        for (uint256 i = 0; i < 48; i++) {
            xFromOutput[i] = g1pt[16 + i];
        }

        // Expected: KNOWN_PUBKEY_48 with flags cleared
        bytes memory expectedX = new bytes(48);
        for (uint256 i = 0; i < 48; i++) {
            expectedX[i] = KNOWN_PUBKEY_48[i];
        }
        expectedX[0] = bytes1(uint8(expectedX[0]) & 0x1f);

        assertEq(
            keccak256(xFromOutput),
            keccak256(expectedX),
            "FIXED: calldatacopy correctly reads pubkey from calldata - x-coordinate matches"
        );
    }

    /// @notice The fixed _buildG2Point uses calldatacopy and correctly reads the signature.
    function test_fixed_buildG2Point_calldatacopy_reads_correctly() external shouldSkip {
        bytes memory y0 = new bytes(48);
        bytes memory y1 = new bytes(48);
        y0[47] = 0x01;
        y1[47] = 0x02;

        bytes memory g2pt = harness.buildG2PointFixed(KNOWN_SIG_96, y0, y1);
        assertEq(g2pt.length, 256, "G2 point should be 256 bytes");

        // x0 from g2pt[16..63] should be sig96[48..95]
        bytes memory x0FromOutput = new bytes(48);
        for (uint256 i = 0; i < 48; i++) {
            x0FromOutput[i] = g2pt[16 + i];
        }
        bytes memory expectedX0 = new bytes(48);
        for (uint256 i = 0; i < 48; i++) {
            expectedX0[i] = KNOWN_SIG_96[48 + i];
        }

        // x1 from g2pt[80..127] should be sig96[0..47] with flags cleared
        bytes memory x1FromOutput = new bytes(48);
        for (uint256 i = 0; i < 48; i++) {
            x1FromOutput[i] = g2pt[80 + i];
        }
        bytes memory expectedX1 = new bytes(48);
        for (uint256 i = 0; i < 48; i++) {
            expectedX1[i] = KNOWN_SIG_96[i];
        }
        expectedX1[0] = bytes1(uint8(expectedX1[0]) & 0x1f);

        assertEq(keccak256(x0FromOutput), keccak256(expectedX0), "FIXED: x0 matches sig96[48..95]");
        assertEq(keccak256(x1FromOutput), keccak256(expectedX1), "FIXED: x1 matches sig96[0..47] with flags cleared");
    }

    // -----------------------------------------------------------------------
    // Bug 5: Missing compression flag validation
    // -----------------------------------------------------------------------

    /// @notice _buildG1Point silently accepts pubkeys with invalid flag bits.
    ///         An uncompressed point (flags = 0x00) or infinity point (flags = 0xC0)
    ///         should be rejected, but the code just masks & 0x1f without checking.
    ///
    ///         NOTE: This test uses the FIXED (calldatacopy) harness so we test flag
    ///         validation in isolation, not conflated with the mcopy bug.
    function test_bug5_buildG1Point_no_flag_validation() external shouldSkip {
        bytes memory y48 = new bytes(48);
        y48[47] = 0x01;

        // Create a pubkey with NO compression flag (MSB = 0x17 — top 3 bits are 000)
        // This represents an uncompressed serialization and should be rejected
        bytes memory uncompressedPubkey = new bytes(48);
        for (uint256 i = 0; i < 48; i++) {
            uncompressedPubkey[i] = KNOWN_PUBKEY_48[i];
        }
        uncompressedPubkey[0] = bytes1(uint8(KNOWN_PUBKEY_48[0]) & 0x1f); // clear all flags = 0x17

        // The BUGGY version should NOT revert (it doesn't validate flags)
        // We can't easily call the buggy version with calldatacopy fix isolated,
        // so we demonstrate that the fixed version correctly reverts
        vm.expectRevert("InvalidBLSCompressionFlags");
        harness.buildG1PointFixed(uncompressedPubkey, y48);
    }

    /// @notice An infinity point (flags = 0xC0) should also be rejected.
    function test_bug5_buildG1Point_rejects_infinity_flag() external shouldSkip {
        bytes memory y48 = new bytes(48);
        y48[47] = 0x01;

        // Create a pubkey with infinity flag set (0xC0 in top bits)
        bytes memory infinityPubkey = new bytes(48);
        infinityPubkey[0] = 0xC0; // infinity flag set, rest zeros

        vm.expectRevert("InvalidBLSCompressionFlags");
        harness.buildG1PointFixed(infinityPubkey, y48);
    }

    /// @notice The fixed version accepts valid compressed pubkeys (flags = 0x80 or 0xA0).
    function test_fixed_buildG1Point_accepts_valid_flags() external shouldSkip {
        bytes memory y48 = new bytes(48);
        y48[47] = 0x01;

        // 0x80 flag (compressed, no sort bit) — should succeed
        bytes memory pubkey80 = new bytes(48);
        pubkey80[0] = 0x80;
        pubkey80[47] = 0x01;
        bytes memory result1 = harness.buildG1PointFixed(pubkey80, y48);
        assertEq(result1.length, 128);

        // 0xA0 flag (compressed, sort bit set) — should succeed
        bytes memory pubkeyA0 = new bytes(48);
        pubkeyA0[0] = 0xA0;
        pubkeyA0[47] = 0x01;
        bytes memory result2 = harness.buildG1PointFixed(pubkeyA0, y48);
        assertEq(result2.length, 128);
    }
}
