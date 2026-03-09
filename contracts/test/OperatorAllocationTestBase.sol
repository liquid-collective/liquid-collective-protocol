//SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.34;

import "forge-std/Test.sol";
import "../src/interfaces/IOperatorRegistry.1.sol";

abstract contract OperatorAllocationTestBase is Test {
    uint256 internal constant DEFAULT_DEPOSIT_AMOUNT = 32 ether;

    function _createAllocation(uint256 count) internal pure returns (IOperatorsRegistryV1.OperatorAllocation[] memory) {
        return _createAllocation(0, count);
    }

    function _createAllocation(uint256 operatorIndex, uint256 count)
        internal
        pure
        returns (IOperatorsRegistryV1.OperatorAllocation[] memory)
    {
        uint256[] memory depositAmounts = new uint256[](count);
        for (uint256 i = 0; i < count; ++i) {
            depositAmounts[i] = DEFAULT_DEPOSIT_AMOUNT;
        }
        IOperatorsRegistryV1.OperatorAllocation[] memory allocations = new IOperatorsRegistryV1.OperatorAllocation[](1);
        allocations[0] =
            IOperatorsRegistryV1.OperatorAllocation({operatorIndex: operatorIndex, depositAmounts: depositAmounts});
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
            uint256[] memory depositAmounts = new uint256[](counts[i]);
            for (uint256 j = 0; j < counts[i]; ++j) {
                depositAmounts[j] = DEFAULT_DEPOSIT_AMOUNT;
            }
            allocations[i] =
                IOperatorsRegistryV1.OperatorAllocation({operatorIndex: opIndexes[i], depositAmounts: depositAmounts});
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

    function _depositAmountsArray(uint256 count) internal pure returns (uint256[] memory) {
        uint256[] memory amounts = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            amounts[i] = DEFAULT_DEPOSIT_AMOUNT;
        }
        return amounts;
    }

    function _createExitAllocation(uint256[] memory opIndexes, uint32[] memory counts)
        internal
        pure
        returns (IOperatorsRegistryV1.ExitAllocation[] memory)
    {
        IOperatorsRegistryV1.ExitAllocation[] memory allocations =
            new IOperatorsRegistryV1.ExitAllocation[](opIndexes.length);
        for (uint256 i = 0; i < opIndexes.length; ++i) {
            allocations[i] = IOperatorsRegistryV1.ExitAllocation({
                operatorIndex: opIndexes[i],
                ethAmount: uint256(counts[i]) * DEFAULT_DEPOSIT_AMOUNT
            });
        }
        return allocations;
    }

    function _createMultiExitAllocation(uint256[] memory opIndexes, uint32[] memory counts)
        internal
        pure
        virtual
        returns (IOperatorsRegistryV1.ExitAllocation[] memory)
    {
        return _createExitAllocation(opIndexes, counts);
    }
}
