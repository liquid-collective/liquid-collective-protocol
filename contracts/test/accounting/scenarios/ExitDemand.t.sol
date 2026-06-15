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

    /// @dev Adds `ethAmount` of uncommitted balance to River's BalanceToDeposit (a deposit that is
    ///      never pushed to the CL), so rebalancing tests have a deposit buffer to draw from.
    function _addUncommittedDeposit(string memory label, uint256 ethAmount) internal {
        _simTotalUserDeposited += ethAmount;
        address depositor = makeAddr(label);
        _allowUser(depositor);
        vm.deal(depositor, ethAmount);
        vm.prank(depositor);
        river.deposit{value: ethAmount}();
    }

    function _requestETHExit(uint256 opIdx, uint256 ethAmount) internal {
        IOperatorsRegistryV1.ExitETHAllocation[] memory allocations = new IOperatorsRegistryV1.ExitETHAllocation[](1);
        allocations[0] = IOperatorsRegistryV1.ExitETHAllocation({operatorIndex: opIdx, ethAmount: ethAmount});
        // Post-Pectra requestETHExits takes EL allocations + a max fee. This test only exercises the
        // CL-exit path, so the EL allocation array is empty and the fee is zero (no msg.value needed).
        IOperatorsRegistryV1.ELExitETHAllocation[] memory elAllocations =
            new IOperatorsRegistryV1.ELExitETHAllocation[](0);

        vm.prank(keeper);
        operatorsRegistry.requestETHExits(allocations, elAllocations, 0);
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
        (uint256 totalExitedETH, uint256 totalRequestedETHExits) =
            operatorsRegistry.getExitedAndRequestedETHExits();

        assertGt(totalRequestedETHExits, totalExitedETH, "preExitingBalance should be non-zero");
        assertEq(demandAfterSecond, demandAfterRequest, "preExiting should prevent new demand");
    }

    /// @notice Containment must suppress `demandETHExits`. The containment report is the FIRST report
    ///         to see the redeem demand, and the test then shows (counterfactually) that the SAME
    ///         unmet demand DOES produce an exit request once containment clears. Without the
    ///         counterfactual, the assertion would hold even if the containment guard were removed.
    function testSlashingContainmentSkipsDemandETHExits() public {
        _fundRiver(4 * DEPOSIT_SIZE);
        sim_deposit(operatorOneIndex, _amounts(4, DEPOSIT_SIZE));
        sim_activateValidators(4);
        sim_oracleReport();

        // Create redeem demand that has not yet been serviced by any report.
        _depositAndRedeem(2 * DEPOSIT_SIZE);
        assertEq(operatorsRegistry.getCurrentETHExitsDemand(), 0, "no exit demand before any post-redeem report");

        // First post-redeem report runs under containment: exits must be skipped.
        _setAllowSharePriceDecrease(true);
        sim_oracleReport(false, true);
        _setAllowSharePriceDecrease(false);
        assertEq(operatorsRegistry.getCurrentETHExitsDemand(), 0, "containment must skip demandETHExits");

        // Counterfactual: the same unmet demand triggers an exit request once containment clears.
        sim_oracleReport();
        assertGt(operatorsRegistry.getCurrentETHExitsDemand(), 0, "exit demand generated once containment clears");
    }

    /// @notice Containment must also suppress the deposit->redeem rebalancing, even when rebalancing
    ///         is otherwise allowed for the report.
    function testSlashingContainmentSkipsRebalancing() public {
        _fundRiver(2 * DEPOSIT_SIZE);
        sim_deposit(operatorOneIndex, _amounts(2, DEPOSIT_SIZE));
        sim_activateValidators(2);
        sim_oracleReport();

        _addUncommittedDeposit("rebalanceBuffer", 2 * DEPOSIT_SIZE);
        _depositAndRedeem(2 * DEPOSIT_SIZE);

        uint256 depositBefore = river.getBalanceToDeposit();
        uint256 redeemBufferBefore = river.getBalanceToRedeem();
        uint256 redeemDemandBefore = redeemManager.getRedeemDemand();
        assertGt(depositBefore, 0, "should have balance to deposit");
        assertGt(redeemDemandBefore, 0, "should have redeem demand");

        // Rebalancing is allowed (true) but containment (true) must short-circuit before any move.
        _setAllowSharePriceDecrease(true);
        sim_oracleReport(true, true);
        _setAllowSharePriceDecrease(false);

        assertEq(river.getBalanceToDeposit(), depositBefore, "containment must not move deposit balance");
        assertEq(river.getBalanceToRedeem(), redeemBufferBefore, "containment must not move redeem balance");
        assertEq(redeemManager.getRedeemDemand(), redeemDemandBefore, "containment must not service redeem demand");
        assertEq(operatorsRegistry.getCurrentETHExitsDemand(), 0, "containment must not demand exits");
    }

    function testRebalancingMovesDepositToRedeem() public {
        _fundRiver(2 * DEPOSIT_SIZE);
        sim_deposit(operatorOneIndex, _amounts(2, DEPOSIT_SIZE));
        sim_activateValidators(2);
        sim_oracleReport();

        // Add funds that stay in BalanceToDeposit (not committed).
        _addUncommittedDeposit("depositor", 2 * DEPOSIT_SIZE);
        assertTrue(river.getBalanceToDeposit() > 0, "should have balance to deposit");

        // Create redeem demand that exceeds available redeem balance.
        _depositAndRedeem(2 * DEPOSIT_SIZE);

        uint256 depositBefore = river.getBalanceToDeposit();
        uint256 redeemDemandBefore = redeemManager.getRedeemDemand();
        uint256 withdrawalCountBefore = redeemManager.getWithdrawalEventCount();
        assertGt(redeemDemandBefore, 0, "should have redeem demand before rebalancing");

        sim_oracleReport(true, false);

        // Rebalancing moves ETH out of BalanceToDeposit to fully satisfy the demand WITHOUT exiting validators.
        assertLt(river.getBalanceToDeposit(), depositBefore, "deposit balance reduced by rebalancing");
        assertEq(redeemManager.getRedeemDemand(), 0, "rebalancing should fully satisfy redeem demand");
        assertEq(operatorsRegistry.getCurrentETHExitsDemand(), 0, "rebalancing covered demand; no exits demanded");
        assertEq(redeemManager.getWithdrawalEventCount(), withdrawalCountBefore + 1, "should create withdrawal event");
    }

    /// @notice When rebalancing is disabled, an available deposit buffer is left untouched and the
    ///         shortfall is covered by demanding validator exits instead.
    function testRebalancingDisabledGoesStraightToExits() public {
        _fundRiver(2 * DEPOSIT_SIZE);
        sim_deposit(operatorOneIndex, _amounts(2, DEPOSIT_SIZE));
        sim_activateValidators(2);
        sim_oracleReport();

        _addUncommittedDeposit("idleBuffer", 2 * DEPOSIT_SIZE);
        _depositAndRedeem(2 * DEPOSIT_SIZE);

        assertGt(river.getBalanceToDeposit(), 0, "should have balance to deposit");
        uint256 withdrawalCountBefore = redeemManager.getWithdrawalEventCount();

        // Rebalancing disabled (false), no containment (false): the deposit buffer must NOT be used to
        // service redeem demand via rebalancing; instead the shortfall is covered by demanding exits.
        sim_oracleReport(false, false);

        assertGt(operatorsRegistry.getCurrentETHExitsDemand(), 0, "shortfall covered by exit demand");
        assertEq(
            redeemManager.getWithdrawalEventCount(),
            withdrawalCountBefore,
            "no rebalancing-driven redeem servicing when rebalancing disabled"
        );
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

    /// @notice Boundary companion to the floor test: a shortfall above 1 ETH is demanded exactly,
    ///         confirming the `max(..., 1 ether)` floor does not over-apply.
    function testExitDemandAboveOneEtherNotFloored() public {
        _fundRiver(2 * DEPOSIT_SIZE);
        sim_deposit(operatorOneIndex, _amounts(2, DEPOSIT_SIZE));
        sim_activateValidators(2);
        sim_oracleReport();

        _depositAndRedeem(1.5 ether);

        sim_oracleReport();
        uint256 demand = operatorsRegistry.getCurrentETHExitsDemand();
        assertEq(demand, 1.5 ether, "exit demand should equal the shortfall when above the 1 ETH floor");
    }
}
