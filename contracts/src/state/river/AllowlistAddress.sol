//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "../../libraries/UnstructuredStorage.sol";
import "../../interfaces/IAllowlist.sol";

library AllowlistAddress {
    bytes32 internal constant ALLOWLIST_ADDRESS_SLOT = bytes32(uint256(keccak256("river.state.allowlistAddress")) - 1);

    function get() internal view returns (IAllowlist) {
        return IAllowlist(UnstructuredStorage.getStorageAddress(ALLOWLIST_ADDRESS_SLOT));
    }

    function set(address newValue) internal {
        UnstructuredStorage.setStorageAddress(ALLOWLIST_ADDRESS_SLOT, newValue);
    }
}
