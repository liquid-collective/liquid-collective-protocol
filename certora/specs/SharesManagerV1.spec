import "RiverV1.spec";

use rule sanity;

methods {
    // function _.requestRedeem(uint256, address) external => DISPATCHER(true);

    function allowance(address, address) external returns(uint256) envfree;
    function totalUnderlyingSupply() external returns(uint256) envfree;
    function totalSupply() external returns(uint256) envfree;
}

// @title The allowance can only be changed by functions listed in the filter:
// initRiverV1_1, setConsensusLayerData, decreaseAllowance, increaseAllowance, approve, transferFrom
// Almost fixed. Latest run:
// https://prover.certora.com/output/40577/c70e8e35cce446d495beb2c3904cf368?anonymousKey=11133ef88d529912cc091efea5f4f344eb2cf077
// We need this bug to be fixed:
// https://certora.atlassian.net/browse/CERT-4453
rule allowanceChangesRestrictively(method f) filtered {
    f -> !f.isView
        && f.selector != sig:initRiverV1_1(address,uint64,uint64,uint64,uint64,uint64,uint256,uint256,uint128,uint128).selector
        && f.selector != sig:setConsensusLayerData(IOracleManagerV1.ConsensusLayerReport).selector
        && f.selector != sig:decreaseAllowance(address,uint256).selector
        && f.selector != sig:increaseAllowance(address,uint256).selector
        && f.selector != sig:approve(address,uint256).selector
        && f.selector != sig:transferFrom(address,address,uint256).selector
}  {
    env e;
    calldataarg args;
    address owner;
    address spender;
    uint256 allowance_before = allowance(owner, spender);
    // require allowance_before == 12345;
    require owner != spender;
    f(e, args);
    uint256 allowance_after = allowance(owner, spender);
    // require allowance_after == 23456;
    assert allowance_after == allowance_before;
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

// @title The shares balance can only be changed by functions listed in the filter:
// transferFrom, transfer, setConsensusLayerData, depositAndTransfer, deposit, requestRedeem
rule sharesBalanceChangesRestrictively(method f) filtered {
    f -> !f.isView
        && f.selector != sig:transferFrom(address,address,uint256).selector
        && f.selector != sig:transfer(address,uint256).selector
        && f.selector != sig:setConsensusLayerData(IOracleManagerV1.ConsensusLayerReport).selector
        && f.selector != sig:depositAndTransfer(address).selector
        && f.selector != sig:deposit().selector
        && f.selector != sig:requestRedeem(uint256,address).selector
        // f.selector != sig:claimRedeemRequests(uint32[],uint32[]).selector
} {
    env e;
    calldataarg args;
    address owner;
    uint256 shares_balance_before = balanceOf(owner);
    f(e, args);
    uint256 shares_balance_after = balanceOf(owner);
    assert shares_balance_after == shares_balance_before;
}


// @title If the balance changes and shares balance is the same, it must have been one of these functions:
// initRiverV1_1, depositToConsensusLayer, claimRedeemRequests, deposit, depositAndTransfer
rule pricePerShareChangesRespectively(method f) filtered {
    f -> !f.isView
        && f.selector != sig:initRiverV1_1(address,uint64,uint64,uint64,uint64,uint64,uint256,uint256,uint128,uint128).selector
        && f.selector != sig:depositToConsensusLayer(uint256).selector
        && f.selector != sig:claimRedeemRequests(uint32[],uint32[]).selector
        && f.selector != sig:deposit().selector
        && f.selector != sig:depositAndTransfer(address).selector
} {
    env e;
    calldataarg args;
    address owner;
    uint256 shares_balance_before = balanceOf(owner);
    uint256 underlying_balance_before = balanceOfUnderlying(owner);
    f(e, args);
    uint256 shares_balance_after = balanceOf(owner);
    uint256 underlying_balance_after = balanceOfUnderlying(owner);
    assert shares_balance_before == shares_balance_after => underlying_balance_before == underlying_balance_after;
}

rule conversionRateStable(env e, method f) filtered {
    f -> !f.isView
        // && f.selector == sig:RiverV1Harness.depositToConsensusLayer(uint256).selector
} {
    calldataarg args;

    mathint totalETHBefore = totalSupply();
    mathint totalLsETHBefore = totalUnderlyingSupply();

    f(e, args);

    mathint totalETHAfter = totalSupply();
    mathint totalLsETHAfter = totalUnderlyingSupply();

    assert totalETHBefore * totalLsETHAfter == totalETHAfter * totalLsETHBefore;
}

rule conversionRateStableRewardsFeesPenalties(env e, method f) filtered {
    f -> !f.isView
        // && f.selector == sig:RiverV1Harness.depositToConsensusLayer(uint256).selector
} {
    calldataarg args;

    mathint totalETHBefore = totalSupply();
    mathint totalLsETHBefore = totalUnderlyingSupply();

    f(e, args);

    mathint totalETHAfter = totalSupply();
    mathint totalLsETHAfter = totalUnderlyingSupply();

    assert false;
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
