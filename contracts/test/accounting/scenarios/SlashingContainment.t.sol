// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../AccountingInvariants.sol";

contract SlashingContainmentTest is AccountingInvariants {
    /// @notice Verifies that a slashing event followed by an oracle report in slashing-containment
    ///         mode reduces `totalUnderlyingSupply` by the exact simulated penalty.
    ///         The share price is allowed to decrease during this test to reflect the penalty.
    function testSlashingContainmentModeActive() public {
        // Step 1: Fund river with enough ETH for 4 validators and deposit them for operator one.
        _fundRiver(4 * DEPOSIT_SIZE);
        sim_deposit(operatorOneIndex, _amounts(4, DEPOSIT_SIZE));
        // Step 2: Activate all 4 validators and submit the initial oracle report.
        sim_activateValidators(4);
        sim_oracleReport();
        uint256 underlyingBefore = river.totalUnderlyingSupply();
        // Step 3: Apply a 4 ETH slash penalty to an active validator of operator one.
        sim_slash(operatorOneIndex, 4 ether);
        // Step 4: Submit an oracle report in slashing-containment mode (slashingContainment=true),
        //         permitting a share price decrease to absorb the slash.
        _setAllowSharePriceDecrease(true);
        sim_oracleReport(false, true);
        _setAllowSharePriceDecrease(false);
        // Step 5: Assert the exact loss and persisted containment mode.
        assertEq(river.totalUnderlyingSupply(), underlyingBefore - 4 ether, "slash applied exactly");
        assertTrue(river.getLastConsensusLayerReport().slashingContainmentMode, "containment mode persisted");
    }

    /// @notice Verifies that SkippedCommitToDepositDueToSlashingContainment is emitted when
    ///         balance commitment to deposit is suppressed due to slashing containment mode.
    function testEmitsSkippedCommitToDepositEventDuringContainment() public {
        // Step 1: Fund river with enough ETH for 4 validators and deposit them for operator one.
        _fundRiver(4 * DEPOSIT_SIZE);
        sim_deposit(operatorOneIndex, _amounts(4, DEPOSIT_SIZE));
        // Step 2: Activate all 4 validators and submit the initial oracle report.
        sim_activateValidators(4);
        sim_oracleReport();

        address depositor = makeAddr("containmentCommitDepositor");
        _allowUser(depositor);
        _simTotalUserDeposited += DEPOSIT_SIZE;
        vm.deal(depositor, DEPOSIT_SIZE);
        vm.prank(depositor);
        river.deposit{value: DEPOSIT_SIZE}();
        uint256 depositBefore = river.getBalanceToDeposit();
        uint256 committedBefore = river.getCommittedBalance();

        // Apply a slash and prove an otherwise committable deposit remains untouched.
        sim_slash(operatorOneIndex, 4 ether);
        vm.expectEmit(false, false, false, false, address(river));
        emit IRiverV1.SkippedCommitToDepositDueToSlashingContainment();
        _setAllowSharePriceDecrease(true);
        sim_oracleReport(false, true);
        _setAllowSharePriceDecrease(false);
        assertEq(river.getBalanceToDeposit(), depositBefore, "containment must preserve deposit buffer");
        assertEq(river.getCommittedBalance(), committedBefore, "containment must suppress commitment");
    }

    /// @notice Verifies that SkippedExitRequestsDueToSlashingContainment is emitted when
    ///         exit request processing is suppressed due to slashing containment mode.
    function testEmitsSkippedExitRequestsEventDuringContainment() public {
        // Step 1: Fund river with enough ETH for 4 validators and deposit them for operator one.
        address redeemer = makeAddr("redeemer");
        _allowUser(redeemer);
        _simTotalUserDeposited += 4 * DEPOSIT_SIZE;
        vm.deal(redeemer, 4 * DEPOSIT_SIZE);
        vm.prank(redeemer);
        river.deposit{value: 4 * DEPOSIT_SIZE}();
        river.debug_moveDepositToCommitted();
        sim_deposit(operatorOneIndex, _amounts(4, DEPOSIT_SIZE));
        // Step 2: Activate all 4 validators and submit the initial oracle report.
        sim_activateValidators(4);
        sim_oracleReport();
        // Step 3: Create redeem demand that would normally trigger exit-request processing.
        sim_requestRedeem(redeemer, DEPOSIT_SIZE);
        // Step 4: Apply a 4 ETH slash penalty to operator one.
        sim_slash(operatorOneIndex, 4 ether);
        // Step 5: Expect exit request processing to be skipped when reporting in containment mode.
        vm.recordLogs();
        _setAllowSharePriceDecrease(true);
        sim_oracleReport(false, true);
        _setAllowSharePriceDecrease(false);

        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 skippedExitRequestsEvent = keccak256("SkippedExitRequestsDueToSlashingContainment()");
        bool found;
        for (uint256 i = 0; i < entries.length; i++) {
            if (entries[i].emitter == address(river) && entries[i].topics[0] == skippedExitRequestsEvent) {
                found = true;
                break;
            }
        }
        assertTrue(found, "skipped exit requests event");
    }

    /// @notice Verifies that SkippedExitRequestsDueToSlashingContainment is emitted when
    ///         deposit-to-redeem rebalancing is suppressed due to slashing containment mode.
    function testEmitsSkippedExitRequestsEventWhenRebalancingIsSkippedDuringContainment() public {
        // Step 1: Fund river with enough ETH for 4 validators and deposit them for operator one.
        _fundRiver(4 * DEPOSIT_SIZE);
        sim_deposit(operatorOneIndex, _amounts(4, DEPOSIT_SIZE));
        // Step 2: Activate all 4 validators and submit the initial oracle report.
        sim_activateValidators(4);
        sim_oracleReport();
        // Step 3: Leave ETH in the deposit buffer and create redeem demand that rebalancing could cover.
        address redeemer = makeAddr("rebalancingRedeemer");
        _allowUser(redeemer);
        _simTotalUserDeposited += DEPOSIT_SIZE;
        vm.deal(redeemer, DEPOSIT_SIZE);
        vm.prank(redeemer);
        river.deposit{value: DEPOSIT_SIZE}();
        sim_requestRedeem(redeemer, DEPOSIT_SIZE);
        assertEq(river.getBalanceToDeposit(), DEPOSIT_SIZE, "deposit buffer before report");
        assertEq(river.getBalanceToRedeem(), 0, "redeem buffer before report");
        // Step 4: Apply a slash and report with both rebalancing and containment enabled.
        sim_slash(operatorOneIndex, 4 ether);
        vm.recordLogs();
        _setAllowSharePriceDecrease(true);
        sim_oracleReport(true, true);
        _setAllowSharePriceDecrease(false);

        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 skippedExitRequestsEvent = keccak256("SkippedExitRequestsDueToSlashingContainment()");
        bool found;
        for (uint256 i = 0; i < entries.length; i++) {
            if (entries[i].emitter == address(river) && entries[i].topics[0] == skippedExitRequestsEvent) {
                found = true;
                break;
            }
        }
        assertTrue(found, "skipped rebalancing event");
        assertEq(river.getBalanceToDeposit(), DEPOSIT_SIZE, "deposit buffer after report");
        assertEq(river.getBalanceToRedeem(), 0, "redeem buffer after report");
    }

    /// @notice Verifies that the protocol can resume normal oracle reporting after a slashing-
    ///         containment episode. Ensures all accounting invariants hold across the full
    ///         sequence: normal report → slash → containment report → normal report.
    function testContainmentEndAndResume() public {
        // Step 1: Fund river with enough ETH for 4 validators and deposit them for operator one.
        _fundRiver(4 * DEPOSIT_SIZE);
        sim_deposit(operatorOneIndex, _amounts(4, DEPOSIT_SIZE));
        // Step 2: Activate all 4 validators and submit the initial oracle report.
        sim_activateValidators(4);
        sim_oracleReport();

        address depositor = makeAddr("resumeDepositor");
        _allowUser(depositor);
        _simTotalUserDeposited += DEPOSIT_SIZE;
        vm.deal(depositor, DEPOSIT_SIZE);
        vm.prank(depositor);
        river.deposit{value: DEPOSIT_SIZE}();
        uint256 depositBefore = river.getBalanceToDeposit();
        uint256 committedBefore = river.getCommittedBalance();

        sim_slash(operatorOneIndex, 2 ether);
        _setAllowSharePriceDecrease(true);
        sim_oracleReport(false, true);
        _setAllowSharePriceDecrease(false);
        assertEq(river.getBalanceToDeposit(), depositBefore, "containment must defer commitment");
        assertEq(river.getCommittedBalance(), committedBefore, "nothing committed during containment");

        // A normal report must resume the previously suppressed commitment path.
        sim_oracleReport(false, false);
        assertLt(river.getBalanceToDeposit(), depositBefore, "normal reporting consumes deposit buffer");
        assertGt(river.getCommittedBalance(), committedBefore, "normal reporting resumes commitment");
    }
}
