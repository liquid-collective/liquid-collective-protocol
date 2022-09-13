//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "./libraries/LibAdministrable.sol";
import "./libraries/Errors.sol";

contract Administrable {
    modifier onlyAdmin() {
        if (msg.sender != LibAdministrable._getAdmin()) {
            revert Errors.Unauthorized(msg.sender);
        }
        _;
    }

    modifier onlyPendingAdmin() {
        if (msg.sender != LibAdministrable._getPendingAdmin()) {
            revert Errors.Unauthorized(msg.sender);
        }
        _;
    }

    function _setAdmin(address _admin) internal {
        LibAdministrable._setAdmin(_admin);
    }

    function proposeAdmin(address _newOwner) external onlyAdmin {
        if (_newOwner == address(0)) {
            revert Errors.InvalidZeroAddress();
        }
        LibAdministrable._setPendingAdmin(_newOwner);
    }

    function acceptAdmin() external onlyPendingAdmin {
        LibAdministrable._setAdmin(LibAdministrable._getPendingAdmin());
        LibAdministrable._setPendingAdmin(address(0));
    }

    function getAdministrator() external view returns (address) {
        return LibAdministrable._getAdmin();
    }

    function getPendingAdministrator() external view returns (address) {
        return LibAdministrable._getPendingAdmin();
    }
}
