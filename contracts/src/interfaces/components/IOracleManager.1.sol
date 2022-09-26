//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

interface IOracleManagerV1 {
    /// @notice The storage oracle address changed
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

    /// @notice Sets the validator count and validator total balance sum reported by the oracle
    /// @dev Can only be called by the oracle address
    /// @dev The round id is a blackbox value that should only be used to identify unique reports
    /// @param _validatorCount The number of active validators on the consensus layer
    /// @param _validatorTotalBalance The validator balance sum of the active validators on the consensus layer
    /// @param _roundId An identifier for this update
    /// @param _maxIncrease The maximum allowed increase in the total balance
    function setConsensusLayerData(uint256 _validatorCount, uint256 _validatorTotalBalance, bytes32 _roundId, uint256 _maxIncrease)
        external;
}
