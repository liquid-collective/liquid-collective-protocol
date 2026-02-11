//SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.33;

import "forge-std/Test.sol";
import "../src/interfaces/IOperatorRegistry.1.sol";

abstract contract OperatorAllocationTestBase is Test {
    function _createAllocation(uint256 count) internal pure returns (IOperatorsRegistryV1.OperatorAllocation[] memory) {
        return _createAllocation(0, count);
    }

    function _createAllocation(uint256 operatorIndex, uint256 count)
        internal
        pure
        returns (IOperatorsRegistryV1.OperatorAllocation[] memory)
    {
        IOperatorsRegistryV1.OperatorAllocation[] memory allocations = new IOperatorsRegistryV1.OperatorAllocation[](1);
        allocations[0] = IOperatorsRegistryV1.OperatorAllocation({operatorIndex: operatorIndex, validatorCount: count});
        return allocations;
    }

    function _createAllocation(uint256[] memory opIndexes, uint32[] memory counts)
        internal
        pure
        returns (IOperatorsRegistryV1.OperatorAllocation[] memory)
    {
        IOperatorsRegistryV1.OperatorAllocation[] memory allocations =
            new IOperatorsRegistryV1.OperatorAllocation[](opIndexes.length);
        for (uint256 i = 0; i < opIndexes.length; ++i) {
            allocations[i] =
                IOperatorsRegistryV1.OperatorAllocation({operatorIndex: opIndexes[i], validatorCount: counts[i]});
        }
        return allocations;
    }

    function _createMultiAllocation(uint256[] memory opIndexes, uint32[] memory counts)
        internal
        pure
        virtual
        returns (IOperatorsRegistryV1.OperatorAllocation[] memory)
    {
        return _createAllocation(opIndexes, counts);
    }
}
