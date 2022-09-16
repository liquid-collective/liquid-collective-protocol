//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "../state/shared/AdministratorAddress.sol";
import "../state/shared/PendingAdministratorAddress.sol";

library LibAdministrable {
    function _setAdministrator(address newAdmin) internal {
        AdministratorAddress.set(newAdmin);
    }

    function _getAdministrator() internal view returns (address) {
        return AdministratorAddress.get();
    }

    function _setPendingAdministrator(address newAdmin) internal {
        PendingAdministratorAddress.set(newAdmin);
    }

    function _getPendingAdministrator() internal view returns (address) {
        return PendingAdministratorAddress.get();
    }
}
