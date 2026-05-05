// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../AccountingInvariants.sol";

contract SlashingContainmentTest is AccountingInvariants {
    /// @notice Verifies that a slashing event followed by an oracle report in slashing-containment
    ///         mode correctly reduces `totalUnderlyingSupply` below the original principal.
    ///         The share price is allowed to decrease during this test to reflect the penalty.
    function testSlashingContainmentModeActive() public {
        // Step 1: Fund river with enough ETH for 4 validators and deposit them for operator one.
        _fundRiver(4 * DEPOSIT_SIZE);
        sim_deposit(operatorOneIndex, _amounts(4, DEPOSIT_SIZE));
        // Step 2: Activate all 4 validators and submit the initial oracle report.
        sim_activateValidators(4);
        sim_oracleReport();
        // Step 3: Apply a 4 ETH slash penalty to an active validator of operator one.
        sim_slash(operatorOneIndex, 4 ether);
        // Step 4: Submit an oracle report in slashing-containment mode (slashingContainment=true),
        //         permitting a share price decrease to absorb the slash.
        _setAllowSharePriceDecrease(true);
        sim_oracleReport(false, true);
        _setAllowSharePriceDecrease(false);
        // Step 5: Assert that the total underlying supply has decreased below the original principal.
        assertLt(river.totalUnderlyingSupply(), 4 * DEPOSIT_SIZE, "underlying reduced by slash");
    }

    /// @notice Verifies that no new validator exit requests are generated during a slashing-
    ///         containment oracle report. The protocol must suppress exits while in containment
    ///         mode to avoid compounding the impact of a slashing event.
    function testNoExitRequestsDuringContainment() public {
        // Step 1: Fund river with enough ETH for 4 validators and deposit them for operator one.
        _fundRiver(4 * DEPOSIT_SIZE);
        sim_deposit(operatorOneIndex, _amounts(4, DEPOSIT_SIZE));
        // Step 2: Activate all 4 validators and submit the initial oracle report.
        sim_activateValidators(4);
        sim_oracleReport();
        // Step 3: Snapshot the current total ETH exits requested before the slash.
        uint256 exitsBefore = operatorsRegistry.getTotalETHExitsRequested();
        // Step 4: Apply a 4 ETH slash penalty to operator one.
        sim_slash(operatorOneIndex, 4 ether);
        // Step 5: Submit the containment-mode oracle report and confirm no exits were created.
        _setAllowSharePriceDecrease(true);
        sim_oracleReport(false, true);
        _setAllowSharePriceDecrease(false);
        uint256 exitsAfter = operatorsRegistry.getTotalETHExitsRequested();
        assertEq(exitsBefore, exitsAfter, "no exits during slashing containment");
    }

    /// @notice Verifies that SkippedExitRequestsDueToSlashingContainment is emitted when
    ///         exit request processing is suppressed due to slashing containment mode.
    function testEmitsSkippedExitRequestsEventDuringContainment() public {
        // Step 1: Fund river with enough ETH for 4 validators and deposit them for operator one.
        _fundRiver(4 * DEPOSIT_SIZE);
        sim_deposit(operatorOneIndex, _amounts(4, DEPOSIT_SIZE));
        // Step 2: Activate all 4 validators and submit the initial oracle report.
        sim_activateValidators(4);
        sim_oracleReport();
        // Step 3: Apply a 4 ETH slash penalty to operator one.
        sim_slash(operatorOneIndex, 4 ether);
        // Step 4: Expect the SkippedExitRequestsDueToSlashingContainment event when reporting in containment mode.
        vm.expectEmit(false, false, false, false, address(river));
        emit IRiverV1.SkippedExitRequestsDueToSlashingContainment();
        _setAllowSharePriceDecrease(true);
        sim_oracleReport(false, true);
        _setAllowSharePriceDecrease(false);
    }

    /// @notice Verifies that the protocol can resume normal oracle reporting after a slashing-
    ///         containment episode. Ensures all accounting invariants hold across the full
    ///         sequence: normal report → slash → containment report → normal report.
    function testContainmentEndAndResume() public {
        // Step 1: Fund river with enough ETH for 4 validators and deposit them for operator one.
        _fundRiver(4 * DEPOSIT_SIZE);
        sim_deposit(operatorOneIndex, _amounts(4, DEPOSIT_SIZE));
        // Step 2: Activate all 4 validators and submit the initial oracle report.
        sim_activateValidators(4);
        sim_oracleReport();
        // Step 3: Apply a 2 ETH slash penalty to operator one.
        sim_slash(operatorOneIndex, 2 ether);
        // Step 4: Submit a slashing-containment oracle report, allowing share price to decrease.
        _setAllowSharePriceDecrease(true);
        sim_oracleReport(false, true);
        _setAllowSharePriceDecrease(false);
        // Step 5: Submit a follow-up normal oracle report to verify the protocol resumes correctly.
        sim_oracleReport(false, false);
    }
}
