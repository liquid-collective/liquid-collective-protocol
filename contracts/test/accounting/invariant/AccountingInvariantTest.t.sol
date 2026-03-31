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

    function setUp() public override {
        super.setUp();
        handler = new AccountingHandler(IAccountingActions(address(this)));
        targetContract(address(handler));
    }

    // ─── external wrappers (called by handler) ──────────────────────────────────

    function handler_deposit(uint256 opIdx, uint256 n) external {
        sim_deposit(opIdx, n);
    }

    function handler_activateValidators(uint256 n) external {
        sim_activateValidators(n);
    }

    function handler_advanceEpoch(uint256 rewardsPerValidator) external {
        sim_advanceEpoch(rewardsPerValidator);
    }

    function handler_requestExit(uint256 opIdx, uint256 ethAmount) external {
        sim_requestExit(opIdx, ethAmount);
    }

    function handler_completeExit(uint256 opIdx, uint256 ethAmount, uint256 penalty) external {
        sim_completeExit(opIdx, ethAmount, penalty);
    }

    function handler_slash(uint256 opIdx, uint256 penalty) external {
        _setAllowSharePriceDecrease(true);
        sim_slash(opIdx, penalty);
    }

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

    function handler_pendingCount() external view returns (uint256 count) {
        for (uint256 i = 0; i < _simValidators.length; i++) {
            if (_simValidators[i].state == ValidatorState.Pending) count++;
        }
    }

    function handler_activeCount(uint256 opIdx) external view returns (uint256 count) {
        for (uint256 i = 0; i < _simValidators.length; i++) {
            if (_simValidators[i].operatorIndex == opIdx && _simValidators[i].state == ValidatorState.Active) {
                count++;
            }
        }
    }

    function handler_exitingCount(uint256 opIdx) external view returns (uint256 count) {
        for (uint256 i = 0; i < _simValidators.length; i++) {
            if (_simValidators[i].operatorIndex == opIdx && _simValidators[i].state == ValidatorState.Exiting) {
                count++;
            }
        }
    }

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
