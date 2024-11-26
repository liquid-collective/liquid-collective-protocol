import "./../specs/Sanity.spec";
import "./../specs/CVLMath.spec";
import "./../specs/OperatorRegistryV1_base.spec";

// some functions require loop_iter = 4 but loop_iter = 2 is sufficient for most. For this reason we run parametric rule and invariants in two versions
//_LI4 for methods that require loop_iter = 4 and _LI2 for the others.

rule newNOHasZeroKeys(env e)
{
    require isValidState();
    address opAddress;
    uint newOpIndex;
    newOpIndex = addOperator(e, "newNO", opAddress);
    uint keysCount = getKeysCount(newOpIndex);
    assert keysCount == 0;
}

rule removeValidatorsRevertsIfKeysNotSorted(env e)
{
    require isValidState();
    uint i1; uint i2;
    uint256[] indices = [ i1, i2 ];
    uint opIndex;
    uint valIndex1; uint valIndex2;
    require valIndex1 < indices.length && valIndex2 < indices.length;
    require valIndex1 < valIndex2 && indices[valIndex1] < indices[valIndex2]; //not sorted
    removeValidators@withrevert(e, opIndex, indices);
    assert lastReverted;
}

rule removeValidatorsRevertsIfKeysDuplicit(env e)
{
    require isValidState();
    uint i1; uint i2;
    uint256[] indices = [ i1, i2 ];

    uint opIndex;
    uint valIndex1; uint valIndex2;
    require valIndex1 < indices.length && valIndex2 < indices.length;
    require valIndex1 != valIndex2 && indices[valIndex1] == indices[valIndex2]; //duplicit
    removeValidators@withrevert(e, opIndex, indices);
    assert lastReverted;
}

rule validatorStateTransition_1in_M15(method f, env e, calldataarg args) filtered 
    { f -> !f.isView  && isMethodID(f, 15) }
{
    require isValidState();
    bytes validatorData;
    uint opIndex;
    require operatorStateIsValid(opIndex);  //key <= limit <= funded <= exited
    require getKeysCount(opIndex) <= 3; //should not be higher than loop_iter 
    uint stateBefore = getValidatorState(opIndex, validatorData);
    f(e, args);
    uint stateAfter = getValidatorState(opIndex, validatorData);
    assert (stateAfter == 1) =>
        (stateBefore == 2 || stateBefore == 1 || stateBefore == 0);
}

rule validatorStateTransition_2in_M15(method f, env e, calldataarg args) filtered 
    { f -> !f.isView  && isMethodID(f, 15) }
{
    require isValidState();
    bytes validatorData;
    uint opIndex;
    require operatorStateIsValid(opIndex);  //key <= limit <= funded <= exited
    require getKeysCount(opIndex) <= 3; //should not be higher than loop_iter 
    uint stateBefore = getValidatorState(opIndex, validatorData);
    f(e, args);
    uint stateAfter = getValidatorState(opIndex, validatorData);
    assert (stateAfter == 2) =>
        (stateBefore == 2 || stateBefore == 1);
}

rule validatorStateTransition_3in_M15(method f, env e, calldataarg args) filtered 
    { f -> !f.isView && isMethodID(f, 15) }
{
    require isValidState();
    bytes validatorData;
    uint opIndex;
    require operatorStateIsValid(opIndex);  //key <= limit <= funded <= exited
    require getKeysCount(opIndex) <= 3; //should not be higher than loop_iter 
    uint stateBefore = getValidatorState(opIndex, validatorData);
    f(e, args);
    uint stateAfter = getValidatorState(opIndex, validatorData);
    assert (stateAfter == 3) =>
        (stateBefore == 3 || stateBefore == 2);
}

rule whoCanChangeOperatorsCount_IL4(method f, env e, calldataarg args) 
    filtered { f -> f.contract == currentContract && 
    !ignoredMethod(f) && needsLoopIter4(f) } 
{
    require isValidState();
    uint countBefore = getOperatorsCount();
    f(e, args);
    uint countAfter = getOperatorsCount();
    assert countAfter > countBefore => canIncreaseOperatorsCount(f);
    assert countAfter < countBefore => canDecreaseOperatorsCount(f);
}

rule whoCanDeactivateOperator_LI4(method f, env e, calldataarg args)
    filtered { f -> f.contract == currentContract && 
        !ignoredMethod(f) && needsLoopIter4(f) } 
{
    require isValidState();
    uint opIndex;
    bool isActiveBefore = operatorIsActive(opIndex);
    f(e, args);
    bool isActiveAfter = operatorIsActive(opIndex);
    assert (isActiveBefore && !isActiveAfter) => canDeactivateOperators(f);
    assert (!isActiveBefore && isActiveAfter) => canActivateOperators(f);
}