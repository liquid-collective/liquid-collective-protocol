//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../interfaces/components/IOracleManager.1.sol";

import "../state/river/CLSpec.sol";
import "../state/river/LastConsensusLayerReport.sol";
import "../state/river/InFlightDeposit.sol";
import "../state/river/ConsolidationBuffer.sol";

/// @title Lib CL Report
/// @author Alluvial Finance Inc.
/// @notice The report validation/delta-computation block of the oracle report flow, extracted
///         from OracleManagerV1 to keep RiverV1 under the EIP-170 deployed-bytecode limit. The
///         `public` entrypoint is deployed as a standalone contract and invoked by River via
///         DELEGATECALL, so every storage read happens in River's storage context as if inlined.
/// @dev Only the report scalars are passed in and a compact, array-free deltas struct is returned,
///      keeping the ABI encode/decode stubs added to River minimal — passing the full
///      `ConsensusLayerReport` (with its dynamic arrays) across the call boundary would add as much
///      marshalling bytecode as the extraction removes. The spec and last stored report are read
///      from storage here rather than passed in, for the same reason.
library LibCLReport {
    /// @notice Compact, array-free set of report deltas returned by validateAndComputeDeltas
    struct ReportDeltas {
        uint256 lastReportExitedBalance;
        uint256 lastReportSkimmedBalance;
        uint256 exitedAmountIncrease;
        uint256 skimmedAmountIncrease;
        uint256 inFlightDepositedETH;
        uint256 totalDepositedActivatedETHIncrease;
        uint256 lastConsolidationBuffer;
        uint256 totalExternalConsolidationsAmountReportedIncrease;
        uint256 timeElapsedSinceLastReport;
    }

    /// @notice Validates the incoming report against the last stored report and computes the report
    ///         deltas used by the rest of the reporting flow.
    /// @dev Reverts on any invalid transition. Reads `CLSpec`, `LastConsensusLayerReport`,
    ///      `InFlightDeposit` and `ConsolidationBuffer` from River storage via delegatecall.
    /// @param _epoch The reported epoch
    /// @param _validatorsExitedBalance The reported total exited balance(wei)
    /// @param _validatorsSkimmedBalance The reported total skimmed balance(wei)
    /// @param _totalDepositedActivatedETH The reported total deposited activated ETH(wei)
    /// @param _validatorsCount The reported validator count
    /// @param _totalExternalConsolidationsAmountReported The reported total external consolidations amount
    /// @return d The computed report deltas
    function validateAndComputeDeltas(
        uint256 _epoch,
        uint256 _validatorsExitedBalance,
        uint256 _validatorsSkimmedBalance,
        uint256 _totalDepositedActivatedETH,
        uint256 _validatorsCount,
        uint256 _totalExternalConsolidationsAmountReported
    ) public view returns (ReportDeltas memory d) {
        CLSpec.CLSpecStruct memory cls = CLSpec.get();

        // we start by verifying that the reported epoch is valid based on the consensus layer spec
        if (!_isValidEpoch(cls, _epoch)) {
            revert IOracleManagerV1.InvalidEpoch(_epoch);
        }

        IOracleManagerV1.StoredConsensusLayerReport storage lastStoredReport = LastConsensusLayerReport.get();

        d.lastReportExitedBalance = lastStoredReport.validatorsExitedBalance;

        // we ensure that the reported total exited balance is not decreasing
        if (_validatorsExitedBalance < d.lastReportExitedBalance) {
            revert IOracleManagerV1.InvalidDecreasingValidatorsExitedBalance(
                d.lastReportExitedBalance, _validatorsExitedBalance
            );
        }

        // we compute the exited amount increase by taking the delta between reports
        d.exitedAmountIncrease = _validatorsExitedBalance - d.lastReportExitedBalance;

        d.lastReportSkimmedBalance = lastStoredReport.validatorsSkimmedBalance;

        // we ensure that the reported total skimmed balance is not decreasing
        if (_validatorsSkimmedBalance < d.lastReportSkimmedBalance) {
            revert IOracleManagerV1.InvalidDecreasingValidatorsSkimmedBalance(
                d.lastReportSkimmedBalance, _validatorsSkimmedBalance
            );
        }

        if (lastStoredReport.totalDepositedActivatedETH > _totalDepositedActivatedETH) {
            revert IOracleManagerV1.InvalidTotalDepositedActivatedETHDecrease(
                lastStoredReport.totalDepositedActivatedETH, _totalDepositedActivatedETH
            );
        }

        d.totalDepositedActivatedETHIncrease = _totalDepositedActivatedETH - lastStoredReport.totalDepositedActivatedETH;
        d.inFlightDepositedETH = InFlightDeposit.get();

        // we ensure that the total deposited activated ETH increase is not higher than the current in flight ETH
        if (d.totalDepositedActivatedETHIncrease > d.inFlightDepositedETH) {
            revert IOracleManagerV1.InvalidTotalDepositedActivatedETHIncrease(
                d.inFlightDepositedETH, _totalDepositedActivatedETH
            );
        }

        // we ensure that the reported validator count is not decreasing
        if (_validatorsCount < lastStoredReport.validatorsCount) {
            revert IOracleManagerV1.InvalidValidatorCountReport(_validatorsCount, lastStoredReport.validatorsCount);
        }

        if (_totalExternalConsolidationsAmountReported < lastStoredReport.totalExternalConsolidationsAmountReported) {
            revert IOracleManagerV1.InvalidTotalConsolidationsAmountReportedDecrease(
                lastStoredReport.totalExternalConsolidationsAmountReported, _totalExternalConsolidationsAmountReported
            );
        }

        if (_totalExternalConsolidationsAmountReported > lastStoredReport.totalExternalConsolidationsAmountReported) {
            // the total consolidation amount reported has increased so we need to reduce the buffer
            uint256 increaseInConsolidation =
                _totalExternalConsolidationsAmountReported - lastStoredReport.totalExternalConsolidationsAmountReported;
            d.lastConsolidationBuffer = ConsolidationBuffer.get();

            if (increaseInConsolidation > d.lastConsolidationBuffer) {
                // this means that the buffer is completely covered and the extra amount will go to rewards
                // as they would have already been accounted for in the validators balance increase we don't need to account for it
                d.totalExternalConsolidationsAmountReportedIncrease = d.lastConsolidationBuffer;
            } else {
                d.totalExternalConsolidationsAmountReportedIncrease = increaseInConsolidation;
            }
        }

        // we compute the new skimmed amount by taking the delta between reports
        d.skimmedAmountIncrease = _validatorsSkimmedBalance - d.lastReportSkimmedBalance;

        d.timeElapsedSinceLastReport = _timeBetweenEpochs(cls, lastStoredReport.epoch, _epoch);
    }

    /// @notice Internal helper to retrieve the current epoch based on the current timestamp
    /// @param _cls The consensus layer spec struct
    /// @return The current epoch
    function _currentEpoch(CLSpec.CLSpecStruct memory _cls) internal view returns (uint256) {
        return ((block.timestamp - _cls.genesisTime) / _cls.secondsPerSlot) / _cls.slotsPerEpoch;
    }

    /// @notice Internal helper to verify if the given epoch is valid
    /// @param _cls The consensus layer spec struct
    /// @param _epoch The epoch to verify
    /// @return True if valid
    function _isValidEpoch(CLSpec.CLSpecStruct memory _cls, uint256 _epoch) internal view returns (bool) {
        return (_currentEpoch(_cls) >= _epoch + _cls.epochsToAssumedFinality
                && _epoch > LastConsensusLayerReport.get().epoch && _epoch % _cls.epochsPerFrame == 0);
    }

    /// @notice Internal helper to retrieve the number of seconds between two epochs
    /// @param _cls The consensus layer spec struct
    /// @param _epochPast The starting epoch
    /// @param _epochNow The current epoch
    /// @return The number of seconds between the two epochs
    function _timeBetweenEpochs(CLSpec.CLSpecStruct memory _cls, uint256 _epochPast, uint256 _epochNow)
        internal
        pure
        returns (uint256)
    {
        return (_epochNow - _epochPast) * (_cls.secondsPerSlot * _cls.slotsPerEpoch);
    }
}
