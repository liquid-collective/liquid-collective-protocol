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


