//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "./LibErrors.sol";

library LibSanitize {
    function _notZeroAddress(address _address) internal pure {
        if (_address == address(0)) {
            revert LibErrors.InvalidZeroAddress();
        }
    }

    function _notEmptyString(string memory _string) internal pure {
        if (bytes(_string).length == 0) {
            revert LibErrors.InvalidEmptyString();
        }
    }

    function _validFee(uint256 _fee) internal pure {
        if (_fee > 100000) {
            revert LibErrors.InvalidFee();
        }
    }
}
