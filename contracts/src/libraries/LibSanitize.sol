//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "./Errors.sol";

library LibSanitize {
    function _notZeroAddress(address _address) internal pure {
        if (_address == address(0)) {
            revert Errors.InvalidZeroAddress();
        }
    }

    function _notEmptyString(string calldata _string) internal pure {
        if (bytes(_string).length == 0) {
            revert Errors.InvalidEmptyString();
        }
    }

    function _validFee(uint256 _fee) internal pure {
        if (_fee > 100000) {
            revert Errors.InvalidFee();
        }
    }
}
