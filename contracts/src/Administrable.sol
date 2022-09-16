//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "./libraries/LibAdministrable.sol";
import "./libraries/Errors.sol";
import "./interfaces/IAdministrable.sol";

contract Administrable is IAdministrable {
    modifier onlyAdmin() {
        if (msg.sender != LibAdministrable._getAdministrator()) {
            revert Errors.Unauthorized(msg.sender);
        }
        _;
    }

    modifier onlyPendingAdmin() {
        if (msg.sender != LibAdministrable._getPendingAdministrator()) {
            revert Errors.Unauthorized(msg.sender);
        }
        _;
    }

    function _setAdmin(address _admin) internal {
        LibAdministrable._setAdministrator(_admin);
    }

    function _getAdmin() internal view returns (address) {
        return LibAdministrable._getAdministrator();
    }

    function proposeAdmin(address _newOwner) external onlyAdmin {
        LibAdministrable._setPendingAdministrator(_newOwner);
    }

    function acceptAdmin() external onlyPendingAdmin {
        LibAdministrable._setAdministrator(LibAdministrable._getPendingAdministrator());
        LibAdministrable._setPendingAdministrator(address(0));
    }

    function getAdministrator() external view returns (address) {
        return LibAdministrable._getAdministrator();
    }

    function getPendingAdministrator() external view returns (address) {
        return LibAdministrable._getPendingAdministrator();
    }
}
