//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "./libraries/LibAdministrable.sol";
import "./libraries/Errors.sol";
import "./interfaces/IAdministrable.sol";

contract Administrable is IAdministrable {
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

    function _getAdmin() internal view returns (address) {
        return LibAdministrable._getAdmin();
    }

    function proposeAdmin(address _newAdmin) external onlyAdmin {
        LibAdministrable._setPendingAdmin(_newAdmin);
    }

    function acceptAdmin() external onlyPendingAdmin {
        LibAdministrable._setAdmin(LibAdministrable._getPendingAdmin());
        LibAdministrable._setPendingAdmin(address(0));
    }

    function getAdmin() external view returns (address) {
        return LibAdministrable._getAdmin();
    }

    function getPendingAdmin() external view returns (address) {
        return LibAdministrable._getPendingAdmin();
    }
}
