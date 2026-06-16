//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "./IDepositDataBuffer.sol";
import "./IOperatorRegistry.1.sol";

/// @title Funding Deltas Builder Interface
/// @author Alluvial Finance Inc.
/// @notice Externalizes aggregation of attested deposit batches into operator funding deltas.
interface IFundingDeltasBuilder {
    function build(
        IDepositDataBuffer.Deposit[] memory deposits,
        IDepositDataBuffer.TopUp[] memory topUps,
        uint256 operatorCount
    ) external pure returns (IOperatorsRegistryV1.OperatorFundingDelta[] memory deltas);
}
