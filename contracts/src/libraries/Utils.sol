//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "../state/AdministratorAddress.sol";
import "./Errors.sol";

library UtilsLib {
    /// @notice Prevents anyone except the admin to make the call
    function adminOnly() internal view {
        if (msg.sender != AdministratorAddress.get()) {
            revert Errors.Unauthorized(msg.sender);
        }
    }
}
