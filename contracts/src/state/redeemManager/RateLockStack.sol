//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

/// @title Redeem Manager Rate Lock Stack storage
/// @notice FIFO stack of inactive ETH rate-lock events in redeem-request LsETH height space
library RateLockStack {
    bytes32 internal constant RATE_LOCK_STACK_ID_SLOT = bytes32(uint256(keccak256("river.state.rateLockStack")) - 1);

    struct RateLockEvent {
        uint256 amount;
        uint256 ethAmount;
        uint256 height;
    }

    function get() internal pure returns (RateLockEvent[] storage data) {
        bytes32 position = RATE_LOCK_STACK_ID_SLOT;
        assembly {
            data.slot := position
        }
    }
}
