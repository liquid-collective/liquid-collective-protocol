// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "forge-std/Test.sol";

import {BLS12_381} from "../../../src/libraries/BLS12_381.sol";
import {BLSSigner} from "../BLSSigner.sol";
import {BLSVectors} from "./BLSVectors.sol";

/// @dev Known-answer tests against the official `BLS_SIG_BLS12381G2_XMD:SHA-256_SSWU_RO_POP_`
///      fixtures. Without these, `BLSSigner` and `BLS12_381` are only checked against each other:
///      they would agree even if both diverged from the Ethereum spec, and every signature the
///      deposit tests rely on would be consistently wrong. These pin both to external ground truth.
contract BLSVectorsTest is Test {
    BLSSigner internal signer;

    function setUp() public {
        signer = new BLSSigner();
    }

    /// @dev The `sign` handler of ethereum/bls12-381-tests, verbatim. Also the strongest available
    ///      check on production `hashToG2`: a signature is `sk * hashToG2(message)`, so it cannot
    ///      match unless the hash-to-curve is spec-correct.
    function testOfficialSignVectors() public {
        BLSVectors.SignCase[] memory cases = BLSVectors.signCases();
        assertEq(cases.length, 9);

        for (uint256 i = 0; i < cases.length; ++i) {
            (bytes memory signature,) = signer.signRoot(cases[i].privkey, cases[i].message);
            assertEq(signature, cases[i].signature, cases[i].name);
        }
    }

    /// @dev The suite's `sign_case_zero_privkey` expects `output: null`. A zero scalar would sign
    ///      with the infinity point, so reject it rather than emit an unrepresentable signature.
    function testOfficialSignVector_zeroPrivkeyRejected() public {
        vm.expectRevert(BLSSigner.ZeroSecretKey.selector);
        signer.signRoot(BLSVectors.ZERO_PRIVKEY, BLSVectors.ZERO_PRIVKEY_MESSAGE);
    }

    /// @dev Direct coverage of production `BLS12_381.hashToG2`, which otherwise has none in this
    ///      repo. Expectations come from noble-curves rather than the official `hash_to_G2`
    ///      fixtures, whose messages are arbitrary-length while this library takes only `bytes32`.
    function testHashToG2Vectors() public {
        BLSVectors.HashToG2Case[] memory cases = BLSVectors.hashToG2Cases();
        assertEq(cases.length, 3);

        for (uint256 i = 0; i < cases.length; ++i) {
            BLS12_381.G2Point memory got = signer.hashToG2(cases[i].message);
            BLS12_381.G2Point memory want = cases[i].point;
            assertEq(got.x_c0_a, want.x_c0_a, "x_c0_a");
            assertEq(got.x_c0_b, want.x_c0_b, "x_c0_b");
            assertEq(got.x_c1_a, want.x_c1_a, "x_c1_a");
            assertEq(got.x_c1_b, want.x_c1_b, "x_c1_b");
            assertEq(got.y_c0_a, want.y_c0_a, "y_c0_a");
            assertEq(got.y_c0_b, want.y_c0_b, "y_c0_b");
            assertEq(got.y_c1_a, want.y_c1_a, "y_c1_a");
            assertEq(got.y_c1_b, want.y_c1_b, "y_c1_b");
        }
    }

    /// @dev `signDeposit` must route through the same primitive the vectors pin, so the official
    ///      coverage above actually applies to the signatures the deposit tests consume.
    function testSignDepositUsesVectorPinnedPrimitive() public {
        bytes32 wc = 0x02000000000000000000000000000000000000000000000000000000CAFEBABE;
        bytes32 domain = BLS12_381.computeDepositDomain(bytes4(0));
        uint256 sk = signer.secretKeyFromSeed(7);

        BLSSigner.SignedDeposit memory signed = signer.signDeposit(sk, 32 ether, wc, domain);
        bytes32 root = signer.depositMessageSigningRoot(signed.pubkey, 32 ether, wc, domain);
        (bytes memory signature,) = signer.signRoot(sk, root);

        assertEq(signed.signature, signature);
    }
}
