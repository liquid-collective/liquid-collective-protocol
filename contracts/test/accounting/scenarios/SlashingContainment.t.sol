// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../AccountingInvariants.sol";

contract SlashingContainmentTest is AccountingInvariants {
    function testSlashingContainmentModeActive() public {
        _fundRiver(4 * DEPOSIT_SIZE);
        sim_deposit(operatorOneIndex, 4);
        sim_activateValidators(4);
        sim_oracleReport();
        sim_slash(operatorOneIndex, 4 ether);
        _setAllowSharePriceDecrease(true);
        sim_oracleReport(false, true);
        _setAllowSharePriceDecrease(false);
        assertLt(river.totalUnderlyingSupply(), 4 * DEPOSIT_SIZE, "underlying reduced by slash");
    }

    function testNoExitRequestsDuringContainment() public {
        _fundRiver(4 * DEPOSIT_SIZE);
        sim_deposit(operatorOneIndex, 4);
        sim_activateValidators(4);
        sim_oracleReport();
        uint256 exitsBefore = operatorsRegistry.getTotalETHExitsRequested();
        sim_slash(operatorOneIndex, 4 ether);
        _setAllowSharePriceDecrease(true);
        sim_oracleReport(false, true);
        _setAllowSharePriceDecrease(false);
        uint256 exitsAfter = operatorsRegistry.getTotalETHExitsRequested();
        assertEq(exitsBefore, exitsAfter, "no exits during slashing containment");
    }

    function testContainmentEndAndResume() public {
        _fundRiver(4 * DEPOSIT_SIZE);
        sim_deposit(operatorOneIndex, 4);
        sim_activateValidators(4);
        sim_oracleReport();
        sim_slash(operatorOneIndex, 2 ether);
        _setAllowSharePriceDecrease(true);
        sim_oracleReport(false, true);
        _setAllowSharePriceDecrease(false);
        sim_oracleReport(false, false);
    }
}
