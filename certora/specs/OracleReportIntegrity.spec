// OracleReportIntegrity.spec — Pull CL funds exact bucket split
//
// Property: pull_cl_funds_exact_bucket_split (G-6 enforcement)
//
// When _pullCLFunds(skimmed, exited) executes, the ETH received from Withdraw 
// must equal exactly skimmed + exited. BalanceToDeposit increases by exactly 
// skimmed and BalanceToRedeem increases by exactly exited.
// Any mismatch reverts the entire oracle report.

import "MathSummaries.spec";

using RiverHarness as river;

methods {
    // Harness getters
    function river.getBalanceToDepositHarness() external returns (uint256) envfree;
    function river.getBalanceToRedeemHarness() external returns (uint256) envfree;
    function river.getOracleAddressHarness() external returns (address) envfree;
    function river.getAssetBalance() external returns (uint256) envfree;
    function river.getTotalSupply() external returns (uint256) envfree;
    function river.getValidatorsBalance() external returns (uint256) envfree;
    function river.getAdminHarness() external returns (address) envfree;
    function river.getWithdrawalCredentialsAddress() external returns (address) envfree;
    function river.getELFeeRecipientAddress() external returns (address) envfree;
    function river.getCoverageFundAddressHarness() external returns (address) envfree;
    function river.getRedeemManagerAddressHarness() external returns (address) envfree;

    // External calls within setConsensusLayerData
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
    function _.isValidEpoch(uint256) external => NONDET;
    function _.onlyAllowed(address, uint256) external => NONDET;
    function _.isDenied(address) external => NONDET;
    function _.getAllowlist() external => NONDET;
}

// ════════════════════════════════════════════════════════════════════════════
// RULE: Only oracle can call setConsensusLayerData
// ════════════════════════════════════════════════════════════════════════════

/// @notice setConsensusLayerData can only be called by the configured Oracle address.
///         This is the G-19 guard.
rule only_oracle_can_set_consensus_data(env e) {
    IOracleManagerV1.ConsensusLayerReport report;

    river.setConsensusLayerData@withrevert(e, report);

    assert !lastReverted => e.msg.sender == river.getOracleAddressHarness(),
        "Only the Oracle contract can call setConsensusLayerData";
}

// ════════════════════════════════════════════════════════════════════════════
// RULE: Unauthorized caller to setConsensusLayerData always reverts
// ════════════════════════════════════════════════════════════════════════════

/// @notice Any caller that is not the Oracle will be rejected.
rule non_oracle_setConsensusLayerData_reverts(env e) {
    IOracleManagerV1.ConsensusLayerReport report;

    require e.msg.sender != river.getOracleAddressHarness();

    river.setConsensusLayerData@withrevert(e, report);

    assert lastReverted,
        "setConsensusLayerData must revert for non-Oracle callers";
}

// ════════════════════════════════════════════════════════════════════════════
// RULE: sendCLFunds only accepts calls from Withdraw contract
// ════════════════════════════════════════════════════════════════════════════

/// @notice sendCLFunds is the payable callback that only the Withdraw contract 
///         (identified by WithdrawalCredentials address) can call.
///         This enforces G-9.
rule only_withdraw_can_send_cl_funds(env e) {
    river.sendCLFunds@withrevert(e);

    assert !lastReverted => e.msg.sender == river.getWithdrawalCredentialsAddress(),
        "Only the Withdraw contract can call sendCLFunds";
}

// ════════════════════════════════════════════════════════════════════════════
// RULE: sendELFees only accepts calls from ELFeeRecipient
// ════════════════════════════════════════════════════════════════════════════

/// @notice sendELFees is the payable callback that only the ELFeeRecipient can call.
///         This enforces G-8.
rule only_elfee_can_send_el_fees(env e) {
    river.sendELFees@withrevert(e);

    assert !lastReverted => e.msg.sender == river.getELFeeRecipientAddress(),
        "Only the ELFeeRecipient contract can call sendELFees";
}

// ════════════════════════════════════════════════════════════════════════════
// RULE: sendCoverageFunds only accepts calls from CoverageFund
// ════════════════════════════════════════════════════════════════════════════

/// @notice sendCoverageFunds is the payable callback that only CoverageFund can call.
///         This enforces G-10.
rule only_coverage_can_send_coverage_funds(env e) {
    river.sendCoverageFunds@withrevert(e);

    assert !lastReverted => e.msg.sender == river.getCoverageFundAddressHarness(),
        "Only the CoverageFund contract can call sendCoverageFunds";
}

// ════════════════════════════════════════════════════════════════════════════
// RULE: sendRedeemManagerExceedingFunds only from RedeemManager
// ════════════════════════════════════════════════════════════════════════════

/// @notice sendRedeemManagerExceedingFunds callback restricted to RedeemManager.
///         This enforces G-11.
rule only_redeem_mgr_can_send_exceeding_funds(env e) {
    river.sendRedeemManagerExceedingFunds@withrevert(e);

    assert !lastReverted => e.msg.sender == river.getRedeemManagerAddressHarness(),
        "Only the RedeemManager contract can call sendRedeemManagerExceedingFunds";
}
