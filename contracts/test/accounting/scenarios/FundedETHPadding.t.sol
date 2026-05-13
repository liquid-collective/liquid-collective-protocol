// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../AccountingInvariants.sol";
import "../../../src/state/operatorsRegistry/Operators.3.sol";

contract FundedETHPaddingTest is AccountingInvariants {
    /// @notice Verifies the padding branch in River._incrementFundedETH fires when a deposit
    ///         batch only touches operator 0 while 2 operators are registered. The fundedETH
    ///         array passed from the deposit manager has length 1, which is less than
    ///         operatorCount (2), so River must pad it before forwarding to the registry.
    function testPaddingWhenDepositToSubsetOfOperators() public {
        _fundRiver(3 * DEPOSIT_SIZE);
        // Deposit only to operator 0 — fundedETH array will have length 1 (< operatorCount=2).
        sim_deposit(operatorOneIndex, _amounts(3, DEPOSIT_SIZE));
        sim_activateValidators(3);
        sim_oracleReport();

        OperatorsV3.Operator memory op0 = operatorsRegistry.getOperator(operatorOneIndex);
        OperatorsV3.Operator memory op1 = operatorsRegistry.getOperator(operatorTwoIndex);
        assertEq(op0.funded, 3 * DEPOSIT_SIZE, "op0 funded");
        assertEq(op1.funded, 0, "op1 funded should be zero (padding)");
    }

    /// @notice Verifies that after depositing to operator 0 (triggering padding), a subsequent
    ///         deposit to operator 1 works correctly. Both operators should have the correct
    ///         funded ETH values.
    function testPaddingThenDepositToSecondOperator() public {
        _fundRiver(4 * DEPOSIT_SIZE);
        sim_deposit(operatorOneIndex, _amounts(2, DEPOSIT_SIZE));
        sim_deposit(operatorTwoIndex, _amounts(2, DEPOSIT_SIZE));
        sim_activateValidators(4);
        sim_oracleReport();

        OperatorsV3.Operator memory op0 = operatorsRegistry.getOperator(operatorOneIndex);
        OperatorsV3.Operator memory op1 = operatorsRegistry.getOperator(operatorTwoIndex);
        assertEq(op0.funded, 2 * DEPOSIT_SIZE, "op0 funded");
        assertEq(op1.funded, 2 * DEPOSIT_SIZE, "op1 funded");
    }

    /// @notice Verifies the padding branch works with a full exit cycle: deposit to a subset,
    ///         activate, exit, and confirm all invariants hold throughout.
    function testPaddingWithExitCycle() public {
        _fundRiver(5 * DEPOSIT_SIZE);
        // First batch: only operator 0 (triggers padding).
        sim_deposit(operatorOneIndex, _amounts(3, DEPOSIT_SIZE));
        // Second batch: only operator 1; this does not trigger padding, since operatorIndex=1
        // means the array has length 2, which equals operatorCount.
        sim_deposit(operatorTwoIndex, _amounts(2, DEPOSIT_SIZE));
        sim_activateValidators(5);
        sim_oracleReport();

        // Exit from operator 0 only — verifies padding didn't corrupt funded tracking.
        sim_requestExit(operatorOneIndex, 2 * DEPOSIT_SIZE);
        sim_completeExit(operatorOneIndex, 2 * DEPOSIT_SIZE, 0);
        sim_oracleReport();

        OperatorsV3.Operator memory op0 = operatorsRegistry.getOperator(operatorOneIndex);
        assertEq(op0.funded, 3 * DEPOSIT_SIZE, "op0 funded unchanged after exit");
        uint256[] memory exitedPerOp = operatorsRegistry.getExitedETHPerOperator();
        assertEq(exitedPerOp[operatorOneIndex], 2 * DEPOSIT_SIZE, "op0 exited");
        assertEq(exitedPerOp[operatorTwoIndex], 0, "op1 exited should be zero");
    }
}
