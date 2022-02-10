//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

interface IRiverOracleInput {
    function setBeaconData(
        uint256 _validatorCount,
        uint256 _validatorBalanceSum,
        bytes32 _roundId
    ) external;

    function totalSupply() external returns (uint256);

    function totalShares() external returns (uint256);
}
