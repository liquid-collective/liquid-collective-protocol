//SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

library AllowlistHelper {
    function batchAllowees(uint256 length) public pure returns(bool[] memory) {
        bool[] memory statuses = new bool[](length);
        for (uint256 i = 0; i < length; i++) {
            statuses[i] = true;
        }
        return statuses;
    }
}
