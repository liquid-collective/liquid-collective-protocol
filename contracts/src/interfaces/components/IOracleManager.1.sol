//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "../../state/oracle/CLSpec.sol";
import "../../state/oracle/ReportBounds.sol";

/// @title Oracle Manager (v1)
/// @author Kiln
/// @notice This interface exposes methods to handle the inputs provided by the oracle
interface IOracleManagerV1 {
    /// @notice The stored oracle address changed
    /// @param oracleAddress The new oracle address
    event SetOracle(address indexed oracleAddress);

    /// @notice The consensus layer data provided by the oracle has been updated
    /// @param validatorCount The new count of validators running on the consensus layer
    /// @param validatorTotalBalance The new total balance sum of all validators
    /// @param roundId Round identifier
    event ConsensusLayerDataUpdate(uint256 validatorCount, uint256 validatorTotalBalance, bytes32 roundId);

    /// @notice The reported validator count is invalid
    /// @param providedValidatorCount The received validator count value
    /// @param depositedValidatorCount The number of deposits performed by the system
    error InvalidValidatorCountReport(uint256 providedValidatorCount, uint256 depositedValidatorCount);

    /// @notice Get oracle address
    /// @return The oracle address
    function getOracle() external view returns (address);

    /// @notice Get CL validator total balance
    /// @return The CL Validator total balance
    function getCLValidatorTotalBalance() external view returns (uint256);

    /// @notice Get CL validator count (the amount of validator reported by the oracles)
    /// @return The CL validator count
    function getCLValidatorCount() external view returns (uint256);

    /// @notice Set the oracle address
    /// @param _oracleAddress Address of the oracle
    function setOracle(address _oracleAddress) external;

    struct ConsensusLayerReport {
        uint256 epoch;
        uint256 validatorsBalance;
        uint256 validatorsSkimmedBalance;
        uint256 validatorsExitedBalance;
        uint256 validatorsExitingBalance;
        uint32 validatorsCount;
        uint32[] stoppedValidatorCountPerOperator;
        bool bufferRebalancingMode;
        bool slashingContainmentMode;
    }

    function setConsensusLayerData(ConsensusLayerReport calldata report) external;

    function isValidEpoch(uint256 epoch) external view returns (bool);

    /// @notice Retrieve the block timestamp
    /// @return The current timestamp from the EVM context
    function getTime() external view returns (uint256);

    /// @notice Retrieve expected epoch id
    /// @return The current expected epoch id
    function getExpectedEpochId() external view returns (uint256);

    /// @notice Retrieve the last completed epoch id
    /// @return The last completed epoch id
    function getLastCompletedEpochId() external view returns (uint256);

    /// @notice Retrieve the current epoch id based on block timestamp
    /// @return The current epoch id
    function getCurrentEpochId() external view returns (uint256);

    /// @notice Retrieve the current cl spec
    /// @return The Consensus Layer Specification
    function getCLSpec() external view returns (CLSpec.CLSpecStruct memory);

    /// @notice Retrieve the current frame details
    /// @return _startEpochId The epoch at the beginning of the frame
    /// @return _startTime The timestamp of the beginning of the frame in seconds
    /// @return _endTime The timestamp of the end of the frame in seconds
    function getCurrentFrame() external view returns (uint256 _startEpochId, uint256 _startTime, uint256 _endTime);

    /// @notice Retrieve the first epoch id of the frame of the provided epoch id
    /// @param _epochId Epoch id used to get the frame
    /// @return The first epoch id of the frame containing the given epoch id
    function getFrameFirstEpochId(uint256 _epochId) external view returns (uint256);

    /// @notice Retrieve the report bounds
    /// @return The report bounds
    function getReportBounds() external view returns (ReportBounds.ReportBoundsStruct memory);
}
