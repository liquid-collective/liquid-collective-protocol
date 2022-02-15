//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

interface IRiverOracleInput {
    function setBeaconData(
        uint256 _validatorCount,
        uint256 _validatorBalanceSum,
        bytes32 _roundId
    ) external;
    
    // review(nmvalera): why do we need totalSupply on Oracle interface  
    function totalSupply() external returns (uint256);

    // review(nmvalera): why do we need totalShares on Oracle interface
    function totalShares() external returns (uint256);
}
