// //SPDX-License-Identifier: BUSL-1.1

// pragma solidity 0.8.34;

// import "forge-std/Test.sol";
// import "../src/interfaces/IOperatorRegistry.1.sol";

// abstract contract OperatorAllocationTestBase is Test {
//     function _createAllocation(uint256 count) internal pure returns (IOperatorsRegistryV1.ExitETHAllocation[] memory) {
//         return _createAllocation(0, count);
//     }

//     function _createAllocation(uint256 operatorIndex, uint256 count)
//         internal
//         pure
//         returns (IOperatorsRegistryV1.ExitETHAllocation[] memory)
//     {
//         IOperatorsRegistryV1.ExitETHAllocation[] memory allocations = new IOperatorsRegistryV1.ExitETHAllocation[](1);
//         allocations[0] = IOperatorsRegistryV1.ExitETHAllocation({operatorIndex: operatorIndex, ethAmount: count});
//         return allocations;
//     }

//     function _createAllocation(uint256[] memory opIndexes, uint256[] memory counts)
//         internal
//         pure
//         returns (IOperatorsRegistryV1.ExitETHAllocation[] memory)
//     {
//         IOperatorsRegistryV1.ExitETHAllocation[] memory allocations =
//             new IOperatorsRegistryV1.ExitETHAllocation[](opIndexes.length);
//         for (uint256 i = 0; i < opIndexes.length; ++i) {
//             allocations[i] = IOperatorsRegistryV1.ExitETHAllocation({operatorIndex: opIndexes[i], ethAmount: counts[i]});
//         }
//         return allocations;
//     }

//     function _createMultiAllocation(uint256[] memory opIndexes, uint256[] memory counts)
//         internal
//         pure
//         virtual
//         returns (IOperatorsRegistryV1.ExitETHAllocation[] memory)
//     {
//         return _createAllocation(opIndexes, counts);
//     }

//     /// @dev Converts OperatorAllocation[] (count-based) to ValidatorDeposit[] (key-based) for compile compat.
//     ///      ethAmount field is treated as the validator count for each operator.
//     function _toValidatorDeposits(IOperatorsRegistryV1.ValidatorDeposit[] memory allocations)
//         internal
//         pure
//         returns (IOperatorsRegistryV1.ValidatorDeposit[] memory)
//     {
//         uint256 total = 0;
//         for (uint256 i = 0; i < allocations.length; i++) {
//             total += allocations[i].ethAmount;
//         }
//         IOperatorsRegistryV1.ValidatorDeposit[] memory deposits =
//             new IOperatorsRegistryV1.ValidatorDeposit[](total);
//         uint256 idx = 0;
//         for (uint256 i = 0; i < allocations.length; i++) {
//             for (uint256 j = 0; j < allocations[i].ethAmount; j++) {
//                 deposits[idx++] = IOperatorsRegistryV1.ValidatorDeposit({
//                     operatorIndex: allocations[i].operatorIndex,
//                     pubkey: new bytes(48),
//                     signature: new bytes(96),
//                     depositAmount: 32 ether
//                 });
//             }
//         }
//         return deposits;
//     }

//     /// @dev Creates dummy ValidatorDeposit[] with zero-filled pubkeys/sigs for compile compat.
//     function _createValidatorDeposits(uint256 count)
//         internal
//         pure
//         returns (IOperatorsRegistryV1.ValidatorDeposit[] memory)
//     {
//         return _createValidatorDeposits(0, count);
//     }

//     function _createValidatorDeposits(uint256 operatorIndex, uint256 count)
//         internal
//         pure
//         returns (IOperatorsRegistryV1.ValidatorDeposit[] memory)
//     {
//         IOperatorsRegistryV1.ValidatorDeposit[] memory deposits =
//             new IOperatorsRegistryV1.ValidatorDeposit[](count);
//         for (uint256 i = 0; i < count; i++) {
//             deposits[i] = IOperatorsRegistryV1.ValidatorDeposit({
//                 operatorIndex: operatorIndex,
//                 pubkey: new bytes(48),
//                 signature: new bytes(96),
//                 depositAmount: 32 ether
//             });
//         }
//         return deposits;
//     }
// }
