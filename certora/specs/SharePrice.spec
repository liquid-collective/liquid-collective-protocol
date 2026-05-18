// SharePrice.spec — Share price monotonicity absent loss
//
// Property: share_price_monotonic_absent_loss (LCP-RULE-44)
//
// For any non-admin, non-oracle function call that does not decrease 
// validatorsBalance, the LsETH share price must not decrease.
// Uses cross-multiplication to avoid division:
//   _assetBalance_post * totalSupply_pre >= _assetBalance_pre * totalSupply_post

import "MathSummaries.spec";

using RiverHarness as river;

methods {
    // Harness getters — envfree
    function river.getAssetBalance() external returns (uint256) envfree;
    function river.getTotalSupply() external returns (uint256) envfree;
    function river.getSharesPerOwner(address) external returns (uint256) envfree;
    function river.getAdminHarness() external returns (address) envfree;
    function river.getKeeperHarness() external returns (address) envfree;
    function river.getOracleAddressHarness() external returns (address) envfree;
    function river.getSlashingContainmentModeHarness() external returns (bool) envfree;
    function river.getAllowlistAddress() external returns (address) envfree;
    function river.getValidatorsBalance() external returns (uint256) envfree;
    function river.getGlobalFeeHarness() external returns (uint256) envfree;
    function river.getCollectorAddressHarness() external returns (address) envfree;

    // Summarize external calls
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
    function _.isValidEpoch(uint256) external => NONDET;
    function _.transferFrom(address, address, uint256) external => NONDET;
}

/// @notice Helper: check if a function is an admin/oracle/initialization function
///         These can legitimately change share price via fee changes or oracle reports
definition isAdminOrOracleFunction(method f) returns bool =
    // Initializers
    f.selector == sig:river.initRiverV1(address, address, bytes32, address, address, address, address, address, uint256).selector
    || f.selector == sig:river.initRiverV1_1(address, uint64, uint64, uint64, uint64, uint64, uint256, uint256, uint128, uint128).selector
    || f.selector == sig:river.initRiverV1_2().selector
    // Oracle report — can change validatorsBalance (slashing = price decrease)
    || f.selector == sig:river.setConsensusLayerData(IOracleManagerV1.ConsensusLayerReport).selector
    // Admin fee setter — can change fee rate affecting share minting
    || f.selector == sig:river.setGlobalFee(uint256).selector
    // Admin config setters
    || f.selector == sig:river.setAllowlist(address).selector
    || f.selector == sig:river.setCollector(address).selector
    || f.selector == sig:river.setELFeeRecipient(address).selector
    || f.selector == sig:river.setCoverageFund(address).selector
    || f.selector == sig:river.setKeeper(address).selector
    || f.selector == sig:river.setMetadataURI(string).selector
    || f.selector == sig:river.setOracle(address).selector
    || f.selector == sig:river.setCLSpec(CLSpec.CLSpecStruct).selector
    || f.selector == sig:river.setReportBounds(ReportBounds.ReportBoundsStruct).selector
    || f.selector == sig:river.setDailyCommittableLimits(DailyCommittableLimits.DailyCommittableLimitsStruct).selector
    // Admin transfer
    || f.selector == sig:river.proposeAdmin(address).selector
    || f.selector == sig:river.acceptAdmin().selector;

// ════════════════════════════════════════════════════════════════════════════
// RULE: Share price monotonically non-decreasing for non-admin operations
// ════════════════════════════════════════════════════════════════════════════

/// @notice For any non-admin, non-oracle function call, the LsETH share price 
///         must not decrease. Uses cross-multiplication:
///         assetBalance_post * totalSupply_pre >= assetBalance_pre * totalSupply_post
///
///         This captures the core property that user operations (deposit, transfer, 
///         requestRedeem, etc.) cannot decrease the share price.
rule share_price_monotonic_absent_loss(env e, method f, calldataarg args)
    filtered {
        f -> !f.isView
          && !isAdminOrOracleFunction(f)
    }
{
    // Preconditions
    require e.msg.sender != 0;
    // Exclude scene contracts from being the caller
    require e.msg.sender != river;

    // Capture pre-state
    uint256 assetBalancePre = river.getAssetBalance();
    uint256 totalSupplyPre = river.getTotalSupply();

    // Only meaningful when supply exists
    require totalSupplyPre > 0;
    require assetBalancePre > 0;

    // Execute arbitrary non-admin function
    f(e, args);

    // Capture post-state
    uint256 assetBalancePost = river.getAssetBalance();
    uint256 totalSupplyPost = river.getTotalSupply();

    // Share price non-decreasing via cross-multiplication
    // assetBalancePost / totalSupplyPost >= assetBalancePre / totalSupplyPre
    // <==> assetBalancePost * totalSupplyPre >= assetBalancePre * totalSupplyPost
    assert to_mathint(assetBalancePost) * to_mathint(totalSupplyPre) 
        >= to_mathint(assetBalancePre) * to_mathint(totalSupplyPost),
        "Share price must not decrease for non-admin, non-oracle operations";
}

// ════════════════════════════════════════════════════════════════════════════
// RULE: Deposit preserves or improves share price (specific integrity check)
// ════════════════════════════════════════════════════════════════════════════

/// @notice A user deposit at the current rate should not decrease share price.
///         The deposit mints shares proportional to the ETH deposited at the 
///         current exchange rate, maintaining price neutrality.
rule deposit_preserves_share_price(env e) {
    require e.msg.value > 0;
    require e.msg.sender != 0;
    require e.msg.sender != river;

    uint256 assetBalancePre = river.getAssetBalance();
    uint256 totalSupplyPre = river.getTotalSupply();

    require totalSupplyPre > 0;
    require assetBalancePre > 0;

    river.deposit@withrevert(e);
    require !lastReverted;

    uint256 assetBalancePost = river.getAssetBalance();
    uint256 totalSupplyPost = river.getTotalSupply();

    // Cross-multiplication: post-price >= pre-price
    assert to_mathint(assetBalancePost) * to_mathint(totalSupplyPre) 
        >= to_mathint(assetBalancePre) * to_mathint(totalSupplyPost),
        "Deposit must preserve or improve share price";
}

// ════════════════════════════════════════════════════════════════════════════
// RULE: Transfer does not change share price (zero-sum operation)
// ════════════════════════════════════════════════════════════════════════════

/// @notice LsETH transfer is zero-sum: it moves shares between accounts but 
///         does not change totalSupply or _assetBalance, so share price is unchanged.
rule transfer_preserves_share_price(env e, address to, uint256 value) {
    require e.msg.sender != 0;
    require to != 0;

    uint256 assetBalancePre = river.getAssetBalance();
    uint256 totalSupplyPre = river.getTotalSupply();

    river.transfer@withrevert(e, to, value);
    require !lastReverted;

    uint256 assetBalancePost = river.getAssetBalance();
    uint256 totalSupplyPost = river.getTotalSupply();

    // Transfer should not change asset balance or total supply at all
    assert assetBalancePost == assetBalancePre,
        "Transfer must not change asset balance";
    assert totalSupplyPost == totalSupplyPre,
        "Transfer must not change total supply";
}
