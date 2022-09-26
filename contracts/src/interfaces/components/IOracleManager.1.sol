//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

interface IOracleManagerV1 {
    event SetOracle(address indexed oracleAddress);
    event ConsensusLayerDataUpdate(uint256 validatorCount, uint256 validatorTotalBalance, bytes32 roundId);

    error InvalidValidatorCountReport(uint256 _providedValidatorCount, uint256 _depositedValidatorCount);

    function setConsensusLayerData(
        uint256 _validatorCount,
        uint256 _validatorBalanceSum,
        bytes32 _roundId,
        uint256 _maxIncrease
    ) external;
    function getOracle() external view returns (address);
    function setOracle(address _oracleAddress) external;
    function getCLValidatorTotalBalance() external view returns (uint256);
    function getCLValidatorCount() external view returns (uint256);
}
