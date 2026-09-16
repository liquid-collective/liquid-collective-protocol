//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

/// @title Redeem Request Anchor storage
/// @notice Records the request-time valuation of a redeem request, and how much of it has since been
///         credited at a locked rate
/// @dev Side-car to RedeemQueueV2 rather than extra fields on RedeemRequest. The queue is a dynamic
///      array at a raw keccak slot with a stride of 5 words, so widening the struct would shift every
///      existing element (a live-deployment migration over every historical request) and would break
///      the public ABI of `getRedeemRequestDetails`, which returns the struct by value. A mapping at
///      its own slot costs the same SSTOREs at write time and needs no migration.
///
///      `lsETHAtRequest` and `ethAtRequest` are the request-time rate, written once and never again.
///      They cannot live in `RedeemQueueV2.maxRedeemableEth`, which is a running eth balance both
///      payout paths debit by the eth actually paid, so the rate it implies drifts away from the
///      request rate on the first fill. The pair is stored rather than a precomputed rate so the cap
///      arithmetic stays integer-exact and in the same pro-rata form the claim path already uses.
///
///      `creditedLsETH` is the part of the request's remaining LsETH whose backing principal has
///      stopped earning, so it is already valued in `maxRedeemableEth` and must not be valued again
///      at the request rate when it settles. It rises as reports credit the request and falls as
///      claims consume it. The two counters are separate because the eth is a balance that carries
///      unspent cap between fills while the LsETH is a width, and a single number cannot answer both
///      "how much have we credited" and "how much is still to be priced at the request rate".
///
///      A zero `lsETHAtRequest` means the request predates this upgrade. Such requests are never
///      credited and are always paid under the original rules, which is how the launch cutover is
///      enforced without a positional floor. Reports still consume credit against them rather than
///      passing it on, because handing it to the first post-upgrade cohort would lock that cohort at
///      today's rate months before its own principal stops earning.
library RedeemRequestAnchor {
    /// @notice Storage slot of the Redeem Request Anchor mapping
    bytes32 internal constant REDEEM_REQUEST_ANCHOR_SLOT =
        bytes32(uint256(keccak256("river.state.redeemRequestAnchor")) - 1);

    /// @notice The request-time valuation of a redeem request, and its credited width
    struct Anchor {
        /// @custom:attribute The LsETH amount the request was opened with. Write-once
        uint256 lsETHAtRequest;
        /// @custom:attribute The ETH value of `lsETHAtRequest` at the pool rate when the request was opened. Write-once
        uint256 ethAtRequest;
        /// @custom:attribute The part of the request's remaining LsETH already credited at a locked rate
        uint256 creditedLsETH;
    }

    /// @notice Retrieve the Redeem Request Anchor mapping storage pointer
    /// @return data The Redeem Request Anchor mapping storage pointer
    function get() internal pure returns (mapping(uint32 => Anchor) storage data) {
        bytes32 position = REDEEM_REQUEST_ANCHOR_SLOT;
        assembly {
            data.slot := position
        }
    }
}
