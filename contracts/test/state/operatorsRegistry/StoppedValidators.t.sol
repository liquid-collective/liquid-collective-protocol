//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "../../../src/state/operatorsRegistry/StoppedValidators.sol";
import "forge-std/Test.sol";

contract StoppedValidatorsTest is Test {
    function testSetRaw(uint256 salt, uint8 size) external {
        uint32[] memory arr = new uint32[](size);
        uint256 saltIndex = salt;
        for (uint256 idx = 0; idx < size;) {
            arr[idx] = uint32(saltIndex);
            unchecked {
                ++idx;
                saltIndex = uint256(keccak256(abi.encode(saltIndex)));
            }
        }

        StoppedValidators.setRaw(arr);

        uint32[] storage retrieved = StoppedValidators.get();

        assertEq(retrieved.length, size);

        for (uint256 idx = 0; idx < size;) {
            assertEq(retrieved[idx], arr[idx]);
            unchecked {
                ++idx;
            }
        }
    }
}
