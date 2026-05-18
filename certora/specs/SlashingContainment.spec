// SlashingContainment.spec — Slashing containment blocks mutations
//
// Property: slashing_containment_blocks_mutations (LCP-RULE-40)
//
// When slashingContainmentMode is true, deposit(), depositAndTransfer(),
// receive() (deposit path), requestRedeem(), and depositToConsensusLayerWithDepositRoot()
// must all revert. claimRedeemRequests must remain callable.

import "MathSummaries.spec";

using RiverHarness as river;

methods {
    function river.getSlashingContainmentModeHarness() external returns (bool) envfree;
    function river.getKeeperHarness() external returns (address) envfree;
    function river.getAdminHarness() external returns (address) envfree;
    function river.getTotalSupply() external returns (uint256) envfree;
    function river.balanceOf(address) external returns (uint256) envfree;
    function river.getAssetBalance() external returns (uint256) envfree;

    // Summarize external dependencies
    function _.onlyAllowed(address, uint256) external => NONDET;
    function _.isDenied(address) external => NONDET;
    function _.getAllowlist() external => NONDET;
    function _.pullELFees(uint256) external => NONDET;
    function _.pullCoverageFunds(uint256) external => NONDET;
    function _.pullEth(uint256) external => NONDET;
    function _.pullExceedingEth(uint256) external => NONDET;
    function _.requestRedeem(uint256, address, address) external => NONDET;
    function _.reportWithdraw(uint256) external => NONDET;
    function _.getRedeemDemand() external => NONDET;
    function _.reportStoppedValidatorCounts(uint32[], uint256) external => NONDET;
    function _.demandValidatorExits(uint256, uint256) external => NONDET;
    function _.getStoppedAndRequestedExitCounts() external => NONDET;
    function _.pickNextValidatorsToDeposit(IOperatorsRegistryV1.OperatorAllocation[]) external => NONDET;
    function _.get_deposit_root() external => NONDET;
    function _.deposit(bytes, bytes, bytes, bytes32) external => NONDET;
    function _.transferFrom(address, address, uint256) external => NONDET;
    function _.setConsensusLayerData(IOracleManagerV1.ConsensusLayerReport) external => NONDET;
    function _.isValidEpoch(uint256) external => NONDET;
    function _.getSlashingContainmentMode() external => NONDET;
    function _.claimRedeemRequests(uint32[], uint32[], bool, uint16) external => NONDET;
}

// ════════════════════════════════════════════════════════════════════════════
// RULE 1: deposit() reverts when slashing containment mode is active
// ════════════════════════════════════════════════════════════════════════════

rule deposit_reverts_in_containment(env e) {
    require river.getSlashingContainmentModeHarness();
    require e.msg.value > 0;
    
    river.deposit@withrevert(e);
    
    assert lastReverted,
        "deposit() must revert when slashing containment mode is active";
}

// ════════════════════════════════════════════════════════════════════════════
// RULE 2: depositAndTransfer() reverts when slashing containment mode is active
// ════════════════════════════════════════════════════════════════════════════

rule depositAndTransfer_reverts_in_containment(env e) {
    address recipient;
    require recipient != 0;
    require river.getSlashingContainmentModeHarness();
    require e.msg.value > 0;
    
    river.depositAndTransfer@withrevert(e, recipient);
    
    assert lastReverted,
        "depositAndTransfer() must revert when slashing containment mode is active";
}

// ════════════════════════════════════════════════════════════════════════════
// RULE 3: requestRedeem() reverts when slashing containment mode is active
// ════════════════════════════════════════════════════════════════════════════

rule requestRedeem_reverts_in_containment(env e) {
    uint256 amount;
    address recipient;
    require river.getSlashingContainmentModeHarness();
    require e.msg.value == 0;
    require amount > 0;
    
    river.requestRedeem@withrevert(e, amount, recipient);
    
    assert lastReverted,
        "requestRedeem() must revert when slashing containment mode is active";
}

// ════════════════════════════════════════════════════════════════════════════
// RULE 4: depositToConsensusLayerWithDepositRoot() reverts in containment
// ════════════════════════════════════════════════════════════════════════════

rule depositToConsensusLayer_reverts_in_containment(env e) {
    IOperatorsRegistryV1.OperatorAllocation[] allocations;
    bytes32 depositRoot;
    
    require river.getSlashingContainmentModeHarness();
    // Caller is the keeper (otherwise it reverts for a different reason)
    require e.msg.sender == river.getKeeperHarness();
    require e.msg.value == 0;
    
    river.depositToConsensusLayerWithDepositRoot@withrevert(e, allocations, depositRoot);
    
    assert lastReverted,
        "depositToConsensusLayerWithDepositRoot() must revert in slashing containment mode";
}
