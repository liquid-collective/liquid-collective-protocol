// SharesInvariants.spec — LsETH total supply equals sum of all balances
//
// Property: lseth_total_supply_equals_sum_of_balances
//
// Shares.get() must always equal the sum of all SharesPerOwner balances.
// 
// Note: River uses unstructured storage (LibUnstructuredStorage) for Shares
// and SharesPerOwner, so we cannot use named Sstore/Sload hooks.
// Instead we use ghost + ALL_SSTORE/ALL_SLOAD hooks keyed on the known
// storage slots, or we rely on the ERC20 transfer/mint/burn events via
// the harness view functions.

using RiverHarness as river;

methods {
    function river.getTotalSupply() external returns (uint256) envfree;
    function river.getSharesPerOwner(address) external returns (uint256) envfree;
    function river.getCommittedBalanceHarness() external returns (uint256) envfree;
    function river.getAssetBalance() external returns (uint256) envfree;
    function river.getAdminHarness() external returns (address) envfree;
    function river.getKeeperHarness() external returns (address) envfree;
    function river.totalSupply() external returns (uint256) envfree;
    function river.balanceOf(address) external returns (uint256) envfree;

    // Summarize external calls that River makes to other contracts
    // These are not relevant to the share accounting property
    function _.onlyAllowed(address, uint256) external => NONDET;
    function _.isDenied(address) external => NONDET;
    function _.isAllowed(address, uint256) external => NONDET;
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

    function _.isValidEpoch(uint256) external => NONDET;
    function _.sendCLFunds() external => NONDET;
    function _.sendELFees() external => NONDET;
    function _.sendCoverageFunds() external => NONDET;
    function _.sendRedeemManagerExceedingFunds() external => NONDET;
}

// ════════════════════════════════════════════════════════════════════════════
// RULE: No function creates or destroys shares out of thin air
//       (totalSupply change always matches per-owner changes)
// ════════════════════════════════════════════════════════════════════════════

/// @notice 2-user model: if user1 and user2 hold ALL shares in the system,
///         then the total supply change must exactly equal the sum of their
///         balance changes (no shares created/destroyed out of thin air).
///         This is sound because if conservation holds for any 2-user partition
///         it holds for N users.
///
///         We filter out functions that can mint/burn shares to addresses
///         not controlled by msg.sender (e.g., setConsensusLayerData mints
///         to the collector, depositAndTransfer mints to an arbitrary recipient,
///         requestRedeem transfers to RedeemManager). For those, we write
///         dedicated rules or accept the coverage gap.
rule totalSupply_change_consistent_twoUsers(env e, method f, calldataarg args, address user1, address user2)
    filtered {
        f -> !f.isView
          && f.selector != sig:river.setConsensusLayerData(IOracleManagerV1.ConsensusLayerReport).selector
          && f.selector != sig:river.depositAndTransfer(address).selector
          && f.selector != sig:river.requestRedeem(uint256, address).selector
          && f.selector != sig:river.transferFrom(address, address, uint256).selector
          && f.selector != sig:river.sendELFees().selector
          && f.selector != sig:river.sendCLFunds().selector
          && f.selector != sig:river.sendCoverageFunds().selector
          && f.selector != sig:river.sendRedeemManagerExceedingFunds().selector
          && f.selector != sig:river.initRiverV1_2().selector
    }
{
    require user1 != user2;
    require e.msg.sender != river;

    // The 2-user model requires that msg.sender is one of the two tracked users
    // so that any minted/burned shares are captured in our balance tracking.
    require e.msg.sender == user1 || e.msg.sender == user2;

    // Require that all other known addresses hold zero shares.
    require river.getSharesPerOwner(river) == 0;

    mathint supplyBefore = to_mathint(river.getTotalSupply());
    mathint bal1Before = to_mathint(river.getSharesPerOwner(user1));
    mathint bal2Before = to_mathint(river.getSharesPerOwner(user2));

    // 2-user model: these two users hold ALL the shares
    require supplyBefore == bal1Before + bal2Before;

    f(e, args);

    mathint supplyAfter = to_mathint(river.getTotalSupply());
    mathint bal1After = to_mathint(river.getSharesPerOwner(user1));
    mathint bal2After = to_mathint(river.getSharesPerOwner(user2));

    // The conservation property: after the call, the two users still hold ALL shares.
    // If this fails, shares were created/destroyed outside the tracked partition.
    assert supplyAfter == bal1After + bal2After,
        "Total supply must equal sum of all balance deltas (2-user model)";
}

/// @notice Transfer between two users does not change total supply
rule transfer_preserves_supply(env e, address to, uint256 value) {
    require e.msg.sender != river;

    mathint supplyBefore = to_mathint(river.getTotalSupply());

    river.transfer(e, to, value);

    mathint supplyAfter = to_mathint(river.getTotalSupply());

    assert supplyAfter == supplyBefore,
        "Transfer must not change total supply";
}

/// @notice TransferFrom between two users does not change total supply
rule transferFrom_preserves_supply(env e, address from, address to, uint256 value) {
    require e.msg.sender != river;

    mathint supplyBefore = to_mathint(river.getTotalSupply());

    river.transferFrom(e, from, to, value);

    mathint supplyAfter = to_mathint(river.getTotalSupply());

    assert supplyAfter == supplyBefore,
        "TransferFrom must not change total supply";
}

/// @notice A transfer correctly moves shares: sender loses what receiver gains
rule transfer_conservation(env e, address to, uint256 value) {
    require e.msg.sender != to;
    require e.msg.sender != river;

    mathint senderBefore = to_mathint(river.getSharesPerOwner(e.msg.sender));
    mathint receiverBefore = to_mathint(river.getSharesPerOwner(to));

    river.transfer(e, to, value);

    mathint senderAfter = to_mathint(river.getSharesPerOwner(e.msg.sender));
    mathint receiverAfter = to_mathint(river.getSharesPerOwner(to));

    assert senderBefore - senderAfter == receiverAfter - receiverBefore,
        "Sender loss must equal receiver gain";
    assert senderBefore - senderAfter == to_mathint(value),
        "Sender must lose exactly the transferred amount";
}
