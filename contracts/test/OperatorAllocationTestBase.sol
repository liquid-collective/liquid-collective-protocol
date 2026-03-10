//SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.34;

import "forge-std/Test.sol";
import "../src/interfaces/IOperatorRegistry.1.sol";

abstract contract OperatorAllocationTestBase is Test {
    /// @dev Creates `count` ValidatorDeposit entries for operator 0, each with 32 ether depositAmount
    function _createAllocation(uint256 count) internal pure returns (IOperatorsRegistryV1.ValidatorDeposit[] memory) {
        return _createAllocation(0, count);
    }

    /// @dev Creates `count` ValidatorDeposit entries for `operatorIndex`, each with 32 ether depositAmount
    function _createAllocation(uint256 operatorIndex, uint256 count)
        internal
        pure
        returns (IOperatorsRegistryV1.ValidatorDeposit[] memory)
    {
        IOperatorsRegistryV1.ValidatorDeposit[] memory allocations = new IOperatorsRegistryV1.ValidatorDeposit[](count);
        for (uint256 i = 0; i < count; ++i) {
            allocations[i] = IOperatorsRegistryV1.ValidatorDeposit({
                operatorIndex: operatorIndex,
                pubkey: bytes(new bytes(48)),
                signature: bytes(new bytes(96)),
                depositAmount: 32 ether
            });
        }
        return allocations;
    }

    /// @dev Creates sum(counts) ValidatorDeposit entries, counts[i] entries per opIndexes[i], each with 32 ether
    function _createAllocation(uint256[] memory opIndexes, uint32[] memory counts)
        internal
        pure
        returns (IOperatorsRegistryV1.ValidatorDeposit[] memory)
    {
        uint256 totalCount = 0;
        for (uint256 i = 0; i < counts.length; ++i) {
            totalCount += counts[i];
        }
        IOperatorsRegistryV1.ValidatorDeposit[] memory allocations =
            new IOperatorsRegistryV1.ValidatorDeposit[](totalCount);
        uint256 idx = 0;
        for (uint256 i = 0; i < opIndexes.length; ++i) {
            for (uint256 j = 0; j < counts[i]; ++j) {
                allocations[idx] = IOperatorsRegistryV1.ValidatorDeposit({
                    operatorIndex: opIndexes[i],
                    pubkey: bytes(new bytes(48)),
                    signature: bytes(new bytes(96)),
                    depositAmount: 32 ether
                });
                ++idx;
            }
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

    /// @dev Creates OperatorAllocation[] for exit requests (one entry per operator with validatorCount)
    function _createExitAllocation(uint256[] memory opIndexes, uint32[] memory counts)
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
}
