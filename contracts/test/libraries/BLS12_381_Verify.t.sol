// SPDX-License-Identifier: CC0-1.0
pragma solidity 0.8.34;

import {Test} from "forge-std/Test.sol";
import {BLS12_381} from "../../src/libraries/BLS12_381.sol";

// Exercises the REAL BLS signature-verification path (verifyDepositMessage), which
// runs the EIP-2537 pairing precompile. Other tests in this repo mock BLS
// verification on the stale assumption that the precompile is unavailable in
// Foundry; it is available (Foundry 1.4.4), so the path can be tested for real.
//
// The test vector is lifted from lidofinance/core (MIT), test/common/lib/BLS.t.sol,
// `LOCAL_MESSAGE_1`. Our BLS12_381.sol is adapted from Lido's BLS.sol, so the same
// vector applies directly — a valid signature must verify and a tampered message
// must be rejected.

/// @dev Thin harness exposing the internal library functions.
contract BLS12_381VerifyHarness {
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

    function depositMessageSigningRoot(bytes calldata pubkey, uint256 amount, bytes32 wc, bytes32 domain)
        external
        view
        returns (bytes32)
    {
        return BLS12_381.depositMessageSigningRoot(pubkey, amount, wc, domain);
    }
}

contract BLS12_381VerifyTest is Test {
    BLS12_381VerifyHarness internal harness;

    // --- LOCAL_MESSAGE_1 vector (lidofinance/core, MIT) ---
    bytes internal constant PUBKEY =
        hex"b79902f435d268d6d37ac3ab01f4536a86c192fa07ba5b63b5f8e4d0e05755cfeab9d35fbedb9c02919fe02a81f8b06d";
    bytes internal constant SIGNATURE =
        hex"b357f146f53de27ae47d6d4bff5e8cc8342d94996143b2510452a3565701c3087a0ba04bed41d208eb7d2f6a50debeac09bf3fcf5c28d537d0fe4a52bb976d0c19ea37a31b6218f321a308f8017e5fd4de63df270f37df58c059c75f0f98f980";
    uint256 internal constant AMOUNT = 1 ether;
    bytes32 internal constant WITHDRAWAL_CREDENTIALS =
        0xf3d93f9fbc6a229f3b11340b4b52ae53833813efab76e812d1d014163259ef1f;
    // Mainnet deposit domain (genesis fork version 0x00000000).
    bytes32 internal constant MAINNET_DEPOSIT_DOMAIN =
        0x03000000f5a5fd42d16a20302798ef6ed309979b43003d2320d9f0e8ea9831a9;
    // depositMessageSigningRoot of the vector, per Lido's test.
    bytes32 internal constant EXPECTED_SIGNING_ROOT =
        0xa0ea5aa96388d0375c9181eac29fa198cea873c818efe7442bd49c03948f2a69;

    function setUp() public {
        harness = new BLS12_381VerifyHarness();
    }

    /// @dev Uncompressed Y-coordinates of the pubkey (G1) and signature (G2) for the vector.
    function _depositY() internal pure returns (BLS12_381.DepositY memory) {
        return BLS12_381.DepositY(
            BLS12_381.Fp(
                0x0000000000000000000000000000000019b71bd2a9ebf09809b6c380a1d1de0c,
                0x2d9286a8d368a2fc75ad5ccc8aec572efdff29d50b68c63e00f6ce017c24e083
            ),
            BLS12_381.Fp2(
                0x00000000000000000000000000000000160f8d804d277c7a079f451bce224fd4,
                0x2397e75676d965a1ebe79e53beeb2cb48be01f4dc93c0bad8ae7560c3e8048fb,
                0x0000000000000000000000000000000010d96c5dcc6e32bcd43e472317e18ad9,
                0x4dde89c9361d79bec5378c72214083ea40f3dc43ee759025eb4c25150e1943bf
            )
        );
    }

    // The real signature must verify (no revert). This runs the EIP-2537 pairing
    // precompile end to end — the path that is mocked elsewhere.
    function test_verifyDepositMessage_validVectorPasses() public view {
        harness.verifyDepositMessage(
            PUBKEY, SIGNATURE, AMOUNT, _depositY(), WITHDRAWAL_CREDENTIALS, MAINNET_DEPOSIT_DOMAIN
        );
    }

    // Tampering the withdrawal credentials changes the signed message, so the same
    // signature must now be rejected with InvalidSignature.
    function test_verifyDepositMessage_corruptedReverts() public {
        vm.expectRevert(BLS12_381.InvalidSignature.selector);
        harness.verifyDepositMessage(PUBKEY, SIGNATURE, AMOUNT, _depositY(), bytes32(0), MAINNET_DEPOSIT_DOMAIN);
    }

    // depositMessageSigningRoot must reproduce the known signing root for the vector.
    // This also confirms our `toLittleEndian64` substitution matches Lido's encoding.
    function test_depositMessageSigningRoot_matchesLidoVector() public {
        bytes32 root = harness.depositMessageSigningRoot(PUBKEY, AMOUNT, WITHDRAWAL_CREDENTIALS, MAINNET_DEPOSIT_DOMAIN);
        assertEq(root, EXPECTED_SIGNING_ROOT, "signing root does not match Lido vector");
    }
}
