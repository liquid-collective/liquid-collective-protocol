import "./../specs/Sanity.spec";
import "./../specs/CVLMath.spec";
import "./../specs/MathSummaries.spec";
import "./../specs/Base.spec";
import "River_base.spec";

methods {
    // MathSummarizations
    function _.mulDivDown(uint256 a, uint256 b, uint256 c) internal => mulDivDownAbstractPlus(a, b, c) expect uint256 ALL;

}

invariant totalSupplyBasicIntegrity() 
    totalSupply() == sharesFromUnderlyingBalance(totalUnderlyingSupply())
    filtered { f -> !ignoredMethod(f) }

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

invariant noAssetsNoShares()
    totalUnderlyingSupply() == 0 => totalSupply() == 0
    filtered { f -> !ignoredMethod(f)
}

invariant noAssetsNoSharesUser(address user)
    balanceOfUnderlying(user) == 0 => balanceOf(user) == 0;

rule depositAdditivitySplittingNotProfitable(env e1, env e2, env eSum)
{
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

