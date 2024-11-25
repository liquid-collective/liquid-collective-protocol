import "Base.spec";

methods {
    function _.mulDivDown(uint256 a, uint256 b, uint256 c) internal => mulDivDownAbstractPlus(a, b, 3) expect uint256 ALL;
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
