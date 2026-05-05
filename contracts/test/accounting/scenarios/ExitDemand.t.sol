// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../AccountingInvariants.sol";

contract ExitDemandTest is AccountingInvariants {
    function _depositAndRedeem(uint256 ethAmount) internal {
        address user = makeAddr(string(abi.encode("redeemer", ethAmount)));
        _allowUser(user);
        _simTotalUserDeposited += ethAmount;
        vm.deal(user, ethAmount);
        vm.prank(user);
        river.deposit{value: ethAmount}();
        sim_requestRedeem(user, river.balanceOf(user));
    }

    function testPreExitingBalanceReducesExitDemand() public {
        _fundRiver(4 * DEPOSIT_SIZE);
        sim_deposit(operatorOneIndex, _amounts(4, DEPOSIT_SIZE));
        sim_activateValidators(4);
        sim_oracleReport();

        _depositAndRedeem(2 * DEPOSIT_SIZE);

        sim_oracleReport();
        uint256 demandAfterFirst = operatorsRegistry.getCurrentETHExitsDemand();
        assertTrue(demandAfterFirst > 0, "should have exit demand after redeem request");

        sim_requestExit(operatorOneIndex, DEPOSIT_SIZE);
        sim_completeExit(operatorOneIndex, DEPOSIT_SIZE, 0);

        sim_oracleReport();
        uint256 demandAfterSecond = operatorsRegistry.getCurrentETHExitsDemand();

        assertLe(demandAfterSecond, demandAfterFirst, "demand should not increase when preExiting covers shortfall");
    }

    function testSlashingContainmentSkipsDemandETHExits() public {
        _fundRiver(4 * DEPOSIT_SIZE);
        sim_deposit(operatorOneIndex, _amounts(4, DEPOSIT_SIZE));
        sim_activateValidators(4);
        sim_oracleReport();

        _depositAndRedeem(2 * DEPOSIT_SIZE);

        uint256 demandBefore = operatorsRegistry.getCurrentETHExitsDemand();

        _setAllowSharePriceDecrease(true);
        sim_oracleReport(false, true);
        _setAllowSharePriceDecrease(false);

        uint256 demandAfter = operatorsRegistry.getCurrentETHExitsDemand();
        assertEq(demandAfter, demandBefore, "demand must not change under slashing containment");
    }

    function testRebalancingMovesDepositToRedeem() public {
        _fundRiver(2 * DEPOSIT_SIZE);
        sim_deposit(operatorOneIndex, _amounts(2, DEPOSIT_SIZE));
        sim_activateValidators(2);
        sim_oracleReport();

        // Add funds that stay in BalanceToDeposit (not committed).
        _simTotalUserDeposited += 2 * DEPOSIT_SIZE;
        address depositor = makeAddr("depositor");
        _allowUser(depositor);
        vm.deal(depositor, 2 * DEPOSIT_SIZE);
        vm.prank(depositor);
        river.deposit{value: 2 * DEPOSIT_SIZE}();

        uint256 depositBefore = river.getBalanceToDeposit();
        assertTrue(depositBefore > 0, "should have balance to deposit");

        // Create redeem demand that exceeds available redeem balance.
        _depositAndRedeem(2 * DEPOSIT_SIZE);

        sim_oracleReport(true, false);

        uint256 depositAfter = river.getBalanceToDeposit();
        assertLt(depositAfter, depositBefore, "BalanceToDeposit should decrease after rebalancing");
    }

    function testOneEtherMinimumFloor() public {
        _fundRiver(2 * DEPOSIT_SIZE);
        sim_deposit(operatorOneIndex, _amounts(2, DEPOSIT_SIZE));
        sim_activateValidators(2);
        sim_oracleReport();

        // Create a tiny redeem demand — shortfall will be < 1 ETH.
        _depositAndRedeem(0.5 ether);

        sim_oracleReport();
        uint256 demand = operatorsRegistry.getCurrentETHExitsDemand();
        assertGe(demand, 1 ether, "exit demand must be at least 1 ETH due to floor");
    }
}
