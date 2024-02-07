import "RiverV1.spec";
//import "Sanity.spec";
//import "CVLMath.spec";

use rule method_reachability;

methods {
    function getRedeemRequestDetails(uint32) external returns (RedeemQueue.RedeemRequest) envfree;
    function resolveRedeemRequests(uint32[]) external returns (int64[]) envfree;

    function getRedeemRequestCount() external returns (uint256) envfree;
    function getWithdrawalEventCount() external returns (uint256) envfree;
    function getWithdrawalEventDetails(uint32) external returns (WithdrawalStack.WithdrawalEvent) envfree;
    
    //Harness
    function get_CLAIM_FULLY_CLAIMED() external returns (uint8) envfree;
    function get_CLAIM_PARTIALLY_CLAIMED() external returns (uint8) envfree;
    function get_CLAIM_SKIPPED() external returns (uint8) envfree;

    // MathSummarizations
    //function _.mulDivDown(uint256 a, uint256 b, uint256 c) internal => mulDivDownAbstractPlus(a, b, c) expect uint256 ALL;
}  


rule first_redeem_request_height_is_zero
{
    uint256 redeemRequestCount = getRedeemRequestCount();
    env e; uint256 lsETHAmount; address recipient;
    uint32 redeemRequestId = requestRedeem(e, lsETHAmount, recipient);
    RedeemQueue.RedeemRequest redeemRequest = getRedeemRequestDetails(redeemRequestId);

    assert redeemRequestCount == 0 => redeemRequest.height == 0;
}

// height of a redeem request corresponds to the previous request
// todo: convert to a invariant
rule height_of_consequent_redeem_requests
{
    env e0; env e1;
    uint256 lsETHAmount0; address recipient0;
    uint256 lsETHAmount1; address recipient1;
    uint32 redeemRequestId0 = requestRedeem(e0, lsETHAmount0, recipient0);
    uint32 redeemRequestId1 = requestRedeem(e1, lsETHAmount1, recipient1);
    RedeemQueue.RedeemRequest redeemRequest0 = getRedeemRequestDetails(redeemRequestId0);
    RedeemQueue.RedeemRequest redeemRequest1 = getRedeemRequestDetails(redeemRequestId1);

    require getRedeemRequestCount() <= max_uint32; // requestRedeem() casts redeemRequests.length from uint256 to uint32
    
    assert to_mathint(redeemRequest1.height) == to_mathint(redeemRequest0.amount) + to_mathint(redeemRequest0.height);
}



// Given 2 consequent redeem requests and a single withdrawal event,
// if the first request is partially claimed then second request cannot be fully claimed 
// TODO: check claim properties with double call of claimRedeemRequests()
// TODO: check unconstrained redeem requests and withdrawal events
// @dev must use loop_iter 2 or higher
// runtime: 18 minutes
// https://vaas-stg.certora.com/output/99352/2e4efaf0b90e4a3ab57f5ded18304aa6/?anonymousKey=7d03fd70d4730acc02bbb3638e69bf5fb198fddd
rule claim_order__single_call__same_withdrawal_event__subsequent_redeem_requests
{
    env e;

    uint32[] redeemRequestIds1;
    uint32[] withdrawalEventIds1;

    bool skipAlreadyClaimed1; uint16 depth1;
    uint8[] claimStatuses1 = claimRedeemRequests(e, redeemRequestIds1, withdrawalEventIds1, skipAlreadyClaimed1, depth1);
    uint8 claimStatuses1_0 = claimStatuses1[0];
    uint8 claimStatuses1_1 = claimStatuses1[1];

    
    RedeemQueue.RedeemRequest redeemRequest0 = getRedeemRequestDetails(redeemRequestIds1[0]);
    RedeemQueue.RedeemRequest redeemRequest1 = getRedeemRequestDetails(redeemRequestIds1[1]);

    require to_mathint(redeemRequest1.height) == to_mathint(redeemRequest0.amount) + to_mathint(redeemRequest0.height);
    require to_mathint(redeemRequestIds1[1]) == to_mathint(redeemRequestIds1[0]) + 1;
    require getRedeemRequestCount() <= max_uint32; // requestRedeem() casts redeemRequests.length from uint256 to uint32

    assert (redeemRequestIds1.length > 1  && withdrawalEventIds1[0] == withdrawalEventIds1[1])
            => (claimStatuses1_1 == get_CLAIM_FULLY_CLAIMED() => claimStatuses1_0 != get_CLAIM_PARTIALLY_CLAIMED()) ;
}


//pass
// dashboard runtime 18/23 minutes with/without rule_sanity basic
// https://vaas-stg.certora.com/output/99352/448fe29698f4405f9d1193f3563d6287/?anonymousKey=45ab4b33c79faa276121eda3e3b000e402f1d939
rule claim_order__single_call__same_withdrawal_event__subsequent_redeem_requests_no_invariant
{
    env e1; env e2; env e3; env e4; 

    
    calldataarg args;
    uint256 lsETHAmount1; address recipient1;
    uint256 lsETHAmount2; address recipient2;
    uint32 redeemRequestId1 = requestRedeem(e1, lsETHAmount1, recipient1);
    uint32 redeemRequestId2 = requestRedeem(e2, lsETHAmount2, recipient2);

    uint256 lsETHWithdrawable;
    reportWithdraw(e3, lsETHWithdrawable);
    
    uint32[] redeemRequestIds1; uint32[] withdrawalEventIds1;

    require to_mathint(withdrawalEventIds1[0]) == to_mathint(getWithdrawalEventCount()) - 1;
    require redeemRequestIds1[0] == redeemRequestId1;
    require redeemRequestIds1[1] == redeemRequestId2;
    
    RedeemQueue.RedeemRequest redeemRequest0 = getRedeemRequestDetails(redeemRequestIds1[0]);
    RedeemQueue.RedeemRequest redeemRequest1 = getRedeemRequestDetails(redeemRequestIds1[1]);
    
    
    bool skipAlreadyClaimed1; uint16 depth1;
    uint8[] claimStatuses1 = claimRedeemRequests(e4, redeemRequestIds1, withdrawalEventIds1, skipAlreadyClaimed1, depth1);
    uint8 claimStatuses1_0 = claimStatuses1[0];
    uint8 claimStatuses1_1 = claimStatuses1[1];

    WithdrawalStack.WithdrawalEvent withdrawalEvent = getWithdrawalEventDetails(withdrawalEventIds1[0]);

    require getRedeemRequestCount() <= max_uint32; // requestRedeem() casts redeemRequests.length from uint256 to uint32

    
    assert (redeemRequestIds1.length > 1  && withdrawalEventIds1[0] == withdrawalEventIds1[1])
            => (claimStatuses1_1 == get_CLAIM_FULLY_CLAIMED() => claimStatuses1_0 != get_CLAIM_PARTIALLY_CLAIMED()) ;
}



// output length of claimRedeemRequests() is the same as its input length
rule claimStatuses_length_eq_redeemRequestIds_length
{
    env e; calldataarg args;
    uint32[] redeemRequestIds; uint32[] withdrawalEventIds; bool skipAlreadyClaimed; uint16 depth;

    uint8[] claimStatuses = claimRedeemRequests(e, redeemRequestIds, withdrawalEventIds, skipAlreadyClaimed, depth);

    assert redeemRequestIds.length == claimStatuses.length;
}

// Once claimRedeemRequests(id) is full claimed subsequent calls are skipped
// pass with loop_iter 1 z3 parametric rule
// https://prover.certora.com/output/99352/4b31e156fca74fb888bb7a62d2aa43e8/?anonymousKey=29473295c3dbf7694f5f01ac24d341bb5344606f
// pass loop iter 2 z3 non-parametric rule 
// https://prover.certora.com/output/99352/685c922ed9cf48529b01712dfe7731bc/?anonymousKey=0157886421a0805cdb8eea325016ba5bce995ef7
// timeout loop_iter 3
// https://prover.certora.com/output/99352/d38f9588b74a47dfb222d6e7a7f7393d/?anonymousKey=897b383089646af6489f7b091a9bed023aa5b089
// timeout loop_iter 1 and all contracts
// https://vaas-stg.certora.com/output/99352/4557dd5f07fa4e54a42bda02c0465200/?anonymousKey=5cc206e7e8a04f9ba3059d8b2bfa5bea8430d23a
//
rule full_claim_is_terminal
(method f)filtered { f-> !f.isView }
{
    env e1; env e2; env e3;
    calldataarg args;
    uint32[] redeemRequestIds1; uint32[] withdrawalEventIds1;
    bool skipAlreadyClaimed1; uint16 depth1;

    uint8[] claimStatuses1 = claimRedeemRequests(e1, redeemRequestIds1, withdrawalEventIds1, skipAlreadyClaimed1, depth1);
    uint8 claimStatuses1_0 = claimStatuses1[0];
    f(e2, args);
    bool skipAlreadyClaimed2; uint16 depth2;
    uint32[] redeemRequestIds2; uint32[] withdrawalEventIds2;
    uint8[] claimStatuses2 = claimRedeemRequests(e3, redeemRequestIds2, withdrawalEventIds2, skipAlreadyClaimed2, depth2);
    uint8 claimStatuses2_0 = claimStatuses2[0];

    assert redeemRequestIds1.length > 0 && redeemRequestIds2.length > 0 && redeemRequestIds1[0] == redeemRequestIds2[0] 
            => (claimStatuses1_0 == get_CLAIM_FULLY_CLAIMED() => skipAlreadyClaimed2);
    assert redeemRequestIds1.length > 0 && redeemRequestIds2.length > 0 && redeemRequestIds1[0] == redeemRequestIds2[0] 
            => (claimStatuses1_0 == get_CLAIM_FULLY_CLAIMED() => claimStatuses2_0 == get_CLAIM_SKIPPED());
}

rule full_claim_is_terminal_witness_nontrivial_antecedent
(method f)filtered { f-> !f.isView }
{
    env e1; env e2; env e3;
    calldataarg args;
    uint32[] redeemRequestIds1; uint32[] withdrawalEventIds1;
    bool skipAlreadyClaimed1; uint16 depth1;

    uint8[] claimStatuses1 = claimRedeemRequests(e1, redeemRequestIds1, withdrawalEventIds1, skipAlreadyClaimed1, depth1);
    uint8 claimStatuses1_0 = claimStatuses1[0];
    f(e2, args);
    bool skipAlreadyClaimed2; uint16 depth2;
    uint32[] redeemRequestIds2; uint32[] withdrawalEventIds2;
    uint8[] claimStatuses2 = claimRedeemRequests(e3, redeemRequestIds2, withdrawalEventIds2, skipAlreadyClaimed2, depth2);
    uint8 claimStatuses2_0 = claimStatuses2[0];

    require redeemRequestIds1.length > 0 && redeemRequestIds2.length > 0 && redeemRequestIds1[0] == redeemRequestIds2[0]; 
    require claimStatuses1_0 == get_CLAIM_FULLY_CLAIMED();
    satisfy claimStatuses2_0 == get_CLAIM_SKIPPED();
}

rule full_claim_is_terminal_witness_nontrivial_consequent
(method f)filtered { f-> !f.isView }
{
    env e1; env e2; env e3;
    calldataarg args;
    uint32[] redeemRequestIds1; uint32[] withdrawalEventIds1;
    bool skipAlreadyClaimed1; uint16 depth1;

    uint8[] claimStatuses1 = claimRedeemRequests(e1, redeemRequestIds1, withdrawalEventIds1, skipAlreadyClaimed1, depth1);
    uint8 claimStatuses1_0 = claimStatuses1[0];
    f(e2, args);
    bool skipAlreadyClaimed2; uint16 depth2;
    uint32[] redeemRequestIds2; uint32[] withdrawalEventIds2;
    uint8[] claimStatuses2 = claimRedeemRequests(e3, redeemRequestIds2, withdrawalEventIds2, skipAlreadyClaimed2, depth2);
    uint8 claimStatuses2_0 = claimStatuses2[0];

    require redeemRequestIds1.length > 0 && redeemRequestIds2.length > 0 && redeemRequestIds1[0] == redeemRequestIds2[0]; 
    require claimStatuses2_0 != get_CLAIM_SKIPPED();
    satisfy claimStatuses1_0 != get_CLAIM_FULLY_CLAIMED();
}



// A Claim request’s entitled LsETH is monotonically decreasing TODO: verify property meaning
// redeemRequest.amount is non-increasing, in particular if the amount reaches zero it'll stay zero.
// Hence a fully claimed request stays fully claimed.
rule redeem_request_amount_non_increasing(method f)filtered { f-> !f.isView }{

    uint32 redeemRequestId;
    RedeemQueue.RedeemRequest redeemRequest1 = getRedeemRequestDetails(redeemRequestId);
    mathint redeemRequestCount = getRedeemRequestCount();
    require redeemRequestCount <= 2^32; //Solidity downcast to uint32
    env e; calldataarg args;
    f(e, args);
    RedeemQueue.RedeemRequest redeemRequest2 = getRedeemRequestDetails(redeemRequestId);

    assert to_mathint(redeemRequestId) < redeemRequestCount =>  redeemRequest1.amount == 0 => redeemRequest2.amount == 0;
    assert to_mathint(redeemRequestId) < redeemRequestCount =>  redeemRequest1.amount >= redeemRequest2.amount;
}

//witness https://vaas-stg.certora.com/output/99352/e721640004e44ad688044ab7fa240959/?anonymousKey=9eef2cb0b3d69333de2a9af2fa44a39dd615f416
rule redeem_request_amount_non_increasing_witness_2_partial_claims{

    uint32 redeemRequestId;
    RedeemQueue.RedeemRequest redeemRequest1 = getRedeemRequestDetails(redeemRequestId);
    mathint redeemRequestCount = getRedeemRequestCount();
    require redeemRequestCount <= 2^32;
    env e; calldataarg args;
    claimRedeemRequests(e, args);
    RedeemQueue.RedeemRequest redeemRequest2 = getRedeemRequestDetails(redeemRequestId);

    require to_mathint(redeemRequestId) < redeemRequestCount;
    require redeemRequest1.amount != redeemRequest2.amount;
    satisfy redeemRequest2.amount > 0;
}

//Request Ids are incremental, hence unique
rule incremental_redeemRequestId(method f)filtered { f-> !f.isView }
{
    
    env e1;
    uint256 lsETHAmount1; address recipient1;
    uint32 redeemRequestId1 = requestRedeem(e1, lsETHAmount1, recipient1);
    require redeemRequestId1 < max_uint32;
    env e2; calldataarg args;
    f(e2, args);
    env e3;
    uint256 lsETHAmount3; address recipient3;
    uint32 redeemRequestId3 = requestRedeem(e3, lsETHAmount3, recipient3);
    assert (f.selector != sig:requestRedeem(uint256,address).selector
           && f.selector != sig:requestRedeem(uint256).selector)
                => to_mathint(redeemRequestId3) == to_mathint(redeemRequestId1) + 1;
}

// ideas for additional properties
// one can redeem/deposit any amount
// witness deposit and redeem without funds reaching the consensus layer
// redeem stack and withdraw queue
// if a withdrawal stack height >= redeem request height then satisfy succeeds

