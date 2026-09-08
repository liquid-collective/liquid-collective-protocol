// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import {BLS12_381} from "../../src/libraries/BLS12_381.sol";
import {LibUint256} from "../../src/libraries/LibUint256.sol";

/**
 * @title BLSSigner
 * @notice Test-only BLS12-381 signer. Derives real keypairs and produces real deposit-message
 *         signatures entirely on-chain, so tests can exercise `BLS12_381.verifyDepositMessage`
 *         instead of mocking it.
 * @dev Requires the EIP-2537 precompiles, which Foundry's EVM provides from Prague onwards.
 *      Signing is `sk * hashToG2(signingRoot)` (G2MSM) and the pubkey is `sk * G1` (G1MSM) —
 *      the same relation `verifyDepositMessage`'s pairing check asserts.
 * @dev A contract rather than a library so that `hashToG2` can be reached through a real
 *      self-staticcall — see `hashToG2Trampoline`.
 * @dev NEVER use this outside tests: the secret keys are derived from public data.
 */
contract BLSSigner {
    /// @dev For scalar multiplication on the BLS12-381 G1 curve (EIP-2537).
    address internal constant BLS12_G1MSM = 0x000000000000000000000000000000000000000C;

    /// @dev For scalar multiplication on the BLS12-381 G2 curve (EIP-2537).
    address internal constant BLS12_G2MSM = 0x000000000000000000000000000000000000000E;

    /// @dev Order of the BLS12-381 prime-order subgroup (r). Secret keys live in [1, r).
    uint256 internal constant R = 0x73eda753299d7d483339d80809a1d80553bda402fffe5bfeffffffff00000001;

    /// @dev G1 generator in EIP-2537 encoding: x then y, each a 64-byte field element
    ///      (16 zero bytes || 48-byte limb). `y` here is the positive one, i.e. the negation of
    ///      the NEGATED_G1_GENERATOR constant inlined in `BLS12_381.verifyDepositMessage`.
    bytes32 internal constant G1_X_A = 0x0000000000000000000000000000000017f1d3a73197d7942695638c4fa9ac0f;
    bytes32 internal constant G1_X_B = 0xc3688c4f9774b905a14e3a3f171bac586c55e83ff97a1aeffb3af00adb22c6bb;
    bytes32 internal constant G1_Y_A = 0x0000000000000000000000000000000008b3f481e3aaa0f1a09e30ed741d8ae4;
    bytes32 internal constant G1_Y_B = 0xfcf5e095d5d00af600db18cb2c04b3edd03cc744a2888ae40caa232946c5e7e1;

    /// @dev A signed deposit, shaped for `IDepositDataBuffer.Deposit` / `verifyBLSDeposit`.
    struct SignedDeposit {
        bytes pubkey; // 48-byte compressed G1
        bytes signature; // 96-byte compressed G2
        BLS12_381.DepositY depositY; // uncompressed Y coordinates of both
    }

    error G1MsmFailed();
    error G2MsmFailed();
    error OnlySelfCall();

    /**
     * @notice Trampoline around `BLS12_381.hashToG2`. Only ever reach it via `_hashToG2`.
     * @dev `hashToG2` builds its `expand_message_xmd` input (RFC 9380 5.3.1) in scratch memory
     *      past the free pointer and takes the leading 64-byte `Z_pad` to be implicitly zero
     *      without zeroing it. It also dirties that same region — it writes ~0x300 bytes past the
     *      free pointer without bumping it — so a second call at the same free pointer hashes its
     *      own leftovers and silently returns a different curve point.
     *
     *      Production is unaffected because `AttestationVerifierV1.verifyBLSDeposit` is itself
     *      reached through a self-staticcall trampoline, so every `hashToG2` runs in a fresh frame
     *      with clean memory. Signing mirrors that rather than forking a "safe" copy of the
     *      assembly, which could drift from the verifier and make these tests prove the wrong
     *      thing. It also keeps the guarantee local to `_hashToG2`, so it holds for any caller —
     *      including a contract that inherits `BLSSigner` and signs in its own frame.
     */
    function hashToG2Trampoline(bytes32 message) external view returns (BLS12_381.G2Point memory) {
        if (msg.sender != address(this)) revert OnlySelfCall();
        return BLS12_381.hashToG2(message);
    }

    /// @notice Deterministic secret key from an arbitrary test seed.
    function secretKeyFromSeed(uint256 seed) public pure returns (uint256 sk) {
        sk = uint256(keccak256(abi.encode("BLSSigner.sk", seed))) % R;
        // `sk == 0` would produce the infinity pubkey, which the verifier rejects.
        if (sk == 0) sk = 1;
    }

    /// @notice Public key for `sk`: the compressed form of `sk * G1` plus its uncompressed Y.
    function derivePubkey(uint256 sk) public view returns (bytes memory pubkey, BLS12_381.Fp memory pubkeyY) {
        bytes memory out = _msm(BLS12_G1MSM, abi.encodePacked(G1_X_A, G1_X_B, G1_Y_A, G1_Y_B, bytes32(sk % R)), 0x80);
        if (out.length != 0x80) revert G1MsmFailed();

        (bytes32 xa, bytes32 xb) = _word2(out, 0);
        (bytes32 ya, bytes32 yb) = _word2(out, 0x40);

        pubkeyY = BLS12_381.Fp({a: ya, b: yb});
        pubkey = _compress48(xa, xb, _signBitFp(ya, yb));
    }

    /// @notice Convenience wrapper: the compressed pubkey for `seed`'s keypair.
    function pubkeyFromSeed(uint256 seed) public view returns (bytes memory pubkey) {
        (pubkey,) = derivePubkey(secretKeyFromSeed(seed));
    }

    /// @notice Signs a deposit message with `seed`'s keypair.
    /// @param seed Arbitrary test seed identifying the validator key.
    /// @param amount Deposit amount in wei (must be gwei-aligned).
    /// @param withdrawalCredentials Withdrawal credentials committed to by the deposit message.
    /// @param depositDomain Deposit domain for the chain, per `BLS12_381.computeDepositDomain`.
    function signDepositFromSeed(uint256 seed, uint256 amount, bytes32 withdrawalCredentials, bytes32 depositDomain)
        public
        view
        returns (SignedDeposit memory)
    {
        return signDeposit(secretKeyFromSeed(seed), amount, withdrawalCredentials, depositDomain);
    }

    /// @notice Signs one deposit per seed, all in a single call frame.
    function signDepositsFromSeeds(
        uint256[] calldata seeds,
        uint256 amount,
        bytes32 withdrawalCredentials,
        bytes32 depositDomain
    ) external view returns (SignedDeposit[] memory signed) {
        signed = new SignedDeposit[](seeds.length);
        for (uint256 i = 0; i < seeds.length; ++i) {
            signed[i] = signDepositFromSeed(seeds[i], amount, withdrawalCredentials, depositDomain);
        }
    }

    /// @notice Signs a deposit message with `sk`, returning the pubkey, signature and Y coordinates.
    function signDeposit(uint256 sk, uint256 amount, bytes32 withdrawalCredentials, bytes32 depositDomain)
        public
        view
        returns (SignedDeposit memory signed)
    {
        (bytes memory pubkey, BLS12_381.Fp memory pubkeyY) = derivePubkey(sk);
        bytes32 signingRoot = depositMessageSigningRoot(pubkey, amount, withdrawalCredentials, depositDomain);

        BLS12_381.G2Point memory msgG2 = _hashToG2(signingRoot);
        bytes memory out = _msm(
            BLS12_G2MSM,
            abi.encodePacked(
                abi.encodePacked(
                    msgG2.x_c0_a,
                    msgG2.x_c0_b,
                    msgG2.x_c1_a,
                    msgG2.x_c1_b,
                    msgG2.y_c0_a,
                    msgG2.y_c0_b,
                    msgG2.y_c1_a,
                    msgG2.y_c1_b
                ),
                bytes32(sk % R)
            ),
            0x100
        );
        if (out.length != 0x100) revert G2MsmFailed();

        (bytes32 x_c0_a, bytes32 x_c0_b) = _word2(out, 0x00);
        (bytes32 x_c1_a, bytes32 x_c1_b) = _word2(out, 0x40);
        (bytes32 y_c0_a, bytes32 y_c0_b) = _word2(out, 0x80);
        (bytes32 y_c1_a, bytes32 y_c1_b) = _word2(out, 0xc0);

        // Compressed G2 X is encoded `c1 || c0`, with the flag bits in the first byte of c1.
        bool signBit = _signBitFp2(y_c0_a, y_c0_b, y_c1_a, y_c1_b);
        signed.signature = bytes.concat(_compress48(x_c1_a, x_c1_b, signBit), _limb48(x_c0_a, x_c0_b));
        signed.pubkey = pubkey;
        signed.depositY = BLS12_381.DepositY({
            pubkeyY: pubkeyY, signatureY: BLS12_381.Fp2({c0_a: y_c0_a, c0_b: y_c0_b, c1_a: y_c1_a, c1_b: y_c1_b})
        });
    }

    /// @notice Memory-argument twin of `BLS12_381.depositMessageSigningRoot`, which takes calldata.
    /// @dev Kept byte-for-byte equivalent: any divergence makes the pairing check fail.
    function depositMessageSigningRoot(
        bytes memory pubkey,
        uint256 amount,
        bytes32 withdrawalCredentials,
        bytes32 depositDomain
    ) public pure returns (bytes32) {
        // `pubkeyRoot`: 48-byte pubkey right-padded to 64 bytes.
        bytes32 pubkeyRoot = sha256(bytes.concat(pubkey, bytes16(0)));
        bytes32 amountLeaf = sha256(bytes.concat(bytes32(LibUint256.toLittleEndian64(amount / 1 gwei)), bytes32(0)));
        bytes32 depositMessageRoot =
            sha256(bytes.concat(sha256(bytes.concat(pubkeyRoot, withdrawalCredentials)), amountLeaf));
        return sha256(bytes.concat(depositMessageRoot, depositDomain));
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                         INTERNALS                          */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev `BLS12_381.hashToG2` in a fresh call frame. See `hashToG2Trampoline`.
    function _hashToG2(bytes32 message) internal view returns (BLS12_381.G2Point memory) {
        (bool ok, bytes memory ret) = address(this).staticcall(abi.encodeCall(this.hashToG2Trampoline, (message)));
        if (!ok) {
            // Bubble the library's own error (MapFp2ToG2Failed, Sha256PrecompileFailed, ...).
            assembly {
                revert(add(ret, 0x20), mload(ret))
            }
        }
        return abi.decode(ret, (BLS12_381.G2Point));
    }

    function _msm(address precompile, bytes memory input, uint256 outLen) private view returns (bytes memory out) {
        bool ok;
        (ok, out) = precompile.staticcall(input);
        if (!ok || out.length != outLen) return "";
    }

    /// @dev Reads the two words of a 64-byte field element at `offset` within `data`.
    function _word2(bytes memory data, uint256 offset) private pure returns (bytes32 hi, bytes32 lo) {
        assembly {
            let p := add(add(data, 0x20), offset)
            hi := mload(p)
            lo := mload(add(p, 0x20))
        }
    }

    /// @dev The 48 significant bytes of a 64-byte EIP-2537 field element (drops the 16-byte pad).
    function _limb48(bytes32 hi, bytes32 lo) private pure returns (bytes memory) {
        return bytes.concat(bytes16(uint128(uint256(hi))), lo);
    }

    /// @dev `_limb48` with the compression flag (always set) and the Y sign bit applied.
    function _compress48(bytes32 hi, bytes32 lo, bool signBit) private pure returns (bytes memory limb) {
        limb = _limb48(hi, lo);
        limb[0] = bytes1(uint8(limb[0]) | 0x80 | (signBit ? 0x20 : 0));
    }

    /// @dev Sign bit of an Fp: `y > p / 2`. Mirrors `BLS12_381.validateCompressedPubkeyFlags`.
    function _signBitFp(bytes32 a, bytes32 b) private pure returns (bool) {
        return a > BLS12_381.HALF_P_A || (a == BLS12_381.HALF_P_A && b > BLS12_381.HALF_P_B);
    }

    /// @dev Sign bit of an Fp2: driven by `c1`, falling back to `c0` when `c1` is zero.
    ///      Mirrors `BLS12_381.validateCompressedSignatureFlags`.
    function _signBitFp2(bytes32 c0_a, bytes32 c0_b, bytes32 c1_a, bytes32 c1_b) private pure returns (bool) {
        if (c1_a == 0 && c1_b == 0) return _signBitFp(c0_a, c0_b);
        return _signBitFp(c1_a, c1_b);
    }
}
