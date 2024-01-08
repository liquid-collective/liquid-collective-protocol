import "Sanity.spec";

using AllowlistV1 as AL;
using CoverageFundV1 as CF;
// using DepositContractMock as DCM;
using ELFeeRecipientV1 as ELFR;
using OperatorsRegistryV1Harness as OR;
using RedeemManagerV1Harness as RM;
using WithdrawV1 as Wd;

use rule method_reachability;

methods {

    // AllowlistV1
    function AllowlistV1.onlyAllowed(address, uint256) external envfree;
    function _.onlyAllowed(address, uint256) external => DISPATCHER(true);
    function AllowlistV1.isDenied(address) external returns (bool) envfree;
    function _.isDenied(address) external => DISPATCHER(true);

    // RedeemManagerV1
    function RM.resolveRedeemRequests(uint32[]) external returns(int64[]) envfree;
    function _.resolveRedeemRequests(uint32[]) external => DISPATCHER(true); 
     // requestRedeem function is also defined in River:
    // function _.requestRedeem(uint256) external => DISPATCHER(true); //not required, todo: remove
    function _.requestRedeem(uint256 _lsETHAmount, address _recipient) external => DISPATCHER(true);
    function _.claimRedeemRequests(uint32[], uint32[], bool, uint16) external => DISPATCHER(true);
    // function _.claimRedeemRequests(uint32[], uint32[]) external => DISPATCHER(true); //not required, todo: remove
    function _.pullExceedingEth(uint256) external => DISPATCHER(true);
    function _.reportWithdraw(uint256) external => DISPATCHER(true);
    function RM.getRedeemDemand() external returns (uint256) envfree;
    function _.getRedeemDemand() external => DISPATCHER(true);

    // RiverV1
    function _.sendRedeemManagerExceedingFunds() external => DISPATCHER(true);
    function _.getAllowlist() external => DISPATCHER(true);
    function RiverV1Harness.getAllowlist() external returns(address) envfree;
    function _.sendCLFunds() external => DISPATCHER(true);
    function _.sendCoverageFunds() external => DISPATCHER(true);
    function _.sendELFees() external => DISPATCHER(true);
    
    // RiverV1 : SharesManagerV1
    function _.transferFrom(address, address, uint256) external => DISPATCHER(true);
    function _.underlyingBalanceFromShares(uint256) external => DISPATCHER(true);
    function RiverV1Harness.underlyingBalanceFromShares(uint256) external returns(uint256) envfree;
    // RiverV1 : OracleManagerV1
    function _.setConsensusLayerData(IOracleManagerV1.ConsensusLayerReport) external => DISPATCHER(true); 
    // RiverV1 : ConsensusLayerDepositManagerV1
    function _.depositToConsensusLayer(uint256) external => DISPATCHER(true);

    // WithdrawV1
    function _.pullEth(uint256) external => DISPATCHER(true);

    // ELFeeRecipientV1
    function _.pullELFees(uint256) external => DISPATCHER(true);

    // CoverageFundV1
    function _.pullCoverageFunds(uint256) external => DISPATCHER(true);

    // OperatorsRegistryV1
    function _.reportStoppedValidatorCounts(uint32[], uint256) external => DISPATCHER(true);
    function OperatorsRegistryV1.getStoppedAndRequestedExitCounts() external returns (uint32, uint256) envfree;
    function _.getStoppedAndRequestedExitCounts() external => DISPATCHER(true);
    function _.demandValidatorExits(uint256, uint256) external => DISPATCHER(true);
    function _.pickNextValidatorsToDeposit(uint256) external => DISPATCHER(true); // has no effect - CERT-4615

    function _.deposit(bytes,bytes,bytes,bytes32) external => DISPATCHER(true); // has no effect - CERT-4615 
    function OR.getOperatorAddress(uint256) external returns(address) envfree;
    function OR.operatorStateIsValid(uint256) external returns(bool) envfree;
    function OR.operatorIsActive(uint256) external returns(bool) envfree;
    function OR.getValidatorKey(uint256,uint256) external returns(bytes) envfree;
    function OR.getOperator(uint256) external returns(OperatorsV2.Operator memory) envfree;
}

rule inactiveOperatorsCantBeFunded()
{
    uint opIndex;
    OperatorsV2.Operator op = getOperator(opIndex);
    assert !op.active => op.funded == 0;
}

invariant inactiveOperatorsRemainNonFunded(uint opIndex)
    !getOperator(opIndex).active => getOperator(opIndex).funded == 0;

invariant operatorsAddressesRemainUnique(uint opIndex1, uint opIndex2) 
    getOperatorAddress(opIndex1) == getOperatorAddress(opIndex2)
    => opIndex1 == opIndex2;

invariant operatorsStatesRemainValid(uint opIndex) 
    operatorStateIsValid(opIndex);

rule canDeactivateAnyOperator() {
    uint opIndex;
    method f;
    env e; 
    calldataarg args;
    bool isActiveBefore = operatorIsActive(opIndex);
    f(e, args);
    bool isActiveAfter = operatorIsActive(opIndex);
    satisfy isActiveBefore && !isActiveAfter;
}

/*
invariant validatorKeysRemainUnique(
    uint opIndex1, uint valIndex1,
    uint opIndex2, uint valIndex2)
    (getValidatorKey(opIndex1, valIndex1) == 
        getValidatorKey(opIndex2, valIndex2)) =>
        (opIndex1 == opIndex2 && valIndex1 == valIndex2);
*/

