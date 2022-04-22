//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "./libraries/LibOwnable.sol";

contract FunctionPermissionsV1 {
    mapping(bytes4 => uint256) internal permissions;
    uint256 internal constant GOVERNOR_ONLY_MASK = 0x1;
    uint256 internal constant GOVERNOR_OR_ADMIN_MASK = 0x1 << 1;

    function set(bytes4 functionSelector, uint256 newPermission) public {
        permissions[functionSelector] = newPermission;
    }

    /// @notice Prevents unauthorized calls
    function checkPermissions(bytes4 functionSelector) external view {
        // TODO would be nice to use the errors library here to revert with message
        if (permissions[functionSelector] == GOVERNOR_OR_ADMIN_MASK) {
            require(msg.sender == LibOwnable._getGovernor() || msg.sender == LibOwnable._getAdmin());
        } else if (permissions[functionSelector] == GOVERNOR_ONLY_MASK) {
            require(msg.sender == LibOwnable._getGovernor());
        }
    }

    function changePermissions(bytes4 functionSelector, uint256 newPermission) public {
        require(msg.sender == LibOwnable._getGovernor());
        set(functionSelector, newPermission);
    }
}
