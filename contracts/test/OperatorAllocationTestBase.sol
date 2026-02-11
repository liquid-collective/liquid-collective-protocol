//SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.33;

import "forge-std/Test.sol";
import "../src/interfaces/IOperatorRegistry.1.sol";

abstract contract OperatorAllocationTestBase is Test {
    function _createAllocation(uint256 count) internal pure returns (IOperatorsRegistryV1.OperatorAllocation[] memory) {
        IOperatorsRegistryV1.OperatorAllocation[] memory allocations = new IOperatorsRegistryV1.OperatorAllocation[](1);
        allocations[0] = IOperatorsRegistryV1.OperatorAllocation({operatorIndex: 0, validatorCount: count});
        return allocations;
    }
}
