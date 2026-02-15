// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.33;

import "contracts/src/River.1.sol";
import "./RiverV1Harness.sol";

/// @notice Harness for AllocationDepositFlow CI. Overrides _getNextValidators to
///         return empty arrays so the OperatorsRegistry is never called — works
///         around Prover internal error 4201170753 when the real registry is in
///         the scene. We still verify keeper check, allocation ordering, zero
///         count, and insufficient-funds revert.
contract AllocationDepositFlowHarness is RiverV1Harness {
    function _getNextValidators(IOperatorsRegistryV1.OperatorAllocation[] memory _allocations)
        internal
        override
        returns (bytes[] memory publicKeys, bytes[] memory signatures)
    {
        _allocations; // silence unused
        return (new bytes[](0), new bytes[](0));
    }
}
