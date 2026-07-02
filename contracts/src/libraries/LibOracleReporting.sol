//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../interfaces/IRiver.1.sol";
import "../interfaces/IWithdraw.1.sol";
import "../interfaces/ICoverageFund.1.sol";
import "../interfaces/IRedeemManager.1.sol";
import "../interfaces/IELFeeRecipient.1.sol";
import "../interfaces/IOperatorRegistry.1.sol";
import "../interfaces/components/ISharesManager.1.sol";
import "../interfaces/components/IOracleManager.1.sol";
import "../interfaces/components/IConsensusLayerDepositManager.1.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

import "./LibErrors.sol";
import "./LibUint256.sol";
import "./LibBasisPoints.sol";

import "../state/river/Shares.sol";
import "../state/river/GlobalFee.sol";
import "../state/river/SharesPerOwner.sol";
import "../state/river/BalanceToDeposit.sol";
import "../state/river/BalanceToRedeem.sol";
import "../state/river/CommittedBalance.sol";
import "../state/river/CollectorAddress.sol";
import "../state/river/ConsolidationBuffer.sol";
import "../state/river/CoverageFundAddress.sol";
import "../state/river/ConsolidationCoverageFundAddress.sol";
import "../state/river/RedeemManagerAddress.sol";
import "../state/river/InFlightDeposit.sol";
import "../state/river/WithdrawalCredentials.sol";
import "../state/river/ELFeeRecipientAddress.sol";
import "../state/river/DailyCommittableLimits.sol";
import "../state/river/LastConsensusLayerReport.sol";
import "../state/river/OracleAddress.sol";
import "../state/river/CLSpec.sol";
import "../state/river/ReportBounds.sol";
import "../state/shared/OperatorsRegistryAddress.sol";

/// @title Lib Oracle Reporting (v1)
/// @author Alluvial Finance Inc.
/// @notice External library holding the entire oracle report computation for RiverV1: the
/// @notice `setConsensusLayerData` orchestrator and every report-path handler it drives.
/// @notice Deployed as a separate contract and invoked via DELEGATECALL from River's oracle
/// @notice report entry point, so it reads and writes River's unstructured storage slots
/// @notice directly and its events surface from River's address. Extracting this — the single
/// @notice largest code path in River — keeps River's deployed bytecode under EIP-170 without
/// @notice changing behaviour. Re-entrant share math and collaborator calls resolve against
/// @notice River because `address(this)` is River under delegatecall.
library LibOracleReporting {
    uint256 internal constant ONE_YEAR = 365 days;

    /// @notice Structure holding internal variables used during reporting
    struct ConsensusLayerDataReportingVariables {
        uint256 preReportUnderlyingBalance;
        uint256 postReportUnderlyingBalance;
        uint256 lastReportExitedBalance;
        uint256 lastReportSkimmedBalance;
        uint256 exitedAmountIncrease;
        uint256 skimmedAmountIncrease;
        uint256 inFlightDepositedETH;
        uint256 totalDepositedActivatedETHIncrease;
        uint256 lastConsolidationBuffer;
        uint256 totalExternalConsolidationsAmountReportedIncrease;
        uint256 timeElapsedSinceLastReport;
        uint256 availableAmountToUpperBound;
        uint256 redeemManagerDemand;
        IOracleManagerV1.ConsensusLayerDataReportingTrace trace;
    }

    /// @notice Pushes a new consensus layer report, applies bound checks, pulls available funds,
    ///         distributes rewards, requests exits, reports to the redeem manager and commits to deposit.
    /// @dev DELEGATECALL target: `address(this)` is RiverV1, `msg.sender` is the oracle. Byte-for-byte
    ///      port of the former `OracleManagerV1.setConsensusLayerData`, with the virtual handler calls
    ///      resolved to this library's own functions and `_assetBalance()` read via River's
    ///      `totalUnderlyingSupply()` self-call.
    /// @param _report The consensus layer report
    function setConsensusLayerData(IOracleManagerV1.ConsensusLayerReport calldata _report) external {
        // only the oracle is allowed to call this endpoint
        if (msg.sender != OracleAddress.get()) {
            revert LibErrors.Unauthorized(msg.sender);
        }

        CLSpec.CLSpecStruct memory cls = CLSpec.get();

        // we start by verifying that the reported epoch is valid based on the consensus layer spec
        if (!_isValidEpoch(cls, _report.epoch)) {
            revert IOracleManagerV1.InvalidEpoch(_report.epoch);
        }

        ConsensusLayerDataReportingVariables memory vars;

        {
            IOracleManagerV1.StoredConsensusLayerReport storage lastStoredReport = LastConsensusLayerReport.get();

            vars.lastReportExitedBalance = lastStoredReport.validatorsExitedBalance;

            // we ensure that the reported total exited balance is not decreasing
            if (_report.validatorsExitedBalance < vars.lastReportExitedBalance) {
                revert IOracleManagerV1.InvalidDecreasingValidatorsExitedBalance(
                    vars.lastReportExitedBalance, _report.validatorsExitedBalance
                );
            }

            // we compute the exited amount increase by taking the delta between reports
            vars.exitedAmountIncrease = _report.validatorsExitedBalance - vars.lastReportExitedBalance;

            vars.lastReportSkimmedBalance = lastStoredReport.validatorsSkimmedBalance;

            // we ensure that the reported total skimmed balance is not decreasing
            if (_report.validatorsSkimmedBalance < vars.lastReportSkimmedBalance) {
                revert IOracleManagerV1.InvalidDecreasingValidatorsSkimmedBalance(
                    vars.lastReportSkimmedBalance, _report.validatorsSkimmedBalance
                );
            }

            if (lastStoredReport.totalDepositedActivatedETH > _report.totalDepositedActivatedETH) {
                revert IOracleManagerV1.InvalidTotalDepositedActivatedETHDecrease(
                    lastStoredReport.totalDepositedActivatedETH, _report.totalDepositedActivatedETH
                );
            }

            vars.totalDepositedActivatedETHIncrease =
                _report.totalDepositedActivatedETH - lastStoredReport.totalDepositedActivatedETH;
            vars.inFlightDepositedETH = InFlightDeposit.get();

            // we ensure that the total deposited activated ETH increase is not higher than the current in flight ETH
            if (vars.totalDepositedActivatedETHIncrease > vars.inFlightDepositedETH) {
                revert IOracleManagerV1.InvalidTotalDepositedActivatedETHIncrease(
                    vars.inFlightDepositedETH, _report.totalDepositedActivatedETH
                );
            }

            // we ensure that the reported validator count is not decreasing
            if (_report.validatorsCount < lastStoredReport.validatorsCount) {
                revert IOracleManagerV1.InvalidValidatorCountReport(
                    _report.validatorsCount, lastStoredReport.validatorsCount
                );
            }

            if (
                _report.totalExternalConsolidationsAmountReported
                    < lastStoredReport.totalExternalConsolidationsAmountReported
            ) {
                revert IOracleManagerV1.InvalidTotalConsolidationsAmountReportedDecrease(
                    lastStoredReport.totalExternalConsolidationsAmountReported,
                    _report.totalExternalConsolidationsAmountReported
                );
            }

            if (
                _report.totalExternalConsolidationsAmountReported
                    > lastStoredReport.totalExternalConsolidationsAmountReported
            ) {
                // the total consolidation amount reported has increased so we need to reduce the buffer
                uint256 increaseInConsolidation = _report.totalExternalConsolidationsAmountReported
                    - lastStoredReport.totalExternalConsolidationsAmountReported;
                vars.lastConsolidationBuffer = ConsolidationBuffer.get();

                if (increaseInConsolidation > vars.lastConsolidationBuffer) {
                    // this means that the buffer is completely covered and the extra amount will go to rewards
                    // as they would have already been accounted for in the validators balance increase we don't need to account for it
                    vars.totalExternalConsolidationsAmountReportedIncrease = vars.lastConsolidationBuffer;
                } else {
                    vars.totalExternalConsolidationsAmountReportedIncrease = increaseInConsolidation;
                }
            }

            // we compute the new skimmed amount by taking the delta between reports
            vars.skimmedAmountIncrease = _report.validatorsSkimmedBalance - vars.lastReportSkimmedBalance;

            vars.timeElapsedSinceLastReport = _timeBetweenEpochs(cls, lastStoredReport.epoch, _report.epoch);
        }

        // we retrieve the current total underlying balance before any reporting data is applied to the system
        vars.preReportUnderlyingBalance = ISharesManagerV1(address(this)).totalUnderlyingSupply();

        // if we have new exited / skimmed eth available, we pull funds from the consensus layer recipient
        if (vars.exitedAmountIncrease + vars.skimmedAmountIncrease > 0) {
            // this method pulls and updates ethToDeposit / ethToRedeem accordingly
            _pullCLFunds(vars.skimmedAmountIncrease, vars.exitedAmountIncrease);
        }

        // if we have new external consolidation funds that were reported, we reduce the consolidation buffer
        if (vars.totalExternalConsolidationsAmountReportedIncrease > 0) {
            _setConsolidationBuffer(
                vars.lastConsolidationBuffer,
                vars.lastConsolidationBuffer - vars.totalExternalConsolidationsAmountReportedIncrease
            );
        }

        // checks if we have new deposited stake that activated in the last oracle reporting
        if (vars.totalDepositedActivatedETHIncrease > 0) {
            uint256 newInFlightETH = vars.inFlightDepositedETH - vars.totalDepositedActivatedETHIncrease;
            InFlightDeposit.set(newInFlightETH);
            emit IConsensusLayerDepositManagerV1.SetInFlightETH(vars.inFlightDepositedETH, newInFlightETH);
        }

        {
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
            storedReport.totalDepositedActivatedETH = _report.totalDepositedActivatedETH;
            storedReport.totalExternalConsolidationsAmountReported = _report.totalExternalConsolidationsAmountReported;
            LastConsensusLayerReport.set(storedReport);
        }

        ReportBounds.ReportBoundsStruct memory rb = ReportBounds.get();

        // we compute the maximum allowed increase in balance based on the pre report value
        uint256 maxIncrease = _maxIncrease(rb, vars.preReportUnderlyingBalance, vars.timeElapsedSinceLastReport);

        // we retrieve the new total underlying balance after system parameters are changed
        vars.postReportUnderlyingBalance = ISharesManagerV1(address(this)).totalUnderlyingSupply();

        // we can now compute the earned rewards from the consensus layer balances
        // in order to properly account for the balance increase, we compare the sums of current balances, skimmed balance and exited balances
        // we also synthetically increase the current balance by 32 eth per new activated validator, this way we have no discrepency due
        // to currently activating funds that were not yet accounted in the consensus layer balances
        if (vars.postReportUnderlyingBalance >= vars.preReportUnderlyingBalance) {
            // if this happens, we revert and the reporting process is cancelled
            if (vars.postReportUnderlyingBalance > vars.preReportUnderlyingBalance + maxIncrease) {
                revert IOracleManagerV1.TotalValidatorBalanceIncreaseOutOfBound(
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
            if (
                vars.postReportUnderlyingBalance
                    < vars.preReportUnderlyingBalance - LibUint256.min(maxDecrease, vars.preReportUnderlyingBalance)
            ) {
                revert IOracleManagerV1.TotalValidatorBalanceDecreaseOutOfBound(
                    vars.preReportUnderlyingBalance,
                    vars.postReportUnderlyingBalance,
                    vars.timeElapsedSinceLastReport,
                    rb.relativeLowerBound
                );
            }

            // we update the available amount to upper bound to be equal to the maximum allowed increase plus the negative delta due to the loss
            vars.availableAmountToUpperBound =
                maxIncrease + (vars.preReportUnderlyingBalance - vars.postReportUnderlyingBalance);
        }

        // if we have available amount to upper bound after the reporting values are applied
        if (vars.availableAmountToUpperBound > 0) {
            // we pull the funds from the execution layer fee recipient
            vars.trace.pulledELFees = _pullELFees(vars.availableAmountToUpperBound);
            // we update the rewards
            vars.trace.rewards += vars.trace.pulledELFees;
            // we update the available amount accordingly
            vars.availableAmountToUpperBound -= vars.trace.pulledELFees;
        }

        // if we have available amount to upper bound after the execution layer fees are pulled
        if (vars.availableAmountToUpperBound > 0) {
            // we pull the funds from the exceeding eth buffer of the redeem manager
            vars.trace.pulledRedeemManagerExceedingEthBuffer =
                _pullRedeemManagerExceedingEth(vars.availableAmountToUpperBound);
            // we update the available amount accordingly
            vars.availableAmountToUpperBound -= vars.trace.pulledRedeemManagerExceedingEthBuffer;
        }

        // if we have available amount to upper bound after pulling the exceeding eth buffer, we attempt to pull coverage funds
        if (vars.availableAmountToUpperBound > 0) {
            // we pull the funds from the coverage recipient
            vars.trace.pulledCoverageFunds = _pullCoverageFunds(vars.availableAmountToUpperBound);
            // we do not update the rewards as coverage is not considered rewards
        }

        uint256 consolidationBuffer = ConsolidationBuffer.get();
        // if the consolidation buffer is greater than 0, we attempt to pull the funds from the consolidation coverage fund
        // we always attempt to pull the funds as we don't track on-chain if a consolidation failure has occurred
        if (consolidationBuffer > 0) {
            vars.trace.pulledConsolidationCoverageFunds = _pullConsolidationCoverageFunds(consolidationBuffer);
            if (vars.trace.pulledConsolidationCoverageFunds > 0) {
                // we update the consolidation buffer
                _setConsolidationBuffer(
                    consolidationBuffer, consolidationBuffer - vars.trace.pulledConsolidationCoverageFunds
                );
                // we do not update the rewards as consolidation coverage is not considered rewards
            }
        }

        // if our rewards are not null, we dispatch the fee to the collector
        if (vars.trace.rewards > 0) {
            _onEarnings(vars.trace.rewards);
        }

        _reportCLETH(_report.activeCLETHPerOperator);

        uint256 base = _report.validatorsBalance + InFlightDeposit.get();
        uint256 totalAvailableCLETH =
            base > _report.validatorsExitingBalance ? base - _report.validatorsExitingBalance : 0;

        _requestExitsBasedOnRedeemDemandAfterRebalancings(
            _report.validatorsExitingBalance,
            _report.exitedETHPerOperator,
            totalAvailableCLETH,
            _report.rebalanceDepositToRedeemMode,
            _report.slashingContainmentMode
        );

        // we use the updated balanceToRedeem value to report a withdraw event on the redeem manager
        _reportWithdrawToRedeemManager();

        // if funds are left in the balance to redeem, we move them to the deposit balance
        _skimExcessBalanceToRedeem();

        // we update the committable amount based on daily maximum allowed
        _commitBalanceToDeposit(vars.timeElapsedSinceLastReport, _report.slashingContainmentMode);

        // we emit a summary event with all the reporting details
        emit IOracleManagerV1.ProcessedConsensusLayerReport(_report, vars.trace);
    }

    // -----------------------------------------------------------------------
    // Report-path handlers (ported from RiverV1 overrides)
    // -----------------------------------------------------------------------

    /// @notice Pulls funds from the Withdraw contract, and adds funds to deposit and redeem balances
    /// @param _skimmedEthAmount The new amount of skimmed eth to pull
    /// @param _exitedEthAmount The new amount of exited eth to pull
    function _pullCLFunds(uint256 _skimmedEthAmount, uint256 _exitedEthAmount) private {
        uint256 currentBalance = address(this).balance;
        uint256 totalAmountToPull = _skimmedEthAmount + _exitedEthAmount;
        IWithdrawV1(WithdrawalCredentials.getAddress()).pullEth(totalAmountToPull);
        uint256 collectedCLFunds = address(this).balance - currentBalance;
        if (collectedCLFunds != _skimmedEthAmount + _exitedEthAmount) {
            revert IRiverV1.InvalidPulledClFundsAmount(_skimmedEthAmount + _exitedEthAmount, collectedCLFunds);
        }
        if (_skimmedEthAmount > 0) {
            _setBalanceToDeposit(BalanceToDeposit.get() + _skimmedEthAmount);
        }
        if (_exitedEthAmount > 0) {
            _setBalanceToRedeem(BalanceToRedeem.get() + _exitedEthAmount);
        }
        emit IRiverV1.PulledCLFunds(_skimmedEthAmount, _exitedEthAmount);
    }

    /// @notice Pulls funds from the execution layer fee recipient to River and returns the delta in the balance
    /// @param _max The maximum amount to pull from the execution layer fee recipient
    /// @return The amount pulled from the execution layer fee recipient
    function _pullELFees(uint256 _max) private returns (uint256) {
        address elFeeRecipient = ELFeeRecipientAddress.get();
        uint256 initialBalance = address(this).balance;
        IELFeeRecipientV1(payable(elFeeRecipient)).pullELFees(_max);
        uint256 collectedELFees = address(this).balance - initialBalance;
        if (collectedELFees > 0) {
            _setBalanceToDeposit(BalanceToDeposit.get() + collectedELFees);
        }
        emit IRiverV1.PulledELFees(collectedELFees);
        return collectedELFees;
    }

    /// @notice Pulls funds from the coverage fund to River and returns the delta in the balance
    /// @param _max The maximum amount to pull from the coverage fund
    /// @return collectedCoverageFunds The amount pulled from the coverage fund
    function _pullCoverageFunds(uint256 _max) private returns (uint256 collectedCoverageFunds) {
        collectedCoverageFunds = _pullFundsFromCoverageFund(CoverageFundAddress.get(), _max);
        emit IRiverV1.PulledCoverageFunds(collectedCoverageFunds);
    }

    /// @notice Pulls funds from the consolidation coverage fund to River and returns the delta in the balance
    /// @param _max The maximum amount to pull from the consolidation coverage fund
    /// @return collectedConsolidationCoverageFunds The amount pulled from the consolidation coverage fund
    function _pullConsolidationCoverageFunds(uint256 _max)
        private
        returns (uint256 collectedConsolidationCoverageFunds)
    {
        collectedConsolidationCoverageFunds = _pullFundsFromCoverageFund(ConsolidationCoverageFundAddress.get(), _max);
        emit IRiverV1.PulledConsolidationCoverageFunds(collectedConsolidationCoverageFunds);
    }

    /// @notice Pulls funds from the redeem manager exceeding eth buffer
    /// @param _max The maximum amount to pull
    /// @return The amount pulled
    function _pullRedeemManagerExceedingEth(uint256 _max) private returns (uint256) {
        uint256 currentBalance = address(this).balance;
        IRedeemManagerV1(RedeemManagerAddress.get()).pullExceedingEth(_max);
        uint256 collectedExceedingEth = address(this).balance - currentBalance;
        if (collectedExceedingEth > 0) {
            _setBalanceToDeposit(BalanceToDeposit.get() + collectedExceedingEth);
        }
        emit IRiverV1.PulledRedeemManagerExceedingEth(collectedExceedingEth);
        return collectedExceedingEth;
    }

    /// @notice Computes the fees paid to the collector whenever the balance of ETH handled by the system increases
    /// @param _amount Additional ETH received
    function _onEarnings(uint256 _amount) private {
        uint256 oldTotalSupply = ISharesManagerV1(address(this)).totalSupply();
        if (oldTotalSupply == 0) {
            revert IRiverV1.ZeroMintedShares();
        }
        uint256 newTotalBalance = ISharesManagerV1(address(this)).totalUnderlyingSupply();
        uint256 globalFee = GlobalFee.get();
        uint256 numerator = _amount * oldTotalSupply * globalFee;
        uint256 denominator = (newTotalBalance * LibBasisPoints.BASIS_POINTS_MAX) - (_amount * globalFee);
        uint256 sharesToMint = denominator == 0 ? 0 : (numerator / denominator);

        if (sharesToMint > 0) {
            address collector = CollectorAddress.get();
            _mintRawShares(collector, sharesToMint);
            uint256 newTotalSupply = ISharesManagerV1(address(this)).totalSupply();
            uint256 oldTotalBalance = newTotalBalance - _amount;
            emit IRiverV1.RewardsEarned(collector, oldTotalBalance, oldTotalSupply, newTotalBalance, newTotalSupply);
        }
    }

    /// @notice Reports the ETH that is currently active on the consensus layer for the operators
    /// @param _activeCLETH The array of active ETH amounts
    function _reportCLETH(uint256[] memory _activeCLETH) private {
        IOperatorsRegistryV1(OperatorsRegistryAddress.get()).reportCLETH(_activeCLETH);
    }

    /// @notice Requests exits of validators after possibly rebalancing deposit and redeem balances
    /// @param _exitingBalance The currently exiting funds, soon to be received on the execution layer
    /// @param _exitedETH The exited ETH(wei)
    /// @param _totalAvailableCLETH The total available ETH(wei) on the consensus layer that can be used to exit validators, this value includes the InFlightDeposit amount & excludes the exiting balance
    /// @param _depositToRedeemRebalancingAllowed True if rebalancing from deposit to redeem is allowed
    /// @param _slashingContainmentModeEnabled True if slashing containment mode is enabled
    function _requestExitsBasedOnRedeemDemandAfterRebalancings(
        uint256 _exitingBalance,
        uint256[] memory _exitedETH,
        uint256 _totalAvailableCLETH,
        bool _depositToRedeemRebalancingAllowed,
        bool _slashingContainmentModeEnabled
    ) private {
        IOperatorsRegistryV1(OperatorsRegistryAddress.get()).reportExitedETH(_exitedETH);

        // When slashing containment mode is active, skip exit demand logic to avoid forcing additional
        // validator exits during a slashing event. The reward-pull pipeline is unaffected by this check.
        if (_slashingContainmentModeEnabled) {
            emit IRiverV1.SkippedExitRequestsDueToSlashingContainment();
            return;
        }

        uint256 totalSupply = ISharesManagerV1(address(this)).totalSupply();
        if (totalSupply > 0) {
            uint256 availableBalanceToRedeem = BalanceToRedeem.get();
            uint256 availableBalanceToDeposit = BalanceToDeposit.get();
            uint256 redeemManagerDemandInEth = ISharesManagerV1(address(this)).underlyingBalanceFromShares(
                IRedeemManagerV1(RedeemManagerAddress.get()).getRedeemDemand()
            );

            // if after all rebalancings, the redeem manager demand is still higher than the balance to redeem and exiting eth, we compute
            // the amount of ETH (wei) to exit in order to cover the remaining demand
            if (availableBalanceToRedeem + _exitingBalance < redeemManagerDemandInEth) {
                // if rebalancing is enabled and the redeem manager demand is higher than exiting eth, we add eth for deposit buffer to redeem buffer
                if (_depositToRedeemRebalancingAllowed && availableBalanceToDeposit > 0) {
                    uint256 rebalancingAmount = LibUint256.min(
                        availableBalanceToDeposit, redeemManagerDemandInEth - _exitingBalance - availableBalanceToRedeem
                    );
                    if (rebalancingAmount > 0) {
                        availableBalanceToRedeem += rebalancingAmount;
                        _setBalanceToRedeem(availableBalanceToRedeem);
                        _setBalanceToDeposit(availableBalanceToDeposit - rebalancingAmount);
                    }
                }

                IOperatorsRegistryV1 or = IOperatorsRegistryV1(OperatorsRegistryAddress.get());

                (uint256 totalExitedETH, uint256 totalRequestedETHExits) = or.getExitedAndRequestedETHExits();

                // what we are calling pre-exiting balance is the amount of ETH (wei) the protocol has committed to exit
                // but not yet received — covering both dispatched exit requests and demand not yet sent to operators
                // we take them into account to not over-request exits across oracle cycles
                uint256 preExitingBalance =
                    totalRequestedETHExits > totalExitedETH ? (totalRequestedETHExits - totalExitedETH) : 0;

                if (availableBalanceToRedeem + _exitingBalance + preExitingBalance < redeemManagerDemandInEth) {
                    uint256 exitAmountToRequest = LibUint256.max(
                        redeemManagerDemandInEth - (availableBalanceToRedeem + _exitingBalance + preExitingBalance),
                        1 ether
                    );

                    // we demand the exits based on the total available ETH on the consensus layer
                    // we don't include the ETH that is present on river as have already rebalanced it
                    or.demandETHExits(exitAmountToRequest, _totalAvailableCLETH);
                }
            }
        }
    }

    /// @notice Uses the balance to redeem to report a withdrawal event on the redeem manager
    function _reportWithdrawToRedeemManager() private {
        IRedeemManagerV1 redeemManager_ = IRedeemManagerV1(RedeemManagerAddress.get());
        uint256 underlyingAssetBalance = ISharesManagerV1(address(this)).totalUnderlyingSupply();
        uint256 totalSupply = ISharesManagerV1(address(this)).totalSupply();

        if (underlyingAssetBalance > 0 && totalSupply > 0) {
            // we compute the redeem manager demands in eth and lsEth based on current conversion rate
            uint256 redeemManagerDemand = redeemManager_.getRedeemDemand();
            uint256 suppliedRedeemManagerDemand = redeemManagerDemand;
            uint256 suppliedRedeemManagerDemandInEth =
                ISharesManagerV1(address(this)).underlyingBalanceFromShares(suppliedRedeemManagerDemand);
            uint256 availableBalanceToRedeem = BalanceToRedeem.get();

            // if demand is higher than available eth, we update demand values to use the available eth
            if (suppliedRedeemManagerDemandInEth > availableBalanceToRedeem) {
                suppliedRedeemManagerDemandInEth = availableBalanceToRedeem;
                suppliedRedeemManagerDemand =
                    ISharesManagerV1(address(this)).sharesFromUnderlyingBalance(suppliedRedeemManagerDemandInEth);
            }

            emit IRiverV1.ReportedRedeemManager(
                redeemManagerDemand, suppliedRedeemManagerDemand, suppliedRedeemManagerDemandInEth
            );

            if (suppliedRedeemManagerDemandInEth > 0) {
                // the available balance to redeem is updated
                unchecked {
                    _setBalanceToRedeem(availableBalanceToRedeem - suppliedRedeemManagerDemandInEth);
                }

                // we burn the shares of the redeem manager associated with the amount of eth provided
                _burnRawShares(address(redeemManager_), suppliedRedeemManagerDemand);

                // perform a report withdraw call to the redeem manager
                redeemManager_.reportWithdraw{value: suppliedRedeemManagerDemandInEth}(suppliedRedeemManagerDemand);
            }
        }
    }

    /// @notice Skims the redeem balance and sends remaining funds to the deposit balance
    function _skimExcessBalanceToRedeem() private {
        uint256 availableBalanceToRedeem = BalanceToRedeem.get();

        // if the available balance to redeem is not 0, it means that all the redeem requests are fulfilled, we should redirect funds for deposits
        if (availableBalanceToRedeem > 0) {
            _setBalanceToDeposit(BalanceToDeposit.get() + availableBalanceToRedeem);
            _setBalanceToRedeem(0);
        }
    }

    /// @notice Commits the deposit balance up to the allowed daily limit in batches of 32 ETH.
    /// @param _period The period between current and last report
    /// @param _slashingContainmentModeEnabled True if slashing containment mode is enabled
    function _commitBalanceToDeposit(uint256 _period, bool _slashingContainmentModeEnabled) private {
        // When slashing containment mode is active, skip new validator funding to prevent compounding
        // losses. The deposit buffer remains available for redeem rebalancing but nothing is committed.
        if (_slashingContainmentModeEnabled) {
            emit IRiverV1.SkippedCommitToDepositDueToSlashingContainment();
            return;
        }

        uint256 underlyingAssetBalance = ISharesManagerV1(address(this)).totalUnderlyingSupply();
        uint256 currentBalanceToDeposit = BalanceToDeposit.get();
        DailyCommittableLimits.DailyCommittableLimitsStruct memory dcl = DailyCommittableLimits.get();

        // we compute the max daily committable amount by taking the asset balance without the balance to deposit into account
        // this value is the daily maximum amount we can commit for deposits
        // we take the maximum value between a net amount and an amount relative to the asset balance
        // this ensures that the amount we can commit is not too low in the beginning and that it is not too high when volumes grow
        // the relative amount is computed from the committed and activated funds (on the CL or committed to be on the CL soon) and not
        // the deposit balance
        // this value is computed by subtracting the current balance to deposit from the underlying asset balance
        uint256 currentMaxDailyCommittableAmount = LibUint256.max(
            dcl.minDailyNetCommittableAmount,
            (uint256(dcl.maxDailyRelativeCommittableAmount) * (underlyingAssetBalance - currentBalanceToDeposit))
                / LibBasisPoints.BASIS_POINTS_MAX
        );
        // we adapt the value for the reporting period by using the asset balance as upper bound
        uint256 currentMaxCommittableAmount =
            LibUint256.min((currentMaxDailyCommittableAmount * _period) / 1 days, currentBalanceToDeposit);

        currentMaxCommittableAmount = (currentMaxCommittableAmount / 1 gwei) * 1 gwei;

        if (currentMaxCommittableAmount > 0) {
            uint256 oldCommittedBalance = CommittedBalance.get();
            emit IRiverV1.SetBalanceCommittedToDeposit(
                oldCommittedBalance, oldCommittedBalance + currentMaxCommittableAmount
            );
            CommittedBalance.set(oldCommittedBalance + currentMaxCommittableAmount);
            _setBalanceToDeposit(currentBalanceToDeposit - currentMaxCommittableAmount);
        }
    }

    // -----------------------------------------------------------------------
    // Internal state helpers (mirror the RiverV1 / SharesManagerV1 setters)
    // -----------------------------------------------------------------------

    /// @notice Pulls funds from a coverage fund to River, mirroring RiverV1._pullFundsFromCoverageFund
    /// @param _coverageFund The address of the coverage fund
    /// @param _max The maximum amount to pull from the coverage fund
    /// @return The amount pulled from the coverage fund
    function _pullFundsFromCoverageFund(address _coverageFund, uint256 _max) private returns (uint256) {
        if (_coverageFund == address(0)) {
            return 0;
        }
        uint256 initialBalance = address(this).balance;
        ICoverageFundV1(payable(_coverageFund)).pullCoverageFunds(_max);
        uint256 collected = address(this).balance - initialBalance;
        if (collected > 0) {
            _setBalanceToDeposit(BalanceToDeposit.get() + collected);
        }
        return collected;
    }

    /// @notice Mints shares without any conversion, mirroring SharesManagerV1._mintRawShares
    /// @param _owner Account that should receive the new shares
    /// @param _value Amount of shares to mint
    function _mintRawShares(address _owner, uint256 _value) private {
        uint256 newTotalSupply = Shares.get() + _value;
        Shares.set(newTotalSupply);
        emit ISharesManagerV1.SetTotalSupply(newTotalSupply);
        SharesPerOwner.set(_owner, SharesPerOwner.get(_owner) + _value);
        emit IERC20.Transfer(address(0), _owner, _value);
    }

    /// @notice Burns shares without any conversion, mirroring SharesManagerV1._burnRawShares
    /// @param _owner Account that should burn its shares
    /// @param _value Amount of shares to burn
    function _burnRawShares(address _owner, uint256 _value) private {
        uint256 newTotalSupply = Shares.get() - _value;
        Shares.set(newTotalSupply);
        emit ISharesManagerV1.SetTotalSupply(newTotalSupply);
        SharesPerOwner.set(_owner, SharesPerOwner.get(_owner) - _value);
        emit IERC20.Transfer(_owner, address(0), _value);
    }

    /// @notice Sets the balance to deposit, mirroring RiverV1._setBalanceToDeposit
    /// @param _newBalanceToDeposit The new balance to deposit value
    function _setBalanceToDeposit(uint256 _newBalanceToDeposit) private {
        emit IRiverV1.SetBalanceToDeposit(BalanceToDeposit.get(), _newBalanceToDeposit);
        BalanceToDeposit.set(_newBalanceToDeposit);
    }

    /// @notice Sets the balance to redeem, mirroring RiverV1._setBalanceToRedeem
    /// @param _newBalanceToRedeem The new balance to redeem value
    function _setBalanceToRedeem(uint256 _newBalanceToRedeem) private {
        emit IRiverV1.SetBalanceToRedeem(BalanceToRedeem.get(), _newBalanceToRedeem);
        BalanceToRedeem.set(_newBalanceToRedeem);
    }

    /// @notice Sets the consolidation buffer, mirroring RiverV1._setConsolidationBuffer
    /// @param _oldConsolidationBuffer The old consolidation buffer value
    /// @param _newConsolidationBuffer The new consolidation buffer value
    function _setConsolidationBuffer(uint256 _oldConsolidationBuffer, uint256 _newConsolidationBuffer) private {
        emit IRiverV1.SetConsolidationBuffer(_oldConsolidationBuffer, _newConsolidationBuffer);
        ConsolidationBuffer.set(_newConsolidationBuffer);
    }

    // -----------------------------------------------------------------------
    // Internal view helpers (mirror the OracleManagerV1 report helpers)
    // -----------------------------------------------------------------------

    /// @notice Retrieve the current epoch based on the current timestamp
    /// @param _cls The consensus layer spec struct
    /// @return The current epoch
    function _currentEpoch(CLSpec.CLSpecStruct memory _cls) private view returns (uint256) {
        return ((block.timestamp - _cls.genesisTime) / _cls.secondsPerSlot) / _cls.slotsPerEpoch;
    }

    /// @notice Verifies if the given epoch is valid
    /// @param _cls The consensus layer spec struct
    /// @param _epoch The epoch to verify
    /// @return True if valid
    function _isValidEpoch(CLSpec.CLSpecStruct memory _cls, uint256 _epoch) private view returns (bool) {
        return (
            _currentEpoch(_cls) >= _epoch + _cls.epochsToAssumedFinality
                && _epoch > LastConsensusLayerReport.get().epoch && _epoch % _cls.epochsPerFrame == 0
        );
    }

    /// @notice Retrieves the maximum increase in balance based on current total underlying supply and period since last report
    /// @param _rb The report bounds struct
    /// @param _prevTotalEth The total underlying supply during reporting
    /// @param _timeElapsed The time since last report
    /// @return The maximum allowed increase in balance
    function _maxIncrease(ReportBounds.ReportBoundsStruct memory _rb, uint256 _prevTotalEth, uint256 _timeElapsed)
        private
        pure
        returns (uint256)
    {
        return (_prevTotalEth * _rb.annualAprUpperBound * _timeElapsed) / (LibBasisPoints.BASIS_POINTS_MAX * ONE_YEAR);
    }

    /// @notice Retrieves the maximum decrease in balance based on current total underlying supply
    /// @param _rb The report bounds struct
    /// @param _prevTotalEth The total underlying supply during reporting
    /// @return The maximum allowed decrease in balance
    function _maxDecrease(ReportBounds.ReportBoundsStruct memory _rb, uint256 _prevTotalEth)
        private
        pure
        returns (uint256)
    {
        return (_prevTotalEth * _rb.relativeLowerBound) / LibBasisPoints.BASIS_POINTS_MAX;
    }

    /// @notice Retrieve the number of seconds between two epochs
    /// @param _cls The consensus layer spec struct
    /// @param _epochPast The starting epoch
    /// @param _epochNow The current epoch
    /// @return The number of seconds between the two epochs
    function _timeBetweenEpochs(CLSpec.CLSpecStruct memory _cls, uint256 _epochPast, uint256 _epochNow)
        private
        pure
        returns (uint256)
    {
        return (_epochNow - _epochPast) * (_cls.secondsPerSlot * _cls.slotsPerEpoch);
    }
}
