import "Sanity.spec";
import "CVLMath.spec";
import "OperatorRegistryV1_base.spec";

//uses a more complex check for discrepancy that the prover can't handle
rule startingValidatorsDecreasesDiscrepancyFULL(env e) {
    require isValidState();
    uint discrepancyBefore = getOperatorsSaturationDiscrepancy();
    uint count;
    require count <= 10;
    pickNextValidatorsToDeposit(e, count);
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


