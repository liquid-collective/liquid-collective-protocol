// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../AccountingInvariants.sol";

contract InFlightETHTest is AccountingInvariants {
    function testReportWithPendingValidators() public {
        _fundRiver(3 * DEPOSIT_SIZE);
        sim_deposit(operatorOneIndex, 3);
        // No activation — validators still Pending
        sim_oracleReport();
        // inFlightDeposit stays 96 ether (oracle confirmed the value)
        assertEq(river.getInFlightDeposit(), 96 ether, "inFlight preserved after report with pending");
    }

    function testPartialActivation() public {
        _fundRiver(3 * DEPOSIT_SIZE);
        sim_deposit(operatorOneIndex, 3);
        sim_activateValidators(2); // 1 still pending
        sim_oracleReport();
        assertEq(river.getInFlightDeposit(), DEPOSIT_SIZE, "1 validator still pending");
        sim_activateValidators(1);
        sim_oracleReport();
        assertEq(river.getInFlightDeposit(), 0, "all activated");
    }

    function testIncrementalDepositsBetweenReports() public {
        _fundRiver(5 * DEPOSIT_SIZE);
        sim_deposit(operatorOneIndex, 2);
        sim_activateValidators(2);
        sim_oracleReport();
        assertEq(river.getInFlightDeposit(), 0);
        sim_deposit(operatorOneIndex, 3);
        assertEq(river.getInFlightDeposit(), 3 * DEPOSIT_SIZE, "inFlight after second deposit");
        sim_activateValidators(3);
        sim_oracleReport();
        assertEq(river.getInFlightDeposit(), 0);
    }

    function testReportInFlightETHIncreaseReverts() public {
        _fundRiver(2 * DEPOSIT_SIZE);
        sim_deposit(operatorOneIndex, 2);
        sim_activateValidators(2);
        sim_oracleReport();
        // Now inFlightDeposit == 0. Craft a report with inFlightETH = 1 ether (invalid increase).
        uint256 reportEpoch = river.getExpectedEpochId();
        vm.warp((SECONDS_PER_SLOT * SLOTS_PER_EPOCH) * (reportEpoch + EPOCHS_UNTIL_FINAL) + 1);
        IOracleManagerV1.ConsensusLayerReport memory bad = _buildReport(false, false);
        bad.epoch = reportEpoch;
        bad.inFlightETH = 1 ether; // invalid: increases stored value
        vm.prank(oracleMember);
        vm.expectRevert();
        oracle.reportConsensusLayerData(bad);
    }
}
