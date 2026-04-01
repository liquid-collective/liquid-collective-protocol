// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../AccountingInvariants.sol";
import "../../../src/state/operatorsRegistry/Operators.3.sol";

contract ExitAccountingTest is AccountingInvariants {
    /// @notice Verifies that a clean (penalty-free) exit correctly updates the per-operator
    ///         exited ETH tracker while leaving the funded ETH value unchanged.
    ///         After exiting 2 of 4 validators, `funded` must remain at the original deposit
    ///         amount and `exitedETHPerOperator` must reflect exactly the 2 exited validators.
    function testCleanExit() public {
        // Step 1: Fund river with enough ETH for 4 validators and deposit them for operator one.
        _fundRiver(4 * DEPOSIT_SIZE);
        sim_deposit(operatorOneIndex, 4);
        // Step 2: Activate all 4 validators and submit the initial oracle report.
        sim_activateValidators(4);
        sim_oracleReport();
        // Step 3: Request an exit for 2 validators and complete those exits with no penalty.
        sim_requestExit(operatorOneIndex, 2 * DEPOSIT_SIZE);
        sim_completeExit(operatorOneIndex, 2 * DEPOSIT_SIZE, 0);
        // Step 4: Submit oracle report to confirm the exits.
        sim_oracleReport();
        // Step 5: Assert that funded ETH remains unchanged (exits do not reduce the funded counter)
        //         and that exited ETH per operator equals exactly the 2 exited validators' principal.
        OperatorsV3.Operator memory op = operatorsRegistry.getOperator(operatorOneIndex);
        assertEq(op.funded, 4 * DEPOSIT_SIZE, "funded ETH");
        uint256[] memory exitedPerOp = operatorsRegistry.getExitedETHPerOperator();
        assertEq(exitedPerOp[operatorOneIndex], 2 * DEPOSIT_SIZE, "exited ETH for op1");
    }

    /// @notice Verifies that exits from two different operators are tracked independently and
    ///         that the aggregate exited ETH equals the sum of both operators' exited amounts.
    function testTwoOperatorExits() public {
        // Step 1: Fund river for 6 validators and split deposits across both operators.
        _fundRiver(6 * DEPOSIT_SIZE);
        sim_deposit(operatorOneIndex, 3);
        sim_deposit(operatorTwoIndex, 3);
        // Step 2: Activate all 6 validators and submit the initial oracle report.
        sim_activateValidators(6);
        sim_oracleReport();
        // Step 3: Request and complete exits — 1 validator for operator one, 2 for operator two.
        sim_requestExit(operatorOneIndex, DEPOSIT_SIZE);
        sim_requestExit(operatorTwoIndex, 2 * DEPOSIT_SIZE);
        sim_completeExit(operatorOneIndex, DEPOSIT_SIZE, 0);
        sim_completeExit(operatorTwoIndex, 2 * DEPOSIT_SIZE, 0);
        // Step 4: Submit oracle report to confirm both sets of exits.
        sim_oracleReport();
        // Step 5: Assert per-operator exited ETH and aggregate total are correct.
        uint256[] memory exitedPerOp = operatorsRegistry.getExitedETHPerOperator();
        assertEq(exitedPerOp[operatorOneIndex], DEPOSIT_SIZE, "op1 exited");
        assertEq(exitedPerOp[operatorTwoIndex], 2 * DEPOSIT_SIZE, "op2 exited");
        (uint256 totalExited,) = operatorsRegistry.getExitedETHAndRequestedExitAmounts();
        assertEq(totalExited, 3 * DEPOSIT_SIZE, "total exited");
    }

    /// @notice Verifies that a validator exit with a slash penalty results in a reduced exited
    ///         ETH amount. The exited ETH for the operator must equal `DEPOSIT_SIZE - penalty`.
    function testSlashedExit() public {
        // Step 1: Fund river for 2 validators and deposit them for operator one.
        _fundRiver(2 * DEPOSIT_SIZE);
        sim_deposit(operatorOneIndex, 2);
        // Step 2: Activate both validators and submit the initial oracle report.
        sim_activateValidators(2);
        sim_oracleReport();
        // Step 3: Request an exit for 1 validator and complete it with a 1 ETH penalty.
        uint256 penalty = 1 ether;
        sim_requestExit(operatorOneIndex, DEPOSIT_SIZE);
        sim_completeExit(operatorOneIndex, DEPOSIT_SIZE, penalty);
        // Step 4: Submit oracle report, allowing share price to decrease due to the penalty.
        _setAllowSharePriceDecrease(true);
        sim_oracleReport();
        _setAllowSharePriceDecrease(false);
        // Step 5: Assert that exited ETH reflects the reduced amount (principal minus penalty).
        uint256[] memory exitedPerOp = operatorsRegistry.getExitedETHPerOperator();
        assertEq(exitedPerOp[operatorOneIndex], DEPOSIT_SIZE - penalty, "slashed exit");
    }

    /// @notice Verifies that `getTotalDepositedETH` is monotonically non-decreasing throughout
    ///         the full lifecycle: deposit → activate → report → exit request → exit completion → report.
    ///         Exits return ETH to the EL but must not reduce the total deposited counter.
    function testTotalDepositedETHMonotonic() public {
        // Step 1: Fund river for 3 validators and deposit them for operator one.
        _fundRiver(3 * DEPOSIT_SIZE);
        sim_deposit(operatorOneIndex, 3);
        // Step 2: Record total deposited ETH immediately after the deposit.
        uint256 totalAfterDeposit = river.getTotalDepositedETH();
        // Step 3: Activate all validators and report — total deposited must not change.
        sim_activateValidators(3);
        sim_oracleReport();
        assertEq(river.getTotalDepositedETH(), totalAfterDeposit, "no change after report");
        // Step 4: Request and complete the full exit of all 3 validators with no penalty.
        sim_requestExit(operatorOneIndex, 3 * DEPOSIT_SIZE);
        sim_completeExit(operatorOneIndex, 3 * DEPOSIT_SIZE, 0);
        // Step 5: Report again — total deposited must still match the original deposit value.
        sim_oracleReport();
        assertEq(river.getTotalDepositedETH(), totalAfterDeposit, "no change after exit");
    }
}
