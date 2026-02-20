// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "contracts/src/River.1.sol";

contract RiverV1Harness is RiverV1 {

    function riverEthBalance() external view returns (uint256) {
        return address(this).balance;
    }
    
    function consensusLayerDepositSize() external view returns (uint256) {
        return ConsensusLayerDepositManagerV1.DEPOSIT_SIZE;
    }

    function consensusLayerEthBalance() external view returns (uint256) {
        IOracleManagerV1.StoredConsensusLayerReport storage storedReport = LastConsensusLayerReport.get();
        uint256 clValidatorCount = storedReport.validatorsCount;
        uint256 depositedValidatorCount = DepositedValidatorCount.get();

        uint256 depositSize = ConsensusLayerDepositManagerV1.DEPOSIT_SIZE;
        if (depositedValidatorCount == clValidatorCount)
            return 0;
        return (clValidatorCount - depositedValidatorCount) * depositSize;
    }

    function reportWithdrawToRedeemManager() external {
        _reportWithdrawToRedeemManager();
    }

    /// @inheritdoc IOracleManagerV1
    function setConsensusLayerData(IOracleManagerV1.ConsensusLayerReport calldata _report) external override(IOracleManagerV1, OracleManagerV1) {
        // only the oracle is allowed to call this endpoint
        if (msg.sender != OracleAddress.get()) {
            revert LibErrors.Unauthorized(msg.sender);
        }
        ConsensusLayerDataReportingVariables memory vars = helper1_fillUpVarsAndPullCL(_report);

        helper2_updateLastReport(_report);

        ReportBounds.ReportBoundsStruct memory rb = ReportBounds.get();

        // we compute the maximum allowed increase in balance based on the pre report value
        uint256 maxIncrease = _maxIncrease(rb, vars.preReportUnderlyingBalance, vars.timeElapsedSinceLastReport);

        // we retrieve the new total underlying balance after system parameters are changed
        vars.postReportUnderlyingBalance = _assetBalance();

        // we can now compute the earned rewards from the consensus layer balances
        // in order to properly account for the balance increase, we compare the sums of current balances, skimmed balance and exited balances
        // we also synthetically increase the current balance by 32 eth per new activated validator, this way we have no discrepency due
        // to currently activating funds that were not yet accounted in the consensus layer balances
        if (vars.postReportUnderlyingBalance >= vars.preReportUnderlyingBalance) {
            // if this happens, we revert and the reporting process is cancelled
            if (vars.postReportUnderlyingBalance > vars.preReportUnderlyingBalance + maxIncrease) {
                revert TotalValidatorBalanceIncreaseOutOfBound(
                    vars.preReportUnderlyingBalance,
                    vars.postReportUnderlyingBalance,
                    vars.timeElapsedSinceLastReport,
                    rb.annualAprUpperBound
                );
            }

            // we update the rewards based on the balance delta
            vars.trace.rewards = vars.postReportUnderlyingBalance - vars.preReportUnderlyingBalance;

            // we update the available amount to upper bound (the amount of eth we can still pull and stay below the upper reporting bound)
            vars.availableAmountToUpperBound = maxIncrease - vars.trace.rewards;
        } else {
            // otherwise if the balance has decreased, we verify that we are not exceeding the lower reporting bound

            // we compute the maximum allowed decrease in balance
            uint256 maxDecrease = _maxDecrease(rb, vars.preReportUnderlyingBalance);

            // we verify that the bound is not crossed
            helper3_checkBounds(vars, rb, maxDecrease);

            // we update the available amount to upper bound to be equal to the maximum allowed increase plus the negative delta due to the loss
            vars.availableAmountToUpperBound =
                maxIncrease + (vars.preReportUnderlyingBalance - vars.postReportUnderlyingBalance);
        }

        helper4_pullELFees(vars);

        helper5_pullRedeemManagerExceedingEth(vars);

        helper6_pullCoverageFunds(vars);

        helper7_onEarnings(vars);

        helper8_requestExitsBasedOnRedeemDemandAfterRebalancings(vars, _report);

        helper9_reportWithdrawToRedeemManager(vars);

        helper10_skimExcessBalanceToRedeem(vars);

        helper11_commitBalanceToDeposit(vars);

        // we emit a summary event with all the reporting details
        emit ProcessedConsensusLayerReport(_report, vars.trace);
    }
    
    /// @notice helper1
    function helper1_fillUpVarsAndPullCL(IOracleManagerV1.ConsensusLayerReport calldata _report) public returns (ConsensusLayerDataReportingVariables memory) {
        CLSpec.CLSpecStruct memory cls = CLSpec.get();

        // we start by verifying that the reported epoch is valid based on the consensus layer spec
        if (!_isValidEpoch(cls, _report.epoch)) {
            revert InvalidEpoch(_report.epoch);
        }

        ConsensusLayerDataReportingVariables memory vars;

        {
            IOracleManagerV1.StoredConsensusLayerReport storage lastStoredReport = LastConsensusLayerReport.get();

            vars.lastReportExitedBalance = lastStoredReport.validatorsExitedBalance;

            // we ensure that the reported total exited balance is not decreasing
            if (_report.validatorsExitedBalance < vars.lastReportExitedBalance) {
                revert InvalidDecreasingValidatorsExitedBalance(
                    vars.lastReportExitedBalance, _report.validatorsExitedBalance
                );
            }

            // we compute the exited amount increase by taking the delta between reports
            vars.exitedAmountIncrease = _report.validatorsExitedBalance - vars.lastReportExitedBalance;

            vars.lastReportSkimmedBalance = lastStoredReport.validatorsSkimmedBalance;

            // we ensure that the reported total skimmed balance is not decreasing
            if (_report.validatorsSkimmedBalance < vars.lastReportSkimmedBalance) {
                revert InvalidDecreasingValidatorsSkimmedBalance(
                    vars.lastReportSkimmedBalance, _report.validatorsSkimmedBalance
                );
            }

            // we ensure that the reported validator count is not decreasing
            if (
                _report.validatorsCount > DepositedValidatorCount.get()
                    || _report.validatorsCount < lastStoredReport.validatorsCount
            ) {
                revert InvalidValidatorCountReport(
                    _report.validatorsCount, DepositedValidatorCount.get(), lastStoredReport.validatorsCount
                );
            }

            // we compute the new skimmed amount by taking the delta between reports
            vars.skimmedAmountIncrease = _report.validatorsSkimmedBalance - vars.lastReportSkimmedBalance;

            vars.timeElapsedSinceLastReport = _timeBetweenEpochs(cls, lastStoredReport.epoch, _report.epoch);
        }

        // we retrieve the current total underlying balance before any reporting data is applied to the system
        vars.preReportUnderlyingBalance = _assetBalance();

        // if we have new exited / skimmed eth available, we pull funds from the consensus layer recipient
        if (vars.exitedAmountIncrease + vars.skimmedAmountIncrease > 0) {
            // this method pulls and updates ethToDeposit / ethToRedeem accordingly
            _pullCLFunds(vars.skimmedAmountIncrease, vars.exitedAmountIncrease);
        }

        return vars;
    }

    /// @notice helper 2
    function helper2_updateLastReport(IOracleManagerV1.ConsensusLayerReport calldata _report) public {
        // we update the system parameters, this will have an impact on how the total underlying balance is computed
        IOracleManagerV1.StoredConsensusLayerReport memory storedReport;

        storedReport.epoch = _report.epoch;
        storedReport.validatorsBalance = _report.validatorsBalance;
        storedReport.validatorsSkimmedBalance = _report.validatorsSkimmedBalance;
        storedReport.validatorsExitedBalance = _report.validatorsExitedBalance;
        storedReport.validatorsExitingBalance = _report.validatorsExitingBalance;
        storedReport.validatorsCount = _report.validatorsCount;
        storedReport.rebalanceDepositToRedeemMode = _report.rebalanceDepositToRedeemMode;
        storedReport.slashingContainmentMode = _report.slashingContainmentMode;
        LastConsensusLayerReport.set(storedReport);
    }

    /// @notice helper 3
    function helper3_checkBounds(ConsensusLayerDataReportingVariables memory vars, ReportBounds.ReportBoundsStruct memory rb, uint256 maxDecrease) public {
        if (
                vars.postReportUnderlyingBalance
                    < vars.preReportUnderlyingBalance - LibUint256.min(maxDecrease, vars.preReportUnderlyingBalance)
        ) {
            revert TotalValidatorBalanceDecreaseOutOfBound(
                vars.preReportUnderlyingBalance,
                vars.postReportUnderlyingBalance,
                vars.timeElapsedSinceLastReport,
                rb.relativeLowerBound
            );
        }
    }

    /// @notice helper 4
    function helper4_pullELFees(ConsensusLayerDataReportingVariables memory vars) public returns (ConsensusLayerDataReportingVariables memory) {
        // if we have available amount to upper bound after the reporting values are applied
        if (vars.availableAmountToUpperBound > 0) {
            // we pull the funds from the execution layer fee recipient
            vars.trace.pulledELFees = _pullELFees(vars.availableAmountToUpperBound);
            // we update the rewards
            vars.trace.rewards += vars.trace.pulledELFees;
            // we update the available amount accordingly
            vars.availableAmountToUpperBound -= vars.trace.pulledELFees;
        }
        return vars;
    }

    /// @notice helper 5
    function helper5_pullRedeemManagerExceedingEth(ConsensusLayerDataReportingVariables memory vars) public {
        // if we have available amount to upper bound after the execution layer fees are pulled
        if (vars.availableAmountToUpperBound > 0) {
            // we pull the funds from the exceeding eth buffer of the redeem manager
            vars.trace.pulledRedeemManagerExceedingEthBuffer =
                _pullRedeemManagerExceedingEth(vars.availableAmountToUpperBound);
            // we update the available amount accordingly
            vars.availableAmountToUpperBound -= vars.trace.pulledRedeemManagerExceedingEthBuffer;
        }
    }

    /// @notice helper 6
    function helper6_pullCoverageFunds(ConsensusLayerDataReportingVariables memory vars) public {
        // if we have available amount to upper bound after pulling the exceeding eth buffer, we attempt to pull coverage funds
        if (vars.availableAmountToUpperBound > 0) {
            // we pull the funds from the coverage recipient
            vars.trace.pulledCoverageFunds = _pullCoverageFunds(vars.availableAmountToUpperBound);
            // we do not update the rewards as coverage is not considered rewards
            // we do not update the available amount as there are no more pulling actions to perform afterwards
        }
    }

    /// @notice helper 7
    function helper7_onEarnings(ConsensusLayerDataReportingVariables memory vars) public {
        // if our rewards are not null, we dispatch the fee to the collector
        if (vars.trace.rewards > 0) {
            _onEarnings(vars.trace.rewards);
        }
    }

    /// @notice helper 8
    function helper8_requestExitsBasedOnRedeemDemandAfterRebalancings(ConsensusLayerDataReportingVariables memory vars, IOracleManagerV1.ConsensusLayerReport calldata _report) public {
        _requestExitsBasedOnRedeemDemandAfterRebalancings(
            _report.validatorsExitingBalance,
            _report.stoppedValidatorCountPerOperator,
            _report.rebalanceDepositToRedeemMode,
            _report.slashingContainmentMode
        );
    }

    /// @notice helper 9
    function helper9_reportWithdrawToRedeemManager(ConsensusLayerDataReportingVariables memory vars) public {
        // we use the updated balanceToRedeem value to report a withdraw event on the redeem manager
        _reportWithdrawToRedeemManager();
    }

    /// @notice helper 10
    function helper10_skimExcessBalanceToRedeem(ConsensusLayerDataReportingVariables memory vars) public {
        // if funds are left in the balance to redeem, we move them to the deposit balance
        _skimExcessBalanceToRedeem();
    }

    /// @notice helper 11
    function helper11_commitBalanceToDeposit(ConsensusLayerDataReportingVariables memory vars) public {
        // we update the committable amount based on daily maximum allowed
        _commitBalanceToDeposit(vars.timeElapsedSinceLastReport);
    }
}
