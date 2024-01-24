import "Sanity.spec";
import "CVLMath.spec";
//import "OperatorRegistryV1_base.spec";

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
	require(buffer.length <= require_uint256(start + len));
	bytes32 buffer_hash = keccak256(buffer);
	require keccak256(to_ret) == sliceGhost[buffer_hash][start];
	return to_ret;
}

use rule method_reachability;

//these methods require loopiter of 4
// LI3: https://prover.certora.com/output/6893/452145271ff04d63a8db8ccc56dde1ff/?anonymousKey=fdd8d20db9a84dc5c1d5be848cb14ef6c6f6705b
// LI4: https://prover.certora.com/output/6893/53cc556c787641b8b4f46582b884927d/?anonymousKey=926967facfef0c6ba24b2a0e6db960f5bca93584
definition needsLoopIter4(method f) returns bool =
    f.selector == sig:addValidators(uint256,uint32,bytes).selector ||
    f.selector == sig:reportStoppedValidatorCounts(uint32[],uint256).selector;

function isValidState() returns bool
{
    return getOperatorsCount() <= 3;
}

definition ignoredMethod(method f) returns bool =
    f.selector == sig:forceFundedValidatorKeysEventEmission(uint256).selector ||
    //f.selector == sig:_migrateOperators_V1_1().selector ||
    f.selector == sig:initOperatorsRegistryV1_1().selector;

invariant inactiveOperatorsRemainNotFunded(uint opIndex) 
    isValidState() => (!getOperator(opIndex).active => getOperator(opIndex).funded == 0)
    filtered { f -> !ignoredMethod(f) && 
        f.selector != sig:setOperatorStatus(uint256,bool).selector } //method is allowed to break this

invariant operatorsAddressesRemainUnique(uint opIndex1, uint opIndex2) 
    isValidState() => (getOperatorAddress(opIndex1) == getOperatorAddress(opIndex2)
    => opIndex1 == opIndex2)
    filtered { f -> !ignoredMethod(f) && 
        f.selector != sig:setOperatorAddress(uint256,address).selector } //method is allowed to break this

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

rule startingValidatorsDecreasesDiscrepancy(env e) 
{
    require isValidState();
    uint index1; uint index2;
    requireInvariant operatorsStatesRemainValid(index1);
    requireInvariant operatorsStatesRemainValid(index2);

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
    requireInvariant operatorsStatesRemainValid(index1);
    requireInvariant operatorsStatesRemainValid(index2);
    
    uint discrepancyBefore = getOperatorsSaturationDiscrepancy(index1, index2);
    uint count;
    require count <= 1;
    pickNextValidatorsToDeposit(e, count);
    uint discrepancyAfter = getOperatorsSaturationDiscrepancy(index1, index2);
    satisfy discrepancyBefore == 4 && discrepancyAfter == 3;
}

// shows that operator.funded and operator.requestedExits can only increase in time.
rule FundedAndExitedCanOnlyIncrease(method f, env e, calldataarg args) filtered 
    { f -> !f.isView && !ignoredMethod(f) }
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

