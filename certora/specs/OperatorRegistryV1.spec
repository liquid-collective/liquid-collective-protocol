import "Sanity.spec";
import "CVLMath.spec";
import "OperatorRegistryV1_base.spec";

use rule method_reachability;

invariant inactiveOperatorsRemainNotFunded_LI2(uint opIndex) 
    isValidState() => (!getOperator(opIndex).active => getOperator(opIndex).funded == 0)
    filtered { f -> !ignoredMethod(f) && !needsLoopIter4(f) && 
        f.selector != sig:setOperatorStatus(uint256,bool).selector } //method is allowed to break this

invariant inactiveOperatorsRemainNotFunded_LI4(uint opIndex) 
    isValidState() => (!getOperator(opIndex).active => getOperator(opIndex).funded == 0)
    filtered { f -> !ignoredMethod(f) && needsLoopIter4(f) && 
        f.selector != sig:setOperatorStatus(uint256,bool).selector } //method is allowed to break this

invariant operatorsStatesRemainValid_LI2_hardMethods(uint opIndex) 
    isValidState() => (operatorStateIsValid(opIndex))
    filtered { f -> !ignoredMethod(f) && 
    !needsLoopIter4(f) && 
    f.selector == sig:requestValidatorExits(uint256).selector ||
    f.selector == sig:pickNextValidatorsToDeposit(uint256).selector ||
    f.selector == sig:removeValidators(uint256,uint256[]).selector
    }

invariant operatorsStatesRemainValid_LI4_m1(uint opIndex) 
    isValidState() => (operatorStateIsValid(opIndex))
    filtered { f -> !ignoredMethod(f) && 
    f.selector != sig:reportStoppedValidatorCounts(uint32[],uint256).selector }

invariant operatorsStatesRemainValid_LI4_m2(uint opIndex) 
    isValidState() => (operatorStateIsValid(opIndex))
    filtered { f -> !ignoredMethod(f) && 
    f.selector != sig:addValidators(uint256,uint32,bytes).selector }

invariant validatorKeysRemainUnique(
    uint opIndex1, uint valIndex1,
    uint opIndex2, uint valIndex2)
    isValidState() => (compare(getValidatorKey(opIndex1, valIndex1),
        getValidatorKey(opIndex2, valIndex2)) =>
        (opIndex1 == opIndex2 && valIndex1 == valIndex2))
    filtered { f -> !ignoredMethod(f) }

rule whoCanDeactivateOperator_LI2(method f, env e, calldataarg args)
    filtered { f -> f.contract == currentContract 
        && !ignoredMethod(f) && !needsLoopIter4(f) } 
{
    require isValidState();
    uint opIndex;
    bool isActiveBefore = operatorIsActive(opIndex);
    f(e, args);
    bool isActiveAfter = operatorIsActive(opIndex);
    assert (isActiveBefore && !isActiveAfter) => canDeactivateOperators(f);
    assert (!isActiveBefore && isActiveAfter) => canActivateOperators(f);
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



rule startingValidatorsDecreasesDiscrepancy(env e) 
{
    require isValidState();
    uint index1; uint index2;
    require operatorStateIsValid(index1);
    require operatorStateIsValid(index1);

    uint discrepancyBefore = getOperatorsSaturationDiscrepancy(index1, index2);
    
    uint256 keysBefore1; uint256 limitBefore1; uint256 fundedBefore1; uint256 requestedExitsBefore1; bool activeBefore1; address operatorBefore1;
    keysBefore1, limitBefore1, fundedBefore1, requestedExitsBefore1, activeBefore1, operatorBefore1 = getOperatorState(e, index1);
    uint256 keysBefore2; uint256 limitBefore2; uint256 fundedBefore2; uint256 requestedExitsBefore2; bool activeBefore2; address operatorBefore2;
    keysBefore2, limitBefore2, fundedBefore2, requestedExitsBefore2, activeBefore2, operatorBefore2 = getOperatorState(e, index2);

    uint count;
    require count <= 1;
    pickNextValidatorsToDeposit(e, count);
    uint discrepancyAfter = getOperatorsSaturationDiscrepancy(index1, index2);

    uint256 keysAfter1; uint256 limitAfter1; uint256 fundedAfter1; uint256 requestedExitsAfter1; bool activeAfter1; address operatorAfter1;
    keysAfter1, limitAfter1, fundedAfter1, requestedExitsAfter1, activeAfter1, operatorAfter1 = getOperatorState(e, index1);
    uint256 keysAfter2; uint256 limitAfter2; uint256 fundedAfter2; uint256 requestedExitsAfter2; bool activeAfter2; address operatorAfter2;
    keysAfter2, limitAfter2, fundedAfter2, requestedExitsAfter2, activeAfter2, operatorAfter2 = getOperatorState(e, index2);

    assert discrepancyBefore > 0 => discrepancyBefore >= discrepancyAfter;
}

rule witness4_3StartingValidatorsDecreasesDiscrepancy(env e) 
{
    require isValidState();
    uint index1; uint index2;
    require operatorStateIsValid(index1);
    require operatorStateIsValid(index1);
    
    uint discrepancyBefore = getOperatorsSaturationDiscrepancy(index1, index2);
    uint count;
    require count <= 1;
    pickNextValidatorsToDeposit(e, count);
    uint discrepancyAfter = getOperatorsSaturationDiscrepancy(index1, index2);
    satisfy discrepancyBefore == 4 && discrepancyAfter == 3;
}

// shows that operator.funded and operator.requestedExits can only increase in time.
rule fundedAndExitedCanOnlyIncrease_IL2(method f, env e, calldataarg args) filtered 
    { f -> !f.isView && !ignoredMethod(f) && !needsLoopIter4(f) }
{
    require isValidState();
    uint256 opIndex;
    uint256 keysBefore; uint256 limitBefore; uint256 fundedBefore; uint256 requestedExitsBefore; bool activeBefore; address operatorBefore;
    keysBefore, limitBefore, fundedBefore, requestedExitsBefore, activeBefore, operatorBefore = getOperatorState(e, opIndex);

    f(e, args);
    uint256 keysAfter; uint256 limitAfter; uint256 fundedAfter; uint256 requestedExitsAfter; bool activeAfter; address operatorAfter;
    keysAfter, limitAfter, fundedAfter, requestedExitsAfter, activeAfter, operatorAfter = getOperatorState(e, opIndex);

    assert fundedBefore <= fundedAfter;
    assert requestedExitsBefore <= requestedExitsAfter;
}

// shows that operator.funded and operator.requestedExits can only increase in time.
rule fundedAndExitedCanOnlyIncrease_IL4(method f, env e, calldataarg args) filtered 
    { f -> !f.isView && !ignoredMethod(f) && needsLoopIter4(f) }
{
    require isValidState();
    uint256 opIndex;
    uint256 keysBefore; uint256 limitBefore; uint256 fundedBefore; uint256 requestedExitsBefore; bool activeBefore; address operatorBefore;
    keysBefore, limitBefore, fundedBefore, requestedExitsBefore, activeBefore, operatorBefore = getOperatorState(e, opIndex);

    f(e, args);
    uint256 keysAfter; uint256 limitAfter; uint256 fundedAfter; uint256 requestedExitsAfter; bool activeAfter; address operatorAfter;
    keysAfter, limitAfter, fundedAfter, requestedExitsAfter, activeAfter, operatorAfter = getOperatorState(e, opIndex);

    assert fundedBefore <= fundedAfter;
    assert requestedExitsBefore <= requestedExitsAfter;
}
 
rule removeValidatorsRevertsIfKeysNotSorted(env e)
{
    require isValidState();
    uint256[] keys;
    require keys.length <= 2; //should  be less than loop iter
    uint opIndex;
    uint keysIndex1; uint keysIndex2;
    uint key1 = keys[keysIndex1]; uint key2 = keys[keysIndex2];
    require keysIndex1 < keysIndex2 && keys[keysIndex1] > keys[keysIndex2]; //not sorted
    removeValidators@withrevert(e, opIndex, keys);
    assert lastReverted;
}

rule removeValidatorsRevertsIfKeysDuplicit(env e)
{
    require isValidState();
    uint256[] keys;
    require keys.length <= 2; //must be less than loop iter
    uint opIndex;
    uint keysIndex1; uint keysIndex2;
    uint key1 = keys[keysIndex1]; uint key2 = keys[keysIndex2];
    require keysIndex1 != keysIndex2 && keys[keysIndex1] == keys[keysIndex2]; //duplicit
    removeValidators@withrevert(e, opIndex, keys);
    assert lastReverted;
}

