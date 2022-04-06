//SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

contract User {}

contract UserFactory {
    function _new(uint256 _salt) external returns (address user) {
        bytes memory bytecode = type(User).creationCode;
        bytes32 salt = bytes32(_salt);
        assembly {
            user := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
    }
}
