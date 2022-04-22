//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "../state/shared/AdministratorAddress.sol";
import "../state/shared/GovernorAddress.sol";

library LibOwnable {
    function _setAdmin(address newAdmin) internal {
        AdministratorAddress.set(newAdmin);
    }

    function _getAdmin() internal view returns (address) {
        return AdministratorAddress.get();
    }

    function _setGovernor(address newGovernor) internal {
        GovernorAddress.set(newGovernor);
    }

    function _getGovernor() internal view returns (address) {
        return GovernorAddress.get();
    }
}
