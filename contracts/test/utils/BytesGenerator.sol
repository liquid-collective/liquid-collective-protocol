//SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import "../../src/libraries/BytesLib.sol";

contract BytesGenerator {
    bytes32 internal salt = bytes32(0);

    function genBytes(uint256 len) internal returns (bytes memory) {
        bytes memory res = "";
        while (res.length < len) {
            salt = keccak256(abi.encodePacked(salt));
            if (len - res.length >= 32) {
                res = bytes.concat(res, abi.encode(salt));
            } else {
                res = bytes.concat(res, BytesLib.slice(abi.encode(salt), 0, len - res.length));
            }
        }
        return res;
    }
}
