// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "./AccountingHarnessBase.sol";
import "../../src/interfaces/components/IOracleManager.1.sol";

/// @dev Beacon-chain simulator mixin for accounting tests.
///      Step functions are shells that revert; view helpers are fully implemented.
abstract contract BeaconChainSimulator is AccountingHarnessBase {
    // ─── validator state ──────────────────────────────────────────────────────

    enum ValidatorState {
        Pending,
        Active,
        Exiting,
        Exited
    }

    struct SimValidator {
        uint256 operatorIndex;
        uint256 depositedETH;
        uint256 currentBalance;
        ValidatorState state;
        uint256 exitedETH;
    }

    // ─── simulator storage ────────────────────────────────────────────────────

    SimValidator[] internal _simValidators;

    /// @dev Cumulative skimmed ETH (monotonically increasing).
    uint256 internal _simCumulativeSkimmed;
    /// @dev Cumulative exited ETH (monotonically increasing).
    uint256 internal _simCumulativeExited;
    /// @dev Mirrors the contract's InFlightDeposit: ETH sent to the deposit contract
    ///      but not yet oracle-confirmed. Incremented in sim_deposit, reset after oracle report.
    uint256 internal _simInFlightDeposit;
    /// @dev Cumulative ETH deposited on the EL deposit contract that has been activated on the CL.
    ///      Monotonically increasing — incremented in sim_activateValidators.
    uint256 internal _simTotalDepositedActivatedETH;

    uint256 internal _lastReportedSkimmed;
    uint256 internal _lastReportedExited;
    uint256 internal _lastReportEpoch;

    // ─── step functions ───────────────────────────────────────────────────────

    function sim_deposit(uint256 opIdx, uint256 n) internal {
        uint256 needed = n * DEPOSIT_SIZE;
        if (river.getCommittedBalance() < needed) {
            _fundRiver(needed - river.getCommittedBalance());
        }
        uint256 prevInFlight = river.getInFlightDeposit();
        IOperatorsRegistryV1.ValidatorDeposit[] memory allocs = _makeDeposits(opIdx, n);
        vm.prank(keeper);
        river.depositToConsensusLayerWithDepositRoot(allocs, bytes32(0));
        for (uint256 i = 0; i < n; i++) {
            _simValidators.push(
                SimValidator({
                    operatorIndex: opIdx,
                    depositedETH: DEPOSIT_SIZE,
                    currentBalance: DEPOSIT_SIZE,
                    state: ValidatorState.Pending,
                    exitedETH: 0
                })
            );
        }
        _simInFlightDeposit += needed;
        assertEq(river.getInFlightDeposit(), prevInFlight + needed, "sim_deposit: InFlightDeposit mismatch");
    }

    function sim_activateValidators(uint256 n) internal {
        uint256 activated = 0;
        for (uint256 i = 0; i < _simValidators.length && activated < n; i++) {
            if (_simValidators[i].state == ValidatorState.Pending) {
                _simValidators[i].state = ValidatorState.Active;
                activated++;
            }
        }
        assertEq(activated, n, "sim_activateValidators: insufficient pending validators");
        _simTotalDepositedActivatedETH += n * DEPOSIT_SIZE;
    }

    function sim_advanceEpoch(uint256 rewardsPerValidator) internal {
        for (uint256 i = 0; i < _simValidators.length; i++) {
            if (_simValidators[i].state == ValidatorState.Active) {
                // Rewards are swept (skimmed) from the CL to EL each epoch.
                // The validator's CL balance remains at the principal (DEPOSIT_SIZE)
                // after the sweep, so we only track cumulative skimmed rewards separately.
                _simCumulativeSkimmed += rewardsPerValidator;
            }
        }
    }

    function sim_requestExit(uint256 opIdx, uint256 ethAmount) internal {
        require(ethAmount % DEPOSIT_SIZE == 0, "sim_requestExit: must be multiple of DEPOSIT_SIZE");
        uint256 remaining = ethAmount;
        for (uint256 i = 0; i < _simValidators.length && remaining > 0; i++) {
            SimValidator storage v = _simValidators[i];
            if (v.operatorIndex == opIdx && v.state == ValidatorState.Active) {
                v.state = ValidatorState.Exiting;
                remaining -= DEPOSIT_SIZE;
            }
        }
        assertEq(remaining, 0, "sim_requestExit: insufficient active validators");
    }

    /// @dev Completes the exit of `ethAmount / DEPOSIT_SIZE` validators belonging to `opIdx`.
    ///      `penalty` is an ADDITIONAL exit-time deduction applied only to the first validator,
    ///      on top of any slash already reflected in `v.currentBalance`.
    ///      For cleanly-exiting validators, `penalty` should be 0.
    function sim_completeExit(uint256 opIdx, uint256 ethAmount, uint256 penalty) internal {
        require(ethAmount % DEPOSIT_SIZE == 0, "sim_completeExit: must be multiple of DEPOSIT_SIZE");
        uint256 toExit = ethAmount / DEPOSIT_SIZE;
        uint256 done = 0;
        for (uint256 i = 0; i < _simValidators.length && done < toExit; i++) {
            SimValidator storage v = _simValidators[i];
            if (v.operatorIndex == opIdx && v.state == ValidatorState.Exiting) {
                // currentBalance already reflects any prior slash; penalty is an additional
                // exit-time deduction (e.g. a partial withdrawal not yet swept).
                uint256 thisPenalty = (done == 0) ? penalty : 0;
                v.exitedETH = v.currentBalance - thisPenalty; // currentBalance already reflects any prior slash
                v.currentBalance = 0;
                v.state = ValidatorState.Exited;
                _simCumulativeExited += v.exitedETH;
                done++;
            }
        }
        assertEq(done, toExit, "sim_completeExit: insufficient exiting validators");
    }

    function sim_slash(uint256 opIdx, uint256 penalty) internal {
        for (uint256 i = 0; i < _simValidators.length; i++) {
            SimValidator storage v = _simValidators[i];
            if (v.operatorIndex == opIdx && v.state == ValidatorState.Active) {
                require(penalty <= v.currentBalance, "sim_slash: penalty exceeds balance");
                v.currentBalance -= penalty;
                return;
            }
        }
        revert("sim_slash: no active validator found");
    }

    /// @dev Convenience overload — delegates to the two-argument variant.
    function sim_oracleReport() internal {
        sim_oracleReport(false, false);
    }

    /// @dev Shell — overridden in AccountingInvariants which has access to snapshot/assert helpers.
    function sim_oracleReport(bool rebalance, bool slashingContainment) internal virtual;

    // ─── internal view helpers ────────────────────────────────────────────────

    /// @dev Returns the total ETH held in Pending validators.
    function _pendingETH() internal view returns (uint256 total) {
        for (uint256 i = 0; i < _simValidators.length; i++) {
            if (_simValidators[i].state == ValidatorState.Pending) {
                total += _simValidators[i].depositedETH;
            }
        }
    }

    /// @dev Returns the count of validators that have been activated (non-Pending).
    function _simActivatedCount() internal view returns (uint32 count) {
        for (uint256 i = 0; i < _simValidators.length; i++) {
            if (_simValidators[i].state != ValidatorState.Pending) {
                count++;
            }
        }
    }

    // ─── report builder ───────────────────────────────────────────────────────

    function _buildReport(bool rebalance, bool slashingContainment)
        internal
        view
        virtual
        returns (IOracleManagerV1.ConsensusLayerReport memory report)
    {
        uint256 validatorsBalance = 0;
        uint256 validatorsExiting = 0;
        uint32 activatedCount = 0;

        uint256 opCount = operatorsRegistry.getOperatorCount();
        uint256[] memory exitedArr = new uint256[](opCount + 1);
        uint256[] memory activeCLETHArr = new uint256[](opCount);
        uint256 cumulativeExited = 0;

        for (uint256 i = 0; i < _simValidators.length; i++) {
            SimValidator memory v = _simValidators[i];
            if (v.state == ValidatorState.Pending) {
                // pending validators are not yet activated; they are tracked via _simInFlightDeposit
            } else if (v.state == ValidatorState.Active) {
                validatorsBalance += v.currentBalance;
                activeCLETHArr[v.operatorIndex] += v.currentBalance;
                activatedCount++;
            } else if (v.state == ValidatorState.Exiting) {
                validatorsBalance += v.currentBalance;
                validatorsExiting += v.currentBalance;
                activeCLETHArr[v.operatorIndex] += v.currentBalance;
                activatedCount++;
            } else if (v.state == ValidatorState.Exited) {
                activatedCount++;
                exitedArr[v.operatorIndex + 1] += v.exitedETH;
                cumulativeExited += v.exitedETH;
            }
        }
        exitedArr[0] = cumulativeExited;

        report.validatorsBalance = validatorsBalance;
        report.validatorsSkimmedBalance = _simCumulativeSkimmed;
        report.validatorsExitedBalance = _simCumulativeExited;
        report.validatorsExitingBalance = validatorsExiting;
        report.totalDepositedActivatedETH = _simTotalDepositedActivatedETH;
        report.validatorsCount = activatedCount;
        report.exitedETHPerOperator = exitedArr;
        report.activeCLETHPerOperator = activeCLETHArr;
        report.rebalanceDepositToRedeemMode = rebalance;
        report.slashingContainmentMode = slashingContainment;
    }
}
