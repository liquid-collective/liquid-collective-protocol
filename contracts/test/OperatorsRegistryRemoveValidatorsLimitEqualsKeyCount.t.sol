//SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.34;

import "forge-std/Test.sol";
import "./utils/LibImplementationUnbricker.sol";
import "./utils/BytesGenerator.sol";
import "../src/OperatorsRegistry.1.sol";
import "../src/state/operatorsRegistry/Operators.2.sol";

event SetOperatorLimit(uint256 indexed index, uint256 newLimit);

/// @notice Minimal concrete registry (no overrides) so coverage for removeValidators is attributed to OperatorsRegistry.1.sol
contract OperatorsRegistryV1Minimal is OperatorsRegistryV1 {}

contract RiverMockForLimitTest {
    function setKeeper(address) external {}
    function getKeeper() external view returns (address) { return address(0); }
}

/// @notice Single test that triggers the limitEqualsKeyCount branch (first if block) in removeValidators.
///         Uses OperatorsRegistryV1Minimal (no overrides) so execution is attributed to OperatorsRegistry.1.sol.
contract OperatorsRegistryRemoveValidatorsLimitEqualsKeyCountTest is Test, BytesGenerator {
    OperatorsRegistryV1Minimal internal registry;
    address internal admin;
    address internal river;

    function setUp() public {
        admin = makeAddr("admin");
        river = address(new RiverMockForLimitTest());
        registry = new OperatorsRegistryV1Minimal();
        LibImplementationUnbricker.unbrick(vm, address(registry));
        registry.initOperatorsRegistryV1(admin, river);
    }

    /// @dev Triggers if (limitEqualsKeyCount) and emit SetOperatorLimit(_index, operator.keys) in removeValidators (OperatorsRegistry.1.sol ~410-412)
    function testRemoveValidatorsLimitEqualsKeyCountBranch() public {
        address opAddr = makeAddr("operator");
        vm.startPrank(admin);
        uint256 index = registry.addOperator("Op", opAddr);
        bytes memory tenKeys = genBytes((48 + 96) * 10);
        vm.stopPrank();
        vm.prank(opAddr);
        registry.addValidators(index, 10, tenKeys);
        vm.roll(block.number + 1);
        vm.prank(admin);
        uint256[] memory operatorIndexes = new uint256[](1);
        uint32[] memory limits = new uint32[](1);
        operatorIndexes[0] = index;
        limits[0] = 10;
        registry.setOperatorLimits(operatorIndexes, limits, block.number);
        assertEq(registry.getOperator(index).limit, 10, "limit must be 10");
        assertEq(registry.getOperator(index).keys, 10, "keys must be 10");

        uint256[] memory toRemove = new uint256[](2);
        toRemove[0] = 9;
        toRemove[1] = 8;
        vm.prank(opAddr);
        vm.expectEmit(true, true, true, true);
        emit SetOperatorLimit(index, 8);
        registry.removeValidators(index, toRemove);

        assertEq(registry.getOperator(index).keys, 8);
        assertEq(registry.getOperator(index).limit, 8);
    }
}
