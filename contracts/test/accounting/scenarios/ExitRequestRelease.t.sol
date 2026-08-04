// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../AccountingInvariants.sol";
import "../../../src/interfaces/IOperatorRegistry.1.sol";
import "../../../src/interfaces/IRiver.1.sol";
import "../../../src/state/operatorsRegistry/Operators.3.sol";

/// @notice End-to-end scenario for the CL-failure recovery path: an exit request that the consensus layer
///         silently drops leaves a phantom reservation which permanently suppresses new exit demand, so
///         the LsETH redemption behind it is never funded. `releaseExitRequests` unwinds the reservation,
///         the keeper re-dispatches, and the redemption settles.
contract ExitRequestReleaseTest is AccountingInvariants {
    function _depositAndRedeem(uint256 ethAmount) internal {
        address user = makeAddr(string(abi.encode("release-redeemer", ethAmount)));
        _allowUser(user);
        _simTotalUserDeposited += ethAmount;
        vm.deal(user, ethAmount);
        vm.prank(user);
        river.deposit{value: ethAmount}();
        sim_requestRedeem(user, river.balanceOf(user));
    }

    function _requestETHExit(uint256 opIdx, uint256 ethAmount) internal {
        IOperatorsRegistryV1.ExitsViaConsolidationAllocation memory noConsolidation;
        IOperatorsRegistryV1.ExitETHAllocation[] memory allocations = new IOperatorsRegistryV1.ExitETHAllocation[](1);
        allocations[0] = IOperatorsRegistryV1.ExitETHAllocation({operatorIndex: opIdx, ethAmount: ethAmount});
        IOperatorsRegistryV1.ELExitETHAllocation[] memory elAllocations =
            new IOperatorsRegistryV1.ELExitETHAllocation[](0);

        vm.prank(keeper);
        operatorsRegistry.requestETHExits(allocations, elAllocations, noConsolidation, 0, 0);
    }

    function _releaseExitRequest(uint256 opIdx, uint256 ethAmount) internal {
        IOperatorsRegistryV1.ExitReleaseAllocation[] memory allocations =
            new IOperatorsRegistryV1.ExitReleaseAllocation[](1);
        allocations[0] = IOperatorsRegistryV1.ExitReleaseAllocation({operatorIndex: opIdx, ethAmount: ethAmount});

        vm.prank(admin);
        operatorsRegistry.releaseExitRequests(allocations, 0);
    }

    /// @notice A dropped exit request strands the redemption behind it across successive oracle reports;
    ///         releasing the reservation is what lets the keeper re-dispatch and the redemption settle.
    function testDroppedExitStrandsRedeemUntilReleased() public {
        _fundRiver(4 * DEPOSIT_SIZE);
        sim_deposit(operatorOneIndex, _amounts(4, DEPOSIT_SIZE));
        sim_activateValidators(4);
        sim_oracleReport();

        uint256 redeemAmount = 2 * DEPOSIT_SIZE;
        _depositAndRedeem(redeemAmount);

        sim_oracleReport();
        assertEq(operatorsRegistry.getCurrentETHExitsDemand(), redeemAmount, "report demands the redeem shortfall");
        uint256 strandedRedeemDemand = redeemManager.getRedeemDemand();
        assertGt(strandedRedeemDemand, 0, "redeem request is outstanding");

        // The keeper dispatches the exit. The reservation is booked on-chain, but the consensus layer
        // silently drops the request — the simulator never queues or completes the exit, so nothing ever
        // comes back. This is the bug being recovered from.
        _requestETHExit(operatorOneIndex, redeemAmount);
        assertEq(operatorsRegistry.getTotalETHExitsRequested(), redeemAmount, "reservation booked");
        assertEq(operatorsRegistry.getCurrentETHExitsDemand(), 0, "reservation consumed the demand");

        // Across further reports the phantom reservation inflates `preExitingBalance`, so no new demand is
        // ever created and the redemption stays unfunded indefinitely.
        uint256 withdrawalCountBefore = redeemManager.getWithdrawalEventCount();
        sim_oracleReport();
        sim_oracleReport();
        sim_oracleReport();
        assertEq(operatorsRegistry.getCurrentETHExitsDemand(), 0, "phantom reservation suppresses new demand");
        assertEq(redeemManager.getRedeemDemand(), strandedRedeemDemand, "redeem demand never serviced");
        assertEq(redeemManager.getWithdrawalEventCount(), withdrawalCountBefore, "no withdrawal event created");

        // Counterfactual: with demand at zero the keeper has nothing to dispatch, so it cannot retry.
        IOperatorsRegistryV1.ExitsViaConsolidationAllocation memory noConsolidation;
        IOperatorsRegistryV1.ExitETHAllocation[] memory retry = new IOperatorsRegistryV1.ExitETHAllocation[](1);
        retry[0] = IOperatorsRegistryV1.ExitETHAllocation({operatorIndex: operatorOneIndex, ethAmount: redeemAmount});
        vm.prank(keeper);
        vm.expectRevert(IOperatorsRegistryV1.NoExitRequestsToPerform.selector);
        operatorsRegistry.requestETHExits(
            retry, new IOperatorsRegistryV1.ELExitETHAllocation[](0), noConsolidation, 0, 0
        );

        // Break glass: release the stuck reservation. The sum the redeem formula reads is unchanged; only
        // dispatchability is restored.
        (, uint256 requestedPlusDemandBefore) = operatorsRegistry.getExitedAndRequestedETHExits();
        _releaseExitRequest(operatorOneIndex, redeemAmount);
        (, uint256 requestedPlusDemandAfter) = operatorsRegistry.getExitedAndRequestedETHExits();

        assertEq(requestedPlusDemandAfter, requestedPlusDemandBefore, "release is sum-invariant");
        assertEq(operatorsRegistry.getTotalETHExitsRequested(), 0, "reservation unwound");
        assertEq(operatorsRegistry.getCurrentETHExitsDemand(), redeemAmount, "demand restored");
        assertEq(operatorsRegistry.getReleasedETHPerOperator()[operatorOneIndex], redeemAmount, "release recorded");

        // The keeper re-dispatches, and this time the consensus layer honours the request.
        _requestETHExit(operatorOneIndex, redeemAmount);
        sim_requestExit(operatorOneIndex, redeemAmount);
        sim_completeExit(operatorOneIndex, redeemAmount, 0);
        sim_oracleReport();

        assertEq(redeemManager.getRedeemDemand(), 0, "redeem demand settled after the re-dispatched exit");
        assertEq(
            redeemManager.getWithdrawalEventCount(),
            withdrawalCountBefore + 1,
            "withdrawal event created for the settled redeem"
        );
        (uint256 totalExited,) = operatorsRegistry.getExitedAndRequestedETHExits();
        assertEq(totalExited, redeemAmount, "the exit actually landed the second time");
    }
}
