//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.20;

import "../../libraries/LibUnstructuredStorage.sol";

library ExchangeRate {
    bytes32 internal constant EXCHANGE_RATE_SLOT = bytes32(uint256(keccak256("river.state.exchangeRate")) - 1);

    function get() internal view returns (uint256) {
        return LibUnstructuredStorage.getStorageUint256(EXCHANGE_RATE_SLOT);
    }

    function set(uint256 newValue) internal {
        LibUnstructuredStorage.setStorageUint256(EXCHANGE_RATE_SLOT, newValue);
    }
}
