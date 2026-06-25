#!/usr/bin/env bash
# Assert that all 8 v1.3.0 implementation contracts are byte-equivalent to
# the canonical reference: deployedBytecode committed in deployments/hoodi/
# on branch chore/mainnet-upgrade (Hoodi staging, PR #615).
#
# Note: the v1.3.0 GitHub release tag does NOT contain these artifacts —
# the 1_3_0 implementation files were committed after the tag in cf06a6f5.
# However, contracts/src/ is identical between the tag and that commit
# (zero diff), so the bytecode comparison is valid against the release source.
#
# No Hoodi RPC needed — bytecode is read from the local artifact files.
#
# Usage:
#   bash scripts/compare_bytecode.sh
#
# Tip — avoid zsh history-expansion errors: invoke with `bash`, not `zsh`.

set -euo pipefail

# ── 1. Assign your freshly-deployed mainnet / Tenderly fork addresses ─────────
# Order matches 19_upgrade_v1_3_0_proxies.ts
# Phase 1 — direct-admin proxies
MAINNET_WITHDRAW_IMPL="0x94a470be6a17d0f5db490dc2d80febceac33a1ce"
MAINNET_COVERAGE_FUND_IMPL="0x46bdea883c174c9c91e46dcd978d8713c42bca99"
MAINNET_EL_FEE_RECIPIENT_IMPL="0x066d3244359649f5a557401c0ee1494dfccf263f"
# Phase 2 — firewalled proxies
MAINNET_ALLOWLIST_IMPL="0x04b5a28d1c08b4a4bec74405d3e7b0351ac27fdb"
MAINNET_OPERATORS_REGISTRY_IMPL="0x15521d87f93d99903eb03ec5132fd0b3e8efc3cd"
MAINNET_ORACLE_IMPL="0x8784d7318e8809f4703666c6b1d0bd601d55ec6e"
MAINNET_REDEEM_MANAGER_IMPL="0xe87e766f9a8dd042b60f92e8264ed057a379b4f6"
# Phase 3 — River
MAINNET_RIVER_IMPL="0xf8cc01a92b9a5d07ff5adefaac31a789d1124661"

# ── 2. Mainnet / Tenderly fork RPC ────────────────────────────────────────────
RPC_MAINNET="${RPC_MAINNET:-https://virtual.mainnet.eu.rpc.tenderly.co/liquid-collective/liquid-collective-mainnet/1deda0-b0dda7}"

# ── 3. Reference bytecode — from committed hoodi artifacts (PR #615 / v1.3.0) ─
#    These are read automatically from deployments/hoodi/ — do not edit.
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ARTIFACTS_DIR="$REPO_ROOT/deployments/hoodi"

# ── helpers ───────────────────────────────────────────────────────────────────
PASS=0
FAIL=0
SKIP=0

compare() {
  local name=$1
  local artifact_file="$ARTIFACTS_DIR/${name}V1_Implementation_1_3_0.json"
  local mainnet_addr=$2

  if [[ -z "$mainnet_addr" ]]; then
    echo "⚠️  SKIP  $name  (mainnet address not set)"
    SKIP=$((SKIP + 1))
    return
  fi

  if [[ ! -f "$artifact_file" ]]; then
    echo "❌  FAIL  $name  (artifact not found: $artifact_file)"
    FAIL=$((FAIL + 1))
    return
  fi

  # Extract deployedBytecode and address from the committed artifact
  local ref_bytecode ref_addr
  ref_bytecode=$(python3 -c "import json,sys; d=json.load(open('$artifact_file')); print(d['deployedBytecode'])")
  ref_addr=$(python3    -c "import json,sys; d=json.load(open('$artifact_file')); print(d['address'])")

  # Fetch runtime bytecode from the target chain
  local mainnet_bytecode
  mainnet_bytecode=$(cast code "$mainnet_addr" --rpc-url "$RPC_MAINNET")

  if [[ "$ref_bytecode" == "$mainnet_bytecode" ]]; then
    echo "✅  OK    $name"
    echo "         artifact (hoodi/v1.3.0): $ref_addr"
    echo "         mainnet/fork:            $mainnet_addr"
    PASS=$((PASS + 1))
  else
    echo "❌  FAIL  $name  — bytecode mismatch"
    echo "         artifact (hoodi/v1.3.0): $ref_addr"
    echo "         mainnet/fork:            $mainnet_addr"
    echo "         ref length:     ${#ref_bytecode}"
    echo "         mainnet length: ${#mainnet_bytecode}"
    diff <(echo "$ref_bytecode") <(echo "$mainnet_bytecode") || true
    FAIL=$((FAIL + 1))
  fi
}

# ── run ───────────────────────────────────────────────────────────────────────
echo "Comparing v1.3.0 implementations against committed hoodi artifacts (PR #615 / v1.3.0 release)"
echo "  Reference artifacts: $ARTIFACTS_DIR"
echo "  Mainnet/fork RPC:    $RPC_MAINNET"
echo ""

compare "Withdraw"          "$MAINNET_WITHDRAW_IMPL"
compare "CoverageFund"      "$MAINNET_COVERAGE_FUND_IMPL"
compare "ELFeeRecipient"    "$MAINNET_EL_FEE_RECIPIENT_IMPL"
compare "Allowlist"         "$MAINNET_ALLOWLIST_IMPL"
compare "OperatorsRegistry" "$MAINNET_OPERATORS_REGISTRY_IMPL"
compare "Oracle"            "$MAINNET_ORACLE_IMPL"
compare "RedeemManager"     "$MAINNET_REDEEM_MANAGER_IMPL"
compare "River"             "$MAINNET_RIVER_IMPL"

# ── summary ───────────────────────────────────────────────────────────────────
echo ""
echo "Results: ${PASS} passed  ${FAIL} failed  ${SKIP} skipped"

if [[ $FAIL -gt 0 ]]; then
  echo "Bytecode mismatch detected — do not proceed with the upgrade."
  exit 1
fi

if [[ $SKIP -gt 0 ]]; then
  echo "Some contracts were skipped. Fill in all 8 MAINNET_* addresses before signing off."
  exit 1
fi

echo "All 8 implementations are byte-equivalent to the Hoodi staging artifacts (PR #615, v1.3.0 source). ✅"
