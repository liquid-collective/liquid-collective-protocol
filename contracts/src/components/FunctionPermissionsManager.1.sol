//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "../libraries/LibOwnable.sol";

abstract contract FunctionPermissionsManagerV1 {
    mapping(bytes4 => uint256) permissions;
    uint256 internal constant GOVERNOR_ONLY_MASK = 0x1;
    uint256 internal constant GOVERNOR_OR_ADMIN_MASK = 0x1 << 1;

    function get(bytes4 functionSelector) internal view returns (uint) {
        return permissions[functionSelector];
    }

    function set(bytes4 functionSelector, uint256 newPermission) internal {
        permissions[functionSelector] = newPermission;
    }

    /// @notice Prevents unauthorized calls
    function checkPermissions(bytes4 functionSelector) internal view {
        // TODO would be nice to use the errors library here to revert with message
        if (get(functionSelector) == GOVERNOR_OR_ADMIN_MASK) {
            require(msg.sender == LibOwnable._getGovernor() || msg.sender == LibOwnable._getAdmin());
        } else if (get(functionSelector) == GOVERNOR_ONLY_MASK) {
            require(msg.sender == LibOwnable._getGovernor());
        }
    }

    function changePermissions(bytes4 functionSelector, uint256 newPermission) external {
        require(msg.sender == LibOwnable._getGovernor());
        set(functionSelector, newPermission);
    }
}
