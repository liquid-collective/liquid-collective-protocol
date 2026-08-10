//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

/// @title Redeem Request Anchor storage
/// @notice Records the immutable request-time valuation of a redeem request
/// @dev Side-car to RedeemQueueV2 rather than extra fields on RedeemRequest. The queue is a dynamic
///      array at a raw keccak slot with a stride of 5 words, so widening the struct would shift every
///      existing element (a live-deployment migration over every historical request) and would break
///      the public ABI of `getRedeemRequestDetails`, which returns the struct by value. A mapping at
///      its own slot costs the same SSTOREs at write time and needs no migration.
///
///      This exists because `RedeemRequest.maxRedeemableEth` cannot serve as the request-time rate.
///      It is a decrementing ETH budget: the claim path subtracts the ETH actually paid from it, so
///      `maxRedeemableEth / amount` equals the request-time rate only at creation. After a partial
///      claim settled below the request rate the implied ratio drifts upward without bound — see
///      `testPartialClaimBelowRequestRateDriftsImpliedCapRate`, where 100 LsETH quoted at 1.0 leaves
///      a residual implied rate of 50.5 ETH per LsETH.
///
///      The pair is stored rather than a precomputed rate so the cap arithmetic stays integer-exact
///      and in the same pro-rata form the claim path already uses.
///
///      A zero `lsETHAtRequest` means the request predates this upgrade. Such requests are never
///      marked and are always paid under the original rules, which is also how the launch cutover is
///      enforced (the PRD excludes retroactive application).
library RedeemRequestAnchor {
    /// @notice Storage slot of the Redeem Request Anchor mapping
    bytes32 internal constant REDEEM_REQUEST_ANCHOR_SLOT =
        bytes32(uint256(keccak256("river.state.redeemRequestAnchor")) - 1);

    /// @notice The request-time valuation of a redeem request
    struct Anchor {
        /// @custom:attribute The LsETH amount the request was opened with
        uint256 lsETHAtRequest;
        /// @custom:attribute The ETH value of `lsETHAtRequest` at the pool rate when the request was opened
        uint256 ethAtRequest;
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
