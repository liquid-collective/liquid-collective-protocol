import "./../specs/Sanity.spec";
import "./../specs/CVLMath.spec";
import "./../specs/OperatorRegistryV1_base.spec";

// Generalized ordering rule for pickNextValidatorsToDeposit.
// Uses a symbolic index j so the prover verifies ALL adjacent pairs, not just (0,1).
// The Solidity check is at OperatorsRegistry.1.sol:545 inside
// _getPerOperatorValidatorKeysForAllocations, called by pickNextValidatorsToDeposit.
rule pickNextValidatorToDepositRevertsIfNotSorted(env e)
{
    require isValidState();

    IOperatorsRegistryV1.OperatorAllocation[] allocations;
    require allocations.length >= 2;

    // There exists some adjacent pair (j-1, j) that is not strictly ascending
    uint256 j;
    require j >= 1 && j < allocations.length;
    require allocations[j].operatorIndex <= allocations[assert_uint256(j - 1)].operatorIndex;

    pickNextValidatorsToDeposit@withrevert(e, allocations);
    assert lastReverted, "unordered allocations must revert";
}

// When pickNextValidatorsToDeposit succeeds, returned key count equals total allocation validator count (generic; no fixed operator count).
rule pickNextValidatorsToDepositReturnsTotalAllocationCount(env e)
{
    require isValidState();

    IOperatorsRegistryV1.OperatorAllocation[] allocations;
    require allocations.length >= 1;
    require allocations.length <= 2;
    if (allocations.length >= 2) {
        require allocations[1].operatorIndex > allocations[0].operatorIndex;
    }

    uint256 totalRequested = totalAllocationValidatorCount(allocations);
    require totalRequested >= 1;

    uint256 returnedCount = pickNextValidatorsToDepositReturnCount@withrevert(e, allocations);
    assert lastReverted || (returnedCount == totalRequested),
        "when call succeeds, returned key count must equal total allocation validator count";
}

// Generalized ordering rule for requestValidatorExits.
// Same pattern: symbolic index j covers all adjacent pairs.
// The Solidity check is at OperatorsRegistry.1.sol:463.
rule requestValidatorExitsRevertsIfNotSorted(env e)
{
    require isValidState();

    IOperatorsRegistryV1.OperatorAllocation[] allocations;
    require allocations.length >= 2;

    // There exists some adjacent pair (j-1, j) that is not strictly ascending
    uint256 j;
    require j >= 1 && j < allocations.length;
    require allocations[j].operatorIndex <= allocations[assert_uint256(j - 1)].operatorIndex;

    requestValidatorExits@withrevert(e, allocations);
    assert lastReverted, "unordered allocations must revert";
}

// Empty allocation must revert (InvalidEmptyArray) for both deposit and exit flows.
rule pickNextValidatorsToDepositRevertsOnEmptyAllocation(env e)
{
    require isValidState();
    IOperatorsRegistryV1.OperatorAllocation[] allocations;
    require allocations.length == 0;
    pickNextValidatorsToDepositReturnCount@withrevert(e, allocations);
    assert lastReverted, "empty allocations must revert";
}

rule requestValidatorExitsRevertsOnEmptyAllocation(env e)
{
    require isValidState();
    IOperatorsRegistryV1.OperatorAllocation[] allocations;
    require allocations.length == 0;
    requestValidatorExits@withrevert(e, allocations);
    assert lastReverted, "empty allocations must revert";
}

// If any allocation entry has validatorCount 0, the call must revert (AllocationWithZeroValidatorCount).
rule pickNextValidatorsToDepositRevertsOnZeroValidatorCount(env e)
{
    require isValidState(), "bounded operator count for preserved method and loop bounds";
    IOperatorsRegistryV1.OperatorAllocation[] allocations;
    require allocations.length >= 1, "at least one allocation entry";
    require allocations.length <= 2, "preserved bound for pickNextValidatorsToDeposit in this spec";
    if (allocations.length >= 2) {
        require allocations[1].operatorIndex > allocations[0].operatorIndex,
            "allocations ordered by operator index";
    }
    uint256 j;
    require j < allocations.length;
    require allocations[j].validatorCount == 0, "some allocation has zero validator count";
    pickNextValidatorsToDepositReturnCount@withrevert(e, allocations);
    assert lastReverted, "zero validator count in any allocation must revert";
}

rule requestValidatorExitsRevertsOnZeroValidatorCount(env e)
{
    require isValidState(), "bounded operator count for preserved method and loop bounds";
    IOperatorsRegistryV1.OperatorAllocation[] allocations;
    require allocations.length >= 1, "at least one allocation entry";
    require allocations.length <= 2, "preserved bound for requestValidatorExits in this spec";
    if (allocations.length >= 2) {
        require allocations[1].operatorIndex > allocations[0].operatorIndex,
            "allocations ordered by operator index";
    }
    uint256 j;
    require j < allocations.length;
    require allocations[j].validatorCount == 0, "some allocation has zero validator count";
    requestValidatorExits@withrevert(e, allocations);
    assert lastReverted, "zero validator count in any allocation must revert";
}

// Only River may call pickNextValidatorsToDeposit (onlyRiver).
rule onlyRiverCanCallPickNextValidatorsToDeposit(env e)
{
    require isValidState();
    require e.msg.sender != getRiver();
    IOperatorsRegistryV1.OperatorAllocation[] allocations;
    require allocations.length >= 1;
    require allocations.length <= 2;
    if (allocations.length >= 2) {
        require allocations[1].operatorIndex > allocations[0].operatorIndex;
    }
    require totalAllocationValidatorCount(allocations) >= 1;
    pickNextValidatorsToDepositReturnCount@withrevert(e, allocations);
    assert lastReverted, "non-River caller must revert";
}

rule removeValidatorsDecreaseKeys(env e)
{
    uint256[] indices;
    uint opIndex;
    uint keysBefore = getOperator(opIndex).keys;
    require keysBefore < 4;
    removeValidators(e, opIndex, indices);
    uint keysAfter = getOperator(opIndex).keys;
    assert keysBefore > keysAfter;
}

rule whoCanChangeValidatorsCount(method f, env e, calldataarg args) filtered 
    { f -> !ignoredMethod(f) }
{
    require getOperatorsCount() == 1;
    uint valCountBefore = getOperator(0).keys;
    f(e, args);
    uint valCountAfter = getOperator(0).keys;
    assert valCountAfter < valCountBefore => canRemoveValidators(f);
    assert valCountAfter > valCountBefore => canAddValidators(f);
}

invariant operatorsAddressesRemainUnique_LI4(uint opIndex1, uint opIndex2) 
    isValidState() => (getOperatorAddress(opIndex1) == getOperatorAddress(opIndex2)
    => opIndex1 == opIndex2)
    filtered { f -> !ignoredMethod(f) && needsLoopIter4(f) && 
        f.selector != sig:setOperatorAddress(uint256,address).selector } //method is allowed to break this

// https://prover.certora.com/output/6893/d30f35befc754188b887309de5ffa30f/?anonymousKey=da737f977281de9c86fe7561dd63c6b11dbfd644
invariant operatorsAddressesRemainUnique_LI2(uint opIndex1, uint opIndex2) 
    isValidState() => (getOperatorAddress(opIndex1) == getOperatorAddress(opIndex2)
    => opIndex1 == opIndex2)
    filtered { f -> !ignoredMethod(f) && !needsLoopIter4(f) && 
        f.selector != sig:setOperatorAddress(uint256,address).selector } //method is allowed to break this
// ------------ inactiveOperatorsRemainNotFunded
// https://prover.certora.com/output/6893/6e9b0f3a147f4d048c25b70ed8627816/?anonymousKey=f35fa72ed7c790162056f0c77606e348fccc7435
invariant inactiveOperatorsRemainNotFunded_LI4(uint opIndex) 
    isValidState() => (!getOperator(opIndex).active => getOperator(opIndex).funded == 0)
    filtered { f -> !ignoredMethod(f) && needsLoopIter4(f) && 
        f.selector != sig:setOperatorStatus(uint256,bool).selector } //method is allowed to break this

// https://prover.certora.com/output/6893/a3abe3a68a254531a6bfa6703f5ecd5b/?anonymousKey=7dc68513575b3f3686b6d39523c6067c266e0cbf
invariant inactiveOperatorsRemainNotFunded_LI2(uint opIndex) 
    isValidState() => (!getOperator(opIndex).active => getOperator(opIndex).funded == 0)
    filtered { f -> !ignoredMethod(f) && !needsLoopIter4(f)
        && f.selector != sig:setOperatorStatus(uint256,bool).selector  //method is allowed to break this
        //&& f.selector == sig:requestValidatorExits(uint256).selector
        } 
    { 
        preserved requestValidatorExits(IOperatorsRegistryV1.OperatorAllocation[] x) with(env e) { require x.length <= 2; }
        preserved pickNextValidatorsToDeposit(IOperatorsRegistryV1.OperatorAllocation[] x) with(env e) { require x.length <= 1; }  
        preserved removeValidators(uint256 _index, uint256[] _indexes) with(env e) { require _indexes.length <= 1; }  
    }

// ------------ whoCanChangeOperatorsCount
// https://prover.certora.com/output/6893/360d2ea0c38c48f88ba600ce16e5b4f0/?anonymousKey=b52535f640d13bdae23463ed46a8496081887813
rule whoCanChangeOperatorsCount_IL2(method f, env e, calldataarg args) 
    filtered { f -> f.contract == currentContract && 
    !ignoredMethod(f) && !needsLoopIter4(f) } 
{
    require isValidState();
    uint countBefore = getOperatorsCount();
    f(e, args);
    uint countAfter = getOperatorsCount();
    assert countAfter > countBefore => canIncreaseOperatorsCount(f);
    assert countAfter < countBefore => canDecreaseOperatorsCount(f);
}



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

rule fundedAndExitedCanOnlyIncrease_IL2(method f, env e, calldataarg args) filtered 
    { f -> !f.isView && !ignoredMethod(f) && !needsLoopIter4(f) }
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

// ------------ operatorsStatesRemainValid
// We split the property to several special cases. 
// For the hardes methods, we also split the property, i.e. insted of proving key >= limit >= funded >= exited
// we only prove one unequality at a time (denoted cond1, cond2, cond3).
// https://prover.certora.com/output/6893/bfd27cb65484472da1ead2b8178d7bb5/?anonymousKey=66caae5f45e04af246224f114442200d9e7fa8c0
invariant operatorsStatesRemainValid_LI2_easyMethods(uint opIndex) 
    isValidState() => (operatorStateIsValid(opIndex))
    filtered { f -> !ignoredMethod(f) && 
    !needsLoopIter4(f) &&
    f.selector != sig:requestValidatorExits(IOperatorsRegistryV1.OperatorAllocation[]).selector &&
    f.selector != sig:pickNextValidatorsToDeposit(IOperatorsRegistryV1.OperatorAllocation[]).selector &&
    f.selector != sig:removeValidators(uint256,uint256[]).selector
    }

    // requires special configuration!
    // https://prover.certora.com/output/6893/b8f0e5fb8b3b4b5685a522ee20e967c9/?anonymousKey=504a8d77280a1fb1d9415114904b0872e7607815
invariant operatorsStatesRemainValid_LI2_pickNextValidatorsToDeposit(uint opIndex) 
    isValidState() => (operatorStateIsValid(opIndex))
    filtered { f -> !ignoredMethod(f) && 
    !needsLoopIter4(f) && f.selector != sig:pickNextValidatorsToDeposit(IOperatorsRegistryV1.OperatorAllocation[]).selector
    }

// proves the invariant for reportStoppedValidatorCounts
// requires special configuration!
// https://prover.certora.com/output/6893/06b7de4c27ad4ef8b519282a831c3823/?anonymousKey=35f5112dd9eac39c2e9aa81dd87a3edc1a452670
invariant operatorsStatesRemainValid_LI4_m1(uint opIndex) 
    isValidState() => (operatorStateIsValid(opIndex))
    filtered { f -> !ignoredMethod(f) && 
    f.selector == sig:reportStoppedValidatorCounts(uint32[],uint256).selector }
// https://prover.certora.com/output/6893/ee6dc8f5245647b8b0c9758360992b48/?anonymousKey=c5a40d1f26ee0860ea2502c48a8b99baa7e98490
invariant operatorsStatesRemainValid_LI2_cond3_requestValidatorExits(uint opIndex) 
    isValidState() => (operatorStateIsValid_cond3(opIndex))
    filtered { f -> f.selector == sig:requestValidatorExits(IOperatorsRegistryV1.OperatorAllocation[]).selector }
    { 
        preserved requestValidatorExits(IOperatorsRegistryV1.OperatorAllocation[] x) with(env e) { require x.length <= 2; }  
    }
// https://prover.certora.com/output/6893/9b9eaf30d9274d02934641a25351218f/?anonymousKey=27d543677f1c1d051d7a5715ce4e41fd5ffaf412
invariant operatorsStatesRemainValid_LI2_cond2_requestValidatorExits(uint opIndex) 
    isValidState() => (operatorStateIsValid_cond2(opIndex))
    filtered { f -> f.selector == sig:requestValidatorExits(IOperatorsRegistryV1.OperatorAllocation[]).selector }
    { 
        preserved requestValidatorExits(IOperatorsRegistryV1.OperatorAllocation[] x) with(env e) { require x.length <= 2; }  
    }

// https://prover.certora.com/output/6893/87eaf2d5d9ad427781570b215598a7a7/?anonymousKey=7e0aa6df6957986370875945b0c894a2b993b99c
invariant operatorsStatesRemainValid_LI2_cond1_requestValidatorExits(uint opIndex) 
    isValidState() => (operatorStateIsValid_cond1(opIndex))
    filtered { f -> f.selector == sig:requestValidatorExits(IOperatorsRegistryV1.OperatorAllocation[]).selector }


// proves the invariant for addValidators
// requires special configuration!
// https://prover.certora.com/output/6893/850c24ab14cc4a2eb3a372abcebc9069/?anonymousKey=c697aaa0f8f6c857e14b8820888fb657caa89e70
invariant operatorsStatesRemainValid_LI4_m2(uint opIndex) 
    isValidState() => (operatorStateIsValid(opIndex))
    filtered { f -> !ignoredMethod(f) && 
    f.selector == sig:addValidators(uint256,uint32,bytes).selector }

// condition 1: https://prover.certora.com/output/40748/b91e4acc88f348b087f329e14a1f7d83?anonymousKey=92b57424b7a9911350ac5d58c45ef97229e84c31
// condition 2: https://prover.certora.com/output/40748/3eb0854e2d9448b4a1baebe08efa79de?anonymousKey=6a6dc1b0b79efdf84723273905875cbaf791e053
// condition 3: https://prover.certora.com/output/6893/4f083a358b5c4870a8c8d7b671d62aba/?anonymousKey=feb3fb6e3eb7fadd1fd9b0f4d943b85b17372924
invariant operatorsStatesRemainValid_LI2_cond3_removeValidators(uint opIndex) 
    isValidState() => (operatorStateIsValid_cond3(opIndex))
    filtered { f -> f.selector == sig:removeValidators(uint256,uint256[]).selector }
    { 
        preserved removeValidators(uint256 _index, uint256[] _indexes) with(env e)        
        {
            require operatorStateIsValid(opIndex);
            require _indexes.length <= 1; 
        }  
    }



// ------------ Validators state-transition
rule validatorStateTransition_0in_index(method f, env e, calldataarg args) filtered 
    { f -> !f.isView }// isMethodID(f, 7) }
{
    require isValidState();
    uint opIndex; uint valIndex;
    require operatorStateIsValid(opIndex);  //key <= limit <= funded <= exited
    require getKeysCount(opIndex) <= 4; //should not be higher than loop_iter 
    require isValIndexInBounds(opIndex, valIndex);
    uint stateBefore = getValidatorStateByIndex(opIndex, valIndex);
    f(e, args);
    uint stateAfter = getValidatorStateByIndex(opIndex, valIndex);
    assert (stateAfter == 0) =>
        (stateBefore == 2 || stateBefore == 1 || stateBefore == 0);
}

rule validatorStateTransition_1in_index(method f, env e, calldataarg args) filtered 
    { f -> !f.isView }// isMethodID(f, 7) }
{
    require isValidState();
    uint opIndex; uint valIndex;
    require operatorStateIsValid(opIndex);  //key <= limit <= funded <= exited
    require getKeysCount(opIndex) <= 4; //should not be higher than loop_iter 
    require isValIndexInBounds(opIndex, valIndex);
    uint stateBefore = getValidatorStateByIndex(opIndex, valIndex);
    f(e, args);
    uint stateAfter = getValidatorStateByIndex(opIndex, valIndex);
    assert (stateAfter == 1) =>
        (stateBefore == 2 || stateBefore == 1 || stateBefore == 0);
}

rule validatorStateTransition_2in_index(method f, env e, calldataarg args) filtered 
    { f -> !f.isView }// isMethodID(f, 7) }
{
    require isValidState();
    uint opIndex; uint valIndex;
    require operatorStateIsValid(opIndex);  //key <= limit <= funded <= exited
    require getKeysCount(opIndex) <= 4; //should not be higher than loop_iter 
    require isValIndexInBounds(opIndex, valIndex);
    uint stateBefore = getValidatorStateByIndex(opIndex, valIndex);
    f(e, args);
    uint stateAfter = getValidatorStateByIndex(opIndex, valIndex);
    assert (stateAfter == 2) =>
        (stateBefore == 2 || stateBefore == 1);
}

rule validatorStateTransition_3in_index(method f, env e, calldataarg args) filtered 
    { f -> !f.isView }// isMethodID(f, 7) }
{
    require isValidState();
    uint opIndex; uint valIndex;
    require operatorStateIsValid(opIndex);  //key <= limit <= funded <= exited
    require getKeysCount(opIndex) <= 4; //should not be higher than loop_iter 
    require isValIndexInBounds(opIndex, valIndex);
    uint stateBefore = getValidatorStateByIndex(opIndex, valIndex);
    f(e, args);
    uint stateAfter = getValidatorStateByIndex(opIndex, valIndex);
    assert (stateAfter == 3) =>
        (stateBefore == 3 || stateBefore == 2);
}

rule validatorStateTransition_4in_index(method f, env e, calldataarg args) filtered 
    { f -> !f.isView }// isMethodID(f, 7) }
{
    require isValidState();
    uint opIndex; uint valIndex;
    require operatorStateIsValid(opIndex);  //key <= limit <= funded <= exited
    require getKeysCount(opIndex) <= 4; //should not be higher than loop_iter 
    require isValIndexInBounds(opIndex, valIndex);
    uint stateBefore = getValidatorStateByIndex(opIndex, valIndex);
    f(e, args);
    uint stateAfter = getValidatorStateByIndex(opIndex, valIndex);
    assert (stateAfter == 4) =>
        (stateBefore == 3 || stateBefore == 4);
}




// if the key is below limit and goes above the limit, it could only happen when limit decreased
// https://prover.certora.com/output/6893/7e423ff12f26465f9cf13ec200406cdd/?anonymousKey=93c2262eb0465adf609e01dbbf1f790207898bc2
rule validatorStateTransition_2_1_index_limit(method f, env e, calldataarg args) filtered 
    { f -> !f.isView }// isMethodID(f, 7) }
{
    require isValidState();
    bytes validatorData;
    uint opIndex;
    require operatorStateIsValid(opIndex);  //key <= limit <= funded <= exited
    uint limitBefore;
    _, limitBefore, _, _, _, _, _ = getOperatorState(e, opIndex);
    require getKeysCount(opIndex) <= 3; //should not be higher than loop_iter 
    uint stateBefore = getValidatorState(opIndex, validatorData);
    f(e, args);
    uint stateAfter = getValidatorState(opIndex, validatorData);
    uint limitAfter;
    _, limitAfter, _, _, _, _, _ = getOperatorState(e, opIndex);
    assert (stateBefore == 2 && stateAfter == 1) => limitAfter < limitBefore;
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

rule validatorStateTransition_3_2(method f, env e, calldataarg args) filtered 
    { f -> !f.isView }// isMethodID(f, 7) }
{
    require isValidState();
    bytes validatorData;
    uint opIndex;
    require operatorStateIsValid(opIndex);  //key <= limit <= funded <= exited
    require getKeysCount(opIndex) <= 4; //should not be higher than loop_iter 
    uint stateBefore = getValidatorState(opIndex, validatorData);
    f(e, args);
    uint stateAfter = getValidatorState(opIndex, validatorData);
    assert (stateAfter == 3) =>
        (stateBefore == 3 || stateBefore == 2);
}



rule validatorStateTransition_3in_M9(env e)
{
    require isValidState();
    bytes validatorData;
    uint opIndex;
    require operatorStateIsValid(opIndex);  //key <= limit <= funded <= exited
    require getKeysCount(opIndex) <= 3; //should not be higher than loop_iter 
    uint stateBefore = getValidatorState(opIndex, validatorData);
    uint256[] _indexes;
    require _indexes.length <= 2;
    removeValidators(e, opIndex, _indexes);
    uint stateAfter = getValidatorState(opIndex, validatorData);
    assert (stateAfter == 3) =>
        (stateBefore == 3 || stateBefore == 2);
}

rule validatorStateTransition_2in_M9(env e)
{
    require isValidState();
    bytes validatorData;
    uint opIndex;
    require operatorStateIsValid(opIndex);  //key <= limit <= funded <= exited
    require getKeysCount(opIndex) <= 3; //should not be higher than loop_iter 
    uint stateBefore = getValidatorState(opIndex, validatorData);
    uint256[] _indexes;
    require _indexes.length <= 2;
    removeValidators(e, opIndex, _indexes);
    uint stateAfter = getValidatorState(opIndex, validatorData);
    assert (stateAfter == 2) =>
        (stateBefore == 2 || stateBefore == 1);
}

rule validatorStateTransition_1in_M9(env e)
{
    require isValidState();
    bytes validatorData;
    uint opIndex;
    require operatorStateIsValid(opIndex);  //key <= limit <= funded <= exited
    require getKeysCount(opIndex) <= 3; //should not be higher than loop_iter 
    uint stateBefore = getValidatorState(opIndex, validatorData);
    uint256[] _indexes;
    require _indexes.length <= 2;
    removeValidators(e, opIndex, _indexes);
    uint stateAfter = getValidatorState(opIndex, validatorData);
    assert (stateAfter == 1) =>
        (stateBefore == 2 || stateBefore == 1 || stateBefore == 0);
}



rule validatorStateTransition_0in_M9(method f, env e, calldataarg args) filtered 
    { f -> !f.isView  && isMethodID(f, 9) }
{
    require isValidState();
    bytes validatorData;
    uint opIndex;
    require operatorStateIsValid(opIndex);  //key <= limit <= funded <= exited
    require getKeysCount(opIndex) <= 3; //should not be higher than loop_iter 
    uint stateBefore = getValidatorState(opIndex, validatorData);
    f(e, args);
    uint stateAfter = getValidatorState(opIndex, validatorData);
    assert (stateAfter == 0) =>
        (stateBefore == 2 || stateBefore == 1 || stateBefore == 0);
}





rule validatorStateTransition_3_4_M7(method f, env e, calldataarg args) filtered 
    { f -> isMethodID(f, 7) }
{
    require isValidState();
    bytes validatorData;
    uint opIndex;
    require operatorStateIsValid(opIndex);  //key <= limit <= funded <= exited
    require getKeysCount(opIndex) <= 4; //should not be higher than loop_iter 
    uint stateBefore = getValidatorState(opIndex, validatorData);
    f(e, args);
    uint stateAfter = getValidatorState(opIndex, validatorData);
    assert (stateBefore == 3) =>
        (stateAfter == 3 || stateAfter == 4);
}

rule validatorStateTransition_3_4_M9(method f, env e, calldataarg args) filtered 
    { f -> isMethodID(f, 9) }
{
    require isValidState();
    bytes validatorData;
    uint opIndex;
    require operatorStateIsValid(opIndex);  //key <= limit <= funded <= exited
    require getKeysCount(opIndex) <= 4; //should not be higher than loop_iter 
    uint stateBefore = getValidatorState(opIndex, validatorData);
    f(e, args);
    uint stateAfter = getValidatorState(opIndex, validatorData);
    assert (stateBefore == 3) =>
        (stateAfter == 3 || stateAfter == 4);
}

rule validatorStateTransition_3_4_M10(method f, env e, calldataarg args) filtered 
    { f -> isMethodID(f, 10) }
{
    require isValidState();
    bytes validatorData;
    uint opIndex;
    require operatorStateIsValid(opIndex);  //key <= limit <= funded <= exited
    require getKeysCount(opIndex) <= 4; //should not be higher than loop_iter 
    uint stateBefore = getValidatorState(opIndex, validatorData);
    f(e, args);
    uint stateAfter = getValidatorState(opIndex, validatorData);
    assert (stateBefore == 3) =>
        (stateAfter == 3 || stateAfter == 4);
}

rule validatorStateTransition_3_4_M12(method f, env e, calldataarg args) filtered 
    { f -> isMethodID(f, 12) }
{
    require isValidState();
    bytes validatorData;
    uint opIndex;
    require operatorStateIsValid(opIndex);  //key <= limit <= funded <= exited
    require getKeysCount(opIndex) <= 4; //should not be higher than loop_iter 
    uint stateBefore = getValidatorState(opIndex, validatorData);
    f(e, args);
    uint stateAfter = getValidatorState(opIndex, validatorData);
    assert (stateBefore == 3) =>
        (stateAfter == 3 || stateAfter == 4);
}

rule validatorStateTransition_3_4_M14(method f, env e, calldataarg args) filtered 
    { f -> isMethodID(f, 14) }
{
    require isValidState();
    bytes validatorData;
    uint opIndex;
    require operatorStateIsValid(opIndex);  //key <= limit <= funded <= exited
    require getKeysCount(opIndex) <= 4; //should not be higher than loop_iter 
    uint stateBefore = getValidatorState(opIndex, validatorData);
    f(e, args);
    uint stateAfter = getValidatorState(opIndex, validatorData);
    assert (stateBefore == 3) =>
        (stateAfter == 3 || stateAfter == 4);
}

rule validatorStateTransition_4in_M9(env e)
{
    require isValidState();
    bytes validatorData;
    uint opIndex;
    require operatorStateIsValid(opIndex);  //key <= limit <= funded <= exited
    require getKeysCount(opIndex) <= 4; //should not be higher than loop_iter 
    uint stateBefore = getValidatorState(opIndex, validatorData);
    uint256[] _indexes;
    require _indexes.length <= 2;
    removeValidators(e, opIndex, _indexes);
    uint stateAfter = getValidatorState(opIndex, validatorData);
    assert (stateBefore == 3) =>
        (stateAfter == 3 || stateAfter == 4);
}

rule validatorStateTransition_4_3_M7(method f, env e, calldataarg args) filtered 
    { f -> isMethodID(f, 7) }
{
    require isValidState();
    bytes validatorData;
    uint opIndex;
    require operatorStateIsValid(opIndex);  //key <= limit <= funded <= exited
    require getKeysCount(opIndex) <= 4; //should not be higher than loop_iter 
    uint stateBefore = getValidatorState(opIndex, validatorData);
    f(e, args);
    uint stateAfter = getValidatorState(opIndex, validatorData);
    assert (stateAfter == 4) =>
        (stateBefore == 3 || stateBefore == 4);
}

rule validatorStateTransition_4_3_M9(method f, env e, calldataarg args) filtered 
    { f -> isMethodID(f, 9) }
{
    require isValidState();
    bytes validatorData;
    uint opIndex;
    require operatorStateIsValid(opIndex);  //key <= limit <= funded <= exited
    require getKeysCount(opIndex) <= 3; //should not be higher than loop_iter 
    uint stateBefore = getValidatorState(opIndex, validatorData);
    f(e, args);
    uint stateAfter = getValidatorState(opIndex, validatorData);
    assert (stateAfter == 4) =>
        (stateBefore == 3 || stateBefore == 4);
}

rule validatorStateTransition_4_3_M10(method f, env e, calldataarg args) filtered 
    { f -> isMethodID(f, 10) }
{
    require isValidState();
    bytes validatorData;
    uint opIndex;
    require operatorStateIsValid(opIndex);  //key <= limit <= funded <= exited
    require getKeysCount(opIndex) <= 4; //should not be higher than loop_iter 
    uint stateBefore = getValidatorState(opIndex, validatorData);
    f(e, args);
    uint stateAfter = getValidatorState(opIndex, validatorData);
    assert (stateAfter == 4) =>
        (stateBefore == 3 || stateBefore == 4);
}



rule validatorStateTransition_4_3_M12(method f, env e, calldataarg args) filtered 
    { f -> isMethodID(f, 12) }
{
    require isValidState();
    bytes validatorData;
    uint opIndex;
    require operatorStateIsValid(opIndex);  //key <= limit <= funded <= exited
    require getKeysCount(opIndex) <= 4; //should not be higher than loop_iter 
    uint stateBefore = getValidatorState(opIndex, validatorData);
    f(e, args);
    uint stateAfter = getValidatorState(opIndex, validatorData);
    assert (stateAfter == 4) =>
        (stateBefore == 3 || stateBefore == 4);
}

rule validatorStateTransition_4_3_M13(method f, env e, calldataarg args) filtered 
    { f -> isMethodID(f, 13) }
{
    require isValidState();
    bytes validatorData;
    uint opIndex;
    require operatorStateIsValid(opIndex);  //key <= limit <= funded <= exited
    require getKeysCount(opIndex) <= 4; //should not be higher than loop_iter 
    uint stateBefore = getValidatorState(opIndex, validatorData);
    f(e, args);
    uint stateAfter = getValidatorState(opIndex, validatorData);
    assert (stateAfter == 4) =>
        (stateBefore == 3 || stateBefore == 4);
}

rule validatorStateTransition_4_3_M14(method f, env e, calldataarg args) filtered 
    { f -> isMethodID(f, 14) }
{
    require isValidState();
    bytes validatorData;
    uint opIndex;
    require operatorStateIsValid(opIndex);  //key <= limit <= funded <= exited
    require getKeysCount(opIndex) <= 4; //should not be higher than loop_iter 
    uint stateBefore = getValidatorState(opIndex, validatorData);
    f(e, args);
    uint stateAfter = getValidatorState(opIndex, validatorData);
    assert (stateAfter == 4) =>
        (stateBefore == 3 || stateBefore == 4);
}

rule validatorStateTransition_4_3_M15(env e)
{
    require isValidState();
    bytes validatorData;
    uint opIndex;
    require operatorStateIsValid(opIndex);  //key <= limit <= funded <= exited
    require getKeysCount(opIndex) <= 3; //should not be higher than loop_iter 
    uint stateBefore = getValidatorState(opIndex, validatorData);
    uint256[] _indexes;
    require _indexes.length <= 2;
    removeValidators(e, opIndex, _indexes);
    uint stateAfter = getValidatorState(opIndex, validatorData);
    assert (stateAfter == 4) =>
        (stateBefore == 3 || stateBefore == 4);
}

rule validatorStateTransition_4_3_M16(method f, env e, calldataarg args) filtered 
    { f -> isMethodID(f, 16) }
{
    require isValidState();
    bytes validatorData;
    uint opIndex;
    require operatorStateIsValid(opIndex);  //key <= limit <= funded <= exited
    require getKeysCount(opIndex) <= 3; //should not be higher than loop_iter 
    uint stateBefore = getValidatorState(opIndex, validatorData);
    f(e, args);
    uint stateAfter = getValidatorState(opIndex, validatorData);
    assert (stateAfter == 4) =>
        (stateBefore == 3 || stateBefore == 4);
}

// if the key is below limit and goes above the limit, it could only happen when limi decreased
rule _2_1_index_limit_15(method f, env e, calldataarg args) filtered 
    { f -> !f.isView && (isMethodID(f, 15)) }
{
    require isValidState();
    bytes validatorData;
    uint opIndex;
    require operatorStateIsValid(opIndex);  //key <= limit <= funded <= exited
    uint limitBefore;
    _, limitBefore, _, _, _, _, _ = getOperatorState(e, opIndex);
    require getKeysCount(opIndex) <= 3; //should not be higher than loop_iter 
    uint stateBefore = getValidatorState(opIndex, validatorData);
    f(e,args);
    uint stateAfter = getValidatorState(opIndex, validatorData);
    uint limitAfter;
    _, limitAfter, _, _, _, _, _ = getOperatorState(e, opIndex);
    assert (stateBefore == 2 && stateAfter == 1) => limitAfter < limitBefore;
}

// ------------ inactiveOperatorsRemainNotFunded
// variant for the training
invariant inactiveOperatorsRemainNotFunded(uint opIndex) 
    (isValidState() && isOpIndexInBounds(opIndex)) => 
        (!getOperator(opIndex).active => getOperator(opIndex).funded == 0)
    { 
        preserved requestValidatorExits(IOperatorsRegistryV1.OperatorAllocation[] x) with(env e) { require x.length <= 2; }
        preserved pickNextValidatorsToDeposit(IOperatorsRegistryV1.OperatorAllocation[] x) with(env e) { require x.length <= 1; }  
        preserved removeValidators(uint256 _index, uint256[] _indexes) with(env e) { require _indexes.length <= 1; }  
    }

// ------------ whoCanChangeOperatorsCount
// version for the training
rule whoCanChangeOperatorsCount(method f, env e, calldataarg args)
{
    uint countBefore = getOperatorsCount();
    f(e, args);
    uint countAfter = getOperatorsCount();
    assert countAfter > countBefore => canIncreaseOperatorsCount(f);
    assert countAfter < countBefore => canDecreaseOperatorsCount(f);
}

// ------------ Validators state-transition
// 3 out
//https://prover.certora.com/output/6893/520346e7cd7b48518a1edeb0b5dd6f50/?anonymousKey=a9941cb5661982d807f31ba4e4b88d5bbdc355e4
rule validatorStateTransition_3_4_M1(method f, env e, calldataarg args) filtered 
    { f -> isMethodID(f, 1) }
{
    require isValidState();
    bytes validatorData;
    uint opIndex;
    require operatorStateIsValid(opIndex);  //key <= limit <= funded <= exited
    require getKeysCount(opIndex) <= 4; //should not be higher than loop_iter 
    uint stateBefore = getValidatorState(opIndex, validatorData);
    f(e, args);
    uint stateAfter = getValidatorState(opIndex, validatorData);
    assert (stateBefore == 3) =>
        (stateAfter == 3 || stateAfter == 4);
}
rule validatorStateTransition_3_4_M2(method f, env e, calldataarg args) filtered 
    { f -> isMethodID(f, 2) }
{
    require isValidState();
    bytes validatorData;
    uint opIndex;
    require operatorStateIsValid(opIndex);  //key <= limit <= funded <= exited
    require getKeysCount(opIndex) <= 4; //should not be higher than loop_iter 
    uint stateBefore = getValidatorState(opIndex, validatorData);
    f(e, args);
    uint stateAfter = getValidatorState(opIndex, validatorData);
    assert (stateBefore == 3) =>
        (stateAfter == 3 || stateAfter == 4);
}
rule validatorStateTransition_3_4_M3(method f, env e, calldataarg args) filtered 
    { f -> isMethodID(f, 3) }
{
    require isValidState();
    bytes validatorData;
    uint opIndex;
    require operatorStateIsValid(opIndex);  //key <= limit <= funded <= exited
    require getKeysCount(opIndex) <= 4; //should not be higher than loop_iter 
    uint stateBefore = getValidatorState(opIndex, validatorData);
    f(e, args);
    uint stateAfter = getValidatorState(opIndex, validatorData);
    assert (stateBefore == 3) =>
        (stateAfter == 3 || stateAfter == 4);
}
rule validatorStateTransition_3_4_M5(method f, env e, calldataarg args) filtered 
    { f -> isMethodID(f, 5) }
{
    require isValidState();
    bytes validatorData;
    uint opIndex;
    require operatorStateIsValid(opIndex);  //key <= limit <= funded <= exited
    require getKeysCount(opIndex) <= 4; //should not be higher than loop_iter 
    uint stateBefore = getValidatorState(opIndex, validatorData);
    f(e, args);
    uint stateAfter = getValidatorState(opIndex, validatorData);
    assert (stateBefore == 3) =>
        (stateAfter == 3 || stateAfter == 4);
}
rule validatorStateTransition_3_4_M6(method f, env e, calldataarg args) filtered 
    { f -> isMethodID(f, 6) }
{
    require isValidState();
    bytes validatorData;
    uint opIndex;
    require operatorStateIsValid(opIndex);  //key <= limit <= funded <= exited
    require getKeysCount(opIndex) <= 4; //should not be higher than loop_iter 
    uint stateBefore = getValidatorState(opIndex, validatorData);
    f(e, args);
    uint stateAfter = getValidatorState(opIndex, validatorData);
    assert (stateBefore == 3) =>
        (stateAfter == 3 || stateAfter == 4);
}

// https://prover.certora.com/output/6893/bbd548db7c82444d9c026c144569f25d/?anonymousKey=d329b065d252557c7e5bdaa1399139a44ae5e472
rule validatorStateTransition_3_4_M11(method f, env e, calldataarg args) filtered 
    { f -> isMethodID(f, 11) }
{
    require isValidState();
    bytes validatorData;
    uint opIndex;
    require operatorStateIsValid(opIndex);  //key <= limit <= funded <= exited
    require getKeysCount(opIndex) <= 4; //should not be higher than loop_iter 
    uint stateBefore = getValidatorState(opIndex, validatorData);
    f(e, args);
    uint stateAfter = getValidatorState(opIndex, validatorData);
    assert (stateBefore == 3) =>
        (stateAfter == 3 || stateAfter == 4);
}
rule validatorStateTransition_3_4_M8(method f, env e, calldataarg args) filtered 
    { f -> isMethodID(f, 8) }
{
    require isValidState();
    bytes validatorData;
    uint opIndex;
    require operatorStateIsValid(opIndex);  //key <= limit <= funded <= exited
    require getKeysCount(opIndex) <= 4; //should not be higher than loop_iter 
    uint stateBefore = getValidatorState(opIndex, validatorData);
    f(e, args);
    uint stateAfter = getValidatorState(opIndex, validatorData);
    assert (stateBefore == 3) =>
        (stateAfter == 3 || stateAfter == 4);
}

// https://prover.certora.com/output/6893/3d9c8adbdeb74acd85de720de3d7528b/?anonymousKey=9dd1b8d858342e77d0ee26fb3da23e5ef5aa631b
rule validatorStateTransition_3_4_M4(method f, env e, calldataarg args) filtered 
    { f -> isMethodID(f, 4) }
{
    require isValidState();
    bytes validatorData;
    uint opIndex;
    require operatorStateIsValid(opIndex);  //key <= limit <= funded <= exited
    require getKeysCount(opIndex) <= 4; //should not be higher than loop_iter 
    uint stateBefore = getValidatorState(opIndex, validatorData);
    f(e, args);
    uint stateAfter = getValidatorState(opIndex, validatorData);
    assert (stateBefore == 3) =>
        (stateAfter == 3 || stateAfter == 4);
}


// 4 in
// https://prover.certora.com/output/6893/520346e7cd7b48518a1edeb0b5dd6f50/?anonymousKey=a9941cb5661982d807f31ba4e4b88d5bbdc355e4
rule validatorStateTransition_4_3_M1(method f, env e, calldataarg args) filtered 
    { f -> isMethodID(f, 1) }
{
    require isValidState();
    bytes validatorData;
    uint opIndex;
    require operatorStateIsValid(opIndex);  //key <= limit <= funded <= exited
    require getKeysCount(opIndex) <= 4; //should not be higher than loop_iter 
    uint stateBefore = getValidatorState(opIndex, validatorData);
    f(e, args);
    uint stateAfter = getValidatorState(opIndex, validatorData);
    assert (stateAfter == 4) =>
        (stateBefore == 3 || stateBefore == 4);
}
rule validatorStateTransition_4_3_M2(method f, env e, calldataarg args) filtered 
    { f -> isMethodID(f, 2) }
{
    require isValidState();
    bytes validatorData;
    uint opIndex;
    require operatorStateIsValid(opIndex);  //key <= limit <= funded <= exited
    require getKeysCount(opIndex) <= 4; //should not be higher than loop_iter 
    uint stateBefore = getValidatorState(opIndex, validatorData);
    f(e, args);
    uint stateAfter = getValidatorState(opIndex, validatorData);
    assert (stateAfter == 4) =>
        (stateBefore == 3 || stateBefore == 4);
}
rule validatorStateTransition_4_3_M6(method f, env e, calldataarg args) filtered 
    { f -> isMethodID(f, 6) }
{
    require isValidState();
    bytes validatorData;
    uint opIndex;
    require operatorStateIsValid(opIndex);  //key <= limit <= funded <= exited
    require getKeysCount(opIndex) <= 4; //should not be higher than loop_iter 
    uint stateBefore = getValidatorState(opIndex, validatorData);
    f(e, args);
    uint stateAfter = getValidatorState(opIndex, validatorData);
    assert (stateAfter == 4) =>
        (stateBefore == 3 || stateBefore == 4);
}
rule validatorStateTransition_4_3_M8(method f, env e, calldataarg args) filtered 
    { f -> isMethodID(f, 8) }
{
    require isValidState();
    bytes validatorData;
    uint opIndex;
    require operatorStateIsValid(opIndex);  //key <= limit <= funded <= exited
    require getKeysCount(opIndex) <= 4; //should not be higher than loop_iter 
    uint stateBefore = getValidatorState(opIndex, validatorData);
    f(e, args);
    uint stateAfter = getValidatorState(opIndex, validatorData);
    assert (stateAfter == 4) =>
        (stateBefore == 3 || stateBefore == 4);
}

// https://prover.certora.com/output/6893/bbd548db7c82444d9c026c144569f25d/?anonymousKey=d329b065d252557c7e5bdaa1399139a44ae5e472
rule validatorStateTransition_4_3_M3(method f, env e, calldataarg args) filtered 
    { f -> isMethodID(f, 3) }
{
    require isValidState();
    bytes validatorData;
    uint opIndex;
    require operatorStateIsValid(opIndex);  //key <= limit <= funded <= exited
    require getKeysCount(opIndex) <= 4; //should not be higher than loop_iter 
    uint stateBefore = getValidatorState(opIndex, validatorData);
    f(e, args);
    uint stateAfter = getValidatorState(opIndex, validatorData);
    assert (stateAfter == 4) =>
        (stateBefore == 3 || stateBefore == 4);
}
rule validatorStateTransition_4_3_M4(method f, env e, calldataarg args) filtered 
    { f -> isMethodID(f, 4) }
{
    require isValidState();
    bytes validatorData;
    uint opIndex;
    require operatorStateIsValid(opIndex);  //key <= limit <= funded <= exited
    require getKeysCount(opIndex) <= 4; //should not be higher than loop_iter 
    uint stateBefore = getValidatorState(opIndex, validatorData);
    f(e, args);
    uint stateAfter = getValidatorState(opIndex, validatorData);
    assert (stateAfter == 4) =>
        (stateBefore == 3 || stateBefore == 4);
}
rule validatorStateTransition_4_3_M5(method f, env e, calldataarg args) filtered 
    { f -> isMethodID(f, 5) }
{
    require isValidState();
    bytes validatorData;
    uint opIndex;
    require operatorStateIsValid(opIndex);  //key <= limit <= funded <= exited
    require getKeysCount(opIndex) <= 4; //should not be higher than loop_iter 
    uint stateBefore = getValidatorState(opIndex, validatorData);
    f(e, args);
    uint stateAfter = getValidatorState(opIndex, validatorData);
    assert (stateAfter == 4) =>
        (stateBefore == 3 || stateBefore == 4);
}
rule validatorStateTransition_4_3_M11(method f, env e, calldataarg args) filtered 
    { f -> isMethodID(f, 11) }
{
    require isValidState();
    bytes validatorData;
    uint opIndex;
    require operatorStateIsValid(opIndex);  //key <= limit <= funded <= exited
    require getKeysCount(opIndex) <= 4; //should not be higher than loop_iter 
    uint stateBefore = getValidatorState(opIndex, validatorData);
    f(e, args);
    uint stateAfter = getValidatorState(opIndex, validatorData);
    assert (stateAfter == 4) =>
        (stateBefore == 3 || stateBefore == 4);
}

// https://prover.certora.com/output/6893/3be6184019f44f9ba01d2aec0f70fdc6/?anonymousKey=cd72e896d6b7b754cd0edf62003b1d58e18734f8
rule validatorStateTransition_0in_M15(method f, env e, calldataarg args) filtered 
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
    assert (stateAfter == 0) =>
        (stateBefore == 2 || stateBefore == 1 || stateBefore == 0);
}
