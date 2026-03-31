// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../AccountingInvariants.sol";

contract RebalancingModeTest is AccountingInvariants {
    function testRebalancingModePreservesConservation() public {
        _fundRiver(6 * DEPOSIT_SIZE);
        sim_deposit(operatorOneIndex, 3);
        sim_activateValidators(3);
        sim_oracleReport();
        sim_oracleReport(true, false);
    }

    function testResumeAfterRebalancing() public {
        _fundRiver(4 * DEPOSIT_SIZE);
        sim_deposit(operatorOneIndex, 4);
        sim_activateValidators(4);
        sim_oracleReport();
        sim_oracleReport(true, false);
        sim_oracleReport(false, false);
    }
}
