//SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.20;

/// @title Operator Registry Events
/// @author Alluvial Finance Inc.
/// @notice Event definitions as emitted by the Operator Registry for testing purposes
contract OperatorRegistryEvents {
    event SetCurrentValidatorExitsDemand(uint256 previousValidatorExitsDemand, uint256 nextValidatorExitsDemand);
}
