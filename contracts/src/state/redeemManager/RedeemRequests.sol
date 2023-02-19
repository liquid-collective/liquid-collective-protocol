//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

/// @title Redeem Manager Redeem Requests storage
/// @notice Utility to manage the Redeem Requests in the Redeem Manager
library RedeemRequests {
    /// @notice Storage slot of the Redeem Requests
    bytes32 internal constant REDEEM_REQUESTS_ID_SLOT = bytes32(uint256(keccak256("river.state.redeemRequests")) - 1);

    /// @notice The Redeemer structure represents the redeem request made by a user
    struct RedeemRequest {
        /// @custom:attribute The height is the cumulative sum of all the sizes of preceding redeem requests
        uint256 height;
        /// @custom:attribute The size of the redeem request in LsETH
        uint256 size;
        /// @custom:attribute The owner of the redeem request
        address owner;
    }

    /// @notice Retrieve the Redeem Requests array storage pointer
    /// @return data The Redeem Requests array storage pointer
    function get() internal pure returns (RedeemRequest[] storage data) {
        bytes32 position = REDEEM_REQUESTS_ID_SLOT;
        assembly {
            data.slot := position
        }
    }
}
