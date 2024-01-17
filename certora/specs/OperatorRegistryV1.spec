import "Sanity.spec";
import "CVLMath.spec";

//using AllowlistV1 as AL;
//using CoverageFundV1 as CF;
// using DepositContractMock as DCM;
//using ELFeeRecipientV1 as ELFR;
using OperatorsRegistryV1Harness as OR;
//using RedeemManagerV1Harness as RM;
//using WithdrawV1 as Wd;

use rule method_reachability;

methods {

    // OperatorsRegistryV1
    function _.reportStoppedValidatorCounts(uint32[], uint256) external => DISPATCHER(true);
    function OperatorsRegistryV1.getStoppedAndRequestedExitCounts() external returns (uint32, uint256) envfree;
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
    function OR.pickNextValidatorsToDeposit(uint256) external returns (bytes[] memory, bytes[] memory) envfree;
    function OR.requestValidatorExits(uint256) external;
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

invariant inactiveOperatorsRemainNonFunded(uint opIndex)
    !getOperator(opIndex).active => getOperator(opIndex).funded == 0;

invariant operatorsAddressesRemainUnique(uint opIndex1, uint opIndex2) 
    getOperatorAddress(opIndex1) == getOperatorAddress(opIndex2)
    => opIndex1 == opIndex2;

invariant operatorsStatesRemainValid(uint opIndex) 
    operatorStateIsValid(opIndex);

invariant validatorKeysRemainUnique(
    uint opIndex1, uint valIndex1,
    uint opIndex2, uint valIndex2)
    compare(getValidatorKey(opIndex1, valIndex1),
        getValidatorKey(opIndex2, valIndex2)) =>
        (opIndex1 == opIndex2 && valIndex1 == valIndex2);

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
    filtered { f -> f.contract == currentContract } 
{
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
    filtered { f -> f.contract == currentContract } 
{
    uint countBefore = getOperatorsCount();
    f(e, args);
    uint countAfter = getOperatorsCount();
    assert countAfter > countBefore => canIncreaseOperatorsCount(f);
    assert countAfter < countBefore => canDecreaseOperatorsCount(f);
}

rule startingValidatorsDecreasesDiscrepancyFULL() {
    require getActiveOperatorsCount() <= 5; //there's a loop iter limit set to 5;
    uint discrepancyBefore = getOperatorsSaturationDiscrepancy();
    uint count;
    require count <= 10;
    pickNextValidatorsToDeposit(count);
    uint discrepancyAfter = getOperatorsSaturationDiscrepancy();
    assert discrepancyBefore >= discrepancyAfter;
}

rule exitingValidatorsDecreasesDiscrepancyFULL(env e) {
    require getActiveOperatorsCount() <= 5; //there's a loop iter limit set to 5;
    uint discrepancyBefore = getOperatorsSaturationDiscrepancy();
    uint count;
    require count <= 10;
    requestValidatorExits(e, count);
    uint discrepancyAfter = getOperatorsSaturationDiscrepancy();
    assert discrepancyBefore >= discrepancyAfter;
}

rule startingValidatorsDecreasesDiscrepancy(env e) {
require getActiveOperatorsCount() <= 3; //there's a loop iter limit set to 5;
    uint index1; uint index2;
    uint discrepancyBefore = getOperatorsSaturationDiscrepancy(index1, index2);
    uint count;
    require count <= 1;
    pickNextValidatorsToDeposit(e, count);
    uint discrepancyAfter = getOperatorsSaturationDiscrepancy(index1, index2);
    assert discrepancyBefore > 0 => discrepancyBefore >= discrepancyAfter;
}

rule exitingValidatorsDecreasesDiscrepancy(env e) {
    require getActiveOperatorsCount() <= 3; //there's a loop iter limit set to 5;
    uint index1; uint index2;
    uint discrepancyBefore = getOperatorsSaturationDiscrepancy(index1, index2);
    uint count;
    require count <= 1;
    requestValidatorExits(e, count);
    uint discrepancyAfter = getOperatorsSaturationDiscrepancy(index1, index2);
    assert discrepancyBefore > 0 => discrepancyBefore >= discrepancyAfter;
}

