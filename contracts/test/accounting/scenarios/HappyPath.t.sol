// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../AccountingInvariants.sol";

contract HappyPathTest is AccountingInvariants {
    /// @notice Verifies the core deposit-activate-report lifecycle.
    ///         Funds the river, deposits 3 validators for a single operator, activates them,
    ///         and confirms that the in-flight deposit is set correctly after the deposit step
    ///         and cleared to zero once the oracle report confirms validator activation.
    function testDepositActivateReport() public {
        // Step 1: Fund river with enough ETH for 3 validator deposits (3 × 32 ETH).
        _fundRiver(3 * DEPOSIT_SIZE);
        // Step 2: Deposit 3 validators for operator one; 96 ETH (3 × 32) should be in-flight.
        sim_deposit(operatorOneIndex, 3);
        assertEq(river.getInFlightDeposit(), 96 ether, "inFlight after deposit");
        // Step 3: Activate all 3 pending validators on the beacon chain simulator.
        sim_activateValidators(3);
        // Step 4: Submit an oracle report; in-flight deposit must clear to zero once the oracle
        //         confirms that all pending validators have transitioned to active.
        sim_oracleReport();
        assertEq(river.getInFlightDeposit(), 0, "inFlight after report");
    }

    /// @notice Verifies that rewards accumulate correctly across multiple oracle epochs
    ///         when validators from two different operators are active.
    ///         Confirms that `totalUnderlyingSupply` grows beyond the initial principal after
    ///         two full epoch advances with reward sweeps.
    function testMultiOperatorWithRewards() public {
        // Step 1: Fund river with enough ETH for 10 validator deposits (10 × 32 ETH).
        _fundRiver(10 * DEPOSIT_SIZE);
        // Step 2: Split deposits across two operators — 6 for operator one, 4 for operator two.
        sim_deposit(operatorOneIndex, 6);
        sim_deposit(operatorTwoIndex, 4);
        // Step 3: Activate all 10 validators and submit the initial oracle report.
        sim_activateValidators(10);
        sim_oracleReport();
        // Step 4: Advance one epoch with per-validator rewards and report again.
        sim_advanceEpoch(0.008 ether);
        sim_oracleReport();
        // Step 5: Advance a second epoch with per-validator rewards and report again.
        sim_advanceEpoch(0.008 ether);
        sim_oracleReport();
        // Step 6: Total underlying supply must be greater than the original principal,
        //         confirming that skimmed rewards have been accounted for.
        assertGt(river.totalUnderlyingSupply(), 10 * DEPOSIT_SIZE, "rewards accrued");
    }

    /// @notice Verifies that multiple sequential deposit batches for the same operator
    ///         correctly accumulate in-flight ETH, and that the entire in-flight balance
    ///         is cleared after a single oracle report once all validators are activated.
    function testIncrementalDeposits() public {
        // Step 1: Fund river with enough ETH for 5 validator deposits (5 × 32 ETH).
        _fundRiver(5 * DEPOSIT_SIZE);
        // Step 2: First deposit batch — 2 validators; expect 64 ETH (2 × 32) in-flight.
        sim_deposit(operatorOneIndex, 2);
        assertEq(river.getInFlightDeposit(), 64 ether, "after first batch");
        // Step 3: Second deposit batch — 3 more validators; expect 160 ETH (5 × 32) in-flight.
        sim_deposit(operatorOneIndex, 3);
        assertEq(river.getInFlightDeposit(), 160 ether, "after second batch");
        // Step 4: Activate all 5 validators.
        sim_activateValidators(5);
        // Step 5: Submit oracle report; in-flight deposit must drop to zero.
        sim_oracleReport();
        assertEq(river.getInFlightDeposit(), 0, "after report");
    }
}
