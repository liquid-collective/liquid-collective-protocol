// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "forge-std/Test.sol";

import {BLS12_381} from "../../../src/libraries/BLS12_381.sol";
import {BLSSigner} from "../BLSSigner.sol";

/// @dev Exposes the library's calldata-argument functions for direct testing.
contract BLSEdgeHarness {
    function verifyDepositMessage(
        bytes calldata pubkey,
        bytes calldata signature,
        uint256 amount,
        BLS12_381.DepositY calldata depositY,
        bytes32 withdrawalCredentials,
        bytes32 depositDomain
    ) external view {
        BLS12_381.verifyDepositMessage(pubkey, signature, amount, depositY, withdrawalCredentials, depositDomain);
    }

    function validateCompressedPubkeyFlags(bytes calldata pubkey, BLS12_381.Fp calldata pubkeyY) external pure {
        BLS12_381.validateCompressedPubkeyFlags(pubkey, pubkeyY);
    }

    function validateCompressedSignatureFlags(bytes calldata signature, BLS12_381.Fp2 calldata signatureY)
        external
        pure
    {
        BLS12_381.validateCompressedSignatureFlags(signature, signatureY);
    }

    function extractFlags(bytes1 header) external pure returns (bool signBit, bool areOtherFlagsValid) {
        return BLS12_381.extractFlags(header);
    }

    function pubkeyRoot(bytes calldata pubkey) external view returns (bytes32) {
        return BLS12_381.pubkeyRoot(pubkey);
    }

    function depositMessageSigningRoot(bytes calldata pubkey, uint256 amount, bytes32 wc, bytes32 domain)
        external
        view
        returns (bytes32)
    {
        return BLS12_381.depositMessageSigningRoot(pubkey, amount, wc, domain);
    }
}

/**
 * @title BLSFlagEdgeCasesTest
 * @notice Solidity counterparts to the `BLS flag edge cases` block of noble-curves'
 *         `test/bls12-381.test.ts`, plus its infinity-point and non-canonical-limb cases.
 * @dev Scope note. Most of noble's bls12-381 suite has no counterpart here, because this repo has
 *      no Solidity surface for it — `BLS12_381` exposes only hash-to-G2, compressed-flag
 *      validation and deposit-message verification, and delegates all curve arithmetic to the
 *      EIP-2537 precompiles (whose own correctness is the client's concern, covered by
 *      ethereum/bls12-381-tests). Deliberately not ported: Fp/Fp2 field arithmetic, point
 *      double/multiply/clearCofactor, `fromBytes`/`toHex` encoding round-trips, Fr round-trips,
 *      public-key aggregation, batch and augmented verification, short signatures (G1), and
 *      pairing internals (`finalExponentiate`, `frobeniusMap`).
 *
 *      Also already covered elsewhere and not duplicated: hash-to-curve vectors and the
 *      zero-private-key rejection (`BLSVectors.t.sol`), sign/verify happy paths and wrong-key /
 *      wrong-amount / wrong-credential rejection (`BLSSigner.t.sol`), and the end-to-end
 *      invalid-signature paths through the deposit flow (`DepositAttestation.t.sol`).
 *
 *      What remains, and is new here: this library never range-checks the X limbs or the supplied
 *      Y coordinates against the field modulus, and never checks for the point at infinity beyond
 *      an all-zero test. These tests pin what actually happens at each of those boundaries.
 */
contract BLSFlagEdgeCasesTest is Test {
    BLSEdgeHarness internal harness;
    BLSSigner internal signer;

    bytes32 internal constant WITHDRAWAL_CREDENTIALS =
        0x02000000000000000000000000000000000000000000000000000000CAFEBABE;

    /// @dev The BLS12-381 base field modulus `p`, split as an EIP-2537 `Fp`.
    bytes32 internal constant P_A = 0x000000000000000000000000000000001a0111ea397fe69a4b1ba7b6434bacd7;
    bytes32 internal constant P_B = 0x64774b84f38512bf6730d2a0f6b0f6241eabfffeb153ffffb9feffffffffaaab;

    /// @dev `p` as the 48 bytes of a compressed X coordinate (flag bits not yet applied).
    bytes internal constant P_48 =
        hex"1a0111ea397fe69a4b1ba7b6434bacd764774b84f38512bf6730d2a0f6b0f6241eabfffeb153ffffb9feffffffffaaab";

    bytes32 internal depositDomain;
    BLSSigner.SignedDeposit internal valid;

    function setUp() public {
        harness = new BLSEdgeHarness();
        signer = new BLSSigner();
        depositDomain = BLS12_381.computeDepositDomain(bytes4(0));
        valid = signer.signDepositFromSeed(1, 32 ether, WITHDRAWAL_CREDENTIALS, depositDomain);
    }

    function _verifyValid() internal view {
        harness.verifyDepositMessage(
            valid.pubkey, valid.signature, 32 ether, valid.depositY, WITHDRAWAL_CREDENTIALS, depositDomain
        );
    }

    function _copy(bytes memory data) internal pure returns (bytes memory out) {
        out = new bytes(data.length);
        for (uint256 i = 0; i < data.length; ++i) {
            out[i] = data[i];
        }
    }

    /// @dev Sanity anchor: the fixture the negative cases mutate must itself verify, otherwise
    ///      every test below could pass for the wrong reason.
    function testFixtureVerifies() public view {
        _verifyValid();
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                     FLAG COMBINATIONS                      */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev noble: `reject noncanonical sort/infinity flag combinations`. Only `10` is accepted in
    ///      the top two bits — compressed, not infinity. Notably this means the canonical zcash
    ///      infinity encoding (`0xc0`) is rejected as a malformed component rather than treated as
    ///      the point at infinity.
    function testExtractFlagsAcceptsOnlyCompressedNonInfinity() public {
        for (uint256 b = 0; b < 256; ++b) {
            (bool signBit, bool otherFlagsValid) = harness.extractFlags(bytes1(uint8(b)));
            assertEq(signBit, (b & 0x20) != 0, "sign bit");
            assertEq(otherFlagsValid, (b & 0xc0) == 0x80, "compression/infinity flags");
        }
    }

    /// @dev noble: same case, applied through the pubkey validator. `0x40` (infinity set) and
    ///      `0x00` (compression cleared, i.e. an uncompressed encoding handed to a compressed API)
    ///      must both be rejected.
    function testRejectNonCanonicalPubkeyFlagCombinations() public {
        uint8[3] memory badTopBits = [0x00, 0x40, 0xc0];
        for (uint256 i = 0; i < badTopBits.length; ++i) {
            bytes memory pubkey = _copy(valid.pubkey);
            pubkey[0] = bytes1((uint8(pubkey[0]) & 0x3f) | badTopBits[i]);
            vm.expectRevert(
                abi.encodeWithSelector(BLS12_381.InvalidCompressedComponent.selector, BLS12_381.Component.PubKey)
            );
            harness.validateCompressedPubkeyFlags(pubkey, valid.depositY.pubkeyY);
        }
    }

    /// @dev Same for the signature component.
    function testRejectNonCanonicalSignatureFlagCombinations() public {
        uint8[3] memory badTopBits = [0x00, 0x40, 0xc0];
        for (uint256 i = 0; i < badTopBits.length; ++i) {
            bytes memory signature = _copy(valid.signature);
            signature[0] = bytes1((uint8(signature[0]) & 0x3f) | badTopBits[i]);
            vm.expectRevert(
                abi.encodeWithSelector(BLS12_381.InvalidCompressedComponent.selector, BLS12_381.Component.Signature)
            );
            harness.validateCompressedSignatureFlags(signature, valid.depositY.signatureY);
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                     SIGN-BIT BOUNDARIES                    */
    /*.•°:°.´+˚.*°.˚:*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev The sign bit encodes `y > p / 2`, so exactly `p / 2` must read as *not* set. Pins the
    ///      comparison to `>` rather than `>=` at the one input where they differ.
    function testPubkeySignBitAtExactlyHalfP() public {
        bytes memory pubkey = _copy(valid.pubkey);

        // y == p / 2  ->  sign bit must be clear.
        pubkey[0] = bytes1(uint8(pubkey[0]) & 0xdf);
        harness.validateCompressedPubkeyFlags(pubkey, BLS12_381.Fp({a: BLS12_381.HALF_P_A, b: BLS12_381.HALF_P_B}));

        // y == p / 2 + 1  ->  sign bit must be set.
        bytes memory pubkeySet = _copy(valid.pubkey);
        pubkeySet[0] = bytes1(uint8(pubkeySet[0]) | 0x20);
        harness.validateCompressedPubkeyFlags(
            pubkeySet, BLS12_381.Fp({a: BLS12_381.HALF_P_A, b: bytes32(uint256(BLS12_381.HALF_P_B) + 1)})
        );

        // ...and the opposite pairings must be rejected.
        vm.expectRevert(
            abi.encodeWithSelector(BLS12_381.InvalidCompressedComponentSignBit.selector, BLS12_381.Component.PubKey)
        );
        harness.validateCompressedPubkeyFlags(pubkeySet, BLS12_381.Fp({a: BLS12_381.HALF_P_A, b: BLS12_381.HALF_P_B}));
    }

    /// @dev For Fp2 the sign bit is driven by `c1`, falling back to `c0` only when `c1` is zero.
    ///      Nothing else in the suite exercises that fallback, and dropping it silently produces
    ///      well-formed signatures over the wrong point.
    function testSignatureSignBitFallsBackToC0WhenC1IsZero() public {
        bytes memory sigClear = _copy(valid.signature);
        sigClear[0] = bytes1(uint8(sigClear[0]) & 0xdf);
        bytes memory sigSet = _copy(valid.signature);
        sigSet[0] = bytes1(uint8(sigSet[0]) | 0x20);

        // c1 == 0, c0 > p/2  ->  driven by c0, sign bit set.
        BLS12_381.Fp2 memory c1ZeroC0High = BLS12_381.Fp2({
            c0_a: BLS12_381.HALF_P_A, c0_b: bytes32(uint256(BLS12_381.HALF_P_B) + 1), c1_a: bytes32(0), c1_b: bytes32(0)
        });
        harness.validateCompressedSignatureFlags(sigSet, c1ZeroC0High);

        // c1 == 0, c0 <= p/2  ->  driven by c0, sign bit clear.
        BLS12_381.Fp2 memory c1ZeroC0Low =
            BLS12_381.Fp2({c0_a: BLS12_381.HALF_P_A, c0_b: BLS12_381.HALF_P_B, c1_a: bytes32(0), c1_b: bytes32(0)});
        harness.validateCompressedSignatureFlags(sigClear, c1ZeroC0Low);

        // c1 non-zero and low  ->  c1 wins, so a high c0 must NOT set the bit.
        BLS12_381.Fp2 memory c1LowC0High = BLS12_381.Fp2({
            c0_a: BLS12_381.HALF_P_A,
            c0_b: bytes32(uint256(BLS12_381.HALF_P_B) + 1),
            c1_a: bytes32(0),
            c1_b: bytes32(uint256(1))
        });
        harness.validateCompressedSignatureFlags(sigClear, c1LowC0High);

        vm.expectRevert(
            abi.encodeWithSelector(BLS12_381.InvalidCompressedComponentSignBit.selector, BLS12_381.Component.Signature)
        );
        harness.validateCompressedSignatureFlags(sigSet, c1LowC0High);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                    INFINITY POINTS                         */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev noble: `G2 BASE is not small-order while ZERO is` — the infinity point must never be
    ///      accepted as a key or signature. EIP-2537 encodes infinity as all-zeroes, and the
    ///      pairing check would accept it, so the library screens for it explicitly.
    function testRejectInfinityPubkey() public {
        // Flags must still validate to reach the infinity screen: compression set, infinity clear,
        // sign bit clear to match a zero Y.
        bytes memory pubkey = new bytes(48);
        pubkey[0] = bytes1(uint8(0x80));

        BLS12_381.DepositY memory depositY = BLS12_381.DepositY({
            pubkeyY: BLS12_381.Fp({a: bytes32(0), b: bytes32(0)}), signatureY: valid.depositY.signatureY
        });

        vm.expectRevert(BLS12_381.InputHasInfinityPoints.selector);
        harness.verifyDepositMessage(pubkey, valid.signature, 32 ether, depositY, WITHDRAWAL_CREDENTIALS, depositDomain);
    }

    /// @dev Same for the signature: an all-zero G2 point must be rejected outright.
    function testRejectInfinitySignature() public {
        bytes memory signature = new bytes(96);
        signature[0] = bytes1(uint8(0x80));

        BLS12_381.DepositY memory depositY = BLS12_381.DepositY({
            pubkeyY: valid.depositY.pubkeyY,
            signatureY: BLS12_381.Fp2({c0_a: bytes32(0), c0_b: bytes32(0), c1_a: bytes32(0), c1_b: bytes32(0)})
        });

        vm.expectRevert(BLS12_381.InputHasInfinityPoints.selector);
        harness.verifyDepositMessage(valid.pubkey, signature, 32 ether, depositY, WITHDRAWAL_CREDENTIALS, depositDomain);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                  NON-CANONICAL FIELD LIMBS                 */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev noble: `reject non-canonical field limbs in point and signature encodings`. This
    ///      library does no range check of its own — it masks the flag bits and hands X to the
    ///      pairing precompile, which rejects `x == p`. Documents that the rejection happens, and
    ///      that it surfaces as `PairingFailed` rather than a dedicated error.
    function testRejectNonCanonicalPubkeyX() public {
        bytes memory pubkey = _copy(valid.pubkey);
        // X := p, preserving the original flag bits so the sign-bit check still passes.
        for (uint256 i = 1; i < 48; ++i) {
            pubkey[i] = P_48[i];
        }
        pubkey[0] = bytes1((uint8(P_48[0]) & 0x1f) | (uint8(valid.pubkey[0]) & 0xe0));

        vm.expectRevert(BLS12_381.PairingFailed.selector);
        harness.verifyDepositMessage(
            pubkey, valid.signature, 32 ether, valid.depositY, WITHDRAWAL_CREDENTIALS, depositDomain
        );
    }

    /// @dev Same for the signature's X, whose compressed form is `c1 || c0`; `c0` occupies bytes
    ///      48..96 and carries no flag bits.
    function testRejectNonCanonicalSignatureX() public {
        bytes memory signature = _copy(valid.signature);
        for (uint256 i = 0; i < 48; ++i) {
            signature[48 + i] = P_48[i];
        }

        vm.expectRevert(BLS12_381.PairingFailed.selector);
        harness.verifyDepositMessage(
            valid.pubkey, signature, 32 ether, valid.depositY, WITHDRAWAL_CREDENTIALS, depositDomain
        );
    }

    /// @dev noble: `reject non-flag high bits in uncompressed coordinate limbs`. The top 16 bytes
    ///      of every 64-byte EIP-2537 field element must be zero. The supplied Y coordinates go
    ///      straight to the precompile, so junk in that padding is caught there — and, because the
    ///      sign-bit rule compares the whole limb, the caller must also flip the sign bit to get
    ///      that far, which is what this constructs.
    function testRejectNonZeroPaddingInPubkeyY() public {
        bytes memory pubkey = _copy(valid.pubkey);
        pubkey[0] = bytes1(uint8(pubkey[0]) | 0x20); // dirty padding makes y compare as > p/2

        BLS12_381.DepositY memory depositY = BLS12_381.DepositY({
            pubkeyY: BLS12_381.Fp({
                a: bytes32(uint256(valid.depositY.pubkeyY.a) | (uint256(1) << 200)), b: valid.depositY.pubkeyY.b
            }),
            signatureY: valid.depositY.signatureY
        });

        vm.expectRevert(BLS12_381.PairingFailed.selector);
        harness.verifyDepositMessage(pubkey, valid.signature, 32 ether, depositY, WITHDRAWAL_CREDENTIALS, depositDomain);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                    MALFORMED INPUT LENGTHS                 */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev noble: `rejects uncompressed signature bytes in raw-byte APIs`. The Solidity analogue
    ///      is the length guard: an uncompressed G1 (96 bytes) or G2 (192 bytes) encoding, or any
    ///      other wrong length, must be refused rather than silently truncated.
    function testRejectWrongPubkeyLength() public {
        uint256[3] memory lengths = [uint256(47), 49, 96];
        for (uint256 i = 0; i < lengths.length; ++i) {
            vm.expectRevert(BLS12_381.InvalidPubkeyLength.selector);
            harness.validateCompressedPubkeyFlags(new bytes(lengths[i]), valid.depositY.pubkeyY);
        }
    }

    function testRejectWrongSignatureLength() public {
        uint256[3] memory lengths = [uint256(95), 97, 192];
        for (uint256 i = 0; i < lengths.length; ++i) {
            vm.expectRevert(BLS12_381.InvalidSignatureLength.selector);
            harness.validateCompressedSignatureFlags(new bytes(lengths[i]), valid.depositY.signatureY);
        }
    }

    /// @dev `pubkeyRoot` hashes a fixed 48 bytes, so it enforces the same length invariant.
    function testPubkeyRootRejectsWrongLength() public {
        vm.expectRevert(BLS12_381.InvalidPubkeyLength.selector);
        harness.pubkeyRoot(new bytes(47));
    }

    /// @dev Deposit amounts are serialised as gwei in the signing root, so a sub-gwei remainder
    ///      would be silently truncated. Must be refused instead.
    function testRejectNonGweiAlignedAmount() public {
        vm.expectRevert(BLS12_381.InvalidDepositAmount.selector);
        harness.depositMessageSigningRoot(valid.pubkey, 32 ether + 1, WITHDRAWAL_CREDENTIALS, depositDomain);
    }
}
