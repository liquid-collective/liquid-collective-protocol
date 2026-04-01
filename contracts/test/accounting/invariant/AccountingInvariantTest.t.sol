// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../AccountingInvariants.sol";
import "./AccountingHandler.sol";
import "../../../src/state/operatorsRegistry/Operators.3.sol";
import "../../../src/interfaces/components/IOracleManager.1.sol";

/// @title AccountingInvariantTest
/// @notice Foundry-native invariant test that targets AccountingHandler.
///         After every random handler call, Foundry checks all invariant_ functions.
contract AccountingInvariantTest is AccountingInvariants {
    AccountingHandler internal handler;

    // ─── ghost state for monotonicity invariants (I14-I17) ──────────────────────

    uint256 internal ghost_lastSkimmedBalance;
    uint256 internal ghost_lastExitedBalance;
    uint256[] internal ghost_lastExitedPerOp;

    /// @notice Initialises the base harness, deploys the `AccountingHandler`, and registers it
    ///         as the sole Foundry invariant target so the fuzzer calls only its bounded functions.
    function setUp() public override {
        // Step 1: Run the base harness setup (deploys river, oracle, operators registry, etc.).
        super.setUp();
        // Step 2: Deploy the handler, wiring it back to this contract for action delegation.
        handler = new AccountingHandler(IAccountingActions(address(this)));
        // Step 3: Register the handler as the only fuzzer target contract.
        targetContract(address(handler));
    }

    // ─── external wrappers (called by handler) ──────────────────────────────────

    /// @notice Delegates a deposit action from the handler to the simulator.
    /// @param opIdx  Operator index to deposit validators for.
    /// @param n      Number of validators to deposit.
    function handler_deposit(uint256 opIdx, uint256 n) external {
        sim_deposit(opIdx, n);
    }

    /// @notice Delegates a validator activation from the handler to the simulator.
    /// @param n  Number of pending validators to activate.
    function handler_activateValidators(uint256 n) external {
        sim_activateValidators(n);
    }

    /// @notice Delegates an epoch advancement (with optional rewards) from the handler to the simulator.
    /// @param rewardsPerValidator  Per-validator reward amount in wei to sweep this epoch.
    function handler_advanceEpoch(uint256 rewardsPerValidator) external {
        sim_advanceEpoch(rewardsPerValidator);
    }

    /// @notice Delegates a validator exit request from the handler to the simulator.
    /// @param opIdx      Operator index whose active validators should be marked as Exiting.
    /// @param ethAmount  Total ETH to exit (must be a multiple of DEPOSIT_SIZE).
    function handler_requestExit(uint256 opIdx, uint256 ethAmount) external {
        sim_requestExit(opIdx, ethAmount);
    }

    /// @notice Delegates a validator exit completion from the handler to the simulator.
    /// @param opIdx      Operator index whose Exiting validators should be marked as Exited.
    /// @param ethAmount  Total ETH being returned (must be a multiple of DEPOSIT_SIZE).
    /// @param penalty    Exit-time penalty in wei applied to the first exiting validator.
    function handler_completeExit(uint256 opIdx, uint256 ethAmount, uint256 penalty) external {
        sim_completeExit(opIdx, ethAmount, penalty);
    }

    /// @notice Delegates a slash event from the handler to the simulator.
    ///         Enables share price decrease before slashing so the invariant checker does not
    ///         reject the expected balance reduction.
    /// @param opIdx    Operator index whose first active validator will be slashed.
    /// @param penalty  ETH penalty to deduct from the validator's current balance.
    function handler_slash(uint256 opIdx, uint256 penalty) external {
        _setAllowSharePriceDecrease(true);
        sim_slash(opIdx, penalty);
    }

    /// @notice Delegates an oracle report from the handler to the simulator.
    ///         Enables share price decrease when slashing-containment mode is active, then
    ///         snapshots the post-report state for monotonicity invariants (I15–I17).
    /// @param rebalance            Whether to submit the report in rebalancing mode.
    /// @param slashingContainment  Whether to submit the report in slashing-containment mode.
    function handler_oracleReport(bool rebalance, bool slashingContainment) external {
        if (slashingContainment) {
            _setAllowSharePriceDecrease(true);
        }
        sim_oracleReport(rebalance, slashingContainment);
        _setAllowSharePriceDecrease(false);
        // Snapshot post-report state for monotonicity invariants (I14-I17)
        IOracleManagerV1.StoredConsensusLayerReport memory report = river.getLastConsensusLayerReport();
        ghost_lastSkimmedBalance = report.validatorsSkimmedBalance;
        ghost_lastExitedBalance = report.validatorsExitedBalance;
        ghost_lastExitedPerOp = operatorsRegistry.getExitedETHPerOperator();
    }

    // ─── state readers (called by handler for precondition guards) ───────────────

    /// @notice Returns the number of simulated validators currently in the Pending state.
    ///         Used by the handler to guard `activateValidators` calls (skip if none are pending).
    function handler_pendingCount() external view returns (uint256 count) {
        for (uint256 i = 0; i < _simValidators.length; i++) {
            if (_simValidators[i].state == ValidatorState.Pending) count++;
        }
    }

    /// @notice Returns the number of Active simulated validators belonging to `opIdx`.
    ///         Used by the handler to guard `requestExit` calls (skip if none are active).
    /// @param opIdx  Operator index to count active validators for.
    function handler_activeCount(uint256 opIdx) external view returns (uint256 count) {
        for (uint256 i = 0; i < _simValidators.length; i++) {
            if (_simValidators[i].operatorIndex == opIdx && _simValidators[i].state == ValidatorState.Active) {
                count++;
            }
        }
    }

    /// @notice Returns the number of Exiting simulated validators belonging to `opIdx`.
    ///         Used by the handler to guard `completeExit` calls (skip if none are exiting).
    /// @param opIdx  Operator index to count exiting validators for.
    function handler_exitingCount(uint256 opIdx) external view returns (uint256 count) {
        for (uint256 i = 0; i < _simValidators.length; i++) {
            if (_simValidators[i].operatorIndex == opIdx && _simValidators[i].state == ValidatorState.Exiting) {
                count++;
            }
        }
    }

    /// @notice Resolves a zero-indexed selector to the corresponding operator's registry index.
    ///         Returns `operatorOneIndex` for `which == 0`, `operatorTwoIndex` otherwise.
    /// @param which  0 for operator one, any other value for operator two.
    function handler_operatorIndex(uint256 which) external view returns (uint256) {
        return which == 0 ? operatorOneIndex : operatorTwoIndex;
    }

    // ═════════════════════════════════════════════════════════════════════════════
    // INVARIANTS — checked by Foundry after every handler call
    // ═════════════════════════════════════════════════════════════════════════════

    // ─── Existing invariants (I1-I6) adapted for continuous checking ─────────────

    /// @dev I2: ETH conservation — totalUnderlying never exceeds user deposits + rewards.
    function invariant_I2_ethConservation() public {
        if (_simTotalUserDeposited == 0) return;
        uint256 upperBound = _simTotalUserDeposited + _simCumulativeSkimmed;
        assertLe(river.totalUnderlyingSupply(), upperBound, "I2: total underlying exceeds deposited + rewards");
        assertGt(river.totalUnderlyingSupply(), 0, "I2: total underlying is zero after deposits");
    }

    /// @dev I3: InFlightDeposit consistency — contract value matches simulator tracking.
    function invariant_I3_inFlightConsistency() public {
        assertEq(river.getInFlightDeposit(), _simInFlightDeposit, "I3: InFlightDeposit != sim in-flight");
    }

    /// @dev I5: TotalDepositedETH is monotonically non-decreasing.
    ///      We check it never falls below what we've ever deposited via sim_deposit.
    function invariant_I5_totalDepositedETHMonotonic() public {
        uint256 totalSimDeposited = 0;
        for (uint256 i = 0; i < _simValidators.length; i++) {
            totalSimDeposited += _simValidators[i].depositedETH;
        }
        assertGe(river.getTotalDepositedETH(), totalSimDeposited, "I5: TotalDepositedETH < sim total deposited");
    }

    /// @dev I6: ExitedETH aggregate — sum of per-operator exited == reported total.
    function invariant_I6_exitedETHAggregate() public {
        (uint256 totalExited,) = operatorsRegistry.getExitedETHAndRequestedExitAmounts();
        uint256[] memory perOp = operatorsRegistry.getExitedETHPerOperator();
        uint256 sum = 0;
        for (uint256 i = 0; i < perOp.length; i++) {
            sum += perOp[i];
        }
        assertEq(totalExited, sum, "I6: exitedETHPerOperator aggregate mismatch");
    }

    // ─── New invariants (I7-I12) ────────────────────────────────────────────────

    /// @dev I7: Asset balance decomposition — totalUnderlying >= EL components.
    ///      The difference is storedReport.validatorsBalance which must be >= 0.
    function invariant_I7_assetBalanceDecomposition() public {
        uint256 elComponents = river.getCommittedBalance() + river.getBalanceToDeposit() + river.getBalanceToRedeem()
            + river.getInFlightDeposit();
        assertGe(
            river.totalUnderlyingSupply(),
            elComponents,
            "I7: totalUnderlying < EL components (negative validatorsBalance)"
        );
    }

    /// @dev I8: TotalDepositedETH == sum of per-operator funded ETH.
    function invariant_I8_totalDepositedETHConsistency() public {
        uint256 totalDeposited = river.getTotalDepositedETH();
        uint256 opCount = operatorsRegistry.getOperatorCount();
        uint256 sumFunded = 0;
        for (uint256 i = 0; i < opCount; i++) {
            OperatorsV3.Operator memory op = operatorsRegistry.getOperator(i);
            sumFunded += op.funded;
        }
        assertEq(totalDeposited, sumFunded, "I8: TotalDepositedETH != sum of per-operator funded");
    }

    /// @dev I9: InFlightDeposit bounded by TotalDepositedETH.
    function invariant_I9_inFlightBoundedByDeposited() public {
        assertLe(river.getInFlightDeposit(), river.getTotalDepositedETH(), "I9: InFlightDeposit > TotalDepositedETH");
    }

    /// @dev I10: EL solvency — River's ETH balance covers tracked EL amounts.
    function invariant_I10_elSolvency() public {
        uint256 required = river.getBalanceToDeposit() + river.getCommittedBalance() + river.getBalanceToRedeem();
        assertGe(address(river).balance, required, "I10: River balance < BalanceToDeposit + Committed + Redeem");
    }

    /// @dev I11: Shares-underlying bidirectional consistency.
    function invariant_I11_sharesUnderlyingConsistency() public {
        if (river.totalSupply() > 0) {
            assertGt(river.totalUnderlyingSupply(), 0, "I11: totalUnderlying is 0 but totalSupply > 0");
        }
        if (river.totalUnderlyingSupply() > 0) {
            assertGt(river.totalSupply(), 0, "I11: totalSupply is 0 but totalUnderlying > 0");
        }
    }

    /// @dev I12: Cumulative exited ETH never exceeds TotalDepositedETH.
    function invariant_I12_exitedBoundedByDeposited() public {
        (uint256 totalExited,) = operatorsRegistry.getExitedETHAndRequestedExitAmounts();
        assertLe(totalExited, river.getTotalDepositedETH(), "I12: total exited > TotalDepositedETH");
    }

    // ─── New invariants (I14-I20) ──────────────────────────────────────────────
    // Note: I13 (CommittedBalance alignment) was removed — the test harness's
    // debug_moveDepositToCommitted() bypasses the protocol's 32-ETH alignment
    // logic, making the invariant invalid in this context.

    /// @dev I15: Stored report validatorsSkimmedBalance never decreases (cumulative accumulator).
    function invariant_I15_skimmedBalanceNonDecreasing() public {
        IOracleManagerV1.StoredConsensusLayerReport memory report = river.getLastConsensusLayerReport();
        assertGe(report.validatorsSkimmedBalance, ghost_lastSkimmedBalance, "I15: validatorsSkimmedBalance decreased");
    }

    /// @dev I16: Stored report validatorsExitedBalance never decreases (cumulative accumulator).
    function invariant_I16_exitedBalanceNonDecreasing() public {
        IOracleManagerV1.StoredConsensusLayerReport memory report = river.getLastConsensusLayerReport();
        assertGe(report.validatorsExitedBalance, ghost_lastExitedBalance, "I16: validatorsExitedBalance decreased");
    }

    /// @dev I17: Per-operator exited ETH values never decrease across reports.
    function invariant_I17_perOperatorExitedNonDecreasing() public {
        uint256[] memory perOp = operatorsRegistry.getExitedETHPerOperator();
        for (uint256 i = 0; i < ghost_lastExitedPerOp.length && i < perOp.length; i++) {
            assertGe(perOp[i], ghost_lastExitedPerOp[i], "I17: per-operator exitedETH decreased");
        }
    }

    /// @dev I18: Per-operator requestedExits <= funded and exited <= funded (continuous check).
    function invariant_I18_exitRequestsBounded() public {
        uint256 opCount = operatorsRegistry.getOperatorCount();
        uint256[] memory perOp = operatorsRegistry.getExitedETHPerOperator();
        for (uint256 i = 0; i < opCount; i++) {
            OperatorsV3.Operator memory op = operatorsRegistry.getOperator(i);
            uint256 exited = (i < perOp.length) ? perOp[i] : 0;
            assertLe(op.requestedExits, op.funded, "I18: requestedExits > funded");
            assertLe(exited, op.funded, "I18: exited > funded");
        }
    }

    /// @dev I19: On-chain CLValidatorCount never exceeds total sim validators created.
    function invariant_I19_clValidatorCountBounded() public {
        uint256 onChainCount = river.getCLValidatorCount();
        assertLe(onChainCount, _simValidators.length, "I19: CLValidatorCount exceeds total validators created");
    }

    /// @dev I20: TotalDepositedETH exactly equals sum of all sim validator deposits.
    function invariant_I20_totalDepositedETHExactMatch() public {
        uint256 simSum = 0;
        for (uint256 i = 0; i < _simValidators.length; i++) {
            simSum += _simValidators[i].depositedETH;
        }
        assertEq(river.getTotalDepositedETH(), simSum, "I20: TotalDepositedETH != exact sim sum");
    }
}
