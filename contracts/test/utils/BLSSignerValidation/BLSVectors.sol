// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import {BLS12_381} from "../../../src/libraries/BLS12_381.sol";

/**
 * @title BLSVectors
 * @notice Known-answer test vectors for the `BLS_SIG_BLS12381G2_XMD:SHA-256_SSWU_RO_POP_`
 *         ciphersuite — the one Ethereum deposits use.
 * @dev GENERATED FILE, do not hand-edit. Regenerate with `npm run bls:vectors`.
 *
 *      `signCases()` is the `sign` handler of ethereum/bls12-381-tests v0.1.2 (CC0-1.0),
 *      verbatim: https://github.com/ethereum/bls12-381-tests/releases/tag/v0.1.2
 *      Its inputs are `(privkey: bytes32, message: bytes32)`, which lines up exactly with
 *      `BLSSigner.signRoot`. Because a signature is `sk * hashToG2(message)`, matching these also
 *      pins the production `BLS12_381.hashToG2` for 32-byte messages: a wrong hash-to-curve cannot
 *      produce a matching signature.
 *
 *      `hashToG2Cases()` covers `BLS12_381.hashToG2` directly, so a hash-to-curve regression is
 *      attributed at its source instead of only surfacing as a signature mismatch. The official
 *      `hash_to_G2` fixtures cannot be used for this: their messages are arbitrary-length
 *      (`""`, `"abc"`, 512 bytes) while this library only accepts `bytes32`. These expectations
 *      are therefore generated from noble-curves for the same 32-byte messages as the `sign`
 *      cases, and are re-checked by `npm run bls:crosscheck`.
 */
library BLSVectors {
    /// @dev One `sign` case: `signRoot(privkey, message)` must equal `signature`.
    struct SignCase {
        string name;
        uint256 privkey;
        bytes32 message;
        bytes signature;
    }

    /// @dev One hash-to-curve case: `hashToG2(message)` must equal `point`.
    struct HashToG2Case {
        bytes32 message;
        BLS12_381.G2Point point;
    }

    /// @dev Private key of the `sign` case the suite expects to be rejected (`output: null`).
    uint256 internal constant ZERO_PRIVKEY = 0x0000000000000000000000000000000000000000000000000000000000000000;

    /// @dev Message paired with `ZERO_PRIVKEY` in that case.
    bytes32 internal constant ZERO_PRIVKEY_MESSAGE = 0xabababababababababababababababababababababababababababababababab;

    function signCases() internal pure returns (SignCase[] memory cases) {
        cases = new SignCase[](9);
        cases[0] = SignCase({
            name: "sign_case_11b8c7cad5238946",
            privkey: 0x47b8192d77bf871b62e87859d653922725724a5c031afeabc60bcef5ff665138,
            message: 0x0000000000000000000000000000000000000000000000000000000000000000,
            signature: hex"b23c46be3a001c63ca711f87a005c200cc550b9429d5f4eb38d74322144f1b63926da3388979e5321012fb1a0526bcd100b5ef5fe72628ce4cd5e904aeaa3279527843fae5ca9ca675f4f51ed8f83bbf7155da9ecc9663100a885d5dc6df96d9"
        });
        cases[1] = SignCase({
            name: "sign_case_142f678a8d05fcd1",
            privkey: 0x47b8192d77bf871b62e87859d653922725724a5c031afeabc60bcef5ff665138,
            message: 0x5656565656565656565656565656565656565656565656565656565656565656,
            signature: hex"af1390c3c47acdb37131a51216da683c509fce0e954328a59f93aebda7e4ff974ba208d9a4a2a2389f892a9d418d618418dd7f7a6bc7aa0da999a9d3a5b815bc085e14fd001f6a1948768a3f4afefc8b8240dda329f984cb345c6363272ba4fe"
        });
        cases[2] = SignCase({
            name: "sign_case_37286e1a6d1f6eb3",
            privkey: 0x47b8192d77bf871b62e87859d653922725724a5c031afeabc60bcef5ff665138,
            message: 0xabababababababababababababababababababababababababababababababab,
            signature: hex"9674e2228034527f4c083206032b020310face156d4a4685e2fcaec2f6f3665aa635d90347b6ce124eb879266b1e801d185de36a0a289b85e9039662634f2eea1e02e670bc7ab849d006a70b2f93b84597558a05b879c8d445f387a5d5b653df"
        });
        cases[3] = SignCase({
            name: "sign_case_7055381f640f2c1d",
            privkey: 0x328388aff0d4a5b7dc9205abd374e7e98f3cd9f3418edb4eafda5fb16473d216,
            message: 0x0000000000000000000000000000000000000000000000000000000000000000,
            signature: hex"948a7cb99f76d616c2c564ce9bf4a519f1bea6b0a624a02276443c245854219fabb8d4ce061d255af5330b078d5380681751aa7053da2c98bae898edc218c75f07e24d8802a17cd1f6833b71e58f5eb5b94208b4d0bb3848cecb075ea21be115"
        });
        cases[4] = SignCase({
            name: "sign_case_84d45c9c7cca6b92",
            privkey: 0x328388aff0d4a5b7dc9205abd374e7e98f3cd9f3418edb4eafda5fb16473d216,
            message: 0xabababababababababababababababababababababababababababababababab,
            signature: hex"ae82747ddeefe4fd64cf9cedb9b04ae3e8a43420cd255e3c7cd06a8d88b7c7f8638543719981c5d16fa3527c468c25f0026704a6951bde891360c7e8d12ddee0559004ccdbe6046b55bae1b257ee97f7cdb955773d7cf29adf3ccbb9975e4eb9"
        });
        cases[5] = SignCase({
            name: "sign_case_8cd3d4d0d9a5b265",
            privkey: 0x328388aff0d4a5b7dc9205abd374e7e98f3cd9f3418edb4eafda5fb16473d216,
            message: 0x5656565656565656565656565656565656565656565656565656565656565656,
            signature: hex"a4efa926610b8bd1c8330c918b7a5e9bf374e53435ef8b7ec186abf62e1b1f65aeaaeb365677ac1d1172a1f5b44b4e6d022c252c58486c0a759fbdc7de15a756acc4d343064035667a594b4c2a6f0b0b421975977f297dba63ee2f63ffe47bb6"
        });
        cases[6] = SignCase({
            name: "sign_case_c82df61aa3ee60fb",
            privkey: 0x263dbd792f5b1be47ed85f8938c0f29586af0d3ac7b977f21c278fe1462040e3,
            message: 0x0000000000000000000000000000000000000000000000000000000000000000,
            signature: hex"b6ed936746e01f8ecf281f020953fbf1f01debd5657c4a383940b020b26507f6076334f91e2366c96e9ab279fb5158090352ea1c5b0c9274504f4f0e7053af24802e51e4568d164fe986834f41e55c8e850ce1f98458c0cfc9ab380b55285a55"
        });
        cases[7] = SignCase({
            name: "sign_case_d0e28d7e76eb6e9c",
            privkey: 0x263dbd792f5b1be47ed85f8938c0f29586af0d3ac7b977f21c278fe1462040e3,
            message: 0x5656565656565656565656565656565656565656565656565656565656565656,
            signature: hex"882730e5d03f6b42c3abc26d3372625034e1d871b65a8a6b900a56dae22da98abbe1b68f85e49fe7652a55ec3d0591c20767677e33e5cbb1207315c41a9ac03be39c2e7668edc043d6cb1d9fd93033caa8a1c5b0e84bedaeb6c64972503a43eb"
        });
        cases[8] = SignCase({
            name: "sign_case_f2ae1097e7d0e18b",
            privkey: 0x263dbd792f5b1be47ed85f8938c0f29586af0d3ac7b977f21c278fe1462040e3,
            message: 0xabababababababababababababababababababababababababababababababab,
            signature: hex"91347bccf740d859038fcdcaf233eeceb2a436bcaaee9b2aa3bfb70efe29dfb2677562ccbea1c8e061fb9971b0753c240622fab78489ce96768259fc01360346da5b9f579e5da0d941e4c6ba18a0e64906082375394f337fa1af2b7127b0d121"
        });
    }

    function hashToG2Cases() internal pure returns (HashToG2Case[] memory cases) {
        cases = new HashToG2Case[](3);
        cases[0] = HashToG2Case({
            message: 0x0000000000000000000000000000000000000000000000000000000000000000,
            point: BLS12_381.G2Point({
                x_c0_a: 0x00000000000000000000000000000000076e5cd6cfb3c361fc767e5f40ce0548,
                x_c0_b: 0x6e1668825ffeecab89d7daa455a179736a387ae93b9b15d283d45ffa14cd4af7,
                x_c1_a: 0x0000000000000000000000000000000017502412bcfc3f1d88b71f1ad9b60fa3,
                x_c1_b: 0x7c332d19466fba1dc991d42bcd09bcd9f1c22a562646ffce0922793b6c69938b,
                y_c0_a: 0x0000000000000000000000000000000006740fd1dd8669dd6938f89bb6f45fe8,
                y_c0_b: 0x8d98e2ddb5a3938af14b6384ca8f09ef57c612076236638f9ff93fc2f77824a0,
                y_c1_a: 0x000000000000000000000000000000000b5870882f02ad57dac847d25b00412a,
                y_c1_b: 0x74c4d16c004e9ae3801e85c3785d497dda79e2c68c6aaf77a165640cb4399237
            })
        });
        cases[1] = HashToG2Case({
            message: 0x5656565656565656565656565656565656565656565656565656565656565656,
            point: BLS12_381.G2Point({
                x_c0_a: 0x000000000000000000000000000000000a8f9dbc3952222c0f76aff9725e56ef,
                x_c0_b: 0x2b0577399ef76a5dc3884d33ecd8f01f02d01c2563afb858e1f702f66f443144,
                x_c1_a: 0x000000000000000000000000000000000c3c33dfebb2e485a637903c7b5d274e,
                x_c1_b: 0x25d47e037a32252efacc7d51238d5be40d174946a77d261c1fa7c42894071f81,
                y_c0_a: 0x00000000000000000000000000000000167977563ff98edfdc19547eca8ad66e,
                y_c0_b: 0xf9487964ba6d8d00612594e012fa3035eef292b164515a29232ce7f65c5403da,
                y_c1_a: 0x000000000000000000000000000000000415071af604f7a2a48b34cdd570cd74,
                y_c1_b: 0x9b11790d5560254c676f4f182c43443f82983907a7828c56e4a2f35930df5763
            })
        });
        cases[2] = HashToG2Case({
            message: 0xabababababababababababababababababababababababababababababababab,
            point: BLS12_381.G2Point({
                x_c0_a: 0x000000000000000000000000000000000bc0f071f2d0655a5edbf6b9208a6649,
                x_c0_b: 0xd3309b8692d2f55bde74c52cc2de0fed2bb60b4c45935b11c32827da1b80cb8f,
                x_c1_a: 0x00000000000000000000000000000000179451d90ade914f7a6ffc5062914af9,
                x_c1_b: 0x90af297abdebf81dcebcaff93a5cb959e7f5db624bc8abb8cdb2660374c86a35,
                y_c0_a: 0x0000000000000000000000000000000010bf383a073a41e693ccc01d380c040c,
                y_c0_b: 0x1aedae63e5ecca4bba4013638718e0f02a7656ffcb1f93c419483f820dc07129,
                y_c1_a: 0x000000000000000000000000000000000c2309a40a73adc91fb43fcb8589048e,
                y_c1_b: 0x0141616d978e120dc4d354b502d93fe74443dec6a00d1f80a487ed4bdfea41c2
            })
        });
    }
}
