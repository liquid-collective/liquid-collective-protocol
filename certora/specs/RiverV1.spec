import "Sanity.spec";
import "CVLMath.spec";
import "MathSummaries.spec";

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
    function getBalanceToDeposit() external returns(uint256) envfree;
    function getCommittedBalance() external returns(uint256) envfree;
    function getBalanceToRedeem() external returns(uint256) envfree;
    function consensusLayerDepositSize() external returns(uint256) envfree;
    function riverEthBalance() external returns(uint256) envfree;
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
    function RiverV1Harness.consensusLayerEthBalance() external returns(uint256) envfree;
    // RiverV1 : OracleManagerV1
    function _.setConsensusLayerData(IOracleManagerV1.ConsensusLayerReport) external => DISPATCHER(true);
    function RiverV1Harness.getCLValidatorCount() external returns(uint256) envfree;
    // RiverV1 : ConsensusLayerDepositManagerV1
    function _.depositToConsensusLayer(uint256) external => DISPATCHER(true);
    function RiverV1Harness.getDepositedValidatorCount() external returns(uint256) envfree;

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
	require(buffer.length <= require_uint256(start + len));
	bytes32 buffer_hash = keccak256(buffer);
	require keccak256(to_ret) == sliceGhost[buffer_hash][start];
	return to_ret;
}

// Ghost for each one of the factors in
// Ghost for Eth in Consensus layer
// Ghost for the RIver balance BalanceToDeposit.get() + CommittedBalance.get() + BalanceToRedeem.get() Eth Deposited
// Ghost for comitted Eth
// Consensus layer balance (depositedValidatorCount - clValidatorCount) * ConsensusLayerDepositManagerV1.DEPOSIT_SIZE


// @title Checks basic formula: totalSupply of shares must match number of underlying tokens.
// Proved
// https://prover.certora.com/output/40577/a451e923be1144ae88f125ac4f7b7a60?anonymousKey=69814a5c38c0f7720859be747546bbbde3f79191
invariant totalSupplyBasicIntegrity()
    totalSupply() == sharesFromUnderlyingBalance(totalUnderlyingSupply());

// @title setConsensusLayerData does not break the following statement: river balance is equal to the sum BalanceToDeposit.get() + CommittedBalance.get() + BalanceToRedeem.get()
// https://prover.certora.com/output/40577/70efd3b673224aebae46ced21e150dce/?anonymousKey=68b4b3fa514f4aceb895c1306f3b44c48e2b4773
rule riverBalanceIsSumOf_ToDeposit_Commmitted_ToRedeem_for_setConsensusLayerData(env e)
{
    mathint assets_before = totalUnderlyingSupply();
    uint256 toDeposit_before = getBalanceToDeposit();
    uint256 committed_before = getCommittedBalance();
    uint256 toRedeem_before = getBalanceToRedeem();
    require assets_before == toDeposit_before + committed_before + toRedeem_before;
    // require assets_before == 0;
    // require toDeposit_before == 0;
    // require committed_before == 0;
    // require toRedeem_before == 0;

    IOracleManagerV1.ConsensusLayerReport report;

    setConsensusLayerData(e, report);

    mathint assets_after = totalUnderlyingSupply();
    uint256 toDeposit_after = getBalanceToDeposit();
    uint256 committed_after = getCommittedBalance();
    uint256 toRedeem_after = getBalanceToRedeem();

    assert assets_after == toDeposit_after + committed_after + toRedeem_after;
}

rule memoryVarsCanBeModifiedFromWithinFunction(env e)
{
    OracleManagerV1.ConsensusLayerDataReportingVariables vars;
    uint256 a;
    require a == vars.trace.rewards;
    pullELFees(e, vars);
    satisfy vars.trace.rewards != a;
}

rule riverBalanceIsSumOf_ToDeposit_Commmitted_ToRedeem_for_helper2_helper7(env e)
{
    mathint assets_before = totalUnderlyingSupply();
    uint256 toDeposit_before = getBalanceToDeposit();
    uint256 committed_before = getCommittedBalance();
    uint256 toRedeem_before = getBalanceToRedeem();
    mathint sum_before = toDeposit_before + committed_before + toRedeem_before;
    uint256 river_balance_before = riverEthBalance();
    require e.msg.sender != currentContract;
    // require assets_before == 0;
    // require toDeposit_before == 0;
    // require committed_before == 0;
    // require toRedeem_before == 0;

    IOracleManagerV1.ConsensusLayerReport report;
    OracleManagerV1.ConsensusLayerDataReportingVariables vars1 = fillUpVarsAndPullCL(e, report);
    // OracleManagerV1.ConsensusLayerDataReportingVariables vars2;

    // require vars1.preReportUnderlyingBalance == totalUnderlyingSupply();

    updateLastReport(e, report); // Just reports, no changes to argument.

    uint256 totalSupplyMidterm = totalUnderlyingSupply();
    uint256 val_balance_midterm = report.validatorsBalance;
    // do something in between
    // require vars1.preReportUnderlyingBalance == vars2.preReportUnderlyingBalance;
    // require vars1.preReportUnderlyingBalance == vars2.preReportUnderlyingBalance;
    // require totalUnderlyingSupply() == vars2.postReportUnderlyingBalance;
    // // require totalUnderlyingSupply() == vars1.postReportUnderlyingBalance; // pass immediately
    // require vars1.lastReportExitedBalance == vars2.lastReportExitedBalance;
    // require vars1.lastReportExitedBalance == 1;
    // require vars1.lastReportSkimmedBalance == vars2.lastReportSkimmedBalance;
    // require vars1.lastReportSkimmedBalance == 10;
    // require vars1.exitedAmountIncrease == vars2.exitedAmountIncrease;
    // require vars1.exitedAmountIncrease == 100;
    // require vars1.skimmedAmountIncrease == vars2.skimmedAmountIncrease;
    // require vars1.skimmedAmountIncrease == 1000;
    // require vars1.timeElapsedSinceLastReport == vars2.timeElapsedSinceLastReport;
    // require vars1.timeElapsedSinceLastReport == 10000;
    // require vars1.availableAmountToUpperBound == vars2.availableAmountToUpperBound;
    // require vars1.availableAmountToUpperBound == 10000;
    // require vars1.redeemManagerDemand == vars2.redeemManagerDemand;
    // require vars1.redeemManagerDemand == 100000;

    OracleManagerV1.ConsensusLayerDataReportingVariables vars4 = pullELFees(e, vars1); // Also changes vars


    // require to_mathint(vars2.trace.rewards) == vars1.trace.rewards + rewards_delta;
    // require rewards_delta == vars1.availableAmountToUpperBound;
    // require vars2.trace.rewards == vars2.postReportUnderlyingBalance - vars.preReportUnderlyingBalance;

    onEarnings(e, vars4); // Just pull on earnings, no changes to argument

    mathint assets_after = totalUnderlyingSupply();
    uint256 toDeposit_after = getBalanceToDeposit();
    uint256 committed_after = getCommittedBalance();
    uint256 toRedeem_after = getBalanceToRedeem();
    mathint sum_after = toDeposit_after + committed_after + toRedeem_after;
    uint256 river_balance_after = riverEthBalance();
    require assets_after == 34636832;

    // satisfy  toDeposit_after != toDeposit_before;
    // satisfy  committed_after != committed_before;
    // satisfy  toRedeem_after != toRedeem_before;
    // assert river_balance_after - river_balance_before == sum_after - sum_before;
    assert river_balance_after + sum_before == sum_after + river_balance_before;
}

rule riverBalanceIsSumOf_ToDeposit_Commmitted_ToRedeem(env e, method f, calldataarg args) filtered {
    f -> !f.isView
        && f.selector != sig:sendCoverageFunds().selector
        && f.selector != sig:sendCLFunds().selector
        && f.selector != sig:sendRedeemManagerExceedingFunds().selector
        && f.selector != sig:certorafallback_0().selector
        && f.selector != sig:sendELFees().selector
} {
    mathint assets_before = totalUnderlyingSupply();
    uint256 toDeposit_before = getBalanceToDeposit();
    uint256 committed_before = getCommittedBalance();
    uint256 toRedeem_before = getBalanceToRedeem();
    mathint sum_before = toDeposit_before + committed_before + toRedeem_before;
    uint256 river_balance_before = riverEthBalance();

    uint256 totalSupplyMidterm = totalUnderlyingSupply();
    require e.msg.sender != currentContract;

    f(e, args);

    mathint assets_after = totalUnderlyingSupply();
    uint256 toDeposit_after = getBalanceToDeposit();
    uint256 committed_after = getCommittedBalance();
    uint256 toRedeem_after = getBalanceToRedeem();
    mathint sum_after = toDeposit_after + committed_after + toRedeem_after;
    uint256 river_balance_after = riverEthBalance();
    //require assets_after == 34636832;

    assert river_balance_after + sum_before == sum_after + river_balance_before;
}

invariant riverBalanceIsSumOf_ToDeposit_Commmitted_ToRedeem_invariant()
    to_mathint(totalUnderlyingSupply()) == getBalanceToDeposit() + getCommittedBalance() + getBalanceToRedeem()
    filtered {
        f -> f.selector != sig:initRiverV1_1(address,uint64,uint64,uint64,uint64,uint64,uint256,uint256,uint128,uint128).selector
        && f.selector != sig:setConsensusLayerData(IOracleManagerV1.ConsensusLayerReport).selector
    }
// @title totalUnderlyingSupply equals to sum of River ETH balance and consensusLayerEthBalance computed in RiverV1Harness as:
//        (clValidatorCount - depositedValidatorCount) * depositSize
// invariant underlyingBalanceEqualToRiverBalancePlusConsensus()
//     to_mathint(totalUnderlyingSupply()) == riverEthBalance() + consensusLayerEthBalance()
//     {
//         preserved
//         {
//             // requireInvariant totalSupplyBasicIntegrity();
//             // requireInvariant riverBalanceIsSumOf_ToDeposit_Commmitted_ToRedeem();
//             require getDepositedValidatorCount() <= getCLValidatorCount();
//             require getCLValidatorCount() <= 2^64;
//             require consensusLayerDepositSize() <= 2^64;
//         }
//     }

rule underlyingBalanceEqualToRiverBalancePlusConsensus_claimRedeemRequests(env e)
{
    require getDepositedValidatorCount() <= getCLValidatorCount();
    require getCLValidatorCount() <= 2^64;
    require consensusLayerDepositSize() <= 2^64;
    require to_mathint(totalUnderlyingSupply()) == riverEthBalance() + consensusLayerEthBalance();

    uint32[] _redeemRequestIds;
    uint32[] _withdrawalEventIds;

    claimRedeemRequests(e, _redeemRequestIds, _withdrawalEventIds);

    assert to_mathint(totalUnderlyingSupply()) == riverEthBalance() + consensusLayerEthBalance();
}

rule consensusLayerEth_changeVitness(env e, method f, calldataarg args)
{
    mathint consensusLayerBalanceBefore = consensusLayerEthBalance();

    f(e, args);

    mathint consensusLayerBalanceAfter = consensusLayerEthBalance();

    assert consensusLayerBalanceBefore == consensusLayerBalanceAfter; // To see which function can change this
}

rule consensusLayerDepositSize_changeVitness(env e, method f, calldataarg args)
{
    mathint depositSizeBefore = consensusLayerDepositSize();

    f(e, args);

    mathint depositSizeAfter = consensusLayerDepositSize();

    assert depositSizeAfter == 2;
//    satisfy depositSizeBefore != depositSizeAfter; // To see which function can change this
}

rule getCLValidatorTotalBalance_changeVitness(env e, env e2, method f, calldataarg args)
{
    mathint before = getCLValidatorTotalBalance(e2);

    f(e, args);

    mathint after = getCLValidatorTotalBalance(e2);

    satisfy before != after; // To see which function can change this
}

rule getLastConsensusLayerReport_changeVitness(env e, env e2, method f, calldataarg args)
{
    IOracleManagerV1.StoredConsensusLayerReport before = getLastConsensusLayerReport(e2);

    f(e, args);

    IOracleManagerV1.StoredConsensusLayerReport after = getLastConsensusLayerReport(e2);

    assert before.epoch == after.epoch; // To see which function can change this
    assert after.epoch == 0;
}

rule underlyingBalanceEqualToRiverBalancePlusConsensus(env e, method f, calldataarg args)
{
    // require getDepositedValidatorCount() <= getCLValidatorCount();
    // require getCLValidatorCount() <= 2^64;
    // require consensusLayerDepositSize() <= 2^64;
    require to_mathint(totalUnderlyingSupply()) == riverEthBalance() + consensusLayerEthBalance();

    f(e, args);

    assert to_mathint(totalUnderlyingSupply()) == riverEthBalance() + consensusLayerEthBalance();
}
// @title total supply of LsEth = (total supply of staked ETH + (consensus layer + execution layer rewards) - (fees + penalties)) * ConversionRate I.e. given a conversion rate and balances, that LsEth balance/total supply is correct The same invariant for every owner’s balance
// rule totalSupplyMainIntegrity(env e, method f, calldataarg args) {
//     mathint totalLSEthBefore = totalSupply();
//     mathint totalEthStakedBefore = totalUnderlyingSupply();
//     mathint totalConsensusLayerRewardsBefore = 0; //TODO
//     mathint totalExecutionLayerRewardsBefore = 0; //TODO
//     mathint totalFeesBefore = 0; //TODO
//     mathint totalPenaltiesBefore = 0; //TODO

//     f(e, args);

//     assert false;
// }


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

// TODO:
// https://prover.certora.com/output/40577/c3d10e61df4f49488d206d34f2fff204/?anonymousKey=97de87a7167bdecd1118ac835cd02161e24fc32f
invariant noAssetsNoShares()
    totalUnderlyingSupply() == 0 => totalSupply() == 0;

// TODO:
invariant noAssetsNoSharesUser(address user)
    balanceOfUnderlying(user) == 0 => balanceOf(user) == 0;

// @title It is never benefitial for any user to deposit in multiple smaller patches instead of one big patch.
rule depositAdditivitySplittingNotProfitable(env e1, env e2, env eSum) {
    mathint amount1;
    mathint amount2;
    address recipient;

    requireInvariant noAssetsNoShares();
    requireInvariant noAssetsNoSharesUser(recipient);

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

    requireInvariant noAssetsNoShares();
    requireInvariant noAssetsNoSharesUser(recipient);

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

    assert shares2 + shares2 + 4 >= sharesSum;
}
