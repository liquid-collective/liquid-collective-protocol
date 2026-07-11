// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../AccountingInvariants.sol";

contract RebalancingModeTest is AccountingInvariants {
    function _depositAndRedeem(string memory label, uint256 ethAmount) internal {
        address user = makeAddr(label);
        _allowUser(user);
        _simTotalUserDeposited += ethAmount;
        vm.deal(user, ethAmount);
        vm.prank(user);
        river.deposit{value: ethAmount}();
        sim_requestRedeem(user, river.balanceOf(user));
    }

    function _addDepositBuffer(string memory label, uint256 ethAmount) internal {
        _simTotalUserDeposited += ethAmount;
        address depositor = makeAddr(label);
        _allowUser(depositor);
        vm.deal(depositor, ethAmount);
        vm.prank(depositor);
        river.deposit{value: ethAmount}();
    }

    /// @notice Exercises a real deposit-to-redeem rebalance and verifies both exact movement
    ///         and conservation rather than merely submitting the mode flag.
    function testRebalancingModePreservesConservation() public {
        _fundRiver(3 * DEPOSIT_SIZE);
        sim_deposit(operatorOneIndex, _amounts(3, DEPOSIT_SIZE));
        sim_activateValidators(3);
        sim_oracleReport();

        _addDepositBuffer("rebalanceBuffer", 2 * DEPOSIT_SIZE);
        _depositAndRedeem("rebalanceRedeemer", 2 * DEPOSIT_SIZE);
        uint256 underlyingBefore = river.totalUnderlyingSupply();
        uint256 redeemManagerBalanceBefore = address(redeemManager).balance;
        uint256 depositSideBefore = river.getBalanceToDeposit() + river.getCommittedBalance();
        uint256 withdrawalCountBefore = redeemManager.getWithdrawalEventCount();

        sim_oracleReport(true, false);

        assertEq(
            river.totalUnderlyingSupply(),
            underlyingBefore - 2 * DEPOSIT_SIZE,
            "serviced redemption leaves River exactly"
        );
        assertEq(
            river.totalUnderlyingSupply() + address(redeemManager).balance,
            underlyingBefore + redeemManagerBalanceBefore,
            "rebalancing conserves system ETH"
        );
        assertEq(
            river.getBalanceToDeposit() + river.getCommittedBalance(),
            depositSideBefore - 2 * DEPOSIT_SIZE,
            "exact amount leaves deposit side"
        );
        assertEq(redeemManager.getRedeemDemand(), 0, "redeem demand fully serviced");
        assertEq(redeemManager.getWithdrawalEventCount(), withdrawalCountBefore + 1, "withdrawal event created");
        assertEq(operatorsRegistry.getCurrentETHExitsDemand(), 0, "no validator exits required");
    }

    /// @notice After a real rebalance, verifies a normal report leaves a new deposit buffer
    ///         untouched and converts new redeem demand into an exact validator-exit demand.
    function testResumeAfterRebalancing() public {
        _fundRiver(4 * DEPOSIT_SIZE);
        sim_deposit(operatorOneIndex, _amounts(4, DEPOSIT_SIZE));
        sim_activateValidators(4);
        sim_oracleReport();

        _addDepositBuffer("firstBuffer", DEPOSIT_SIZE);
        _depositAndRedeem("firstRedeemer", DEPOSIT_SIZE);
        sim_oracleReport(true, false);
        assertEq(redeemManager.getRedeemDemand(), 0, "first demand serviced by rebalancing");

        _addDepositBuffer("secondBuffer", DEPOSIT_SIZE);
        _depositAndRedeem("secondRedeemer", DEPOSIT_SIZE);
        uint256 depositSideBefore = river.getBalanceToDeposit() + river.getCommittedBalance();

        sim_oracleReport(false, false);

        assertEq(
            river.getBalanceToDeposit() + river.getCommittedBalance(),
            depositSideBefore,
            "normal mode must preserve deposit-side funds"
        );
        assertEq(operatorsRegistry.getCurrentETHExitsDemand(), DEPOSIT_SIZE, "normal mode demands exact exits");
    }
}
