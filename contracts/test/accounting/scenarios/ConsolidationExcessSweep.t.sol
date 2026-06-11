// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../AccountingInvariants.sol";
import "../../../src/interfaces/components/IOracleManager.1.sol";
import "../../../src/state/operatorsRegistry/Operators.3.sol";

/// @title ConsolidationExcessSweepScenarioTest
/// @notice Scenario tests for same-protocol consolidation excess-balance sweeps.
///         These sweeps land in WithdrawV1 like ordinary CL withdrawals, so the only
///         thing separating correct accounting from double-counting is the oracle report.
contract ConsolidationExcessSweepScenarioTest is AccountingInvariants {
    function _baseline() internal {
        _fundRiver(3 * DEPOSIT_SIZE);
        sim_deposit(operatorOneIndex, _amounts(3, DEPOSIT_SIZE));
        sim_activateValidators(3);
        sim_oracleReport();
    }

    function _fundWithdraw(uint256 amount) internal {
        vm.deal(address(withdraw), address(withdraw).balance + amount);
    }

    function _depositPipelineBalance() internal view returns (uint256) {
        return river.getBalanceToDeposit() + river.getCommittedBalance();
    }

    function _submitReport(IOracleManagerV1.ConsensusLayerReport memory report) internal {
        vm.prank(oracleMember);
        oracle.reportConsensusLayerData(report);
    }

    /// @notice Correct handling: the excess sweep is reported as skimmed ETH and removed
    ///         from CL validator balance in the same report. Total underlying and shares
    ///         remain unchanged; the swept ETH simply moves into the deposit pipeline.
    function testSameProtocolExcessSweepReportedAsSkimmedIsAccountingNeutral() public {
        _baseline();

        uint256 sweep = 1 ether;
        uint256 underlyingBefore = river.totalUnderlyingSupply();
        uint256 sharesBefore = river.totalSupply();
        uint256 depositPipelineBefore = _depositPipelineBalance();

        IOracleManagerV1.ConsensusLayerReport memory report = _buildBadReport(false, false);
        report.validatorsBalance -= sweep;
        report.validatorsSkimmedBalance += sweep;
        _fundWithdraw(sweep);

        _submitReport(report);

        IOracleManagerV1.StoredConsensusLayerReport memory stored = river.getLastConsensusLayerReport();
        assertEq(stored.validatorsSkimmedBalance, sweep, "sweep should be classified as skimmed");
        assertEq(stored.validatorsExitedBalance, 0, "sweep should not be classified as exited");
        assertEq(river.totalUnderlyingSupply(), underlyingBefore, "underlying unchanged");
        assertEq(river.totalSupply(), sharesBefore, "no fee shares minted");
        assertEq(_depositPipelineBalance(), depositPipelineBefore + sweep, "sweep moved to deposit pipeline");
    }

    /// @notice If the oracle reports the sweep as skimmed ETH but forgets to remove it from
    ///         validatorsBalance, River sees an artificial reward. This intentionally uses
    ///         a small value within the APR bound to prove the report can be accepted.
    function testDoubleCountedExcessSweepInflatesUnderlyingAndMintsFees() public {
        _baseline();

        uint256 sweep = 0.01 ether;
        uint256 underlyingBefore = river.totalUnderlyingSupply();
        uint256 sharesBefore = river.totalSupply();

        IOracleManagerV1.ConsensusLayerReport memory report = _buildBadReport(false, false);
        report.validatorsSkimmedBalance += sweep;
        _fundWithdraw(sweep);

        _submitReport(report);

        assertEq(river.totalUnderlyingSupply(), underlyingBefore + sweep, "sweep was double-counted");
        assertGt(river.totalSupply(), sharesBefore, "fee shares minted on artificial reward");
    }

    /// @notice If the excess sweep is reported as exited ETH, total assets still net out,
    ///         but operator exit accounting is polluted even though no validator exited.
    function testExcessSweepMisclassifiedAsExitedPollutesExitAccounting() public {
        _baseline();

        uint256 sweep = 1 ether;
        uint256 underlyingBefore = river.totalUnderlyingSupply();
        uint256 sharesBefore = river.totalSupply();
        uint256 depositPipelineBefore = _depositPipelineBalance();

        IOracleManagerV1.ConsensusLayerReport memory report = _buildBadReport(false, false);
        report.validatorsBalance -= sweep;
        report.validatorsExitedBalance += sweep;
        report.exitedETHPerOperator[0] = sweep;
        report.exitedETHPerOperator[operatorOneIndex + 1] = sweep;
        _fundWithdraw(sweep);

        _submitReport(report);

        IOracleManagerV1.StoredConsensusLayerReport memory stored = river.getLastConsensusLayerReport();
        (uint256 totalExited, uint256 totalRequestedExitAmounts) =
            operatorsRegistry.getExitedETHAndRequestedExitAmounts();
        OperatorsV3.Operator memory operator = operatorsRegistry.getOperator(operatorOneIndex);

        assertEq(stored.validatorsSkimmedBalance, 0, "sweep should not be classified as skimmed");
        assertEq(stored.validatorsExitedBalance, sweep, "sweep was classified as exited");
        assertEq(totalExited, sweep, "aggregate exited ETH polluted");
        assertEq(totalRequestedExitAmounts, sweep, "requested exits bumped as unsolicited exit");
        assertEq(operator.requestedExits, sweep, "operator requested exits bumped");
        assertEq(river.totalUnderlyingSupply(), underlyingBefore, "underlying unchanged");
        assertEq(river.totalSupply(), sharesBefore, "no fee shares minted");
        assertEq(_depositPipelineBalance(), depositPipelineBefore + sweep, "sweep moved to deposit pipeline");
    }
}
