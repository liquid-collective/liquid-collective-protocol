//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract TUPProxy is TransparentUpgradeableProxy {
    bytes32 private constant _PAUSE_SLOT =
        bytes32(uint256(keccak256("eip1967.proxy.pause")) - 1);

    constructor(
        address _logic,
        address admin_,
        bytes memory _data
    ) payable TransparentUpgradeableProxy(_logic, admin_, _data) {}

    /// @dev Retrieves Paused state
    /// @return Paused state
    function isPaused() external ifAdmin returns (bool) {
        return StorageSlot.getBooleanSlot(_PAUSE_SLOT).value;
    }

    /// @dev Pauses system
    function pause() external ifAdmin {
        StorageSlot.getBooleanSlot(_PAUSE_SLOT).value = true;
    }

    /// @dev Unpauses system
    function unpause() external ifAdmin {
        StorageSlot.getBooleanSlot(_PAUSE_SLOT).value = false;
    }

    modifier isNotPaused() {
        require(
            StorageSlot.getBooleanSlot(_PAUSE_SLOT).value == false,
            "system paused"
        );
        _;
    }

    function _beforeFallback() internal override isNotPaused {
        super._beforeFallback();
    }
}
