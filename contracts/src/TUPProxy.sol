//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

/// @title TUPProxy (Transparent Upgradeable Pausable Proxy)
/// @author SkillZ
/// @notice This contract extends the Transparent Upgradeable proxy and adds a system wide pause feature.
///         When the system is paused, the fallback will fail no matter what calls are made.
contract TUPProxy is TransparentUpgradeableProxy {
    bytes32 private constant _PAUSE_SLOT = bytes32(uint256(keccak256("eip1967.proxy.pause")) - 1);

    error CallWhenPaused();

    address public constant alluvium;

    // admin_ here should be the DAO, which is confusing because in other places we call
    // Alluvium the admin and the DAO the governor
    constructor(
        address _logic,
        address admin_,
        bytes memory _data,
        address alluvium_
    ) payable TransparentUpgradeableProxy(_logic, admin_, _data) {
        alluvium = alluvium_;
    }

    modifier ifAdminOrAlluvium() {
        if (msg.sender == _getAdmin() || msg.sender == alluvium) {
            _;
        } else {
            _fallback();
        }
    }

    /// @dev Retrieves Paused state
    /// @return Paused state
    function isPaused() external ifAdminOrAlluvium returns (bool) {
        return StorageSlot.getBooleanSlot(_PAUSE_SLOT).value;
    }

    /// @dev Pauses system
    function pause() external ifAdminOrAlluvium {
        StorageSlot.getBooleanSlot(_PAUSE_SLOT).value = true;
    }

    /// @dev Unpauses system
    function unpause() external ifAdminOrAlluvium {
        StorageSlot.getBooleanSlot(_PAUSE_SLOT).value = false;
    }

    /// @dev Overrides the fallback method to check if system is not paused before
    function _beforeFallback() internal override {
        if (StorageSlot.getBooleanSlot(_PAUSE_SLOT).value == true) {
            revert CallWhenPaused();
        }
        super._beforeFallback();
    }
}
