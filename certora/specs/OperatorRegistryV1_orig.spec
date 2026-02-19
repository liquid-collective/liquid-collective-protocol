import "Sanity.spec";
import "CVLMath.spec";
import "OperatorRegistryV1_base.spec";

use rule method_reachability;

invariant operatorsStatesRemainValid_LI2_cond1_removeValidators(uint opIndex) 
    (isValidState() && isOpIndexInBounds(opIndex)) => (operatorStateIsValid_cond1(opIndex))
    filtered { f -> f.selector == sig:removeValidators(uint256,uint256[]).selector }
    { 
        preserved removeValidators(uint256 _index, uint256[] _indexes) with(env e) 
        {
            require operatorStateIsValid(opIndex);
            require _indexes.length <= 1; 
        }  
    }

invariant operatorsStatesRemainValid_LI2_cond2_removeValidators(uint opIndex) 
    (isValidState() && isOpIndexInBounds(opIndex)) => (operatorStateIsValid_cond2(opIndex))
    filtered { f -> f.selector == sig:removeValidators(uint256,uint256[]).selector }
    { 
        preserved removeValidators(uint256 _index, uint256[] _indexes) with(env e)        
        {
            require operatorStateIsValid(opIndex);
            require _indexes.length <= 1; 
        }  
    }



invariant validatorKeysRemainUnique_LI2(
    uint opIndex1, uint valIndex1,
    uint opIndex2, uint valIndex2)
    (isValidState() && isValIndexInBounds(opIndex1, valIndex1) && isValIndexInBounds(opIndex2, valIndex2))
        => 
    (equals(getValidatorKey(opIndex1, valIndex1), getValidatorKey(opIndex2, valIndex2)) 
            => (opIndex1 == opIndex2 && valIndex1 == valIndex2))
    filtered { f -> !ignoredMethod(f) && !needsLoopIter4(f) }
    { 
        preserved requestValidatorExits(IOperatorsRegistryV1.OperatorAllocation[] x) with(env e) { require x.length <= 2; }
        preserved pickNextValidatorsToDeposit(IOperatorsRegistryV1.OperatorAllocation[] x) with(env e) { require x.length <= 2; }  
        preserved removeValidators(uint256 _index, uint256[] _indexes) with(env e) { require _indexes.length <= 2; }  
    }

invariant validatorKeysRemainUnique_LI4(
    uint opIndex1, uint valIndex1,
    uint opIndex2, uint valIndex2)
    (isValidState() && isValIndexInBounds(opIndex1, valIndex1) && isValIndexInBounds(opIndex2, valIndex2))
        => 
    (equals(getValidatorKey(opIndex1, valIndex1), getValidatorKey(opIndex2, valIndex2)) 
            => (opIndex1 == opIndex2 && valIndex1 == valIndex2))
    filtered { f -> !ignoredMethod(f) && needsLoopIter4(f) }


rule startingValidatorsDecreasesDiscrepancy(env e) 
{
    uint256 allOpCount = getOperatorsCount();
    require allOpCount <= 3;
    //uint256 fundableOpCount = getFundableOperatorsCount();
    uint index1; uint index2;
    require isOpIndexInBounds(index1);
    require isOpIndexInBounds(index2);
    require operatorStateIsValid(index1);
    require operatorStateIsValid(index2);

    uint discrepancyBefore = getOperatorsSaturationDiscrepancy(index1, index2);
    
    //uint256 keysBefore1; uint256 limitBefore1; uint256 fundedBefore1; uint256 requestedExitsBefore1; uint256 stoppedCountBefore1; bool activeBefore1; address operatorBefore1;
    //keysBefore1, limitBefore1, fundedBefore1, requestedExitsBefore1, stoppedCountBefore1, activeBefore1, operatorBefore1 = getOperatorState(e, index1);
    //uint256 keysBefore2; uint256 limitBefore2; uint256 fundedBefore2; uint256 requestedExitsBefore2; uint256 stoppedCountBefore2; bool activeBefore2; address operatorBefore2;
    //keysBefore2, limitBefore2, fundedBefore2, requestedExitsBefore2, stoppedCountBefore2, activeBefore2, operatorBefore2 = getOperatorState(e, index2);

    require getKeysCount(index1) < 5; 
    require getKeysCount(index2) < 5;  //counterexamples when the keys count overflows
       
    IOperatorsRegistryV1.OperatorAllocation[] allocations;
    require allocations.length > 0 && allocations.length <= 3;
    pickNextValidatorsToDeposit(e, allocations);
    uint discrepancyAfter = getOperatorsSaturationDiscrepancy(index1, index2);

    //uint256 keysAfter1; uint256 limitAfter1; uint256 fundedAfter1; uint256 requestedExitsAfter1; uint256 stoppedCountAfter1; bool activeAfter1; address operatorAfter1;
    //keysAfter1, limitAfter1, fundedAfter1, requestedExitsAfter1, stoppedCountAfter1, activeAfter1, operatorAfter1 = getOperatorState(e, index1);
    //uint256 keysAfter2; uint256 limitAfter2; uint256 fundedAfter2; uint256 requestedExitsAfter2; uint256 stoppedCountAfter2; bool activeAfter2; address operatorAfter2;
    //keysAfter2, limitAfter2, fundedAfter2, requestedExitsAfter2, stoppedCountAfter2, activeAfter2, operatorAfter2 = getOperatorState(e, index2);

    assert discrepancyBefore > 0 => to_mathint(discrepancyBefore) >= 
        discrepancyAfter - allocations.length + 1;
}

rule startingValidatorsNeverUsesSameValidatorTwice(env e) 
{
    uint256 allOpCount = getOperatorsCount();
    require allOpCount <= 2;
    //uint256 fundableOpCount = getFundableOperatorsCount();
    
    uint count;
    require count <= 2;
    bytes[] keys; bytes[] signatures;
    //keys, signatures = pickNextValidatorsToDeposit(e, count);   // Cannot convert `bytes[]` to a CVL dynamic array: conversion is only supported for dynamic arrays of non-dynamic types (e.g. primitive types, or structs containing only primitive types).
    uint resIndex1; uint resIndex2;
    require resIndex1 < keys.length;
    require resIndex2 < keys.length;

    assert resIndex1 != resIndex2 => 
        !equals(keys[resIndex1], keys[resIndex2]) || !equals(signatures[resIndex1], signatures[resIndex2]);
}

rule fundedKeysCantBeChanged(env e) 
{
    require getOperatorsCount() == 1;   //single op is sufficient
    uint256 opIndex = 0;
    require operatorStateIsValid(opIndex);
    require getKeysCount(opIndex) <= 2;    //counterexamples when the keys count overflows
    uint256 valIndex;
    require isValIndexInBounds(opIndex, valIndex);
    bytes valBefore = getRawValidator(e, opIndex, valIndex);
    uint256[] _indexes;
    require _indexes.length <= 1;
    removeValidators(e, opIndex, _indexes);
    bytes valAfter = getRawValidator(e, opIndex, valIndex);
    assert valIndex < require_uint256(getOperator(opIndex).funded) => equals(valBefore, valAfter);
}

rule witness4_3StartingValidatorsDecreasesDiscrepancy(env e) 
{
    require isValidState();
    uint index1; uint index2;
    require operatorStateIsValid(index1);
    require operatorStateIsValid(index2);
    
    uint discrepancyBefore = getOperatorsSaturationDiscrepancy(index1, index2);
    IOperatorsRegistryV1.OperatorAllocation[] allocations;
    require allocations.length <= 1;
    pickNextValidatorsToDeposit(e, allocations);
    uint discrepancyAfter = getOperatorsSaturationDiscrepancy(index1, index2);
    satisfy discrepancyBefore == 4 && discrepancyAfter == 3;
}

rule fundedAndExitedCanOnlyIncrease_removeValidators(env e)
{
    require isValidState();
    uint256 opIndex;
    require isOpIndexInBounds(opIndex);
    uint256 keysBefore; uint256 limitBefore; uint256 fundedBefore; uint256 requestedExitsBefore; bool activeBefore; address operatorBefore;
    keysBefore, limitBefore, fundedBefore, requestedExitsBefore, _, activeBefore, operatorBefore = getOperatorState(e, opIndex);
    //uint256 _index; 
    uint256[] _indexes;
    require _indexes.length <= 2;
    //require isOpIndexInBounds(_index);
    removeValidators(e, opIndex, _indexes);
    uint256 keysAfter; uint256 limitAfter; uint256 fundedAfter; uint256 requestedExitsAfter; bool activeAfter; address operatorAfter;
    keysAfter, limitAfter, fundedAfter, requestedExitsAfter, _, activeAfter, operatorAfter = getOperatorState(e, opIndex);

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
    keysBefore, limitBefore, fundedBefore, requestedExitsBefore, _, activeBefore, operatorBefore = getOperatorState(e, opIndex);

    f(e, args);
    uint256 keysAfter; uint256 limitAfter; uint256 fundedAfter; uint256 requestedExitsAfter; bool activeAfter; address operatorAfter;
    keysAfter, limitAfter, fundedAfter, requestedExitsAfter, _, activeAfter, operatorAfter = getOperatorState(e, opIndex);

    assert fundedBefore <= fundedAfter;
    assert requestedExitsBefore <= requestedExitsAfter;
}

rule removeValidatorsDecreaseKeys(env e)
{
    //uint256 i1; uint256 i2;
    uint256[] indices;// = [ i1, i2 ];
    uint opIndex;
    uint keysBefore = getOperator(opIndex).keys;
    require keysBefore < 4;
    removeValidators(e, opIndex, indices);
    uint keysAfter = getOperator(opIndex).keys;
    assert keysBefore > keysAfter;
}

rule whoCanRemoveValidators(method f, env e, calldataarg args)
{
    require getOperatorsCount() == 1;
    uint valCountBefore = getOperator(0).keys;
    f(e, args);
    uint valCountAfter = getOperator(0).keys;
    assert valCountAfter == valCountBefore;
}

rule fundedValidatorCantBeRemoved(env e)
{
    require getOperatorsCount() == 1;
    bytes validatorData;
    uint opIndex = 0;
    require operatorStateIsValid(opIndex);  //key <= limit <= funded <= exited
    require getKeysCount(opIndex) <= 3; //should not be higher than loop_iter 
    uint validatorStateBefore = getValidatorState(opIndex, validatorData);
    
    uint256[] _indexes;
    removeValidators(e, opIndex, _indexes);
    uint validatorStateAfter = getValidatorState(opIndex, validatorData);
    
    assert validatorStateBefore == 3 //funded
            => validatorStateAfter >= 3; //funded or exited
}
 


