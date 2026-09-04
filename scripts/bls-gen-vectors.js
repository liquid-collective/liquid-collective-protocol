#!/usr/bin/env node
//
// Regenerates contracts/test/utils/BLSSignerValidation/BLSVectors.sol.
//
// Two sources, deliberately:
//   1. The `sign` handler of ethereum/bls12-381-tests (CC0-1.0) — official, authoritative, and
//      conveniently keyed on `(privkey: bytes32, message: bytes32)`, which is exactly
//      BLSSigner.signRoot's signature.
//   2. hashToG2 expectations from noble-curves, because the official `hash_to_G2` fixtures use
//      arbitrary-length messages ("", "abc", 512 bytes) while BLS12_381.hashToG2 accepts only
//      bytes32, so they cannot be applied to it directly. Generated for the same 32-byte messages
//      as the official sign cases.
//
// Usage: npm run bls:vectors

const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { execFileSync } = require("node:child_process");
const { bls12_381 } = require("@noble/curves/bls12-381");

const TESTS_VERSION = "v0.1.2";
const TARBALL = `https://github.com/ethereum/bls12-381-tests/releases/download/${TESTS_VERSION}/bls_tests_json.tar.gz`;
const DST = "BLS_SIG_BLS12381G2_XMD:SHA-256_SSWU_RO_POP_";
const OUT = path.join(__dirname, "..", "contracts", "test", "utils", "BLSSignerValidation", "BLSVectors.sol");

function fetchOfficialSignCases() {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "bls-vectors-"));
  execFileSync("sh", ["-c", `curl -sL "${TARBALL}" | tar -xz -C "${dir}"`], { stdio: "inherit" });

  const signDir = path.join(dir, "sign");
  const cases = [];
  let zero = null;
  for (const file of fs.readdirSync(signDir).sort()) {
    const d = JSON.parse(fs.readFileSync(path.join(signDir, file), "utf8"));
    const entry = {
      name: path.basename(file, ".json"),
      privkey: d.input.privkey,
      message: d.input.message,
      signature: d.output,
    };
    // `output: null` marks an input the suite expects to be rejected.
    if (entry.signature === null) zero = entry;
    else cases.push(entry);
  }
  fs.rmSync(dir, { recursive: true, force: true });
  return { cases, zero };
}

/// Splits an Fp coordinate into the two words of EIP-2537's 64-byte encoding
/// (16 zero bytes || 48-byte limb).
function fpWords(n) {
  const h = n.toString(16).padStart(96, "0");
  return ["0x" + h.slice(0, 32).padStart(64, "0"), "0x" + h.slice(32)];
}

function hashToG2Cases(messages) {
  return messages.map((message) => {
    const p = bls12_381.G2.hashToCurve(Uint8Array.from(Buffer.from(message.slice(2), "hex")), { DST }).toAffine();
    const [x_c0_a, x_c0_b] = fpWords(p.x.c0);
    const [x_c1_a, x_c1_b] = fpWords(p.x.c1);
    const [y_c0_a, y_c0_b] = fpWords(p.y.c0);
    const [y_c1_a, y_c1_b] = fpWords(p.y.c1);
    return { message, x_c0_a, x_c0_b, x_c1_a, x_c1_b, y_c0_a, y_c0_b, y_c1_a, y_c1_b };
  });
}

function render({ cases, zero }, h2gCases) {
  const signBody = cases
    .map(
      (c, i) => `        cases[${i}] = SignCase({
            name: "${c.name}",
            privkey: ${c.privkey},
            message: ${c.message},
            signature: hex"${c.signature.slice(2)}"
        });`
    )
    .join("\n");

  const h2gBody = h2gCases
    .map(
      (c, i) => `        cases[${i}] = HashToG2Case({
            message: ${c.message},
            point: BLS12_381.G2Point({
                x_c0_a: ${c.x_c0_a},
                x_c0_b: ${c.x_c0_b},
                x_c1_a: ${c.x_c1_a},
                x_c1_b: ${c.x_c1_b},
                y_c0_a: ${c.y_c0_a},
                y_c0_b: ${c.y_c0_b},
                y_c1_a: ${c.y_c1_a},
                y_c1_b: ${c.y_c1_b}
            })
        });`
    )
    .join("\n");

  return `// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import {BLS12_381} from "../../../src/libraries/BLS12_381.sol";

/**
 * @title BLSVectors
 * @notice Known-answer test vectors for the \`BLS_SIG_BLS12381G2_XMD:SHA-256_SSWU_RO_POP_\`
 *         ciphersuite — the one Ethereum deposits use.
 * @dev GENERATED FILE, do not hand-edit. Regenerate with \`npm run bls:vectors\`.
 *
 *      \`signCases()\` is the \`sign\` handler of ethereum/bls12-381-tests ${TESTS_VERSION} (CC0-1.0),
 *      verbatim: https://github.com/ethereum/bls12-381-tests/releases/tag/${TESTS_VERSION}
 *      Its inputs are \`(privkey: bytes32, message: bytes32)\`, which lines up exactly with
 *      \`BLSSigner.signRoot\`. Because a signature is \`sk * hashToG2(message)\`, matching these also
 *      pins the production \`BLS12_381.hashToG2\` for 32-byte messages: a wrong hash-to-curve cannot
 *      produce a matching signature.
 *
 *      \`hashToG2Cases()\` covers \`BLS12_381.hashToG2\` directly, so a hash-to-curve regression is
 *      attributed at its source instead of only surfacing as a signature mismatch. The official
 *      \`hash_to_G2\` fixtures cannot be used for this: their messages are arbitrary-length
 *      (\`""\`, \`"abc"\`, 512 bytes) while this library only accepts \`bytes32\`. These expectations
 *      are therefore generated from noble-curves for the same 32-byte messages as the \`sign\`
 *      cases, and are re-checked by \`npm run bls:crosscheck\`.
 */
library BLSVectors {
    /// @dev One \`sign\` case: \`signRoot(privkey, message)\` must equal \`signature\`.
    struct SignCase {
        string name;
        uint256 privkey;
        bytes32 message;
        bytes signature;
    }

    /// @dev One hash-to-curve case: \`hashToG2(message)\` must equal \`point\`.
    struct HashToG2Case {
        bytes32 message;
        BLS12_381.G2Point point;
    }

    /// @dev Private key of the \`sign\` case the suite expects to be rejected (\`output: null\`).
    uint256 internal constant ZERO_PRIVKEY = ${zero.privkey};

    /// @dev Message paired with \`ZERO_PRIVKEY\` in that case.
    bytes32 internal constant ZERO_PRIVKEY_MESSAGE = ${zero.message};

    function signCases() internal pure returns (SignCase[] memory cases) {
        cases = new SignCase[](${cases.length});
${signBody}
    }

    function hashToG2Cases() internal pure returns (HashToG2Case[] memory cases) {
        cases = new HashToG2Case[](${h2gCases.length});
${h2gBody}
    }
}
`;
}

function main() {
  const official = fetchOfficialSignCases();
  const messages = [...new Set(official.cases.map((c) => c.message))].sort();
  const h2g = hashToG2Cases(messages);

  fs.writeFileSync(OUT, render(official, h2g));
  execFileSync("forge", ["fmt", OUT], { stdio: "inherit" });

  console.log(
    `wrote ${path.relative(process.cwd(), OUT)}: ` +
      `${official.cases.length} official sign cases, ${h2g.length} hashToG2 cases`
  );
}

main();
