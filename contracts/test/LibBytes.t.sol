//SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import "../src/libraries/LibBytes.sol";

import "forge-std/Test.sol";

contract BytesTest is Test {
    function testSliceOverflow() external {
        vm.expectRevert(abi.encodeWithSignature("SliceOverflow()"));
        LibBytes.slice("bytes !", 0, type(uint256).max);
    }

    function testSliceOutOfBounds() external {
        vm.expectRevert(abi.encodeWithSignature("SliceOutOfBounds()"));
        LibBytes.slice("bytes !", 5, 5);
    }

    function testSlice() external {
        assertEq(LibBytes.slice("bytes !", 0, 4), "byte");
    }
}
