//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

/// @title Redeem Manager Redeemers storage
/// @notice Utility to manage the redeemer accounts in the Redeem Manager
library Redeemers {
    /// @notice Storage slot of the Redeemers
    bytes32 internal constant REDEEMERS_ID_SLOT = bytes32(uint256(keccak256("river.state.redeemers")) - 1);

    /// @notice The Redeemer structure represents an account that interacts with the Redeem Manager
    struct Redeemer {
        /// @custom:attribute The list of redeem request ids created by the redeemer
        uint256[] redeemRequestIds;
        /// @custom:attribute The starting index in the array above
        uint256 startIndex;
    }

    /// @notice Retrieve the Redeemers mapping storage pointer
    /// @return data The Redeemers mapping storage pointer
    function get() internal pure returns (mapping(address => Redeemer) storage data) {
        bytes32 position = REDEEMERS_ID_SLOT;
        assembly {
            data.slot := position
        }
    }
}
