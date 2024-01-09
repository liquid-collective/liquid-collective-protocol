//import "RiverV1.spec";
import "Sanity.spec";

use rule method_reachability;

methods {
    function getRedeemRequestDetails(uint32) external returns (RedeemQueue.RedeemRequest) envfree;
    function resolveRedeemRequests(uint32[]) external returns (int64[]) envfree;


    //Harness
    function get_CLAIM_FULLY_CLAIMED() external returns (uint8) envfree;
    function get_CLAIM_PARTIALLY_CLAIMED() external returns (uint8) envfree;
    function get_CLAIM_SKIPPED() external returns (uint8) envfree;


}  

rule full_claim_is_terminal(method f)
{
    env e1; env e2; env e3;
    calldataarg args;
    uint32[] redeemRequestIds;
    uint32[] withdrawalEventIds;
    bool skipAlreadyClaimed;
    uint16 depth;

    uint8[] claimStatuses1 = claimRedeemRequests(e1, redeemRequestIds, withdrawalEventIds, skipAlreadyClaimed, depth);
    uint8 claimStatuses1_0 = claimStatuses1[0];
    f(e2, args);
    uint8[] claimStatuses2 = claimRedeemRequests(e3, redeemRequestIds, withdrawalEventIds, skipAlreadyClaimed, depth);
    uint8 claimStatuses2_0 = claimStatuses2[0];

//    assert redeemRequestIds.length == claimStatuses1.length;
//    assert redeemRequestIds.length > 0 && claimStatuses1_0 == 0 && !skipAlreadyClaimed => claimStatuses1_0 == claimStatuses2_0;
    assert redeemRequestIds.length > 0 && claimStatuses1_0 == get_CLAIM_FULLY_CLAIMED() && skipAlreadyClaimed => claimStatuses2_0 == get_CLAIM_SKIPPED();

}


