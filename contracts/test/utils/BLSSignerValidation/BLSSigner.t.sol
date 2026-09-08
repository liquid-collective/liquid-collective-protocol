// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "forge-std/Test.sol";

import {BLS12_381} from "../../../src/libraries/BLS12_381.sol";
import {BLSSigner} from "../BLSSigner.sol";

/// @dev Calldata wrapper: `BLS12_381.verifyDepositMessage` reads its inputs from calldata.
contract BLSVerifierWrapper {
    function verify(
        bytes calldata pubkey,
        bytes calldata signature,
        uint256 amount,
        BLS12_381.DepositY calldata depositY,
        bytes32 withdrawalCredentials,
        bytes32 depositDomain
    ) external view {
        BLS12_381.verifyDepositMessage(pubkey, signature, amount, depositY, withdrawalCredentials, depositDomain);
    }

    function signingRoot(bytes calldata pubkey, uint256 amount, bytes32 wc, bytes32 domain)
        external
        view
        returns (bytes32)
    {
        return BLS12_381.depositMessageSigningRoot(pubkey, amount, wc, domain);
    }
}

contract BLSSignerTest is Test {
    BLSSigner internal signer;
    BLSVerifierWrapper internal wrapper;

    bytes32 internal constant WITHDRAWAL_CREDENTIALS =
        0x02000000000000000000000000000000000000000000000000000000CAFEBABE;

    /// @dev Cached because `computeDepositDomain` calls the sha256 precompile, which must not
    ///      happen after `vm.expectRevert` is armed.
    bytes32 internal depositDomain;

    function setUp() public {
        signer = new BLSSigner();
        wrapper = new BLSVerifierWrapper();
        depositDomain = BLS12_381.computeDepositDomain(bytes4(0));
    }

    /// @dev The memory-argument signing root must match the production calldata one byte-for-byte.
    function testSigningRootMatchesProduction() public {
        bytes memory pubkey = signer.pubkeyFromSeed(1);
        assertEq(
            signer.depositMessageSigningRoot(pubkey, 32 ether, WITHDRAWAL_CREDENTIALS, depositDomain),
            wrapper.signingRoot(pubkey, 32 ether, WITHDRAWAL_CREDENTIALS, depositDomain)
        );
    }

    function testPubkeyAndSignatureShape() public {
        BLSSigner.SignedDeposit memory s =
            signer.signDepositFromSeed(7, 32 ether, WITHDRAWAL_CREDENTIALS, depositDomain);
        assertEq(s.pubkey.length, 48);
        assertEq(s.signature.length, 96);
        // Compression flag set, infinity flag clear on both components.
        assertEq(uint8(s.pubkey[0]) & 0xc0, 0x80);
        assertEq(uint8(s.signature[0]) & 0xc0, 0x80);
    }

    function testSignedDepositVerifies() public view {
        BLSSigner.SignedDeposit memory s =
            signer.signDepositFromSeed(42, 32 ether, WITHDRAWAL_CREDENTIALS, depositDomain);
        wrapper.verify(s.pubkey, s.signature, 32 ether, s.depositY, WITHDRAWAL_CREDENTIALS, depositDomain);
    }

    function testSignedDepositVerifiesFuzz(uint256 seed, uint64 gweiAmount) public view {
        gweiAmount = uint64(bound(gweiAmount, 1, 2048e9));
        uint256 amount = uint256(gweiAmount) * 1 gwei;
        BLSSigner.SignedDeposit memory s =
            signer.signDepositFromSeed(seed, amount, WITHDRAWAL_CREDENTIALS, depositDomain);
        wrapper.verify(s.pubkey, s.signature, amount, s.depositY, WITHDRAWAL_CREDENTIALS, depositDomain);
    }

    /// @dev Batch signing must agree with one-at-a-time signing, and every signature must verify.
    function testBatchSigningMatchesIndividualSigning() public {
        uint256[] memory seeds = new uint256[](6);
        for (uint256 i = 0; i < seeds.length; ++i) {
            seeds[i] = 1000 + i;
        }

        BLSSigner.SignedDeposit[] memory batch =
            signer.signDepositsFromSeeds(seeds, 32 ether, WITHDRAWAL_CREDENTIALS, depositDomain);

        for (uint256 i = 0; i < seeds.length; ++i) {
            BLSSigner.SignedDeposit memory one =
                signer.signDepositFromSeed(seeds[i], 32 ether, WITHDRAWAL_CREDENTIALS, depositDomain);
            assertEq(batch[i].pubkey, one.pubkey);
            assertEq(batch[i].signature, one.signature);
            wrapper.verify(
                batch[i].pubkey, batch[i].signature, 32 ether, batch[i].depositY, WITHDRAWAL_CREDENTIALS, depositDomain
            );
        }
    }

    function testWrongAmountFailsVerification() public {
        BLSSigner.SignedDeposit memory s =
            signer.signDepositFromSeed(45, 32 ether, WITHDRAWAL_CREDENTIALS, depositDomain);
        vm.expectRevert(BLS12_381.InvalidSignature.selector);
        wrapper.verify(s.pubkey, s.signature, 64 ether, s.depositY, WITHDRAWAL_CREDENTIALS, depositDomain);
    }

    function testWrongWithdrawalCredentialsFailsVerification() public {
        BLSSigner.SignedDeposit memory s =
            signer.signDepositFromSeed(46, 32 ether, WITHDRAWAL_CREDENTIALS, depositDomain);
        vm.expectRevert(BLS12_381.InvalidSignature.selector);
        wrapper.verify(s.pubkey, s.signature, 32 ether, s.depositY, bytes32(uint256(1)), depositDomain);
    }

    function testMismatchedKeyFailsVerification() public {
        BLSSigner.SignedDeposit memory a =
            signer.signDepositFromSeed(47, 32 ether, WITHDRAWAL_CREDENTIALS, depositDomain);
        BLSSigner.SignedDeposit memory b =
            signer.signDepositFromSeed(48, 32 ether, WITHDRAWAL_CREDENTIALS, depositDomain);
        // Key A's pubkey against key B's signature (X and Y both taken from B, so the point is
        // still on the curve and the pairing check runs to a clean `false`).
        BLS12_381.DepositY memory mixed =
            BLS12_381.DepositY({pubkeyY: a.depositY.pubkeyY, signatureY: b.depositY.signatureY});
        vm.expectRevert(BLS12_381.InvalidSignature.selector);
        wrapper.verify(a.pubkey, b.signature, 32 ether, mixed, WITHDRAWAL_CREDENTIALS, depositDomain);
    }

    function testRevert_hashToG2TrampolineIsSelfCallOnly() public {
        vm.expectRevert(BLSSigner.OnlySelfCall.selector);
        signer.hashToG2Trampoline(bytes32(uint256(1)));
    }
}
