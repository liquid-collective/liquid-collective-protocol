//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../../libraries/LibUnstructuredStorage.sol";

/// @title Attesters
/// @notice Unstructured storage library for the attester set and count.
///         Attester membership uses a slot-based mapping:
///         slot = keccak256(abi.encode(ATTESTER_MAPPING_BASE_SLOT, account))
library Attesters {
    bytes32 internal constant ATTESTER_MAPPING_BASE_SLOT =
        bytes32(uint256(keccak256("river.state.attesters.mapping")) - 1);

    bytes32 internal constant ATTESTER_COUNT_SLOT = bytes32(uint256(keccak256("river.state.attesters.count")) - 1);

    function isAttester(address account) internal view returns (bool) {
        bytes32 slot = keccak256(abi.encode(ATTESTER_MAPPING_BASE_SLOT, account));
        return LibUnstructuredStorage.getStorageBool(slot);
    }

    function setAttester(address account, bool value) internal {
        bytes32 slot = keccak256(abi.encode(ATTESTER_MAPPING_BASE_SLOT, account));
        LibUnstructuredStorage.setStorageBool(slot, value);
    }

    function getCount() internal view returns (uint256) {
        return LibUnstructuredStorage.getStorageUint256(ATTESTER_COUNT_SLOT);
    }

    function setCount(uint256 count) internal {
        LibUnstructuredStorage.setStorageUint256(ATTESTER_COUNT_SLOT, count);
    }
}
