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
    return getActiveOperatorsCount() <= 3;
}

definition ignoredMethod(method f) returns bool =
    f.selector == sig:forceFundedValidatorKeysEventEmission(uint256).selector ||
    //f.selector == sig:_migrateOperators_V1_1().selector ||
    f.selector == sig:initOperatorsRegistryV1_1().selector;

invariant inactiveOperatorsRemainNonFunded(uint opIndex) 
    isValidState() => (!getOperator(opIndex).active => getOperator(opIndex).funded == 0)
    filtered { f -> !ignoredMethod(f) }

invariant operatorsAddressesRemainUnique(uint opIndex1, uint opIndex2) 
    isValidState() => (getOperatorAddress(opIndex1) == getOperatorAddress(opIndex2)
    => opIndex1 == opIndex2)
    filtered { f -> !ignoredMethod(f) }

invariant operatorsStatesRemainValid(uint opIndex) 
    isValidState() => (operatorStateIsValid(opIndex))
    filtered { f -> !ignoredMethod(f) }

invariant validatorKeysRemainUnique(
    uint opIndex1, uint valIndex1,
    uint opIndex2, uint valIndex2)
    isValidState() => (compare(getValidatorKey(opIndex1, valIndex1),
        getValidatorKey(opIndex2, valIndex2)) =>
        (opIndex1 == opIndex2 && valIndex1 == valIndex2))
    filtered { f -> !ignoredMethod(f) }

definition canActivateOperators(method f) returns bool = 
	//f.selector == sig:depositToConsensusLayer(uint256).selector || 
    //f.selector == sig:setConsensusLayerData(uint256,uint256,uint256,uint256,uint256,uint32,uint32[],bool,bool).selector ||
    f.selector == sig:initOperatorsRegistryV1_1().selector ||
    f.selector == sig:setOperatorStatus(uint256,bool).selector;

definition canDeactivateOperators(method f) returns bool =
    //f.selector == sig:RM.claimRedeemRequests(uint32[],uint32[]).selector || 
    //f.selector == sig:setConsensusLayerData(uint256,uint256,uint256,uint256,uint256,uint32,uint32[],bool,bool).selector ||
    f.selector == sig:requestValidatorExits(uint256).selector || 
    f.selector == sig:removeValidators(uint256,uint256[]).selector || 
    f.selector == sig:initOperatorsRegistryV1_1().selector ||
    f.selector == sig:setOperatorStatus(uint256,bool).selector;

rule whoCanDeactivateOperator(method f, env e, calldataarg args)
    filtered { f -> f.contract == currentContract && !ignoredMethod(f) } 
{
    require isValidState();
    uint opIndex;
    bool isActiveBefore = operatorIsActive(opIndex);
    f(e, args);
    bool isActiveAfter = operatorIsActive(opIndex);
    assert (isActiveBefore && !isActiveAfter) => canDeactivateOperators(f);
    assert (!isActiveBefore && isActiveAfter) => canActivateOperators(f);
}

definition canIncreaseOperatorsCount(method f) returns bool = 
	f.selector == sig:addOperator(string,address).selector || 
    f.selector == sig:initOperatorsRegistryV1_1().selector;
    //f.selector == sig:depositToConsensusLayer(uint256).selector ;

definition canDecreaseOperatorsCount(method f) returns bool = 
    f.selector == sig:initOperatorsRegistryV1_1().selector;

rule whoCanChangeOperatorsCount(method f, env e, calldataarg args) 
    filtered { f -> f.contract == currentContract && !ignoredMethod(f) } 
{
    require isValidState();
    uint countBefore = getOperatorsCount();
    f(e, args);
    uint countAfter = getOperatorsCount();
    assert countAfter > countBefore => canIncreaseOperatorsCount(f);
    assert countAfter < countBefore => canDecreaseOperatorsCount(f);
}

rule startingValidatorsDecreasesDiscrepancyFULL(env e) {
    require isValidState();
    uint discrepancyBefore = getOperatorsSaturationDiscrepancy();
    uint count;
    require count <= 10;
    pickNextValidatorsToDeposit(e, count);
    uint discrepancyAfter = getOperatorsSaturationDiscrepancy();
    assert discrepancyBefore >= discrepancyAfter;
}

rule exitingValidatorsDecreasesDiscrepancyFULL(env e) {
    require isValidState();
    uint discrepancyBefore = getOperatorsSaturationDiscrepancy();
    uint count;
    require count <= 10;
    requestValidatorExits(e, count);
    uint discrepancyAfter = getOperatorsSaturationDiscrepancy();
    assert discrepancyBefore >= discrepancyAfter;
}

rule startingValidatorsDecreasesDiscrepancy(env e) 
{
    require isValidState();
    uint index1; uint index2;
    uint discrepancyBefore = getOperatorsSaturationDiscrepancy(index1, index2);
    uint count;
    require count <= 1;
    pickNextValidatorsToDeposit(e, count);
    uint discrepancyAfter = getOperatorsSaturationDiscrepancy(index1, index2);
    assert discrepancyBefore > 0 => discrepancyBefore >= discrepancyAfter;
}

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

// shows that operator.funded, operator.keys, etc. can only increase in time.
// this proves that validators' state transitions are correct, i.e. fundable -> funded -> exited, etc 
rule operatorsStatsCanOnlyIncrease(method f, env e, calldataarg args) filtered 
    { f -> !f.isView && !ignoredMethod(f) }
{
    require isValidState();
    uint256 opIndex;
    uint256 keysBefore; uint256 limitBefore; uint256 fundedBefore; uint256 requestedExitsBefore; bool activeBefore; address operatorBefore;
    keysBefore, limitBefore, fundedBefore, requestedExitsBefore, activeBefore, operatorBefore = getOperatorState(e, opIndex);

    f(e, args);
    uint256 keysAfter; uint256 limitAfter; uint256 fundedAfter; uint256 requestedExitsAfter; bool activeAfter; address operatorAfter;
    keysAfter, limitAfter, fundedAfter, requestedExitsAfter, activeAfter, operatorAfter = getOperatorState(e, opIndex);

    assert keysBefore <= keysAfter; 
    //assert limitBefore <= limitAfter;
    assert fundedBefore <= fundedAfter;
    assert requestedExitsBefore <= requestedExitsAfter;
}
 
rule removeValidatorsRevertsIfKeysNotSorted(env e)
{
    require getOperatorsCount() <= 2; //doesn't need more for this
    uint256[] keys;
    require keys.length <= 5; //must be less than loop iter
    uint opIndex;
    uint keysIndex1; uint keysIndex2;
    uint key1 = keys[keysIndex1]; uint key2 = keys[keysIndex2];
    require keysIndex1 < keysIndex2 && keys[keysIndex1] > keys[keysIndex2]; //not sorted
    removeValidators@withrevert(e, opIndex, keys);
    assert lastReverted;
}

rule removeValidatorsRevertsIfKeysDuplicit(env e)
{
    require getOperatorsCount() <= 2; //doesn't need more for this
    uint256[] keys;
    require keys.length <= 5; //must be less than loop iter
    uint opIndex;
    uint keysIndex1; uint keysIndex2;
    uint key1 = keys[keysIndex1]; uint key2 = keys[keysIndex2];
    require keysIndex1 != keysIndex2 && keys[keysIndex1] == keys[keysIndex2]; //duplicit
    removeValidators@withrevert(e, opIndex, keys);
    assert lastReverted;
}

