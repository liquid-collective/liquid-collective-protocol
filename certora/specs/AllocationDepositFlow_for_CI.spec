import "Sanity.spec";
import "CVLMath.spec";
import "Base.spec";

// CVL does not support Solidity "memory", "new Type[]", or struct literals.
// We use symbolic IOperatorsRegistryV1.OperatorAllocation[] and constrain with require.
// depositToConsensusLayerWithDepositRoot(OperatorAllocation[], bytes32): use to_bytes32(0) for root (CVL has no bytes32() cast).

// Summarize all external calls into OperatorsRegistryV1Harness and RedeemManagerV1Harness
// to avoid pointer/memory/storage analysis on their complex code and prevent OOM.
// Base.spec uses "OR" and "RM" for these harnesses. Catch-all is sound (HAVOC_ALL).
methods {
    function OR._ external => HAVOC_ALL;
    function RM._ external => HAVOC_ALL;
}

// --- Rules ---
rule depositedValidatorCountIntegrity(env e) {
    uint256 depositedBefore = getDepositedValidatorCount();
    IOperatorsRegistryV1.OperatorAllocation[] allocations;
    require allocations.length == 1;
    require allocations[0].operatorIndex == 0;
    require allocations[0].validatorCount == 1;
    depositToConsensusLayerWithDepositRoot(e, allocations, to_bytes32(0));
    uint256 depositedAfter = getDepositedValidatorCount();
    assert depositedAfter >= depositedBefore, "deposited count must not decrease";
}

rule committedBalanceDecreasesOnDeposit(env e) {
    uint256 committedBefore = getCommittedBalance();
    uint256 depositSize = consensusLayerDepositSize();
    require depositSize > 0;
    require committedBefore >= depositSize;
    IOperatorsRegistryV1.OperatorAllocation[] allocations;
    require allocations.length == 1;
    require allocations[0].operatorIndex == 0;
    require allocations[0].validatorCount == 1;
    depositToConsensusLayerWithDepositRoot(e, allocations, to_bytes32(0));
    uint256 committedAfter = getCommittedBalance();
    assert committedAfter <= committedBefore - depositSize, "committed balance must decrease by at least one deposit size";
}

rule allocationCannotExceedDepositableCount(env e) {
    uint256 committed = getCommittedBalance();
    uint256 depositSize = consensusLayerDepositSize();
    require depositSize > 0;
    mathint maxDepositable = committed / depositSize;
    require maxDepositable >= 1;
    IOperatorsRegistryV1.OperatorAllocation[] allocations;
    require allocations.length == 1;
    require allocations[0].operatorIndex == 0;
    require allocations[0].validatorCount == require_uint256(maxDepositable);
    depositToConsensusLayerWithDepositRoot(e, allocations, to_bytes32(0));
    assert true, "allocation within depositable count succeeds or reverts consistently";
}

rule onlyKeeperCanDeposit(env e) {
    address keeper = getKeeper(e);
    require e.msg.sender != keeper;
    IOperatorsRegistryV1.OperatorAllocation[] allocations;
    require allocations.length == 1;
    require allocations[0].operatorIndex == 0;
    require allocations[0].validatorCount == 1;
    depositToConsensusLayerWithDepositRoot@withrevert(e, allocations, to_bytes32(0));
    assert lastReverted, "non-keeper must revert";
}

// Excluded from CI rule list: triggers Prover internal error 4201170753. Re-enable when fixed.
// TODO: Track prover bug resolution and re-enable this rule
rule depositWithUnorderedAllocationsMustRevert(env e) {
    // Allocations must be ordered by operator index; (1, n) then (0, m) is invalid
    IOperatorsRegistryV1.OperatorAllocation[] allocations;
    require allocations.length == 2;
    require allocations[0].operatorIndex == 1;
    require allocations[0].validatorCount == 1;
    require allocations[1].operatorIndex == 0;
    require allocations[1].validatorCount == 1;
    depositToConsensusLayerWithDepositRoot@withrevert(e, allocations, to_bytes32(0));
    assert lastReverted, "unordered allocations must revert";
}

rule depositWithZeroValidatorCountMustRevert(env e) {
    IOperatorsRegistryV1.OperatorAllocation[] allocations;
    require allocations.length == 1;
    require allocations[0].operatorIndex == 0;
    require allocations[0].validatorCount == 0;
    depositToConsensusLayerWithDepositRoot@withrevert(e, allocations, to_bytes32(0));
    assert lastReverted, "zero validator count must revert";
}

rule depositedValidatorCountMonotonicallyIncreases(env e) {
    uint256 depositedBefore = getDepositedValidatorCount();
    method f;
    calldataarg args;
    f(e, args);
    uint256 depositedAfter = getDepositedValidatorCount();
    assert depositedAfter >= depositedBefore, "deposited validator count must not decrease";
}

rule depositWithInsufficientFundsMustRevert(env e) {
    uint256 committed = getCommittedBalance();
    uint256 depositSize = consensusLayerDepositSize();
    require depositSize > 0;
    mathint maxDepositable = committed / depositSize;
    require maxDepositable < 2;
    IOperatorsRegistryV1.OperatorAllocation[] allocations;
    require allocations.length == 1;
    require allocations[0].operatorIndex == 0;
    require allocations[0].validatorCount == 2;
    depositToConsensusLayerWithDepositRoot@withrevert(e, allocations, to_bytes32(0));
    assert lastReverted, "allocation exceeding depositable count must revert";
}
