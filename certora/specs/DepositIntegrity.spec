// DepositIntegrity.spec — Deposit to consensus layer conservation
//
// Property: deposit_to_cl_conservation (LCP-RULE-05)
//
// When depositToConsensusLayerWithDepositRoot executes successfully,
// CommittedBalance decreases by exactly DEPOSIT_SIZE * N,
// DepositedValidatorCount increases by exactly N,
// and msg.sender must be KeeperAddress.

import "MathSummaries.spec";

using RiverHarness as river;

methods {
    function river.getCommittedBalanceHarness() external returns (uint256) envfree;
    function river.getDepositedValidatorCountHarness() external returns (uint256) envfree;
    function river.getKeeperHarness() external returns (address) envfree;
    function river.getSlashingContainmentModeHarness() external returns (bool) envfree;
    function river.getBalanceToDeposit() external returns (uint256) envfree;

    // External calls from the deposit path
    function _.pickNextValidatorsToDeposit(IOperatorsRegistryV1.OperatorAllocation[]) external => NONDET;
    function _.get_deposit_root() external => NONDET;
    function _.deposit(bytes, bytes, bytes, bytes32) external => NONDET;
    function _.onlyAllowed(address, uint256) external => NONDET;
    function _.isDenied(address) external => NONDET;
    function _.getAllowlist() external => NONDET;
}

// ════════════════════════════════════════════════════════════════════════════
// RULE: Only keeper can deposit to consensus layer
// ════════════════════════════════════════════════════════════════════════════

/// @notice depositToConsensusLayerWithDepositRoot can only be called by the keeper.
rule only_keeper_can_deposit_to_cl(env e) {
    IOperatorsRegistryV1.OperatorAllocation[] allocations;
    bytes32 depositRoot;
    
    require e.msg.value == 0;
    
    river.depositToConsensusLayerWithDepositRoot@withrevert(e, allocations, depositRoot);
    
    assert !lastReverted => e.msg.sender == river.getKeeperHarness(),
        "Only the keeper can successfully call depositToConsensusLayerWithDepositRoot";
}

// ════════════════════════════════════════════════════════════════════════════
// RULE: CommittedBalance + DepositedValidatorCount * 32e18 is conserved
// ════════════════════════════════════════════════════════════════════════════

/// @notice The sum CommittedBalance + DepositedValidatorCount * DEPOSIT_SIZE
///         is conserved across a successful depositToConsensusLayerWithDepositRoot call.
///         CommittedBalance decreases by exactly 32e18 * N, and 
///         DepositedValidatorCount increases by exactly N.
rule deposit_to_cl_conservation(env e) {
    IOperatorsRegistryV1.OperatorAllocation[] allocations;
    bytes32 depositRoot;
    
    uint256 committedBefore = river.getCommittedBalanceHarness();
    uint256 depositedCountBefore = river.getDepositedValidatorCountHarness();
    
    require e.msg.value == 0;
    
    river.depositToConsensusLayerWithDepositRoot@withrevert(e, allocations, depositRoot);
    
    require !lastReverted;

    uint256 committedAfter = river.getCommittedBalanceHarness();
    uint256 depositedCountAfter = river.getDepositedValidatorCountHarness();
    
    // The number of new validators
    mathint N = depositedCountAfter - depositedCountBefore;
    
    // N must be positive (at least one validator deposited)
    assert N > 0,
        "At least one validator must be deposited on success";
    
    // CommittedBalance decreases by exactly 32e18 * N
    assert to_mathint(committedBefore) - to_mathint(committedAfter) == N * 32000000000000000000,
        "CommittedBalance must decrease by exactly DEPOSIT_SIZE * N";
    
    // Conservation: CommittedBalance + DepositedValidatorCount * 32e18
    assert to_mathint(committedAfter) + to_mathint(depositedCountAfter) * 32000000000000000000
        == to_mathint(committedBefore) + to_mathint(depositedCountBefore) * 32000000000000000000,
        "CommittedBalance + DepositedValidatorCount * DEPOSIT_SIZE must be conserved";
}
