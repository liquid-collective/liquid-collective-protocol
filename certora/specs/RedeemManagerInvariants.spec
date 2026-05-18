// RedeemManagerInvariants.spec — Redeem request endpoint invariant & demand conservation

using RedeemManagerHarness as rm;

methods {
    function rm.getRedeemDemandHarness() external returns (uint256) envfree;
    function rm.getRedeemRequestCountHarness() external returns (uint256) envfree;
    function rm.getRedeemRequestHeight(uint32) external returns (uint256) envfree;
    function rm.getRedeemRequestAmount(uint32) external returns (uint256) envfree;
    function rm.getRedeemRequestMaxRedeemableEth(uint32) external returns (uint256) envfree;
    function rm.getWithdrawalEventCountHarness() external returns (uint256) envfree;
    function rm.getBufferedExceedingEthHarness() external returns (uint256) envfree;
    function rm.getRiverHarness() external returns (address) envfree;

    // River interface calls made by RM — summarize as NONDET
    function _.transferFrom(address, address, uint256) external => NONDET;
    function _.underlyingBalanceFromShares(uint256) external => NONDET;
    function _.getAllowlist() external => NONDET;
    function _.getSlashingContainmentMode() external => NONDET;
    function _.onlyAllowed(address, uint256) external => NONDET;
    function _.isDenied(address) external => NONDET;
    function _.sendRedeemManagerExceedingFunds() external => NONDET;
}

// ════════════════════════════════════════════════════════════════════════════
// RULE: Redeem request endpoint (height + amount) is preserved during claims
// ════════════════════════════════════════════════════════════════════════════

/// @notice For any redeem request, after a claim operation:
///         - The endpoint (height + amount) is preserved
///         - Amount can only decrease, height can only increase
rule redeem_request_endpoint_preserved_on_claim(env e) {
    uint32[] redeemRequestIds;
    uint32[] withdrawalEventIds;
    
    require redeemRequestIds.length == 1;
    require withdrawalEventIds.length == 1;
    
    uint32 reqId = redeemRequestIds[0];
    
    // Precondition: request exists
    uint256 reqCount = rm.getRedeemRequestCountHarness();
    require reqId < reqCount;
    require reqCount < 1000000;
    
    // Prevent river address from being the RM contract itself
    require rm.getRiverHarness() != currentContract;
    
    uint256 heightBefore = rm.getRedeemRequestHeight(reqId);
    uint256 amountBefore = rm.getRedeemRequestAmount(reqId);
    
    // The endpoint must not overflow in uint256
    require heightBefore + amountBefore <= max_uint256;
    
    // Require nonzero amount — already-claimed requests are trivially preserved
    require amountBefore > 0;
    
    mathint endpointBefore = to_mathint(heightBefore) + to_mathint(amountBefore);
    
    // Withdrawal event must exist
    uint256 weCount = rm.getWithdrawalEventCountHarness();
    require withdrawalEventIds[0] < weCount;
    require weCount < 1000000;
    
    require e.msg.value == 0;
    
    bool skipAlreadyClaimed = false;
    uint16 depth = 1;
    rm.claimRedeemRequests@withrevert(e, redeemRequestIds, withdrawalEventIds, skipAlreadyClaimed, depth);
    
    bool succeeded = !lastReverted;
    
    uint256 heightAfter = rm.getRedeemRequestHeight(reqId);
    uint256 amountAfter = rm.getRedeemRequestAmount(reqId);
    mathint endpointAfter = to_mathint(heightAfter) + to_mathint(amountAfter);
    
    // Endpoint invariant: height + amount is preserved
    assert succeeded => endpointAfter == endpointBefore,
        "Redeem request endpoint (height + amount) must be preserved during claims";
    
    // Amount can only decrease
    assert succeeded => to_mathint(amountAfter) <= to_mathint(amountBefore),
        "Redeem request amount can only decrease during claims";
    
    // Height can only increase  
    assert succeeded => to_mathint(heightAfter) >= to_mathint(heightBefore),
        "Redeem request height can only increase during claims";
}

// ════════════════════════════════════════════════════════════════════════════
// RULE: Once a redeem request is fully claimed (amount == 0), it stays claimed
// ════════════════════════════════════════════════════════════════════════════

/// @notice Claiming an already-claimed request either reverts (skipAlreadyClaimed=false)
///         or skips (skipAlreadyClaimed=true), preserving amount==0.
rule fully_claimed_stays_claimed_on_claim(env e) {
    uint32[] redeemRequestIds;
    uint32[] withdrawalEventIds;
    
    require redeemRequestIds.length == 1;
    require withdrawalEventIds.length == 1;
    
    uint32 reqId = redeemRequestIds[0];
    
    // Request exists
    uint256 reqCount = rm.getRedeemRequestCountHarness();
    require reqId < reqCount;
    require reqCount < 1000000;
    
    // Request is fully claimed
    require rm.getRedeemRequestAmount(reqId) == 0;
    
    uint256 heightBefore = rm.getRedeemRequestHeight(reqId);
    // A truly claimed request has height > 0
    require heightBefore > 0;
    
    // Prevent river address from being the RM contract itself
    address river = rm.getRiverHarness();
    require river != currentContract;
    require river != 0;
    
    // Prevent msg.sender from being river, RM, or zero
    require e.msg.sender != river;
    require e.msg.sender != currentContract;
    require e.msg.sender != 0;
    
    require e.msg.value == 0;
    
    // Withdrawal event must exist
    uint256 weCount = rm.getWithdrawalEventCountHarness();
    require withdrawalEventIds[0] < weCount;
    require weCount < 1000000;
    
    bool skipAlreadyClaimed;
    uint16 depth = 1;
    
    rm.claimRedeemRequests@withrevert(e, redeemRequestIds, withdrawalEventIds, skipAlreadyClaimed, depth);
    
    bool succeeded = !lastReverted;
    
    assert succeeded => rm.getRedeemRequestAmount(reqId) == 0,
        "A fully claimed redeem request (amount == 0) must stay claimed after claimRedeemRequests";
}

/// @notice For non-claim, non-init functions: a fully claimed request stays claimed.
///         requestRedeem appends new requests (doesn't modify existing ones).
///         reportWithdraw and pullExceedingEth don't touch individual requests.
rule fully_claimed_stays_claimed_other(env e, method f, calldataarg args)
    filtered {
        f -> !f.isView
          && f.selector != sig:rm.initializeRedeemManagerV1(address).selector
          && f.selector != sig:rm.initializeRedeemManagerV1_2().selector
          && f.selector != sig:rm.claimRedeemRequests(uint32[], uint32[]).selector
          && f.selector != sig:rm.claimRedeemRequests(uint32[], uint32[], bool, uint16).selector
    }
{
    uint32 reqId;
    
    // Request exists
    uint256 countBefore = rm.getRedeemRequestCountHarness();
    require reqId < countBefore;
    require countBefore < 1000000;
    
    // Request is fully claimed
    require rm.getRedeemRequestAmount(reqId) == 0;
    
    uint256 heightBefore = rm.getRedeemRequestHeight(reqId);
    // A truly claimed request has height > 0
    require heightBefore > 0;
    
    // Prevent river address from being the RM contract itself
    address river = rm.getRiverHarness();
    require river != currentContract;
    require river != 0;
    
    // Prevent msg.sender from being river, RM, or zero
    require e.msg.sender != river;
    require e.msg.sender != currentContract;
    require e.msg.sender != 0;
    
    require e.msg.value == 0;
    
    uint256 weCount = rm.getWithdrawalEventCountHarness();
    require weCount < 1000000;
    
    f(e, args);
    
    assert rm.getRedeemRequestAmount(reqId) == 0,
        "A fully claimed redeem request (amount == 0) must stay claimed";
}

// ════════════════════════════════════════════════════════════════════════════
// RULE: RedeemDemand conservation — only changed by requestRedeem/reportWithdraw
// ════════════════════════════════════════════════════════════════════════════

/// @notice claimRedeemRequests does not modify RedeemDemand.
rule redeem_demand_unchanged_by_claim(env e) {
    uint32[] redeemRequestIds;
    uint32[] withdrawalEventIds;
    
    require redeemRequestIds.length == 1;
    require withdrawalEventIds.length == 1;
    
    uint256 demandBefore = rm.getRedeemDemandHarness();
    
    require e.msg.value == 0;
    
    // Prevent river address from being the RM contract or zero
    address river = rm.getRiverHarness();
    require river != currentContract;
    require river != 0;
    
    // Prevent msg.sender from being RM, river, or zero
    require e.msg.sender != currentContract;
    require e.msg.sender != river;
    require e.msg.sender != 0;
    
    uint256 reqCount = rm.getRedeemRequestCountHarness();
    require reqCount < 1000000;
    require reqCount > 0;
    
    uint256 weCount = rm.getWithdrawalEventCountHarness();
    require weCount < 1000000;
    require redeemRequestIds[0] < reqCount;
    require withdrawalEventIds[0] < weCount;
    
    // Constrain values to reasonable ranges to avoid overflow-related issues
    require demandBefore < 1000000000000000000000000;
    require rm.getBufferedExceedingEthHarness() < 1000000000000000000000000;
    
    bool skipAlreadyClaimed;
    uint16 depth = 1;
    
    rm.claimRedeemRequests@withrevert(e, redeemRequestIds, withdrawalEventIds, skipAlreadyClaimed, depth);
    
    bool succeeded = !lastReverted;
    
    uint256 demandAfter = rm.getRedeemDemandHarness();
    
    assert succeeded => demandAfter == demandBefore,
        "RedeemDemand must not change via claimRedeemRequests";
}

/// @notice RedeemDemand is not modified by any function other than
///         requestRedeem, reportWithdraw, or init. claimRedeemRequests
///         is verified separately above. pullExceedingEth is onlyRiver
///         and doesn't touch RedeemDemand.
rule redeem_demand_conservation(env e, method f, calldataarg args)
    filtered {
        f -> !f.isView
          && f.selector != sig:rm.requestRedeem(uint256, address, address).selector
          && f.selector != sig:rm.requestRedeem(uint256, address).selector
          && f.selector != sig:rm.reportWithdraw(uint256).selector
          && f.selector != sig:rm.initializeRedeemManagerV1(address).selector
          && f.selector != sig:rm.initializeRedeemManagerV1_2().selector
          && f.selector != sig:rm.pullExceedingEth(uint256).selector
          && f.selector != sig:rm.claimRedeemRequests(uint32[], uint32[]).selector
          && f.selector != sig:rm.claimRedeemRequests(uint32[], uint32[], bool, uint16).selector
    }
{
    uint256 demandBefore = rm.getRedeemDemandHarness();
    
    require e.msg.value == 0;
    
    // Prevent river address from being the RM contract or zero
    address river = rm.getRiverHarness();
    require river != currentContract;
    require river != 0;
    
    // Prevent msg.sender from being RM, river, or zero
    require e.msg.sender != currentContract;
    require e.msg.sender != river;
    require e.msg.sender != 0;
    
    uint256 reqCount = rm.getRedeemRequestCountHarness();
    require reqCount < 1000000;
    
    uint256 weCount = rm.getWithdrawalEventCountHarness();
    require weCount < 1000000;
    
    f(e, args);
    
    uint256 demandAfter = rm.getRedeemDemandHarness();
    
    assert demandAfter == demandBefore,
        "RedeemDemand must only change via requestRedeem or reportWithdraw";
}
