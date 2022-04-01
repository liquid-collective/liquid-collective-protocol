//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "../../libraries/UnstructuredStorage.sol";

library Shares {
    /* Hardcoded hex is: bytes32(uint256(keccak256("river.state.shares")) - 1) */
    bytes32 internal constant SHARES_SLOT = hex"6b842b424335d94ccad97e54548dfa02673c1268aba38d3c3c32d28c8988b70a";

    function get() internal view returns (uint256) {
        return UnstructuredStorage.getStorageUint256(SHARES_SLOT);
    }

    function set(uint256 newValue) internal {
        UnstructuredStorage.setStorageUint256(SHARES_SLOT, newValue);
    }
}
