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
	require(buffer.length <= require_uint256(start + len));
	bytes32 buffer_hash = keccak256(buffer);
	require keccak256(to_ret) == sliceGhost[buffer_hash][start];
	return to_ret;
}

//these methods require loopiter of 4. All the other require just 2.
// LI2: https://prover.certora.com/output/6893/3d347a54f192495b92462196b66a30d3/?anonymousKey=d426e148bff7c5bac48c4f68cec38b84ad2d5a2a
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

definition canIncreaseOperatorsCount(method f) returns bool = 
	f.selector == sig:addOperator(string,address).selector || 
    f.selector == sig:initOperatorsRegistryV1_1().selector;
    //f.selector == sig:depositToConsensusLayer(uint256).selector ;

definition canDecreaseOperatorsCount(method f) returns bool = 
    f.selector == sig:initOperatorsRegistryV1_1().selector;