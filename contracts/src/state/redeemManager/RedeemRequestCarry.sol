//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

/// @title Redeem Request Carry storage
/// @notice Records cap credited to a redeem request by earlier fills but not paid out
/// @dev Side-car to RedeemRequestAnchor rather than a third field on `Anchor`, so the anchor stays
///      literally write-once.
///
///      When a slice settles below its cap, the unspent difference is carried to the next fill rather
///      than swept to `BufferedExceedingEth`. This preserves the pre-upgrade behavior where caps derive
///      from `maxRedeemableEth`, which decrements by actual ETH paid, not the offered cap.
///
///      This only raises caps by adding to `_sliceCap`, preserving the mark's locked rate and keeping
///      the aggregate bounded by the mark-aware value, not `Anchor.ethAtRequest`.
library RedeemRequestCarry {
    /// @notice Storage slot of the Redeem Request Carry mapping
    bytes32 internal constant REDEEM_REQUEST_CARRY_SLOT =
        bytes32(uint256(keccak256("river.state.redeemRequestCarry")) - 1);

    /// @notice Retrieve the Redeem Request Carry mapping storage pointer
    /// @return data The Redeem Request Carry mapping storage pointer
    function get() internal pure returns (mapping(uint32 => uint256) storage data) {
        bytes32 position = REDEEM_REQUEST_CARRY_SLOT;
        assembly {
            data.slot := position
        }
    }
}
