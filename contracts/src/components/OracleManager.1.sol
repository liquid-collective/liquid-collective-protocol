//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "../interfaces/components/IOracleManager.1.sol";
import "../interfaces/IRedeemManager.1.sol";

import "../state/river/OracleAddress.sol";
import "../state/river/LastOracleRoundId.sol";
import "../state/river/CLValidatorTotalBalance.sol";
import "../state/river/CLValidatorCount.sol";
import "../state/river/DepositedValidatorCount.sol";
import "../state/oracle/CLSpec.sol";
import "../state/oracle/ReportBounds.sol";

/// @title Oracle Manager (v1)
/// @author Kiln
/// @notice This contract handles the inputs provided by the oracle
/// @notice The Oracle contract is plugged to this contract and is in charge of pushing
/// @notice data whenever a new report has been deemed valid. The report consists in two
/// @notice values: the sum of all balances of all deposited validators and the count of
/// @notice validators that have been activated on the consensus layer.
abstract contract OracleManagerV1 is IOracleManagerV1 {
    /// @notice Handler called if the delta between the last and new validator balance sum is positive
    /// @dev Must be overridden
    /// @param _profits The positive increase in the validator balance sum (staking rewards)
    function _onEarnings(uint256 _profits) internal virtual;

    /// @notice Handler called to pull the Execution layer fees from the recipient
    /// @dev Must be overridden
    /// @param _max The maximum amount to pull inside the system
    /// @return The amount pulled inside the system
    function _pullELFees(uint256 _max) internal virtual returns (uint256);

    /// @notice Handler called to pull the coverage funds
    /// @dev Must be overridden
    /// @param _max The maximum amount to pull inside the system
    /// @return The amount pulled inside the system
    function _pullCoverageFunds(uint256 _max) internal virtual returns (uint256);

    /// @notice Handler called to retrieve the system administrator address
    /// @dev Must be overridden
    /// @return The system administrator address
    function _getRiverAdmin() internal view virtual returns (address);

    /// @notice Prevents unauthorized calls
    modifier onlyAdmin_OMV1() {
        if (msg.sender != _getRiverAdmin()) {
            revert LibErrors.Unauthorized(msg.sender);
        }
        _;
    }

    /// @notice Set the initial oracle address
    /// @param _oracle Address of the oracle
    function initOracleManagerV1(address _oracle) internal {
        OracleAddress.set(_oracle);
        emit SetOracle(_oracle);
    }

    /// @inheritdoc IOracleManagerV1
    function getOracle() external view returns (address) {
        return OracleAddress.get();
    }

    /// @inheritdoc IOracleManagerV1
    function getCLValidatorTotalBalance() external view returns (uint256) {
        return CLValidatorTotalBalance.get();
    }

    /// @inheritdoc IOracleManagerV1
    function getCLValidatorCount() external view returns (uint256) {
        return CLValidatorCount.get();
    }

    /// @inheritdoc IOracleManagerV1
    function setOracle(address _oracleAddress) external onlyAdmin_OMV1 {
        OracleAddress.set(_oracleAddress);
        emit SetOracle(_oracleAddress);
    }

    /// @inheritdoc IOracleManagerV1
    function setConsensusLayerData(
        uint256 _validatorCount,
        uint256 _validatorTotalBalance,
        bytes32 _roundId,
        uint256 _maxIncrease
    ) external {
        if (msg.sender != OracleAddress.get()) {
            revert LibErrors.Unauthorized(msg.sender);
        }

        if (_validatorCount > DepositedValidatorCount.get()) {
            revert InvalidValidatorCountReport(_validatorCount, DepositedValidatorCount.get());
        }

        uint256 newValidators = _validatorCount - CLValidatorCount.get();
        uint256 previousValidatorTotalBalance = CLValidatorTotalBalance.get() + (newValidators * 32 ether);

        CLValidatorTotalBalance.set(_validatorTotalBalance);
        CLValidatorCount.set(_validatorCount);
        LastOracleRoundId.set(_roundId);

        uint256 executionLayerFees = 0;

        // if there's a margin left for pulling the execution layer fees that would leave our delta under the allowed maxIncrease value, do it
        if ((_maxIncrease + previousValidatorTotalBalance) > _validatorTotalBalance) {
            executionLayerFees = _pullELFees((_maxIncrease + previousValidatorTotalBalance) - _validatorTotalBalance);
        }

        // if there's a margin for pulling coverage funds that would also leave our delta under the allowed maxIncrease value, also do it
        if (((_maxIncrease + previousValidatorTotalBalance) - executionLayerFees) > _validatorTotalBalance) {
            _pullCoverageFunds(
                ((_maxIncrease + previousValidatorTotalBalance) - executionLayerFees) - _validatorTotalBalance
            );
        }

        // the revenue value does not include the pulled coverageFunds
        if (previousValidatorTotalBalance < _validatorTotalBalance + executionLayerFees) {
            _onEarnings((_validatorTotalBalance + executionLayerFees) - previousValidatorTotalBalance);
        }

        emit ConsensusLayerDataUpdate(_validatorCount, _validatorTotalBalance, _roundId);
    }

    // rework beyond this point

    event SetSpec(uint64 epochsPerFrame, uint64 slotsPerEpoch, uint64 secondsPerSlot, uint64 genesisTime);
    event SetBounds(uint256 annualAprUpperBound, uint256 relativeLowerBound);

    error InvalidEpoch(uint256 epoch);
    error TotalValidatorBalanceIncreaseOutOfBound(
        uint256 prevTotalEth, uint256 postTotalEth, uint256 timeElapsed, uint256 annualAprUpperBound
    );
    error TotalValidatorBalanceDecreaseOutOfBound(
        uint256 prevTotalEth, uint256 postTotalEth, uint256 timeElapsed, uint256 relativeLowerBound
    );
    error InvalidDecreasingValidatorsExitedBalance(
        uint256 currentValidatorsExitedBalance, uint256 newValidatorsExitedBalance
    );
    error InvalidDecreasingValidatorsSkimmedBalance(
        uint256 currentValidatorsExitedBalance, uint256 newValidatorsExitedBalance
    );

    uint256 lastReportEpoch;
    uint256 lastValidatorsSkimmedBalance;
    uint256 lastValidatorsExitedBalance;
    uint256 internal constant ONE_YEAR = 365 days;

    // this should be added to CLSpec
    uint64 epochsToAssumedFinality_TO_MOVE;

    function _getTotalUnderlyingBalance() internal view virtual returns (uint256);
    // this method should pull the sum of its parameters, if the amount pulled is lower than the sum it should revert
    // then we increase the deposit buffer by skimmed eth amount
    // we also increase the redeem buffer by exited eth amount
    function _pullCLFunds(uint256 skimmedEthAmount, uint256 exitedEthAmount) internal virtual;

    function _pullRedeemManagerExceedingEth(uint256 max) internal virtual returns (uint256);

    function _reportWithdrawToRedeemManager() internal virtual;
    function _requestExitsBasedOnRedeemDemandAfterRebalancings(
        uint256 exitingBalance,
        bool depositToRedeemRebalancingAllowed
    ) internal virtual;

    function initOracleManagerV1_1(
        uint64 epochsPerFrame,
        uint64 slotsPerEpoch,
        uint64 secondsPerSlot,
        uint64 genesisTime,
        uint64 epochsToAssumedFinality,
        uint256 annualAprUpperBound,
        uint256 relativeLowerBound
    ) internal {
        CLSpec.set(
            CLSpec.CLSpecStruct({
                epochsPerFrame: epochsPerFrame,
                slotsPerEpoch: slotsPerEpoch,
                secondsPerSlot: secondsPerSlot,
                genesisTime: genesisTime
            })
        );
        emit SetSpec(epochsPerFrame, slotsPerEpoch, secondsPerSlot, genesisTime);
        epochsToAssumedFinality_TO_MOVE = epochsToAssumedFinality;
        ReportBounds.set(
            ReportBounds.ReportBoundsStruct({
                annualAprUpperBound: annualAprUpperBound,
                relativeLowerBound: relativeLowerBound
            })
        );
        emit SetBounds(annualAprUpperBound, relativeLowerBound);
    }

    struct ConsensusLayerDataReportingTrace {
        uint256 rewards;
        uint256 pulledELFees;
        uint256 pulledRedeemManagerExceedingEthBuffer;
        uint256 pulledCoverageFunds;
    }

    struct ConsensusLayerDataReportingVariables {
        uint256 preReportUnderlyingBalance;
        uint256 postReportUnderlyingBalance;
        uint256 exitedAmountIncrease;
        uint256 skimmedAmountIncrease;
        uint256 timeElapsedSinceLastReport;
        uint256 availableAmountToUpperBound;
        uint256 redeemManagerDemand;
        ConsensusLayerDataReportingTrace trace;
    }

    event ProcessedConsensusLayerReport(
        IOracleManagerV1.ConsensusLayerReport report, ConsensusLayerDataReportingTrace trace
    );

    function setConsensusLayerData(IOracleManagerV1.ConsensusLayerReport calldata report) external {
        // only the oracle is allowed to call this endpoint
        if (msg.sender != OracleAddress.get()) {
            revert LibErrors.Unauthorized(msg.sender);
        }

        CLSpec.CLSpecStruct memory cls = CLSpec.get();

        // we start by verifying that the reported epoch is valid based on the consensus layer spec
        if (!_isValidEpoch(cls, report.epoch)) {
            revert InvalidEpoch(report.epoch);
        }

        // we ensure that the reported validator count is not decreasing
        if (report.validatorsCount > DepositedValidatorCount.get()) {
            revert InvalidValidatorCountReport(report.validatorsCount, DepositedValidatorCount.get());
        }

        ConsensusLayerDataReportingVariables memory vars;

        // we ensure that the reported total exited balance is not decreasing
        if (report.validatorsExitedBalance < lastValidatorsExitedBalance) {
            revert InvalidDecreasingValidatorsExitedBalance(lastValidatorsExitedBalance, report.validatorsExitedBalance);
        }

        // we compute the exited amount increase by taking the delta between reports
        vars.exitedAmountIncrease = report.validatorsExitedBalance - lastValidatorsExitedBalance;

        // we ensure that the reported total skimmed balance is not decreasing
        if (report.validatorsSkimmedBalance < lastValidatorsSkimmedBalance) {
            revert InvalidDecreasingValidatorsSkimmedBalance(
                lastValidatorsSkimmedBalance, report.validatorsSkimmedBalance
            );
        }

        // we compute the new skimmed amount by taking the delta between reports
        vars.skimmedAmountIncrease = report.validatorsSkimmedBalance - lastValidatorsSkimmedBalance;

        ReportBounds.ReportBoundsStruct memory rb = ReportBounds.get();

        // we retrieve the current total underlying balance before any reporting data is applied to the system
        vars.preReportUnderlyingBalance = _getTotalUnderlyingBalance();
        // we compute the time elapsed since last report based on epoch numbers
        vars.timeElapsedSinceLastReport = _timeBetweenEpochs(cls, lastReportEpoch, report.epoch);

        // we update the system parameters, this will have an impact on how the total underlying balance is computed
        CLValidatorTotalBalance.set(report.validatorsBalance);
        CLValidatorCount.set(report.validatorsCount);

        // we compute the maximum allowed increase in balance based on the pre report value
        uint256 maxIncrease = _maxIncrease(rb, vars.preReportUnderlyingBalance, vars.timeElapsedSinceLastReport);

        // we retrieve the new total underlying balance after system parameters are changed
        vars.postReportUnderlyingBalance = _getTotalUnderlyingBalance();

        // if the new underlying balance has increased, we verify that we are not exceeding reporting bound, and we update
        // reporting variables accordingly
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
            vars.trace.rewards = (vars.postReportUnderlyingBalance - vars.preReportUnderlyingBalance);

            // we update the available amount to upper bound (the amount of eth we can still pull and stay below the upper reporting bound)
            vars.availableAmountToUpperBound = maxIncrease - vars.trace.rewards;
        } else {
            // otherwise if the balance has decreased, we verify that we are not exceeding the lower reporting bound

            // we compute the maximum allowed decrease in balance
            uint256 maxDecrease = _maxDecrease(rb, vars.preReportUnderlyingBalance);

            // we verify that the bound is not crossed
            if (vars.postReportUnderlyingBalance < vars.preReportUnderlyingBalance - maxDecrease) {
                revert TotalValidatorBalanceDecreaseOutOfBound(
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
            // we update the rewards
            vars.trace.rewards += vars.trace.pulledRedeemManagerExceedingEthBuffer;
            // we update the available amount accordingly
            vars.availableAmountToUpperBound -= vars.trace.pulledRedeemManagerExceedingEthBuffer;
        }

        // if we have available amount to upper bound after pulling the exceeding eth buffer, we attempt to pull coverage funds
        if (vars.availableAmountToUpperBound > 0) {
            // we pull the funds from the coverage recipient
            vars.trace.pulledCoverageFunds = _pullCoverageFunds(vars.availableAmountToUpperBound);
            // we do not update the rewards as coverage is not considered rewards
            // we do not update the available amount as there are no more pulling actions to perform afterwards
        }

        // if we have new exited / skimmed eth available, we pull funds from the consensus layer recipient
        if (vars.exitedAmountIncrease + vars.skimmedAmountIncrease > 0) {
            // this method pulls and updates ethToDeposit / ethToRedeem accordingly
            _pullCLFunds(vars.skimmedAmountIncrease, vars.exitedAmountIncrease);
        }

        // we use the updated balanceToRedeem value to report a withdraw event on the redeem manager
        _reportWithdrawToRedeemManager();

        // if our rewards are not null, we dispatch the fee to the collector
        if (vars.trace.rewards > 0) {
            _onEarnings(vars.trace.rewards);
        }

        // if the slashing containment mode is active, we do not perform exit related action until it is disabled
        if (!report.slashingContainmentMode) {
            // we request exits based on incoming still in the exit process and current eth buffers
            _requestExitsBasedOnRedeemDemandAfterRebalancings(
                report.validatorsExitingBalance, report.bufferRebalancingMode
            );
        }

        // we emit a summary event with all the reporting details
        emit ProcessedConsensusLayerReport(report, vars.trace);
    }

    function isValidEpoch(uint256 epoch) external view returns (bool) {
        return _isValidEpoch(CLSpec.get(), epoch);
    }

    function _currentEpoch(CLSpec.CLSpecStruct memory cls) internal view returns (uint256) {
        return ((block.timestamp - cls.genesisTime) / cls.secondsPerSlot) / cls.slotsPerEpoch;
    }

    function _isValidEpoch(CLSpec.CLSpecStruct memory cls, uint256 epoch) internal view returns (bool) {
        return (
            _currentEpoch(cls) >= epoch + epochsToAssumedFinality_TO_MOVE && epoch >= lastReportEpoch
                && epoch % cls.epochsPerFrame == 0
        );
    }

    function _maxIncrease(ReportBounds.ReportBoundsStruct memory rb, uint256 _prevTotalEth, uint256 _timeElapsed)
        internal
        pure
        returns (uint256)
    {
        return (_prevTotalEth * rb.annualAprUpperBound * _timeElapsed) / (LibBasisPoints.BASIS_POINTS_MAX * ONE_YEAR);
    }

    function _maxDecrease(ReportBounds.ReportBoundsStruct memory rb, uint256 _prevTotalEth)
        internal
        pure
        returns (uint256)
    {
        return (_prevTotalEth * rb.relativeLowerBound) / LibBasisPoints.BASIS_POINTS_MAX;
    }

    function _timeBetweenEpochs(CLSpec.CLSpecStruct memory cls, uint256 epochPast, uint256 epochNow)
        internal
        pure
        returns (uint256)
    {
        return (epochNow - epochPast) * (cls.secondsPerSlot * cls.slotsPerEpoch);
    }

    function getReportingBounds() external view returns (ReportBounds.ReportBoundsStruct memory) {
        return ReportBounds.get();
    }

    function getConsensusLayerSpec() external view returns (CLSpec.CLSpecStruct memory) {
        return CLSpec.get();
    }
}
