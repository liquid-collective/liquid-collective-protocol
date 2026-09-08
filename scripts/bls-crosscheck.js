#!/usr/bin/env node
//
// Cross-checks the Solidity BLS signer (contracts/test/utils/BLSSigner.sol) against an
// independent implementation, noble-curves.
//
// Why this exists: BLSSigner and contracts/src/libraries/BLS12_381.sol are otherwise only
// checked against each other. The Foundry suite proves they agree, but they would also agree if
// both diverged from the Ethereum spec in the same way, and every deposit-test signature would
// then be consistently wrong. BLSSignerValidation/BLSVectors.sol pins them to the official
// ethereum/bls12-381-tests `sign` fixtures; this script is the wider net, checking freshly derived
// keys and signatures over arbitrary deposit amounts rather than the nine fixed official cases.
//
// Usage: npm run bls:crosscheck
//
// Requires `@noble/curves` (a declared dependency) and `forge` on PATH.

const { execFileSync } = require("node:child_process");
const { bls12_381 } = require("@noble/curves/bls12-381");

// The Ethereum deposit ciphersuite. noble defaults to the `_NUL_` basic scheme, so this must be
// passed explicitly or every signature comparison fails for the wrong reason.
const DST = "BLS_SIG_BLS12381G2_XMD:SHA-256_SSWU_RO_POP_";

const toBytes = (hex) => Uint8Array.from(Buffer.from(hex.replace(/^0x/, ""), "hex"));
const toHex = (bytes) => "0x" + Buffer.from(bytes).toString("hex");

const EMITTER = "contracts/test/utils/BLSSignerValidation/BLSCrosscheckVectors.s.sol";

function emitVectorsFromSolidity() {
  let out;
  try {
    out = execFileSync("forge", ["script", EMITTER], {
      encoding: "utf8",
      maxBuffer: 64 * 1024 * 1024,
    });
  } catch (err) {
    // A failing or non-compiling emitter is itself a signal worth reporting plainly, rather than
    // letting an execFileSync stack trace bury it.
    console.error(`forge script failed while emitting vectors from ${EMITTER}:\n`);
    console.error(err.stdout || err.message);
    process.exit(1);
  }

  // Each record: `XCHK <seed> <amount> <sk> <signingRoot> <pubkey> <signature>`
  const vectors = [];
  for (const line of out.split("\n")) {
    const parts = line.trim().split(/\s+/);
    if (parts[0] !== "XCHK") continue;
    if (parts.length !== 7) {
      console.error(`malformed XCHK record (${parts.length - 1} fields, expected 6): ${line.trim()}`);
      process.exit(1);
    }
    const [, seed, amount, sk, root, pk, sig] = parts;
    vectors.push({ seed, amount, sk, root, pk, sig });
  }
  return vectors;
}

function main() {
  const vectors = emitVectorsFromSolidity();
  if (vectors.length === 0) {
    console.error(`no vectors emitted — did ${EMITTER} run?`);
    process.exit(1);
  }

  let failures = 0;
  for (const v of vectors) {
    const sk = BigInt(v.sk);
    const msg = toBytes(v.root);

    const noblePubkey = toHex(bls12_381.getPublicKey(sk));
    const nobleSig = toHex(bls12_381.sign(msg, sk, { DST }));
    // Independent verification of the Solidity-produced signature, not just byte equality.
    const nobleVerifies = bls12_381.verify(toBytes(v.sig), msg, toBytes(v.pk), { DST });

    const problems = [];
    if (noblePubkey !== v.pk) problems.push(`pubkey: noble=${noblePubkey} solidity=${v.pk}`);
    if (nobleSig !== v.sig) problems.push(`signature: noble=${nobleSig} solidity=${v.sig}`);
    if (!nobleVerifies) problems.push("noble rejected the Solidity signature");

    if (problems.length > 0) {
      failures++;
      console.error(`FAIL seed=${v.seed} amount=${v.amount}`);
      for (const p of problems) console.error(`  ${p}`);
    }
  }

  const checked = vectors.length;
  if (failures > 0) {
    console.error(`\n${failures}/${checked} vectors diverge from noble-curves`);
    process.exit(1);
  }
  console.log(`OK  ${checked}/${checked} vectors match noble-curves (pubkey, signature, verify)`);
  console.log(`    ciphersuite ${DST}`);
}

main();
