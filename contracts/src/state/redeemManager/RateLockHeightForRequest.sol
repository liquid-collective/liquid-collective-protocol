//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

/// @title Redeem Manager Rate Lock Height storage
/// @notice Current rate-lock stack height per redeem request id
library RateLockHeightForRequest {
    bytes32 internal constant RATE_LOCK_HEIGHT_FOR_REQUEST_SLOT =
        bytes32(uint256(keccak256("river.state.rateLockHeightForRequest")) - 1);

    struct Slot {
        mapping(uint32 => uint256) value;
    }

    function get(uint32 requestId) internal view returns (uint256) {
        bytes32 position = RATE_LOCK_HEIGHT_FOR_REQUEST_SLOT;
        Slot storage slot;
        assembly {
            slot.slot := position
        }
        return slot.value[requestId];
    }

    function set(uint32 requestId, uint256 newValue) internal {
        bytes32 position = RATE_LOCK_HEIGHT_FOR_REQUEST_SLOT;
        Slot storage slot;
        assembly {
            slot.slot := position
        }
        slot.value[requestId] = newValue;
    }
}
