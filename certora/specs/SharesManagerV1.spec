import "RiverV1.spec";

// I have some issues with the setup. See this run:
// https://prover.certora.com/output/40577/8b65edc6e72f4d2391c164ceb4a64022/?anonymousKey=17fd307139e0d734d0a14a4c964e77d73a18390f
rule allowanceChangesRestrictively(method f) filtered {
    f -> !f.isView &&
        f.selector != sig:initRiverV1_1(address,uint64,uint64,uint64,uint64,uint64,uint256,uint256,uint128,uint128).selector &&
        f.selector != sig:setConsensusLayerData(IOracleManagerV1.ConsensusLayerReport).selector &&
        f.selector != sig:decreaseAllowance(address,uint256).selector &&
        f.selector != sig:increaseAllowance(address,uint256).selector &&
        f.selector != sig:approve(address,uint256).selector &&
        f.selector != sig:transferFrom(address,address,uint256).selector
}  {
    env e;
    calldataarg args;
    address owner;
    address spender;
    uint256 allowance_before = allowance(e, owner, spender);
    f(e, args);
    uint256 allowance_after = allowance(e, owner, spender);
    assert allowance_before == allowance_after;
}
