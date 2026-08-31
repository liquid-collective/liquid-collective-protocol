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
 # Phase 1 — direct-admin proxies
  MAINNET_WITHDRAW_IMPL="0x0C3C4B761AB0d6fF500bC9a49f5EA2F7b79Af4f6"
  MAINNET_COVERAGE_FUND_IMPL="0xd4067A7d6b3E0FEC19307e7B89b4FC38867765E3"                                                                                                                                                                                                                
  MAINNET_EL_FEE_RECIPIENT_IMPL="0xbdA8Cc728b0BC6fE634b9D26667f6Cf4b03f73AA"                                                                                                                                                                                                             
  # Phase 2 — firewalled proxies                                                                                                                                                                                                                                                         
  MAINNET_ALLOWLIST_IMPL="0xCC1c4c94f0df9B4930f8aCf6C92F92e2e36F151D"                                                                                                                                                                                                                    
  MAINNET_OPERATORS_REGISTRY_IMPL="0x0170AEAb7B86805d5e7ff19FcDDF62F19575C37B"                                                                                                                                                                                                           
  MAINNET_ORACLE_IMPL="0x2a0cD2854d1F20b93487f438012d7045e398880d"                                                                                                                                                                                                                       
  MAINNET_REDEEM_MANAGER_IMPL="0xA56e13712436189f61aB9fDA1292b26Cf9FEf9F8"                                                                                                                                                                                                               
  # Phase 3 — River                                                                                                                                                                                                                                                                      
  MAINNET_RIVER_IMPL="0x0056f9ed62dAa4dc3F972340C92326AcCddd1a9D" 

# ── 2. Mainnet / Tenderly fork RPC ────────────────────────────────────────────
RPC_MAINNET="${RPC_MAINNET:-${RPC_URL:-}}"

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
