#! /bin/bash

# Fails if any deployable PRODUCTION contract exceeds the EIP-170 runtime bytecode limit.
#
# Why this exists rather than plain `forge build --sizes`: that command exits non-zero on the
# whole build, and three test-only harnesses (AccountingRiverV1, RiverV1ForceCommittable,
# RedemptionRiverV1) are already over the limit by design — they bolt extra helpers onto RiverV1.
# So the unscoped command can never be used as a gate. This script scopes the check to contracts
# declared under
# contracts/src (excluding interfaces/ and mock/), which is exactly the set that gets deployed.
#
# RiverV1 runs close to the limit and every cheap lever is already spent (see foundry.toml:
# optimizer_runs = 3, via_ir, bytecode_hash = none). Anything that widens the oracle report
# struct grows River, so this needs to be checked on every change.
#
# NOTE: this measures the FOUNDRY build. The deploy pipeline compiles with hardhat using looser
# settings (hardhat.config.ts: optimizer runs 100, default ipfs bytecodeHash, evmVersion osaka),
# which produces LARGER bytecode. A green run here is necessary but not sufficient — the hardhat
# side is gated separately by `contractSizer.strict` in hardhat.config.ts.
#
# Usage:
#   ./scripts/check_contract_sizes.sh
#   MIN_RUNTIME_MARGIN=2048 ./scripts/check_contract_sizes.sh   # also fail if margin is too thin

set -euo pipefail

EIP170_LIMIT=24576
MIN_RUNTIME_MARGIN="${MIN_RUNTIME_MARGIN:-0}"

cd "$(dirname "$0")/.."

# Names of every non-abstract contract and every library declared in production sources.
# Internal-only libraries compile to ~16 byte stubs and pass trivially; LibOracleReporting is
# the one that is genuinely deployed and worth watching.
PRODUCTION_NAMES=$(
  find contracts/src -name '*.sol' -not -path '*/interfaces/*' -not -path '*/mock/*' -print0 |
    xargs -0 grep -hE '^(contract|library) [A-Za-z0-9_]+' |
    sed -E 's/^(contract|library) ([A-Za-z0-9_]+).*/\2/' |
    sort -u
)

if [ -z "$PRODUCTION_NAMES" ]; then
  echo "error: found no production contract declarations under contracts/src" >&2
  exit 1
fi

# `forge build --sizes` exits 1 when anything in the build is oversized, so tolerate that here
# and let the scoped comparison below decide.
SIZES_JSON=$(forge build --sizes --json 2>/dev/null || true)

if [ -z "$SIZES_JSON" ]; then
  echo "error: forge build --sizes --json produced no output" >&2
  exit 1
fi

NAMES_JSON=$(echo "$PRODUCTION_NAMES" | jq -R -s -c 'split("\n") | map(select(length > 0))')

jq -n \
    --argjson names "$NAMES_JSON" \
    --argjson sizes "$SIZES_JSON" \
    --argjson limit "$EIP170_LIMIT" \
    --argjson minMargin "$MIN_RUNTIME_MARGIN" '
    [ $names[]
      | select($sizes[.] != null)
      | { name: ., size: $sizes[.].runtime_size, margin: $sizes[.].runtime_margin }
    ] as $checked
    | ($checked | map(select(.size > $limit))) as $over
    | ($checked | map(select(.margin < $minMargin and .size <= $limit))) as $thin
    | {
        checked: ($checked | length),
        limit: $limit,
        minMargin: $minMargin,
        tightest: ($checked | sort_by(.margin) | .[0:8]),
        over: $over,
        thin: $thin
      }
  ' >/tmp/lc_sizes_report.json

python3 - <<'PY'
import json
import sys

with open("/tmp/lc_sizes_report.json") as fh:
    r = json.load(fh)

print(f"EIP-170 runtime limit: {r['limit']} bytes — checked {r['checked']} production contracts")
print()
print(f"{'contract':<48}{'runtime':>10}{'margin':>10}")
for c in r["tightest"]:
    print(f"{c['name']:<48}{c['size']:>10}{c['margin']:>10}")
print()

failed = False

if r["over"]:
    failed = True
    print("FAIL: over the EIP-170 limit:")
    for c in r["over"]:
        print(f"  {c['name']}: {c['size']} bytes ({-c['margin']} over)")

if r["thin"]:
    failed = True
    print(f"FAIL: runtime margin below MIN_RUNTIME_MARGIN={r['minMargin']}:")
    for c in r["thin"]:
        print(f"  {c['name']}: margin {c['margin']}")

if failed:
    sys.exit(1)

print("OK: every production contract is within the EIP-170 limit.")
PY
