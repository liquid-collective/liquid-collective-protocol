import "Sanity.spec";
import "CVLMath.spec";
import "OperatorRegistryV1_base.spec";

// some functions require loop_iter = 4 but loop_iter = 2 is sufficient for most. For this reason we run parametric rule and invariants in two version
//_LI4 for methods that require loop_iter = 4 and _LI2 for the others.

// ------------ startingValidatorsDecreasesDiscrepancy
// https://prover.certora.com/output/6893/73e6c96485364487ac8198f95b89e610/?anonymousKey=9b8cca62f69e27ec851d5adf0213986acb027345
rule startingValidatorsDecreasesDiscrepancy(env e) 
{
    uint256 allOpCount = getOperatorsCount();
    require allOpCount <= 3;
    
    uint index1; uint index2;
    require isOpIndexInBounds(index1);
    require isOpIndexInBounds(index2);
    require operatorStateIsValid(index1);
    require operatorStateIsValid(index2);

    uint discrepancyBefore = getOperatorsSaturationDiscrepancy(index1, index2);

    require getKeysCount(index1) < 5; 
    require getKeysCount(index2) < 5;
       
    uint count;
    require count > 0 && count <= 3;
    pickNextValidatorsToDeposit(e, count);
    uint discrepancyAfter = getOperatorsSaturationDiscrepancy(index1, index2);

    assert discrepancyBefore > 0 => to_mathint(discrepancyBefore) >= 
        discrepancyAfter - count + 1; // this conditions is fine as long as count <= MAX_VALIDATOR_ATTRIBUTION_PER_ROUND
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

// ------------ removeValidatorsDecreaseKeys
// https://prover.certora.com/output/6893/7cf4169661d349848b48bdb801332a30/?anonymousKey=a9d0cca76ad32ef0db778b09dd289239c76e740e
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

// ------------ whoCanChangeValidatorsCount
// https://prover.certora.com/output/6893/b8d27f759f814831ab93f3a95bc44578?anonymousKey=cb5693fec7bc3379beb005857b99f249cd624272
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
 
// ------------ exitingValidatorsDecreasesDiscrepancy
//Holds for loop iter 3 and at most 3 operators
//https://prover.certora.com/output/6893/3a9868a0e6644417a20fc6ab467b2674/?anonymousKey=9120cd1a469c6f54a750187052fdd95efdd53c9f
rule exitingValidatorsDecreasesDiscrepancy(env e) 
{
    require isValidState();
    uint index1; uint index2;
    uint discrepancyBefore = getOperatorsSaturationDiscrepancy(index1, index2);
    uint count;
    require count <= 1;
    requestValidatorExits(e, count);
    uint discrepancyAfter = getOperatorsSaturationDiscrepancy(index1, index2);
    assert discrepancyBefore > 0 => discrepancyBefore >= discrepancyAfter;
}

rule witness4_3ExitingValidatorsDecreasesDiscrepancy(env e) 
{
    require isValidState();
    uint index1; uint index2;
    uint discrepancyBefore = getOperatorsSaturationDiscrepancy(index1, index2);
    uint count;
    require count <= 1;
    requestValidatorExits(e, count);
    uint discrepancyAfter = getOperatorsSaturationDiscrepancy(index1, index2);
    satisfy discrepancyBefore == 4 && discrepancyAfter == 3;
}
// ------------ operatorsAddressesRemainUnique
// https://prover.certora.com/output/6893/9c93d379dbfb40058cb49f16ac5969ae/?anonymousKey=d30b8e9640702d57adfac94fbc1e2fbe1641c90c
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
        preserved requestValidatorExits(uint256 x) with(env e) { require x <= 2; }
        preserved pickNextValidatorsToDeposit(OperatorAllocation[] x) with(env e) { require x.length <= 1; }  
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
// https://prover.certora.com/output/6893/7e7ba2e6ef0c41c699671b492d536593/?anonymousKey=42f042f43a88d9c6a55b681021881a5875dbac2c
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
// ------------ whoCanDeactivateOperator
// https://prover.certora.com/output/6893/bbc5621023d04a75a04fe98fb76940b9/?anonymousKey=eb4b48fcd1912b632d79a6b325063023ecab3d40
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
// requires a specific conf! depth: 0
// https://prover.certora.com/output/6893/3764dc7b05e84c6c89dcc879fcfe63dc/?anonymousKey=f68a1cff027251750c8b662638cadd81b9e03938
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

// ------------ fundedAndExitedCanOnlyIncrease
// https://prover.certora.com/output/6893/50312ae64ff1479ba5309567a49a5caf/?anonymousKey=b4436b0c53f116c5cdb1ced309d634bbd908eea2
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
    f.selector != sig:requestValidatorExits(uint256).selector &&
    f.selector != sig:pickNextValidatorsToDeposit(OperatorAllocation[]).selector &&
    f.selector != sig:removeValidators(uint256,uint256[]).selector
    }

    // requires special configuration!
    // https://prover.certora.com/output/6893/b8f0e5fb8b3b4b5685a522ee20e967c9/?anonymousKey=504a8d77280a1fb1d9415114904b0872e7607815
invariant operatorsStatesRemainValid_LI2_pickNextValidatorsToDeposit(uint opIndex) 
    isValidState() => (operatorStateIsValid(opIndex))
    filtered { f -> !ignoredMethod(f) && 
    !needsLoopIter4(f) && f.selector != sig:pickNextValidatorsToDeposit(OperatorAllocation[]).selector
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
    filtered { f -> f.selector == sig:requestValidatorExits(uint256).selector }
    { 
        preserved requestValidatorExits(uint256 x) with(env e) { require x <= 2; }  
    }
// https://prover.certora.com/output/6893/9b9eaf30d9274d02934641a25351218f/?anonymousKey=27d543677f1c1d051d7a5715ce4e41fd5ffaf412
invariant operatorsStatesRemainValid_LI2_cond2_requestValidatorExits(uint opIndex) 
    isValidState() => (operatorStateIsValid_cond2(opIndex))
    filtered { f -> f.selector == sig:requestValidatorExits(uint256).selector }
    { 
        preserved requestValidatorExits(uint256 x) with(env e) { require x <= 2; }  
    }

// https://prover.certora.com/output/6893/87eaf2d5d9ad427781570b215598a7a7/?anonymousKey=7e0aa6df6957986370875945b0c894a2b993b99c
invariant operatorsStatesRemainValid_LI2_cond1_requestValidatorExits(uint opIndex) 
    isValidState() => (operatorStateIsValid_cond1(opIndex))
    filtered { f -> f.selector == sig:requestValidatorExits(uint256).selector }


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

// ------------ removeValidatorsRevertsIfKeysNotSorted
// https://prover.certora.com/output/6893/e196595be7c7416b9651984d1c4cf1a6/?anonymousKey=0dc04aff2d0ae7d474cbe49e5222d1400fd1c644
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
// ------------ removeValidatorsRevertsIfKeysDuplicit
// https://prover.certora.com/output/6893/e196595be7c7416b9651984d1c4cf1a6/?anonymousKey=0dc04aff2d0ae7d474cbe49e5222d1400fd1c644
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


// https://prover.certora.com/output/6893/8e6109dc221a49d782c0eb3ce807e00c/?anonymousKey=786ba4f35a6ab44127e77c09a7283c87260c2025
rule newNOHasZeroKeys(env e)
{
    require isValidState();
    address opAddress;
    uint newOpIndex;
    newOpIndex = addOperator(e, "newNO", opAddress);
    uint keysCount = getKeysCount(newOpIndex);
    assert keysCount == 0;
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

