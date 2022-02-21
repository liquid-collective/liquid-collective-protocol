//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

contract WithdrawV1 {
    function getCrendentials() external view returns (bytes32) {
        return
            bytes32(
                uint256(uint160(address(this))) + 0x0100000000000000000000000000000000000000000000000000000000000000
            );
    }
}
