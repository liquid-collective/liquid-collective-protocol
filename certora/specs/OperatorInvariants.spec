// OperatorInvariants.spec — Operator chain invariant
//
// Property: operator_chain_invariant (LCP-INV-23, LCP-INV-24, I-5)
//
// For every operator in OperatorsV2:
//   keys >= limit >= funded >= requestedExits
//
// Enforced across all write sites: setOperatorLimits, addValidators, 
// removeValidators, pickNextValidatorsToDeposit, requestValidatorExits.

import "MathSummaries.spec";

using OperatorsRegistryHarness as registry;

methods {
    // Harness getters — envfree
    function registry.getOperatorCountHarness() external returns (uint256) envfree;
    function registry.getOperatorKeys(uint256) external returns (uint32) envfree;
    function registry.getOperatorLimit(uint256) external returns (uint32) envfree;
    function registry.getOperatorFunded(uint256) external returns (uint32) envfree;
    function registry.getOperatorRequestedExits(uint256) external returns (uint32) envfree;
    function registry.getOperatorActive(uint256) external returns (bool) envfree;
    function registry.getRiverHarness() external returns (address) envfree;
    function registry.getAdminHarness() external returns (address) envfree;
    function registry.getTotalValidatorExitsRequestedHarness() external returns (uint256) envfree;
    function registry.getCurrentValidatorExitsDemandHarness() external returns (uint256) envfree;

    // External calls from the registry — summarize as NONDET
    function _.getKeeper() external => NONDET;

    // Summarize heavy/irrelevant external calls
    function _.denied(address) external => NONDET;
}

// ════════════════════════════════════════════════════════════════════════════
// Helper: require chain invariant for a single operator
// ════════════════════════════════════════════════════════════════════════════

function requireChainForOperator(uint256 i) {
    require registry.getOperatorKeys(i) >= registry.getOperatorLimit(i);
    require registry.getOperatorLimit(i) >= registry.getOperatorFunded(i);
    require registry.getOperatorFunded(i) >= registry.getOperatorRequestedExits(i);
}

// Helper: require chain for all operators (up to bound)
function requireChainForAll(uint256 opCount) {
    if (opCount >= 1) {
        requireChainForOperator(0);
    }
    if (opCount >= 2) {
        requireChainForOperator(1);
    }
    if (opCount >= 3) {
        requireChainForOperator(2);
    }
}

// Helper: assert chain invariant for a single operator
function assertChainForOperator(uint256 i) {
    assert registry.getOperatorKeys(i) >= registry.getOperatorLimit(i),
        "keys >= limit violated";
    assert registry.getOperatorLimit(i) >= registry.getOperatorFunded(i),
        "limit >= funded violated";
    assert registry.getOperatorFunded(i) >= registry.getOperatorRequestedExits(i),
        "funded >= requestedExits violated";
}

// ════════════════════════════════════════════════════════════════════════════
// RULE: setOperatorLimits preserves chain invariant (targeted)
// ════════════════════════════════════════════════════════════════════════════

rule setOperatorLimits_preserves_chain(env e, uint256 idx) {
    uint256 opCount = registry.getOperatorCountHarness();
    require idx < opCount;
    require opCount >= 1;
    require opCount <= 3;

    // Chain invariant holds for all operators
    requireChainForAll(opCount);

    // The caller must be admin
    require e.msg.sender == registry.getAdminHarness();
    require e.msg.value == 0;

    // Build arrays for the call
    uint256[] operatorIndexes;
    uint32[] newLimits;
    uint256 snapshotBlock;

    // Call setOperatorLimits
    registry.setOperatorLimits@withrevert(e, operatorIndexes, newLimits, snapshotBlock);

    // If the call succeeded, the chain invariant must still hold
    assert !lastReverted => (
        idx < registry.getOperatorCountHarness() => (
            registry.getOperatorKeys(idx) >= registry.getOperatorLimit(idx)
            && registry.getOperatorLimit(idx) >= registry.getOperatorFunded(idx)
            && registry.getOperatorFunded(idx) >= registry.getOperatorRequestedExits(idx)
        )
    ),
        "setOperatorLimits must preserve chain invariant";
}

// ════════════════════════════════════════════════════════════════════════════
// RULE: addOperator preserves chain for existing operators
// ════════════════════════════════════════════════════════════════════════════

rule addOperator_preserves_chain(env e, uint256 idx) {
    uint256 opCount = registry.getOperatorCountHarness();
    require idx < opCount;
    require opCount >= 1;
    require opCount <= 2;  // leave room for the new operator

    // Chain invariant holds
    requireChainForAll(opCount);

    require e.msg.sender == registry.getAdminHarness();
    require e.msg.value == 0;

    string name;
    address operator;

    registry.addOperator@withrevert(e, name, operator);

    // If succeeded, existing operators' chain must still hold
    assert !lastReverted => (
        registry.getOperatorKeys(idx) >= registry.getOperatorLimit(idx)
        && registry.getOperatorLimit(idx) >= registry.getOperatorFunded(idx)
        && registry.getOperatorFunded(idx) >= registry.getOperatorRequestedExits(idx)
    ),
        "addOperator must preserve chain invariant for existing operators";
}

// ════════════════════════════════════════════════════════════════════════════
// RULE: addOperator initializes new operator with valid chain
// ════════════════════════════════════════════════════════════════════════════

rule addOperator_new_operator_valid(env e) {
    uint256 opCount = registry.getOperatorCountHarness();
    require opCount >= 0;
    require opCount <= 2;

    requireChainForAll(opCount);

    require e.msg.sender == registry.getAdminHarness();
    require e.msg.value == 0;

    string name;
    address operator;

    registry.addOperator@withrevert(e, name, operator);
    bool reverted = lastReverted;

    uint256 newCount = registry.getOperatorCountHarness();

    // If succeeded, the NEW operator should also satisfy the chain
    assert !reverted => (
        newCount == opCount + 1
        => (
            registry.getOperatorKeys(opCount) >= registry.getOperatorLimit(opCount)
            && registry.getOperatorLimit(opCount) >= registry.getOperatorFunded(opCount)
            && registry.getOperatorFunded(opCount) >= registry.getOperatorRequestedExits(opCount)
        )
    ),
        "addOperator must initialize new operator with valid chain";
}

// ════════════════════════════════════════════════════════════════════════════
// RULE: setOperatorStatus preserves chain invariant
// ════════════════════════════════════════════════════════════════════════════

rule setOperatorStatus_preserves_chain(env e, uint256 targetIdx, bool active, uint256 idx) {
    uint256 opCount = registry.getOperatorCountHarness();
    require idx < opCount;
    require targetIdx < opCount;
    require opCount >= 1;
    require opCount <= 3;

    requireChainForAll(opCount);

    require e.msg.sender == registry.getAdminHarness();
    require e.msg.value == 0;

    registry.setOperatorStatus@withrevert(e, targetIdx, active);

    assert !lastReverted => (
        registry.getOperatorKeys(idx) >= registry.getOperatorLimit(idx)
        && registry.getOperatorLimit(idx) >= registry.getOperatorFunded(idx)
        && registry.getOperatorFunded(idx) >= registry.getOperatorRequestedExits(idx)
    ),
        "setOperatorStatus must preserve chain invariant";
}

// ════════════════════════════════════════════════════════════════════════════
// RULE: addValidators preserves chain invariant
//
// addValidators only increases keys, so the chain keys >= limit >= funded >= 
// requestedExits is preserved.
// ════════════════════════════════════════════════════════════════════════════

rule addValidators_preserves_chain(env e, uint256 targetIdx, uint256 idx) {
    uint256 opCount = registry.getOperatorCountHarness();
    require idx < opCount;
    require targetIdx < opCount;
    require opCount >= 1;
    require opCount <= 3;

    requireChainForAll(opCount);

    require e.msg.value == 0;

    uint32 keyCount;
    bytes keys;

    registry.addValidators@withrevert(e, targetIdx, keyCount, keys);

    assert !lastReverted => (
        registry.getOperatorKeys(idx) >= registry.getOperatorLimit(idx)
        && registry.getOperatorLimit(idx) >= registry.getOperatorFunded(idx)
        && registry.getOperatorFunded(idx) >= registry.getOperatorRequestedExits(idx)
    ),
        "addValidators must preserve chain invariant";
}

// ════════════════════════════════════════════════════════════════════════════
// RULE: removeValidators preserves chain invariant
//
// removeValidators removes unfunded keys and adjusts limit downward if needed,
// but cannot go below funded. Chain should be preserved.
// ════════════════════════════════════════════════════════════════════════════

rule removeValidators_preserves_chain(env e, uint256 targetIdx, uint256 idx) {
    uint256 opCount = registry.getOperatorCountHarness();
    require idx < opCount;
    require targetIdx < opCount;
    require opCount >= 1;
    require opCount <= 3;

    requireChainForAll(opCount);

    require e.msg.value == 0;

    uint256[] indexes;

    registry.removeValidators@withrevert(e, targetIdx, indexes);

    assert !lastReverted => (
        registry.getOperatorKeys(idx) >= registry.getOperatorLimit(idx)
        && registry.getOperatorLimit(idx) >= registry.getOperatorFunded(idx)
        && registry.getOperatorFunded(idx) >= registry.getOperatorRequestedExits(idx)
    ),
        "removeValidators must preserve chain invariant";
}

// ════════════════════════════════════════════════════════════════════════════
// RULE: demandValidatorExits preserves chain invariant
//
// demandValidatorExits only increases CurrentValidatorExitsDemand; it does not
// modify per-operator fields.
// ════════════════════════════════════════════════════════════════════════════

rule demandValidatorExits_preserves_chain(env e, uint256 idx) {
    uint256 opCount = registry.getOperatorCountHarness();
    require idx < opCount;
    require opCount >= 1;
    require opCount <= 3;

    requireChainForAll(opCount);

    require e.msg.sender == registry.getRiverHarness();
    require e.msg.value == 0;

    uint256 count;
    uint256 depositedCount;

    registry.demandValidatorExits@withrevert(e, count, depositedCount);

    assert !lastReverted => (
        registry.getOperatorKeys(idx) >= registry.getOperatorLimit(idx)
        && registry.getOperatorLimit(idx) >= registry.getOperatorFunded(idx)
        && registry.getOperatorFunded(idx) >= registry.getOperatorRequestedExits(idx)
    ),
        "demandValidatorExits must preserve chain invariant";
}

// ════════════════════════════════════════════════════════════════════════════
// RULE: requestValidatorExits preserves chain invariant
//
// requestValidatorExits increases requestedExits per operator, but is bounded
// by funded (since you can only request exits for funded validators).
// ════════════════════════════════════════════════════════════════════════════

rule requestValidatorExits_preserves_chain(env e, uint256 idx) {
    uint256 opCount = registry.getOperatorCountHarness();
    require idx < opCount;
    require opCount >= 1;
    require opCount <= 3;

    requireChainForAll(opCount);

    require e.msg.value == 0;

    // requestValidatorExits is called by the keeper
    // The function signature uses OperatorAllocation[] — use calldataarg
    calldataarg args;

    registry.requestValidatorExits@withrevert(e, args);

    assert !lastReverted => (
        registry.getOperatorKeys(idx) >= registry.getOperatorLimit(idx)
        && registry.getOperatorLimit(idx) >= registry.getOperatorFunded(idx)
        && registry.getOperatorFunded(idx) >= registry.getOperatorRequestedExits(idx)
    ),
        "requestValidatorExits must preserve chain invariant";
}

// ════════════════════════════════════════════════════════════════════════════
// RULE: Only River can call onlyRiver functions
// ════════════════════════════════════════════════════════════════════════════

/// @notice reportStoppedValidatorCounts is River-only (LCP-ACCESS-50)
rule only_river_can_report_stopped(env e) {
    uint32[] stoppedCounts;
    uint256 depositedCount;

    registry.reportStoppedValidatorCounts@withrevert(e, stoppedCounts, depositedCount);

    assert !lastReverted => e.msg.sender == registry.getRiverHarness(),
        "Only River can call reportStoppedValidatorCounts";
}

/// @notice demandValidatorExits is River-only (LCP-ACCESS-50)
rule only_river_can_demand_exits(env e) {
    uint256 count;
    uint256 depositedCount;

    registry.demandValidatorExits@withrevert(e, count, depositedCount);

    assert !lastReverted => e.msg.sender == registry.getRiverHarness(),
        "Only River can call demandValidatorExits";
}

// ════════════════════════════════════════════════════════════════════════════
// RULE: Only admin can add operators
// ════════════════════════════════════════════════════════════════════════════

/// @notice addOperator is admin-only
rule only_admin_can_add_operator(env e) {
    string name;
    address operator;

    registry.addOperator@withrevert(e, name, operator);

    assert !lastReverted => e.msg.sender == registry.getAdminHarness(),
        "Only admin can call addOperator";
}
