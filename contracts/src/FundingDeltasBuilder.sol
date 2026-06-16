//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "./interfaces/IFundingDeltasBuilder.sol";
import "./libraries/LibFundingDeltas.sol";

/// @title Funding Deltas Builder
/// @author Alluvial Finance Inc.
/// @notice Deployable wrapper around LibFundingDeltas to keep aggregation bytecode out of River.
contract FundingDeltasBuilder is IFundingDeltasBuilder {
    /// @inheritdoc IFundingDeltasBuilder
    function build(
        IDepositDataBuffer.Deposit[] memory deposits,
        IDepositDataBuffer.TopUp[] memory topUps,
        uint256 operatorCount
    ) external pure returns (IOperatorsRegistryV1.OperatorFundingDelta[] memory deltas) {
        return LibFundingDeltas.build(deposits, topUps, operatorCount);
    }
}
