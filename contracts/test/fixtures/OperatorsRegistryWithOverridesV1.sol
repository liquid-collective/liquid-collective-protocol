//SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.13;

import {OperatorsRegistryV1} from "../../src/OperatorsRegistry.1.sol";

contract OperatorsRegistryWithOverridesV1 is OperatorsRegistryV1 {
    function sudoStoppedValidatorCounts(uint32[] calldata stoppedValidatorCounts, uint256 depositedValidatorCount)
        external
    {
        _setStoppedValidatorCounts(stoppedValidatorCounts, depositedValidatorCount);
    }
}