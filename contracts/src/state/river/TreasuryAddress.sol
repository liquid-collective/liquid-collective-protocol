//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "../../libraries/UnstructuredStorage.sol";

library TreasuryAddress {
    /* Hardcoding: bytes32(uint256(keccak256("river.state.treasuryAddress")) - 1) */
    bytes32 internal constant TREASURY_ADDRESS_SLOT = hex"aa490d1834c76465b09f09618af9f91fbbd04c30f1f453b24b1e8f907c9e1fa2";

    function get() internal view returns (address) {
        return UnstructuredStorage.getStorageAddress(TREASURY_ADDRESS_SLOT);
    }

    function set(address newValue) internal {
        UnstructuredStorage.setStorageAddress(TREASURY_ADDRESS_SLOT, newValue);
    }
}
