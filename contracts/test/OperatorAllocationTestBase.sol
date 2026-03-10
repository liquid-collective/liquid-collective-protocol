//SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.34;

import "forge-std/Test.sol";
import "../src/interfaces/IOperatorRegistry.1.sol";

abstract contract OperatorAllocationTestBase is Test {
    function _createAllocation(uint256 count) internal pure returns (IOperatorsRegistryV1.ValidatorDeposit[] memory) {
        return _createAllocation(0, count);
    }

    function _createAllocation(uint256 operatorIndex, uint256 count)
        internal
        pure
        returns (IOperatorsRegistryV1.ValidatorDeposit[] memory)
    {
        IOperatorsRegistryV1.ValidatorDeposit[] memory allocations = new IOperatorsRegistryV1.ValidatorDeposit[](1);
        allocations[0] = IOperatorsRegistryV1.ValidatorDeposit({operatorIndex: operatorIndex, pubkey: bytes(new bytes(48)), signature: bytes(new bytes(96)), depositAmount: count});
        return allocations;
    }

    function _createAllocation(uint256[] memory opIndexes, uint32[] memory counts)
        internal
        pure
        returns (IOperatorsRegistryV1.ValidatorDeposit[] memory)
    {
        IOperatorsRegistryV1.ValidatorDeposit[] memory allocations =
            new IOperatorsRegistryV1.ValidatorDeposit[](opIndexes.length);
        for (uint256 i = 0; i < opIndexes.length; ++i) {
            allocations[i] =
                IOperatorsRegistryV1.ValidatorDeposit({operatorIndex: opIndexes[i], pubkey: bytes(new bytes(48)), signature: bytes(new bytes(96)), depositAmount: counts[i]});
        }
        return allocations;
    }

    function _createMultiAllocation(uint256[] memory opIndexes, uint32[] memory counts)
        internal
        pure
        virtual
        returns (IOperatorsRegistryV1.ValidatorDeposit[] memory)
    {
        return _createAllocation(opIndexes, counts);
    }
}
