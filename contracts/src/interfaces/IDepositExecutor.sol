//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "./IDepositDataBuffer.sol";

/// @title Deposit Executor Interface
/// @author Alluvial Finance Inc.
/// @notice Externalizes beacon deposit root construction and deposit-contract calls.
interface IDepositExecutor {
    error ErrorOnDeposit();
    error InvalidDepositValue(uint256 expectedValue, uint256 actualValue);

    function executeDeposits(
        IDepositDataBuffer.Deposit[] calldata deposits,
        IDepositDataBuffer.TopUp[] calldata topUps,
        bytes32 withdrawalCredentials,
        address depositContract
    ) external payable;
}
