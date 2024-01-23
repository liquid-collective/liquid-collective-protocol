import "Sanity.spec";
import "CVLMath.spec";

using OperatorsRegistryV1Harness as OR;

methods {

    // OperatorsRegistryV1
    function _.reportStoppedValidatorCounts(uint32[], uint256) external => DISPATCHER(true);
    function OR.getStoppedAndRequestedExitCounts() external returns (uint32, uint256) envfree;
    function _.getStoppedAndRequestedExitCounts() external => DISPATCHER(true);
    function _.demandValidatorExits(uint256, uint256) external => DISPATCHER(true);
    //function _.pickNextValidatorsToDeposit(uint256) external => DISPATCHER(true); // has no effect - CERT-4615

    function _.deposit(bytes,bytes,bytes,bytes32) external => DISPATCHER(true); // has no effect - CERT-4615 
    function OR.getOperatorAddress(uint256) external returns(address) envfree;
    function OR.operatorStateIsValid(uint256) external returns(bool) envfree;
    function OR.operatorIsActive(uint256) external returns(bool) envfree;
    function OR.getValidatorKey(uint256,uint256) external returns(bytes) envfree;
    function OR.getOperator(uint256) external returns(OperatorsV2.Operator memory) envfree;
    function OR.compare(bytes,bytes) external returns (bool) envfree;
    function OR.getOperatorsCount() external returns (uint256) envfree;
    function OR.getActiveOperatorsCount() external returns (uint256) envfree;
    function OR.getOperatorsSaturationDiscrepancy() external returns (uint256) envfree;
    function OR.pickNextValidatorsToDeposit(uint256) external returns (bytes[] memory, bytes[] memory);
    function OR.requestValidatorExits(uint256) external;
    function OR.setOperatorAddress(uint256, address) external;   
    function OR.getOperatorsSaturationDiscrepancy(uint256, uint256) external returns (uint256) envfree;

    //workaroun per CERT-4615 
    function LibBytes.slice(bytes memory _bytes, uint256 _start, uint256 _length) internal returns (bytes memory) => bytesSliceSummary(_bytes, _start, _length);

}

ghost mapping(bytes32 => mapping(uint => bytes32)) sliceGhost;
function bytesSliceSummary(bytes buffer, uint256 start, uint256 len) returns bytes {
	bytes to_ret;
	require(to_ret.length == len);
	require(buffer.length < require_uint256(start + len));
	bytes32 buffer_hash = keccak256(buffer);
	require keccak256(to_ret) == sliceGhost[buffer_hash][start];
	return to_ret;
}

use rule method_reachability;

function isValidState() returns bool
{
    return getOperatorsCount() <= 3;
}

definition ignoredMethod(method f) returns bool =
    f.selector == sig:forceFundedValidatorKeysEventEmission(uint256).selector ||
    //f.selector == sig:_migrateOperators_V1_1().selector ||
    f.selector == sig:initOperatorsRegistryV1_1().selector;

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


