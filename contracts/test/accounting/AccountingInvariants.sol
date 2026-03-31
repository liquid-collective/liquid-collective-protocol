// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "./BeaconChainSimulator.sol";
import "../../src/state/operatorsRegistry/Operators.3.sol";

abstract contract AccountingInvariants is BeaconChainSimulator {
    uint256 private _snapTotalUnderlying;
    uint256 private _snapTotalShares;
    uint256 private _snapTotalDepositedETH;
    bool private _allowSharePriceDecrease;

    // ─── sim_oracleReport implementation ─────────────────────────────────────

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

    function _setAllowSharePriceDecrease(bool allow) internal {
        _allowSharePriceDecrease = allow;
    }

    function _assertAllInvariants() internal {
        _assertI1_SharePriceNonDecrease();
        _assertI2_ETHConservation();
        _assertI3_InFlightConsistency();
        _assertI4_PerOperatorETH();
        _assertI5_TotalDepositedETHMonotonic();
        _assertI6_ExitedETHAggregate();
    }

    function _assertI1_SharePriceNonDecrease() internal {
        if (_allowSharePriceDecrease) return;
        uint256 sharesTotalNow = river.totalSupply();
        if (sharesTotalNow == 0 || _snapTotalShares == 0) return;
        uint256 lhs = river.totalUnderlyingSupply() * _snapTotalShares;
        uint256 rhs = _snapTotalUnderlying * sharesTotalNow;
        assertGe(lhs, rhs, "I1: share price decreased unexpectedly");
    }

    function _assertI2_ETHConservation() internal {
        // totalUnderlyingSupply must never exceed total user deposits + total skimmed rewards.
        // These values are tracked independently of contract storage, so this is a non-tautological check.
        uint256 upperBound = _simTotalUserDeposited + _simCumulativeSkimmed;
        assertLe(river.totalUnderlyingSupply(), upperBound, "I2: total underlying exceeds deposited + rewards");
        // Also: must be > 0 if any user deposited
        if (_simTotalUserDeposited > 0) {
            assertGt(river.totalUnderlyingSupply(), 0, "I2: total underlying is zero after deposits");
        }
    }

    function _assertI3_InFlightConsistency() internal pure {
        // I3 is now checked in _snapshotPreReport() (before the oracle report),
        // where it is meaningful. Post-report it would be a tautology since the
        // oracle just set InFlightDeposit = report.inFlightETH = _pendingETH().
    }

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
                    if (_simValidators[j].state == ValidatorState.Exited) {
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

    function _assertI5_TotalDepositedETHMonotonic() internal {
        assertGe(river.getTotalDepositedETH(), _snapTotalDepositedETH, "I5: TotalDepositedETH decreased");
    }

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
