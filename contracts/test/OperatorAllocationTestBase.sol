//SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.34;

import "forge-std/Test.sol";
import "../src/interfaces/IOperatorRegistry.1.sol";

abstract contract OperatorAllocationTestBase is Test {
    function _createAllocation(uint256 count) internal pure returns (IOperatorsRegistryV1.ExitETHAllocation[] memory) {
        return _createAllocation(0, count);
    }

    function _createAllocation(uint256 operatorIndex, uint256 count)
        internal
        pure
        returns (IOperatorsRegistryV1.ExitETHAllocation[] memory)
    {
        IOperatorsRegistryV1.ExitETHAllocation[] memory allocations = new IOperatorsRegistryV1.ExitETHAllocation[](1);
        allocations[0] = IOperatorsRegistryV1.ExitETHAllocation({operatorIndex: operatorIndex, ethAmount: count});
        return allocations;
    }

    function _createAllocation(uint256[] memory opIndexes, uint256[] memory counts)
        internal
        pure
        returns (IOperatorsRegistryV1.ExitETHAllocation[] memory)
    {
        IOperatorsRegistryV1.ExitETHAllocation[] memory allocations =
            new IOperatorsRegistryV1.ExitETHAllocation[](opIndexes.length);
        for (uint256 i = 0; i < opIndexes.length; ++i) {
            allocations[i] = IOperatorsRegistryV1.ExitETHAllocation({operatorIndex: opIndexes[i], ethAmount: counts[i]});
        }
        return allocations;
    }

    function _createMultiAllocation(uint256[] memory opIndexes, uint256[] memory counts)
        internal
        pure
        virtual
        returns (IOperatorsRegistryV1.ExitETHAllocation[] memory)
    {
        return _createAllocation(opIndexes, counts);
    }
}
