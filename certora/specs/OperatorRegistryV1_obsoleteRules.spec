import "Sanity.spec";
import "CVLMath.spec";
import "OperatorRegistryV1_base.spec";

//uses a more complex check for discrepancy that the prover can't handle
rule startingValidatorsDecreasesDiscrepancyFULL(env e) {
    require isValidState();
    require getOperatorsCount() > 0;
    uint discrepancyBefore = getOperatorsSaturationDiscrepancy();
    uint count;
    require count <= 10;
    pickNextValidatorsToDepositWithCount(e, count);
    uint discrepancyAfter = getOperatorsSaturationDiscrepancy();
    assert discrepancyBefore >= discrepancyAfter;
}

//uses a more complex check for discrepancy that the prover can't handle
rule exitingValidatorsDecreasesDiscrepancyFULL(env e) {
    require isValidState();
    uint discrepancyBefore = getOperatorsSaturationDiscrepancy();
    uint count;
    require count <= 10;
    requestValidatorExits(e, count);
    uint discrepancyAfter = getOperatorsSaturationDiscrepancy();
    assert discrepancyBefore >= discrepancyAfter;
}

//only used for debugging. The problem was solved.
rule rule_operatorStateRemainValid_setOperatorAddress(env e)
{
    //require isValidState();
    uint256 opIndex;
    uint256 countBefore = getActiveOperatorsCount();
    uint256 keysBefore; uint256 limitBefore; uint256 fundedBefore; 
    uint256 requestedExitsBefore; bool activeBefore; address operatorBefore;
    keysBefore, limitBefore, fundedBefore, requestedExitsBefore, activeBefore, operatorBefore = getOperatorState(e, opIndex);

    bool validBefore = operatorStateIsValid(opIndex);
    uint256 opIndex2;
    address newAddress;
    setOperatorAddress(e, opIndex2, newAddress);

    uint256 countAfter = getActiveOperatorsCount();
    uint256 keysAfter; uint256 limitAfter; uint256 fundedAfter; 
    uint256 requestedExitsAfter; bool activeAfter; address operatorAfter;
    keysAfter, limitAfter, fundedAfter, requestedExitsAfter, activeAfter, operatorAfter = getOperatorState(e, opIndex);

    bool validAfter = operatorStateIsValid(opIndex);
    assert validBefore => validAfter;
}

rule test_equals(env e) 
{
    uint256 opIndex = 0;
    require getKeysCount(opIndex) == 2;
    uint256 valIndex = 0;
    bytes val1 = getRawValidator(e, opIndex, valIndex);
    bytes32 hash_1 = getHash(val1);
    bytes val2 = getRawValidator(e, opIndex, valIndex);
    bytes32 hash_2 = getHash(val2);
    require val1.length <= 1000;
    require val2.length <= 1000;
    bool equals_func = equals(val1, val2);
    bool equals_direct = hash_1 == hash_2;

    assert equals_direct => equals_func;
}


