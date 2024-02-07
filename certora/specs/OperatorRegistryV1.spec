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
        preserved requestValidatorExits(uint256 x) with(env e) { require x <= 2; }
        preserved pickNextValidatorsToDeposit(uint256 x) with(env e) { require x <= 2; }  
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
    require isValidState();
    uint256 allOpCount = getOperatorsCount();
    uint256 fundableOpCount = getFundableOperatorsCount();
    uint index1; uint index2;
    require isOpIndexInBounds(index1);
    require isOpIndexInBounds(index2);
    require operatorStateIsValid(index1);
    require operatorStateIsValid(index2);

    uint discrepancyBefore = getOperatorsSaturationDiscrepancy(index1, index2);
    
    uint256 keysBefore1; uint256 limitBefore1; uint256 fundedBefore1; uint256 requestedExitsBefore1; uint256 stoppedCountBefore1; bool activeBefore1; address operatorBefore1;
    keysBefore1, limitBefore1, fundedBefore1, requestedExitsBefore1, stoppedCountBefore1, activeBefore1, operatorBefore1 = getOperatorState(e, index1);
    uint256 keysBefore2; uint256 limitBefore2; uint256 fundedBefore2; uint256 requestedExitsBefore2; uint256 stoppedCountBefore2; bool activeBefore2; address operatorBefore2;
    keysBefore2, limitBefore2, fundedBefore2, requestedExitsBefore2, stoppedCountBefore2, activeBefore2, operatorBefore2 = getOperatorState(e, index2);

    require keysBefore1 <= 4;
    require keysBefore2 <= 4; //must be lower than loop iter

    uint count;
    require count <= 1;
    pickNextValidatorsToDeposit(e, count);
    uint discrepancyAfter = getOperatorsSaturationDiscrepancy(index1, index2);

    uint256 keysAfter1; uint256 limitAfter1; uint256 fundedAfter1; uint256 requestedExitsAfter1; uint256 stoppedCountAfter1; bool activeAfter1; address operatorAfter1;
    keysAfter1, limitAfter1, fundedAfter1, requestedExitsAfter1, stoppedCountAfter1, activeAfter1, operatorAfter1 = getOperatorState(e, index1);
    uint256 keysAfter2; uint256 limitAfter2; uint256 fundedAfter2; uint256 requestedExitsAfter2; uint256 stoppedCountAfter2; bool activeAfter2; address operatorAfter2;
    keysAfter2, limitAfter2, fundedAfter2, requestedExitsAfter2, stoppedCountAfter2, activeAfter2, operatorAfter2 = getOperatorState(e, index2);

    assert discrepancyBefore > 0 => discrepancyBefore >= discrepancyAfter;
}

rule witness4_3StartingValidatorsDecreasesDiscrepancy(env e) 
{
    require isValidState();
    uint index1; uint index2;
    require operatorStateIsValid(index1);
    require operatorStateIsValid(index2);
    
    uint discrepancyBefore = getOperatorsSaturationDiscrepancy(index1, index2);
    uint count;
    require count <= 1;
    pickNextValidatorsToDeposit(e, count);
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
    removeValidators(opIndex, _indexes);
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


 


