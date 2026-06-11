// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "./BeaconChainSimulator.sol";
import "../../src/state/operatorsRegistry/Operators.3.sol";
import "../../src/state/river/ReportBounds.sol";

abstract contract AccountingInvariants is BeaconChainSimulator {
    uint256 private _snapTotalUnderlying;
    uint256 private _snapTotalShares;
    uint256 private _snapTotalDepositedETH;
    bool private _allowSharePriceDecrease;

    /// @dev Snapshot of ReportBounds captured by `_pushRelaxedLowerBound`, restored by `_popBounds`.
    struct BoundsSnapshot {
        uint256 aprUpper;
        uint256 relLower;
    }

    /// @notice Widens `relativeLowerBound` to `relLowerBps` and disables the I1 share-price guard.
    ///         Returns the prior bounds so callers can restore them exactly via `_popBounds`.
    ///         Always paired with `_popBounds` so the I1 disable is scoped to a single report.
    function _pushRelaxedLowerBound(uint256 relLowerBps) internal returns (BoundsSnapshot memory snap) {
        ReportBounds.ReportBoundsStruct memory cur = river.getReportBounds();
        snap = BoundsSnapshot({aprUpper: cur.annualAprUpperBound, relLower: cur.relativeLowerBound});
        vm.prank(admin);
        river.setReportBounds(
            ReportBounds.ReportBoundsStruct({
                annualAprUpperBound: cur.annualAprUpperBound, relativeLowerBound: relLowerBps
            })
        );
        _setAllowSharePriceDecrease(true);
    }

    /// @notice Restores the ReportBounds captured by `_pushRelaxedLowerBound` and re-enables the I1 guard.
    function _popBounds(BoundsSnapshot memory snap) internal {
        _setAllowSharePriceDecrease(false);
        vm.prank(admin);
        river.setReportBounds(
            ReportBounds.ReportBoundsStruct({annualAprUpperBound: snap.aprUpper, relativeLowerBound: snap.relLower})
        );
    }

    // ─── sim_oracleReport implementation ─────────────────────────────────────

    /// @notice Implements the oracle report step: warps time to the required finality epoch,
    ///         funds the withdrawal contract with newly skimmed/exited ETH, builds the CL report,
    ///         snapshots pre-report state, submits the report as the oracle member, and then
    ///         asserts all six accounting invariants (I1–I6).
    /// @param rebalance            Whether to request deposit-to-redeem rebalancing mode.
    /// @param slashingContainment  Whether to submit the report in slashing-containment mode.
    function sim_oracleReport(bool rebalance, bool slashingContainment) internal virtual override {
        uint256 reportEpoch = river.getExpectedEpochId();
        uint256 targetTime = (SECONDS_PER_SLOT * SLOTS_PER_EPOCH) * (reportEpoch + EPOCHS_UNTIL_FINAL) + 1;
        if (block.timestamp < targetTime) {
            vm.warp(targetTime);
        }

        uint256 newSkimmed = _simCumulativeSkimmed - _lastReportedSkimmed;
        uint256 newExited = _simCumulativeExited - _lastReportedExited;
        if (newSkimmed + newExited > 0) {
            vm.deal(address(withdraw), address(withdraw).balance + newSkimmed + newExited);
        }

        IOracleManagerV1.ConsensusLayerReport memory report = _buildReport(rebalance, slashingContainment);
        report.epoch = reportEpoch;

        _snapshotPreReport();

        vm.prank(oracleMember);
        oracle.reportConsensusLayerData(report);

        _lastReportedSkimmed = _simCumulativeSkimmed;
        _lastReportedExited = _simCumulativeExited;
        _lastReportEpoch = reportEpoch;
        // Sync sim in-flight to what the oracle just confirmed: oracle sets InFlightDeposit = _pendingETH().
        _simInFlightDeposit = _pendingETH();

        _assertAllInvariants();
    }

    // ─── snapshot / invariant helpers ────────────────────────────────────────

    /// @notice Captures a pre-report snapshot of `totalUnderlyingSupply`, `totalSupply`,
    ///         and `getTotalDepositedETH`, and also checks invariant I3 at this point
    ///         (pre-report InFlightDeposit must match the simulator's independently tracked value).
    function _snapshotPreReport() internal {
        // I3 (pre-report): the contract's InFlightDeposit must equal the sim's independently-tracked
        // in-flight value (_simInFlightDeposit), which mirrors what the contract should hold:
        // cumulative ETH sent to the deposit contract minus what the oracle has already confirmed.
        assertEq(
            river.getInFlightDeposit(), _simInFlightDeposit, "I3 (pre-report): InFlightDeposit != sim in-flight deposit"
        );

        _snapTotalUnderlying = river.totalUnderlyingSupply();
        _snapTotalShares = river.totalSupply();
        _snapTotalDepositedETH = river.getTotalDepositedETH();
    }

    /// @notice Toggles the flag that permits a share price decrease in the next invariant check.
    ///         Must be set to `true` before oracle reports that include a slash or containment
    ///         penalty, and reset to `false` immediately after to restore the default guard.
    /// @param allow  `true` to allow a share price decrease; `false` to re-enable the guard.
    function _setAllowSharePriceDecrease(bool allow) internal {
        _allowSharePriceDecrease = allow;
    }

    /// @notice Executes all six post-report invariant assertions (I1–I6) in sequence.
    function _assertAllInvariants() internal {
        _assertI1_SharePriceNonDecrease();
        _assertI2_ETHConservation();
        _assertI3_InFlightConsistency();
        _assertI4_PerOperatorETH();
        _assertI5_TotalDepositedETHMonotonic();
        _assertI6_ExitedETHAggregate();
    }

    /// @notice I1: Verifies that the share price has not decreased since the pre-report snapshot.
    ///         Computes `totalUnderlying_now × shares_snap >= totalUnderlying_snap × shares_now`
    ///         (cross-multiplication avoids division precision loss). Skipped when
    ///         `_allowSharePriceDecrease` is set (slashing / containment scenarios).
    function _assertI1_SharePriceNonDecrease() internal {
        if (_allowSharePriceDecrease) return;
        uint256 sharesTotalNow = river.totalSupply();
        if (sharesTotalNow == 0 || _snapTotalShares == 0) return;
        uint256 lhs = river.totalUnderlyingSupply() * _snapTotalShares;
        uint256 rhs = _snapTotalUnderlying * sharesTotalNow;
        assertGe(lhs, rhs, "I1: share price decreased unexpectedly");
    }

    /// @notice I2: Verifies ETH conservation — `totalUnderlyingSupply` must never exceed
    ///         total user deposits plus cumulative skimmed rewards plus autocompounded rewards.
    ///         All values are tracked independently of contract storage, making this a
    ///         non-tautological check. Also asserts non-zero whenever deposits have been made.
    function _assertI2_ETHConservation() internal {
        uint256 upperBound = _simTotalUserDeposited + _simCumulativeSkimmed + _simCumulativeAutocompounded;
        assertLe(river.totalUnderlyingSupply(), upperBound, "I2: total underlying exceeds deposited + rewards");
        // Also: must be > 0 if any user deposited
        if (_simTotalUserDeposited > 0) {
            assertGt(river.totalUnderlyingSupply(), 0, "I2: total underlying is zero after deposits");
        }
    }

    /// @notice I3: In-flight deposit consistency check.
    ///         The substantive check is performed in `_snapshotPreReport` (before the oracle
    ///         report), where it is non-tautological. Post-report it would be a tautology since
    ///         the oracle just decremented `InFlightDeposit` by `report.totalDepositedActivatedETH` increase.
    function _assertI3_InFlightConsistency() internal pure {
        // I3 is now checked in _snapshotPreReport() (before the oracle report),
        // where it is meaningful. Post-report it would be a tautology since the
        // oracle just decremented InFlightDeposit by the totalDepositedActivatedETH increase.
    }

    /// @notice I4: Verifies per-operator ETH consistency — for each operator, the on-chain
    ///         `funded` ETH must equal the simulator's sum of deposited ETH, and the on-chain
    ///         `exitedETHPerOperator` must match the simulator's sum of exited ETH. Also asserts
    ///         that `exited <= funded` and `requestedExits <= funded` for every operator.
    function _assertI4_PerOperatorETH() internal {
        uint256 opCount = operatorsRegistry.getOperatorCount();
        uint256[] memory exitedPerOp = operatorsRegistry.getExitedETHPerOperator();

        for (uint256 i = 0; i < opCount; i++) {
            OperatorsV3.Operator memory op = operatorsRegistry.getOperator(i);

            uint256 simFunded = 0;
            uint256 simExited = 0;
            for (uint256 j = 0; j < _simValidators.length; j++) {
                if (_simValidators[j].operatorIndex == i) {
                    simFunded += _simValidators[j].depositedETH;
                    // Include exitedETH from all non-pending validators: Active validators can
                    // carry exitedETH from partial exits, which _buildReport also reports on-chain.
                    if (_simValidators[j].state != ValidatorState.Pending) {
                        simExited += _simValidators[j].exitedETH;
                    }
                }
            }

            assertEq(op.funded, simFunded, string(abi.encodePacked("I4: op", vm.toString(i), " funded mismatch")));
            uint256 onChainExited = exitedPerOp.length > i ? exitedPerOp[i] : 0;
            assertLe(onChainExited, op.funded, string(abi.encodePacked("I4: op", vm.toString(i), " exited > funded")));
            assertEq(onChainExited, simExited, string(abi.encodePacked("I4: op", vm.toString(i), " exited mismatch")));
            assertLe(
                op.requestedExits,
                op.funded,
                string(abi.encodePacked("I4: op", vm.toString(i), " requestedExits > funded"))
            );
        }
    }

    /// @notice I5: Verifies that `getTotalDepositedETH` is monotonically non-decreasing.
    ///         Compares the current value against the pre-report snapshot captured by `_snapshotPreReport`.
    function _assertI5_TotalDepositedETHMonotonic() internal {
        assertGe(river.getTotalDepositedETH(), _snapTotalDepositedETH, "I5: TotalDepositedETH decreased");
    }

    /// @notice I6: Verifies that the aggregate exited ETH returned by `getExitedETHAndRequestedExitAmounts`
    ///         equals the sum of all per-operator exited ETH values from `getExitedETHPerOperator`.
    function _assertI6_ExitedETHAggregate() internal {
        (uint256 totalExited,) = operatorsRegistry.getExitedETHAndRequestedExitAmounts();
        uint256[] memory perOp = operatorsRegistry.getExitedETHPerOperator();
        uint256 sum = 0;
        for (uint256 i = 0; i < perOp.length; i++) {
            sum += perOp[i];
        }
        assertEq(totalExited, sum, "I6: exitedETHPerOperator aggregate mismatch");
    }
}
