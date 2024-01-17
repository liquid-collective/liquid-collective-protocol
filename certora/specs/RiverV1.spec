import "Sanity.spec";
import "CVLMath.spec";

using AllowlistV1 as AL;
using CoverageFundV1 as CF;
// using DepositContractMock as DCM;
using ELFeeRecipientV1 as ELFR;
using OperatorsRegistryV1 as OR;
using RedeemManagerV1Harness as RM;
using WithdrawV1 as Wd;

use rule method_reachability;

// sanity passes here:
// https://prover.certora.com/output/40577/2031abdd92254bafb49b487cb7466b12?anonymousKey=cef84e43b9a622eb29ce44539dba2dd9a9721096
// sanity with less unresolved calls here:
// https://prover.certora.com/output/40577/49c466500a5248b8b95e9a3a6a2ea245?anonymousKey=e1f4c6e3f2bc651eccad0ed1463ece870525478b


methods {
	
    // AllowlistV1
    function AllowlistV1.onlyAllowed(address, uint256) external envfree;
    function _.onlyAllowed(address, uint256) external => DISPATCHER(true);
    function AllowlistV1.isDenied(address) external returns (bool) envfree;
    function _.isDenied(address) external => DISPATCHER(true);

    // RedeemManagerV1
    function RedeemManagerV1Harness.resolveRedeemRequests(uint32[]) external returns(int64[]) envfree;
    function _.resolveRedeemRequests(uint32[]) external => DISPATCHER(true); 
     // requestRedeem function is also defined in River:
    // function _.requestRedeem(uint256) external => DISPATCHER(true); //not required, todo: remove
    function _.requestRedeem(uint256 _lsETHAmount, address _recipient) external => DISPATCHER(true);
    function _.claimRedeemRequests(uint32[], uint32[], bool, uint16) external => DISPATCHER(true);
    // function _.claimRedeemRequests(uint32[], uint32[]) external => DISPATCHER(true); //not required, todo: remove
    function _.pullExceedingEth(uint256) external => DISPATCHER(true);
    function _.reportWithdraw(uint256) external => DISPATCHER(true);
    function RedeemManagerV1Harness.getRedeemDemand() external returns (uint256) envfree;
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
    function RiverV1Harness.balanceOfUnderlying(address) external returns(uint256) envfree;
    function RiverV1Harness.totalSupply() external returns(uint256) envfree;
    function RiverV1Harness.totalUnderlyingSupply() external returns(uint256) envfree;
    function RiverV1Harness.sharesFromUnderlyingBalance(uint256) external returns(uint256) envfree;
    function RiverV1Harness.balanceOf(address) external returns(uint256) envfree;
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

    // function _.increment_onDepositCounter() external => ghostUpdate_onDepositCounter() expect bool ALL;

    // MathSummarizations
    function _.mulDivDown(uint256 a, uint256 b, uint256 c) internal => mulDivDownAbstractPlus(a, b, c) expect uint256 ALL;

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

// ghost mathint counter_onDeposit; // counter checking number of calls to _onDeposit

// function ghostUpdate_onDepositCounter() returns bool
// {
//     counter_onDeposit = counter_onDeposit + 1;
// 	return true;
// }

// Ghost for each one of the factors in
// Ghost for Eth in Consensus layer
// Ghost for the RIver balance BalanceToDeposit.get() + CommittedBalance.get() + BalanceToRedeem.get() Eth Deposited
// Ghost for comitted Eth
// Consensus layer balance (depositedValidatorCount - clValidatorCount) * ConsensusLayerDepositManagerV1.DEPOSIT_SIZE


// @title Checks basic formula: totalSupply of shares must match number of underlying tokens.
// Proved
// https://prover.certora.com/output/40577/a451e923be1144ae88f125ac4f7b7a60?anonymousKey=69814a5c38c0f7720859be747546bbbde3f79191
invariant totalSupplyBasicIntegrity(env e)
    totalSupply(e) == sharesFromUnderlyingBalance(e, totalUnderlyingSupply(e));

    // Maybe try:
    // BalanceToDeposit.get() + CommittedBalance.get() + BalanceToRedeem.get() == River.balance(); //

// The Eth balance of River is corellated to the internal accounting. So the balance of river equals to 
// BalanceToDeposit.get() + CommittedBalance.get() + BalanceToRedeem.get()

// @title Checks our ghost ghostUpdate_onDepositCounter and that increment_onDepositCounter is called from _onDeposit function.
// rule depositHandlerFunctional(env env_for_f, method f, calldataarg args) filtered {
//     f -> f.selector == sig:RiverV1Harness.depositToConsensusLayer(uint256).selector ||
//          f.selector == sig:RiverV1Harness.depositAndTransfer(address).selector ||
//          f.selector == sig:RiverV1Harness.deposit().selector
// } {
//     mathint counter_onDeposit_before = counter_onDeposit;

//     f(env_for_f, args);

//     mathint counter_onDeposit_after = counter_onDeposit;

//     assert env_for_f.msg.value > 0 => counter_onDeposit_before != counter_onDeposit_after;
// }

// @title When user deposits, there is no additional gift component to the deposit.
// Passing here:
// https://prover.certora.com/output/40577/ab8a00d9e5804d6eb56316149457cbf8/?anonymousKey=224f9317520c66cc0c214cb632a02918577a85ef
rule depositAdditivityNoGiftsToEachDeposit(env e1, env e2, env eSum) {
    mathint amount1;
    mathint amount2;
    address recipient;

    require amount1 == to_mathint(e1.msg.value);
    require amount2 == to_mathint(e2.msg.value);
    require amount1 + amount2 == to_mathint(eSum.msg.value);

    mathint sharesBefore = balanceOf(recipient);

    storage initial = lastStorage;

    depositAndTransfer(e1, recipient);
    mathint shares1 = balanceOf(recipient);

    depositAndTransfer(e2, recipient) at initial;
    mathint shares2 = balanceOf(recipient);

    depositAndTransfer(eSum, recipient) at initial;
    mathint sharesSum = balanceOf(recipient);

    assert shares1 + shares2 <= sharesSum + sharesBefore;
}

// @title It is never benefitial for any user to deposit in multiple smaller patches instead of one big patch.
rule depositAdditivitySplittingNotProfitable(env e1, env e2, env eSum) {
    mathint amount1;
    mathint amount2;
    address recipient;

    require amount1 == to_mathint(e1.msg.value);
    require amount2 == to_mathint(e2.msg.value);
    require amount1 + amount2 == to_mathint(eSum.msg.value);
    // require amount1 == 500;
    // require amount2 == 600;

    mathint sharesBefore = balanceOf(recipient);

    storage initial = lastStorage;

    depositAndTransfer(e1, recipient);
    mathint shares1 = balanceOf(recipient);

    depositAndTransfer(e2, recipient);
    mathint shares2 = balanceOf(recipient);

    depositAndTransfer(eSum, recipient) at initial;
    mathint sharesSum = balanceOf(recipient);

    assert shares2 >= shares1;
    assert shares2 <= sharesSum;
}

// @title Up to off by one it is not benefitial to batch more deposits into one chunk
rule depositAdditivityBatchingNotExtremelyProfitable(env e1, env e2, env eSum) {
    mathint amount1;
    mathint amount2;
    address recipient;

    require amount1 == to_mathint(e1.msg.value);
    require amount2 == to_mathint(e2.msg.value);
    require amount1 + amount2 == to_mathint(eSum.msg.value);

    mathint sharesBefore = balanceOf(recipient);

    storage initial = lastStorage;

    depositAndTransfer(e1, recipient);
    mathint shares1 = balanceOf(recipient);

    depositAndTransfer(e2, recipient);
    mathint shares2 = balanceOf(recipient);

    depositAndTransfer(eSum, recipient) at initial;
    mathint sharesSum = balanceOf(recipient);

    assert shares2 + 1 >= sharesSum;
}