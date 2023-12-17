import "RiverV1.spec";

rule allowanceChangesRestrictively(method f) filtered {
    f -> !f.isView &&
        f.selector != sig:setConsensusLayerData(IOracleManagerV1.ConsensusLayerReport).selector
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
