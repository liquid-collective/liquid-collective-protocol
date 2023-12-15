import "Sanity.spec";

using AllowlistV1 as AL;
using CoverageFundV1 as CF;
using ELFeeRecipientV1 as ELFR;
using OperatorsRegistryV1 as OR;
using RedeemManagerV1 as RM;
using WithdrawV1 as Wd;

use rule sanity;
// sanity passes here:
// https://prover.certora.com/output/40577/2031abdd92254bafb49b487cb7466b12?anonymousKey=cef84e43b9a622eb29ce44539dba2dd9a9721096
// sanity with less unresolved calls here:
// https://prover.certora.com/output/40577/49c466500a5248b8b95e9a3a6a2ea245?anonymousKey=e1f4c6e3f2bc651eccad0ed1463ece870525478b


methods {
    // AllowlistV1
    function AL.onlyAllowed(address, uint256) external envfree;
    function _.onlyAllowed(address, uint256) external => DISPATCHER(true);
    function AL.isDenied(address) external returns (bool) envfree;
    function _.isDenied(address) external => DISPATCHER(true);

    // RedeemManagerV1
    function RM.resolveRedeemRequests(uint32[]) external returns(int64[]) envfree;
    function _.resolveRedeemRequests(uint32[]) external => DISPATCHER(true);
     // requestRedeem function is also defined in River:
    function _.requestRedeem(uint256, address) external => DISPATCHER(true);
    function _.requestRedeem(uint256) external => DISPATCHER(true);
    function _.claimRedeemRequests(uint32[], uint32[], bool, uint16) external => DISPATCHER(true);
    function _.claimRedeemRequests(uint32[], uint32[]) external => DISPATCHER(true);
    function _.pullExceedingEth(uint256) external => DISPATCHER(true);
    function _.reportWithdraw(uint256) external => DISPATCHER(true);
    function RM.getRedeemDemand() external returns (uint256) envfree;
    function _.getRedeemDemand() external => DISPATCHER(true);

    // RiverV1
    function _.sendRedeemManagerExceedingFunds() external => DISPATCHER(true);
    function _.getAllowlist() external => DISPATCHER(true);
    function currentContract.getAllowlist() external returns(address) envfree;
    function _.sendCLFunds() external => DISPATCHER(true);
    function _.sendCoverageFunds() external => DISPATCHER(true);
    function _.sendELFees() external => DISPATCHER(true);
    // RiverV1 : SharesManagerV1
    function _.transferFrom(address, address, uint256) external => DISPATCHER(true);
    function _.underlyingBalanceFromShares(uint256) external => DISPATCHER(true);
    function currentContract.underlyingBalanceFromShares(uint256) external returns(uint256) envfree;
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
    function OR.getStoppedAndRequestedExitCounts() external returns (uint32, uint256) envfree;
    function _.getStoppedAndRequestedExitCounts() external => DISPATCHER(true);
    function _.demandValidatorExits(uint256, uint256) external => DISPATCHER(true);
    // function OR.pickNextValidatorsToDeposit(uint256) internal returns (bytes[], bytes[]);
    // function _.pickNextValidatorsToDeposit(uint256) internal;

    // function _.encodePacked(bytes32) internal;
}


