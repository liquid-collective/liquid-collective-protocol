// OracleQuorum.spec — Oracle one-vote-per-member-per-epoch
//
// Property: oracle_one_vote_per_member_per_epoch

using OracleV1 as oracle;

methods {
    function oracle.getQuorum() external returns (uint256) envfree;
    function oracle.isMember(address) external returns (bool) envfree;
    function oracle.getMemberReportStatus(address) external returns (bool) envfree;
    function oracle.getLastReportedEpochId() external returns (uint256) envfree;
    function oracle.getOracleMembers() external returns (address[]) envfree;
    function oracle.getAdmin() external returns (address) envfree;

    // River calls made by Oracle — summarize
    function _.setConsensusLayerData(bytes) external => NONDET;
    function _.isValidEpoch(uint256) external => ALWAYS(true);
}

// ════════════════════════════════════════════════════════════════════════════
// RULE: A member who has already reported cannot report again in the same round
// ════════════════════════════════════════════════════════════════════════════

/// @notice If getMemberReportStatus(member) returns true, then calling
///         reportConsensusLayerData from that member must revert.
rule already_reported_member_reverts(env e) {
    calldataarg args;
    
    // Precondition: caller is an oracle member who has already reported
    require oracle.isMember(e.msg.sender);
    require oracle.getMemberReportStatus(e.msg.sender);
    require e.msg.value == 0;
    
    oracle.reportConsensusLayerData@withrevert(e, args);
    
    assert lastReverted,
        "A member who has already reported in this round must be rejected (AlreadyReported)";
}

// ════════════════════════════════════════════════════════════════════════════
// RULE: Non-member cannot report
// ════════════════════════════════════════════════════════════════════════════

/// @notice If the caller is not an oracle member, reportConsensusLayerData reverts.
rule non_member_cannot_report(env e) {
    calldataarg args;
    
    require !oracle.isMember(e.msg.sender);
    require e.msg.value == 0;
    
    oracle.reportConsensusLayerData@withrevert(e, args);
    
    assert lastReverted,
        "A non-member must not be able to report consensus layer data";
}

// ════════════════════════════════════════════════════════════════════════════
// RULE: After a successful report, the member's status is marked as reported
// ════════════════════════════════════════════════════════════════════════════

/// @notice After a successful call to reportConsensusLayerData, the caller's
///         report status must be true (for the current round) OR the round
///         was completed and reports were cleared (epoch advanced).
///         Uses implication to avoid vacuity: if the call reverts, the
///         assertion is trivially satisfied.
rule successful_report_marks_member(env e) {
    calldataarg args;
    
    require e.msg.sender != 0;
    require e.msg.value == 0;
    
    // Constrain oracle to have exactly 2 members so the sender can be
    // found within loop_iter=3 iterations. Quorum of 2 means a single
    // vote records without triggering consensus.
    address[] members = oracle.getOracleMembers();
    require members.length == 2;
    require members[0] == e.msg.sender;
    
    require oracle.isMember(e.msg.sender);
    require !oracle.getMemberReportStatus(e.msg.sender);
    require oracle.getQuorum() == 2;
    
    // Epoch 0 so any symbolic report epoch satisfies >= check
    require oracle.getLastReportedEpochId() == 0;
    
    uint256 epochBefore = oracle.getLastReportedEpochId();
    
    oracle.reportConsensusLayerData@withrevert(e, args);
    
    bool succeeded = !lastReverted;
    
    uint256 epochAfter = oracle.getLastReportedEpochId();
    
    // If the call succeeded, then either:
    //   (a) the member is now marked as reported, or
    //   (b) the epoch advanced (quorum reached, reports cleared)
    assert succeeded =>
        (oracle.getMemberReportStatus(e.msg.sender) || epochAfter > epochBefore),
        "After successful report, member must be marked or epoch must have advanced";
}
