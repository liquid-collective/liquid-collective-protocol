// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../AccountingInvariants.sol";
import "../../../src/state/operatorsRegistry/Operators.3.sol";

contract ExitAccountingTest is AccountingInvariants {
    function testCleanExit() public {
        _fundRiver(4 * DEPOSIT_SIZE);
        sim_deposit(operatorOneIndex, 4);
        sim_activateValidators(4);
        sim_oracleReport();
        sim_requestExit(operatorOneIndex, 2 * DEPOSIT_SIZE);
        sim_completeExit(operatorOneIndex, 2 * DEPOSIT_SIZE, 0);
        sim_oracleReport();
        OperatorsV3.Operator memory op = operatorsRegistry.getOperator(operatorOneIndex);
        assertEq(op.funded, 4 * DEPOSIT_SIZE, "funded ETH");
        uint256[] memory exitedPerOp = operatorsRegistry.getExitedETHPerOperator();
        assertEq(exitedPerOp[operatorOneIndex], 2 * DEPOSIT_SIZE, "exited ETH for op1");
    }

    function testTwoOperatorExits() public {
        _fundRiver(6 * DEPOSIT_SIZE);
        sim_deposit(operatorOneIndex, 3);
        sim_deposit(operatorTwoIndex, 3);
        sim_activateValidators(6);
        sim_oracleReport();
        sim_requestExit(operatorOneIndex, DEPOSIT_SIZE);
        sim_requestExit(operatorTwoIndex, 2 * DEPOSIT_SIZE);
        sim_completeExit(operatorOneIndex, DEPOSIT_SIZE, 0);
        sim_completeExit(operatorTwoIndex, 2 * DEPOSIT_SIZE, 0);
        sim_oracleReport();
        uint256[] memory exitedPerOp = operatorsRegistry.getExitedETHPerOperator();
        assertEq(exitedPerOp[operatorOneIndex], DEPOSIT_SIZE, "op1 exited");
        assertEq(exitedPerOp[operatorTwoIndex], 2 * DEPOSIT_SIZE, "op2 exited");
        (uint256 totalExited,) = operatorsRegistry.getExitedETHAndRequestedExitAmounts();
        assertEq(totalExited, 3 * DEPOSIT_SIZE, "total exited");
    }

    function testSlashedExit() public {
        _fundRiver(2 * DEPOSIT_SIZE);
        sim_deposit(operatorOneIndex, 2);
        sim_activateValidators(2);
        sim_oracleReport();
        uint256 penalty = 1 ether;
        sim_requestExit(operatorOneIndex, DEPOSIT_SIZE);
        sim_completeExit(operatorOneIndex, DEPOSIT_SIZE, penalty);
        _setAllowSharePriceDecrease(true);
        sim_oracleReport();
        _setAllowSharePriceDecrease(false);
        uint256[] memory exitedPerOp = operatorsRegistry.getExitedETHPerOperator();
        assertEq(exitedPerOp[operatorOneIndex], DEPOSIT_SIZE - penalty, "slashed exit");
    }

    function testTotalDepositedETHMonotonic() public {
        _fundRiver(3 * DEPOSIT_SIZE);
        sim_deposit(operatorOneIndex, 3);
        uint256 totalAfterDeposit = river.getTotalDepositedETH();
        sim_activateValidators(3);
        sim_oracleReport();
        assertEq(river.getTotalDepositedETH(), totalAfterDeposit, "no change after report");
        sim_requestExit(operatorOneIndex, 3 * DEPOSIT_SIZE);
        sim_completeExit(operatorOneIndex, 3 * DEPOSIT_SIZE, 0);
        sim_oracleReport();
        assertEq(river.getTotalDepositedETH(), totalAfterDeposit, "no change after exit");
    }
}
