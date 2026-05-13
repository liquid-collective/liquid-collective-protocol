// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../AccountingInvariants.sol";
import "../../../src/interfaces/IOperatorRegistry.1.sol";

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

    function _requestETHExit(uint256 opIdx, uint256 ethAmount) internal {
        IOperatorsRegistryV1.ExitETHAllocation[] memory allocations = new IOperatorsRegistryV1.ExitETHAllocation[](1);
        allocations[0] = IOperatorsRegistryV1.ExitETHAllocation({operatorIndex: opIdx, ethAmount: ethAmount});

        vm.prank(keeper);
        operatorsRegistry.requestETHExits(allocations);
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

        uint256 requestedExitAmount = 2 * DEPOSIT_SIZE;
        assertEq(demandAfterFirst, requestedExitAmount, "should demand the exact redeem shortfall");
        _requestETHExit(operatorOneIndex, requestedExitAmount);
        uint256 demandAfterRequest = operatorsRegistry.getCurrentETHExitsDemand();
        assertEq(
            demandAfterRequest, demandAfterFirst - requestedExitAmount, "keeper request should consume current demand"
        );

        sim_requestExit(operatorOneIndex, DEPOSIT_SIZE);
        sim_completeExit(operatorOneIndex, DEPOSIT_SIZE, 0);

        sim_oracleReport();
        uint256 demandAfterSecond = operatorsRegistry.getCurrentETHExitsDemand();
        (uint256 totalExitedETH, uint256 totalRequestedExitAmounts) =
            operatorsRegistry.getExitedETHAndRequestedExitAmounts();

        assertGt(totalRequestedExitAmounts, totalExitedETH, "preExitingBalance should be non-zero");
        assertEq(demandAfterSecond, demandAfterRequest, "preExiting should prevent new demand");
    }

    function testSlashingContainmentSkipsDemandETHExits() public {
        _fundRiver(4 * DEPOSIT_SIZE);
        sim_deposit(operatorOneIndex, _amounts(4, DEPOSIT_SIZE));
        sim_activateValidators(4);
        sim_oracleReport();

        _depositAndRedeem(2 * DEPOSIT_SIZE);

        sim_oracleReport();
        uint256 demandBefore = operatorsRegistry.getCurrentETHExitsDemand();
        assertTrue(demandBefore > 0, "should have exit demand before containment report");

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

        assertTrue(river.getBalanceToDeposit() > 0, "should have balance to deposit");

        // Create redeem demand that exceeds available redeem balance.
        _depositAndRedeem(2 * DEPOSIT_SIZE);

        uint256 redeemDemandBefore = redeemManager.getRedeemDemand();
        uint256 withdrawalCountBefore = redeemManager.getWithdrawalEventCount();
        assertGt(redeemDemandBefore, 0, "should have redeem demand before rebalancing");

        sim_oracleReport(true, false);

        uint256 redeemDemandAfter = redeemManager.getRedeemDemand();
        assertEq(redeemDemandAfter, 0, "rebalancing should fully satisfy redeem demand");
        assertEq(redeemManager.getWithdrawalEventCount(), withdrawalCountBefore + 1, "should create withdrawal event");
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
        assertEq(demand, 1 ether, "exit demand should be exactly 1 ETH due to floor");
    }
}
