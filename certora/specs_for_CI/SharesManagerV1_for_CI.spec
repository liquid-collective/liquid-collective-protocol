import "./../specs/Base.spec";
import "River_base.spec";

methods {
    function allowance(address, address) external returns(uint256) envfree;
    function balanceOf(address) external returns(uint256) envfree;
    function balanceOfUnderlying(address) external returns(uint256) envfree;
    function totalSupply() external returns(uint256) envfree;
}

ghost mathint counter_onEarnings{ // counter checking number of calls to _onDeposit
    init_state axiom counter_onEarnings == 0;
}
ghost mathint total_onEarnings{ // counter checking number of calls to _onDeposit
    init_state axiom total_onEarnings == 0;// this is total earned ETH
}
ghost mathint total_onDeposits{ // counter checking number of calls to _onDeposit
    init_state axiom total_onDeposits == 0;// this is total earned ETH
}

function ghostUpdate_onEarnings(uint256 amount) returns bool
{
    counter_onEarnings = counter_onEarnings + 1;
    total_onEarnings = total_onEarnings + amount;
    return true;
}

function ghostUpdate_onDeposits(uint256 amount) returns bool
{
    total_onDeposits = total_onDeposits + amount;
    return true;
}


// @title The allowance of spender given by owner can always be decreased to 0 by the owner.
// Proved:
// https://prover.certora.com/output/40577/8985ea476a404c22801668777b60cb1e/?anonymousKey=67dc2147dcdd5e40466d907f809241856718be06
rule alwaysPossibleToDecreaseAllowance()
{
    env e;
    address owner;
    address spender;
    uint256 amount;
    decreaseAllowance(e, spender, amount);
    uint256 allowance_after = allowance(owner, spender);
    satisfy e.msg.sender == owner && allowance_after == 0;
}

// @title It is impossible to increase any allowance by calling decreaseAllowance or transferFrom.
// Proved:
// https://prover.certora.com/output/40577/8985ea476a404c22801668777b60cb1e/?anonymousKey=67dc2147dcdd5e40466d907f809241856718be06
rule decreaseAllowanceAndTransferCannotIncreaseAllowance(env e, method f, calldataarg args) filtered {
    f -> f.selector == sig:decreaseAllowance(address,uint256).selector
        || f.selector == sig:transferFrom(address,address,uint256).selector
} {
    address owner;
    address spender;
    uint256 allowance_before = allowance(owner, spender);
    f(e, args);
    uint256 allowance_after = allowance(owner, spender);
    assert allowance_after <= allowance_before;
}

// @title Allowance increases only by owner
// Same issue as in allowanceChangesRestrictively
// https://prover.certora.com/output/40577/8985ea476a404c22801668777b60cb1e/?anonymousKey=67dc2147dcdd5e40466d907f809241856718be06
rule allowanceIncreasesOnlyByOwner(method f) filtered {
    f -> !f.isView
        && f.selector != sig:initRiverV1_1(address,uint64,uint64,uint64,uint64,uint64,uint256,uint256,uint128,uint128).selector
        && f.selector != sig:setConsensusLayerData(IOracleManagerV1.ConsensusLayerReport).selector
        && !ignoredMethod(f) && !excludedInCI(f)
}  {
    env e;
    calldataarg args;
    address owner;
    address spender;
    uint256 allowance_before = allowance(owner, spender);
    f(e, args);
    uint256 allowance_after = allowance(owner, spender);
    assert allowance_before < allowance_after => e.msg.sender == owner;
}

// This rule does not hold for setConsensusLayerData:
// https://prover.certora.com/output/40577/e5a7a762228c45d29adfbdc3ace30530/?anonymousKey=6206b628e02ad22f68fd8f33c537f4eebe44847f
rule sharesMonotonicWithAssets(env e, method f) filtered {
    f -> !f.isView
       // && f.selector != sig:requestRedeem(uint256,address).selector // Prover error
       && f.selector != sig:claimRedeemRequests(uint32[],uint32[]).selector // Claiming rewards can violate the property.
       && f.selector != sig:setConsensusLayerData(IOracleManagerV1.ConsensusLayerReport calldata).selector
       && !ignoredMethod(f) && !excludedInCI(f)
} {
    calldataarg args;

    mathint totalETHBefore = totalSupply();
    mathint totalLsETHBefore = totalUnderlyingSupply();

    f(e, args);

    mathint totalETHAfter = totalSupply();
    mathint totalLsETHAfter = totalUnderlyingSupply();

    // require totalETHBefore + totalLsETHBefore + totalETHAfter + totalLsETHAfter <= max_uint256;
    require totalETHBefore <= 2^128;
    require totalLsETHBefore <= 2^128;
    require totalETHAfter <= 2^128;
    require totalLsETHAfter <= 2^128;

    assert totalETHBefore > totalETHAfter => totalLsETHBefore >= totalLsETHAfter;
    assert totalETHBefore < totalETHAfter => totalLsETHBefore <= totalLsETHAfter;
    assert totalLsETHBefore > totalLsETHAfter => totalETHBefore >= totalETHAfter;
    assert totalLsETHBefore < totalLsETHAfter => totalETHBefore <= totalETHAfter;
}

// This rule does not hold for setConsensusLayerData:
// https://prover.certora.com/output/40577/e5a7a762228c45d29adfbdc3ace30530/?anonymousKey=6206b628e02ad22f68fd8f33c537f4eebe44847f
rule zeroAssetsZeroShares(env e, method f) filtered {
    f -> !f.isView
       // && f.selector != sig:requestRedeem(uint256,address).selector // Prover error
       && f.selector != sig:claimRedeemRequests(uint32[],uint32[]).selector // Claiming rewards can violate the property.
       && f.selector != sig:setConsensusLayerData(IOracleManagerV1.ConsensusLayerReport calldata).selector
       && !ignoredMethod(f) && !excludedInCI(f)
} {
    calldataarg args;

    mathint totalETHBefore = totalSupply();
    mathint totalLsETHBefore = totalUnderlyingSupply();
    require totalLsETHBefore == 0 <=> totalETHBefore == 0;

    f(e, args);

    mathint totalETHAfter = totalSupply();
    mathint totalLsETHAfter = totalUnderlyingSupply();

    // require totalETHBefore + totalLsETHBefore + totalETHAfter + totalLsETHAfter <= max_uint256;
    require totalETHBefore <= 2^128;
    require totalLsETHBefore <= 2^128;
    require totalETHAfter <= 2^128;
    require totalLsETHAfter <= 2^128;

    assert totalLsETHAfter == 0 <=> totalETHAfter == 0;
}

// @title After transfer from, balances are updated accordingly, but not of any other user. Also, totalSupply stays the same.
// Proved:
// https://prover.certora.com/output/40577/0d75136142bd4b458c77e73f4394f101/?anonymousKey=7c99f012e75eb4143a0c3f5dbc180eda79a0c0db
rule transferUpdatesBalances(env e) {
    address from;
    address to;
    address other;
    uint256 amount;
    mathint balanceSenderBefore = balanceOf(from);
    mathint balanceReceiverBefore = balanceOf(to);
    mathint balanceOtherBefore = balanceOf(other);
    mathint totalSupplyBefore = totalSupply();

    transferFrom(e, from, to, amount);

    mathint balanceSenderAfter = balanceOf(from);
    mathint balanceReceiverAfter = balanceOf(to);
    mathint balanceOtherAfter = balanceOf(other);
    mathint totalSupplyAfter = totalSupply();

    assert to != from => balanceSenderBefore - balanceSenderAfter == to_mathint(amount);
    assert to != from => balanceReceiverAfter - balanceReceiverBefore == to_mathint(amount);
    assert other != from && other != to => balanceOtherAfter == balanceOtherBefore;
    assert totalSupplyAfter == totalSupplyBefore;
}
