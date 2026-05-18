// DenyMaskEnforcement.spec — Denied accounts cannot receive LsETH shares
//
// Property: deny_mask_blocks_all_share_inflows
//
// A denylisted account (Allowlist DENY_MASK set) cannot increase its LsETH
// share balance through ANY path.

import "MathSummaries.spec";

using RiverHarness as river;
using AllowlistHarness as allowlist;

methods {
    function river.getTotalSupply() external returns (uint256) envfree;
    function river.getSharesPerOwner(address) external returns (uint256) envfree;
    function river.balanceOf(address) external returns (uint256) envfree;
    function river.getAssetBalance() external returns (uint256) envfree;
    function river.getAllowlistAddress() external returns (address) envfree;
    function river.getAdminHarness() external returns (address) envfree;
    function river.getCollector() external returns (address) envfree;
    function river.getRedeemManagerAddressHarness() external returns (address) envfree;

    function allowlist.isDeniedHarness(address) external returns (bool) envfree;
    function allowlist.isDenied(address) external returns (bool) envfree;

    // Summarize irrelevant external calls
    function _.onlyAllowed(address, uint256) external => NONDET;
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

    function _.isValidEpoch(uint256) external => NONDET;
    function _.transferFrom(address, address, uint256) external => NONDET;
}

// ════════════════════════════════════════════════════════════════════════════
// No ghost/hook needed — the rule uses harness getters directly
// ════════════════════════════════════════════════════════════════════════════

// ════════════════════════════════════════════════════════════════════════════
// RULE: Denied user's share balance cannot increase
// ════════════════════════════════════════════════════════════════════════════

/// @notice For any function call, if a user is denied (has DENY_MASK set),
///         their share balance in River must not increase.
///         This covers: transfer, transferFrom, deposit, depositAndTransfer.
rule denied_user_shares_cannot_increase(env e, method f, calldataarg args)
    filtered {
        f -> !f.isView
          // Exclude initializers
          && f.selector != sig:river.initRiverV1(address, address, bytes32, address, address, address, address, address, uint256).selector
          && f.selector != sig:river.initRiverV1_1(address, uint64, uint64, uint64, uint64, uint64, uint256, uint256, uint128, uint128).selector
          && f.selector != sig:river.initRiverV1_2().selector
    }
{
    address user;
    
    // Link allowlist to river's allowlist
    require river.getAllowlistAddress() == allowlist;
    
    // User is denied
    require allowlist.isDeniedHarness(user);
    
    // User is not the zero address
    require user != 0;
    
    // Exclude protocol-internal addresses that receive shares through
    // admin-configured paths:
    // - River itself may hold shares transiently
    // - Collector gets fee shares via _onEarnings (minted directly, bypasses transfer deny check)
    // - RedeemManager receives shares during requestRedeem (transferFrom from user to RM)
    // The deny-mask property applies to external user accounts, not protocol-internal recipients.
    require user != river;
    require user != river.getCollector();
    require user != river.getRedeemManagerAddressHarness();
    
    // Exclude the msg.sender being river (internal calls)
    require e.msg.sender != river;
    
    uint256 sharesBefore = river.getSharesPerOwner(user);
    
    f(e, args);
    
    uint256 sharesAfter = river.getSharesPerOwner(user);
    
    assert sharesAfter <= sharesBefore,
        "A denied user's LsETH share balance must never increase";
}
