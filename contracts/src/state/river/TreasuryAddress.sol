//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "../../libraries/UnstructuredStorage.sol";

library TreasuryAddress {
    bytes32 internal constant TREASURY_ADDRESS_SLOT = bytes32(uint256(keccak256("river.state.treasuryAddress")) - 1);

    function get() internal view returns (address) {
        return UnstructuredStorage.getStorageAddress(TREASURY_ADDRESS_SLOT);
    }

    function set(address newValue) internal {
        UnstructuredStorage.setStorageAddress(TREASURY_ADDRESS_SLOT, newValue);
    }
}
