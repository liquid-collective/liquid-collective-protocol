// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../AccountingInvariants.sol";

contract InFlightETHTest is AccountingInvariants {
    /// @notice Verifies that an oracle report issued before any validators are activated
    ///         preserves the existing in-flight deposit rather than clearing it.
    ///         The oracle confirms the pending ETH amount, so `getInFlightDeposit` must
    ///         remain at 96 ETH (3 × 32) after the report.
    function testReportWithPendingValidators() public {
        // Step 1: Fund river and deposit 3 validators for operator one.
        _fundRiver(3 * DEPOSIT_SIZE);
        sim_deposit(operatorOneIndex, 3);
        // Step 2: Submit oracle report without activating validators first.
        //         Validators remain in Pending state, so in-flight ETH must be preserved.
        sim_oracleReport();
        // Step 3: Assert in-flight deposit is still 96 ETH — the oracle confirmed the value.
        assertEq(river.getInFlightDeposit(), 96 ether, "inFlight preserved after report with pending");
    }

    /// @notice Verifies that partial validator activation across two oracle reports correctly
    ///         tracks the remaining in-flight ETH. After activating 2 of 3 validators and
    ///         reporting, one validator's deposit (32 ETH) remains in-flight. After activating
    ///         the last validator and reporting again, in-flight ETH drops to zero.
    function testPartialActivation() public {
        // Step 1: Fund river and deposit 3 validators.
        _fundRiver(3 * DEPOSIT_SIZE);
        sim_deposit(operatorOneIndex, 3);
        // Step 2: Activate only 2 of the 3 validators, leaving 1 still pending.
        sim_activateValidators(2);
        // Step 3: Submit first oracle report; 1 validator's deposit should still be in-flight.
        sim_oracleReport();
        assertEq(river.getInFlightDeposit(), DEPOSIT_SIZE, "1 validator still pending");
        // Step 4: Activate the remaining validator.
        sim_activateValidators(1);
        // Step 5: Submit second oracle report; all validators are now active, in-flight clears.
        sim_oracleReport();
        assertEq(river.getInFlightDeposit(), 0, "all activated");
    }

    /// @notice Verifies that deposits made between oracle reports are correctly tracked as
    ///         in-flight ETH, and that each new batch's in-flight balance is cleared after
    ///         the corresponding report confirming activation of that batch.
    function testIncrementalDepositsBetweenReports() public {
        // Step 1: Fund river and deposit the first batch of 2 validators.
        _fundRiver(5 * DEPOSIT_SIZE);
        sim_deposit(operatorOneIndex, 2);
        // Step 2: Activate the first batch and submit the first oracle report.
        //         In-flight deposit should be zero after the report.
        sim_activateValidators(2);
        sim_oracleReport();
        assertEq(river.getInFlightDeposit(), 0);
        // Step 3: Deposit a second batch of 3 validators; 3 × 32 ETH should now be in-flight.
        sim_deposit(operatorOneIndex, 3);
        assertEq(river.getInFlightDeposit(), 3 * DEPOSIT_SIZE, "inFlight after second deposit");
        // Step 4: Activate the second batch and submit the second oracle report.
        //         In-flight deposit must clear to zero again.
        sim_activateValidators(3);
        sim_oracleReport();
        assertEq(river.getInFlightDeposit(), 0);
    }

    /// @notice Verifies that an oracle report attempting to increase the stored in-flight ETH
    ///         value is rejected. After all validators are activated and in-flight ETH is zero,
    ///         a crafted report with `inFlightETH = 1 ether` (invalid increase) must revert.
    function testReportInFlightETHIncreaseReverts() public {
        // Step 1: Fund river, deposit 2 validators, activate them, and report to clear in-flight.
        _fundRiver(2 * DEPOSIT_SIZE);
        sim_deposit(operatorOneIndex, 2);
        sim_activateValidators(2);
        sim_oracleReport();
        // Step 2: Build a valid report structure and override inFlightETH with an illegal increase.
        uint256 reportEpoch = river.getExpectedEpochId();
        vm.warp((SECONDS_PER_SLOT * SLOTS_PER_EPOCH) * (reportEpoch + EPOCHS_UNTIL_FINAL) + 1);
        IOracleManagerV1.ConsensusLayerReport memory bad = _buildReport(false, false);
        bad.epoch = reportEpoch;
        bad.inFlightETH = 1 ether; // invalid: increases stored value
        // Step 3: Submit the crafted report as the oracle member and expect a revert.
        vm.prank(oracleMember);
        vm.expectRevert();
        oracle.reportConsensusLayerData(bad);
    }
}
