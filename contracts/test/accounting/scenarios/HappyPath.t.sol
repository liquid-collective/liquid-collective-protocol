// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../AccountingInvariants.sol";

contract HappyPathTest is AccountingInvariants {
    function testDepositActivateReport() public {
        _fundRiver(3 * DEPOSIT_SIZE);
        sim_deposit(operatorOneIndex, 3);
        assertEq(river.getInFlightDeposit(), 96 ether, "inFlight after deposit");
        sim_activateValidators(3);
        sim_oracleReport();
        assertEq(river.getInFlightDeposit(), 0, "inFlight after report");
    }

    function testMultiOperatorWithRewards() public {
        _fundRiver(10 * DEPOSIT_SIZE);
        sim_deposit(operatorOneIndex, 6);
        sim_deposit(operatorTwoIndex, 4);
        sim_activateValidators(10);
        sim_oracleReport();
        sim_advanceEpoch(0.008 ether);
        sim_oracleReport();
        sim_advanceEpoch(0.008 ether);
        sim_oracleReport();
        assertGt(river.totalUnderlyingSupply(), 10 * DEPOSIT_SIZE, "rewards accrued");
    }

    function testIncrementalDeposits() public {
        _fundRiver(5 * DEPOSIT_SIZE);
        sim_deposit(operatorOneIndex, 2);
        assertEq(river.getInFlightDeposit(), 64 ether, "after first batch");
        sim_deposit(operatorOneIndex, 3);
        assertEq(river.getInFlightDeposit(), 160 ether, "after second batch");
        sim_activateValidators(5);
        sim_oracleReport();
        assertEq(river.getInFlightDeposit(), 0, "after report");
    }
}
