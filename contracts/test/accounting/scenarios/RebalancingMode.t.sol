// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../AccountingInvariants.sol";

contract RebalancingModeTest is AccountingInvariants {
    /// @notice Verifies that an oracle report submitted with `rebalanceDepositToRedeemMode = true`
    ///         still satisfies all accounting invariants (ETH conservation, in-flight consistency,
    ///         per-operator integrity). No assertion on specific values — invariant checks inside
    ///         `sim_oracleReport` act as the oracle.
    ///         All assertions are checked inside sim_oracleReport via _assertAllInvariants().
    function testRebalancingModePreservesConservation() public {
        // Step 1: Fund river with enough ETH for 3 validators and deposit them for operator one.
        _fundRiver(6 * DEPOSIT_SIZE);
        sim_deposit(operatorOneIndex, _amounts(3, DEPOSIT_SIZE));
        // Step 2: Activate all 3 validators and submit the initial normal oracle report.
        sim_activateValidators(3);
        sim_oracleReport();
        // Step 3: Submit a rebalancing-mode oracle report (rebalance=true, slashingContainment=false)
        //         and assert that all accounting invariants still hold.
        sim_oracleReport(true, false);
    }

    /// @notice Verifies that the protocol can correctly resume normal oracle reporting after
    ///         a rebalancing-mode report. Ensures accounting invariants hold throughout the full
    ///         sequence: normal report → rebalancing report → normal report.
    ///         All assertions are checked inside sim_oracleReport via _assertAllInvariants().
    function testResumeAfterRebalancing() public {
        // Step 1: Fund river with enough ETH for 4 validators and deposit them for operator one.
        _fundRiver(4 * DEPOSIT_SIZE);
        sim_deposit(operatorOneIndex, _amounts(4, DEPOSIT_SIZE));
        // Step 2: Activate all 4 validators and submit the initial normal oracle report.
        sim_activateValidators(4);
        sim_oracleReport();
        // Step 3: Submit a rebalancing-mode oracle report (rebalance=true).
        sim_oracleReport(true, false);
        // Step 4: Submit a regular oracle report to verify the protocol resumes normal operation.
        sim_oracleReport(false, false);
    }
}
