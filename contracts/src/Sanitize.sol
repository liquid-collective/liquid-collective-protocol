//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "./libraries/Errors.sol";

contract Sanitize {
    modifier notZeroAddress(address _address) {
        if (_address == address(0)) {
            revert Errors.InvalidZeroAddress();
        }
        _;
    }

    modifier notEmptyString(string calldata _string) {
        if (bytes(_string).length == 0) {
            revert Errors.InvalidEmptyString();
        }
        _;
    }

    modifier validFee(uint256 _fee) {
        if (_fee > 100000) {
            revert Errors.InvalidFee();
        }
        _;
    }
}
