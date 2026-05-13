// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "./AccountingHarnessBase.sol";
import "../../src/interfaces/components/IOracleManager.1.sol";
import "../../src/interfaces/IDepositDataBuffer.sol";
import "../../src/libraries/BLS12_381.sol";

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
        uint256 exitingETH;
        uint256 exitedETH;
    }

    // ─── simulator storage ────────────────────────────────────────────────────

    SimValidator[] internal _simValidators;

    /// @dev Cumulative skimmed ETH (monotonically increasing).
    uint256 internal _simCumulativeSkimmed;
    /// @dev Cumulative exited ETH (monotonically increasing).
    uint256 internal _simCumulativeExited;
    /// @dev Cumulative autocompounded rewards (Pectra 0x02). Increases validator CL balance
    ///      rather than being skimmed, so exits can return more than the original deposit.
    uint256 internal _simCumulativeAutocompounded;
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

    /// @dev Convenience overload — deposits `n` validators of `DEPOSIT_SIZE` each for `opIdx`.
    function sim_deposit(uint256 opIdx, uint256 n) internal {
        sim_deposit(opIdx, _amounts(n, DEPOSIT_SIZE));
    }

    function sim_deposit(uint256 opIdx, uint256[] memory amounts) internal {
        uint256 needed = 0;
        for (uint256 i = 0; i < amounts.length; i++) {
            needed += amounts[i];
        }
        if (river.getCommittedBalance() < needed) {
            _fundRiver(needed - river.getCommittedBalance());
        }
        uint256 prevInFlight = river.getInFlightDeposit();

        // Build DepositObjects for the attestation-based deposit path.
        uint256[] memory opIndices = new uint256[](amounts.length);
        for (uint256 i = 0; i < amounts.length; i++) {
            opIndices[i] = opIdx;
        }
        IDepositDataBuffer.DepositObject[] memory deposits = _makeDepositObjects(opIndices, amounts);

        bytes32 bufferId = keccak256(abi.encode(deposits));
        depositBuffer.submitDepositData(bufferId, deposits);
        bytes32 rootHash = depositContract.get_deposit_root();

        bytes[] memory sigs = new bytes[](2);
        sigs[0] = _signAttestation(ATTESTER_PK_1, bufferId, rootHash);
        sigs[1] = _signAttestation(ATTESTER_PK_2, bufferId, rootHash);

        BLS12_381.DepositY[] memory ys = new BLS12_381.DepositY[](amounts.length);
        for (uint256 i = 0; i < amounts.length; i++) {
            ys[i] = _emptyDepositY();
        }

        vm.prank(keeper);
        river.depositToConsensusLayerWithAttestation(bufferId, rootHash, sigs, ys);

        for (uint256 i = 0; i < amounts.length; i++) {
            _simValidators.push(
                SimValidator({
                    operatorIndex: opIdx,
                    depositedETH: amounts[i],
                    currentBalance: amounts[i],
                    state: ValidatorState.Pending,
                    exitingETH: 0,
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
                _simTotalDepositedActivatedETH += _simValidators[i].depositedETH;
                activated++;
            }
        }
        assertEq(activated, n, "sim_activateValidators: insufficient pending validators");
    }

    function sim_advanceEpoch(uint256 rewardsPerValidator) internal {
        for (uint256 i = 0; i < _simValidators.length; i++) {
            if (_simValidators[i].state == ValidatorState.Active) {
                // Models 0x01 (BLS) withdrawal credentials: rewards are swept (skimmed)
                // from the CL to EL each epoch. The validator's CL balance remains at the
                // principal after the sweep. See sim_autocompound for 0x02 (Pectra) behavior.
                _simCumulativeSkimmed += rewardsPerValidator;
            }
        }
    }

    /// @dev Models 0x02 (Pectra) autocompounding: rewards increase the validator's CL balance
    ///      instead of being skimmed. This means exits can return more than the original deposit.
    function sim_autocompound(uint256 rewardsPerValidator) internal {
        for (uint256 i = 0; i < _simValidators.length; i++) {
            if (_simValidators[i].state == ValidatorState.Active) {
                _simValidators[i].currentBalance += rewardsPerValidator;
                _simCumulativeAutocompounded += rewardsPerValidator;
            }
        }
    }

    function sim_requestExit(uint256 opIdx, uint256 ethAmount) internal {
        uint256 remaining = ethAmount;
        for (uint256 i = 0; i < _simValidators.length && remaining > 0; i++) {
            SimValidator storage v = _simValidators[i];
            if (v.operatorIndex != opIdx || v.state != ValidatorState.Active) continue;

            uint256 available = v.currentBalance - v.exitingETH;
            if (available == 0) continue;

            uint256 toQueue = available < remaining ? available : remaining;
            v.exitingETH += toQueue;
            remaining -= toQueue;

            if (v.exitingETH == v.currentBalance) v.state = ValidatorState.Exiting;
        }
        assertEq(remaining, 0, "sim_requestExit: insufficient active ETH");
    }

    /// @dev Completes the exit of `ethAmount` wei belonging to `opIdx`.
    ///      Handles both partial exits (active validators with exitingETH > 0) and full exits.
    ///      `penalty` is an ADDITIONAL exit-time deduction applied only to the first exiting chunk,
    ///      on top of any slash already reflected in `v.currentBalance`.
    ///      For cleanly-exiting validators, `penalty` should be 0.
    function sim_completeExit(uint256 opIdx, uint256 ethAmount, uint256 penalty) internal {
        uint256 remaining = ethAmount;
        bool penaltyApplied = false;
        for (uint256 i = 0; i < _simValidators.length && remaining > 0; i++) {
            SimValidator storage v = _simValidators[i];
            if (v.operatorIndex != opIdx || v.exitingETH == 0) continue;

            uint256 toComplete = v.exitingETH < remaining ? v.exitingETH : remaining;
            uint256 thisPenalty = (!penaltyApplied && penalty > 0) ? penalty : 0;
            if (thisPenalty > toComplete) thisPenalty = toComplete;
            penaltyApplied = penaltyApplied || thisPenalty > 0;

            uint256 actualExited = toComplete - thisPenalty;
            v.currentBalance -= toComplete;
            v.exitingETH -= toComplete;
            v.exitedETH += actualExited;
            _simCumulativeExited += actualExited;
            remaining -= toComplete;

            if (v.currentBalance == 0) v.state = ValidatorState.Exited;
        }
        assertEq(remaining, 0, "sim_completeExit: insufficient exiting ETH");
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
                if (v.exitingETH > 0) validatorsExiting += v.exitingETH;
            } else if (v.state == ValidatorState.Exiting) {
                validatorsBalance += v.currentBalance;
                validatorsExiting += v.currentBalance;
                activeCLETHArr[v.operatorIndex] += v.currentBalance;
                activatedCount++;
            } else if (v.state == ValidatorState.Exited) {
                activatedCount++;
            }
            // Cumulative exited ETH tracked per-operator across all partial and full exits
            if (v.state != ValidatorState.Pending && v.exitedETH > 0) {
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

    /// @dev Builds a simulator-consistent `ConsensusLayerReport`, stamps `epoch` to the expected
    ///      reporting epoch, funds `withdraw` with any pending skimmed/exited ETH, and warps time
    ///      to post-finality. Intended for adversarial tests that mutate the returned struct and
    ///      submit the mutated report directly via `oracle.reportConsensusLayerData(report)` with
    ///      `vm.prank(oracleMember)` + `vm.expectRevert(...)`. Does NOT submit the report itself.
    function _buildBadReport(bool rebalance, bool slashingContainment)
        internal
        virtual
        returns (IOracleManagerV1.ConsensusLayerReport memory report)
    {
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

        report = _buildReport(rebalance, slashingContainment);
        report.epoch = reportEpoch;
    }
}
