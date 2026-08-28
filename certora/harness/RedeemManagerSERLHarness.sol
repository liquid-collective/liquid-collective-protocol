// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import {RedeemManagerV1, WithdrawalStack} from "contracts/src/RedeemManager.1.sol";
import "contracts/src/state/redeemManager/RedeemQueue.2.sol";
import "contracts/src/state/redeemManager/RateMarkStack.sol";
import "contracts/src/state/redeemManager/RedeemRequestAnchor.sol";
import "contracts/src/state/redeemManager/RateMarkFloor.sol";

/// @title Redeem Manager SERL harness
/// @notice Certora harness exposing the stopped-earning rate-lock (SERL) internals of RedeemManagerV1
/// @dev Kept separate from `RedeemManagerV1Harness` on purpose. That harness is referenced by
///      `conf/RedeemManagerV1.conf` and `confs_for_CI/RedeemManagerV1.conf`, both of which also pull in
///      `RiverV1Harness` and therefore do not currently compile (see certora/README.md). Adding methods
///      there would also widen the parametric method set of the existing specs, which have recorded
///      runtimes tuned to their current set. This harness stands alone and only adds `view` functions,
///      so it changes no production behaviour and no existing rule.
///
///      Every index-taking getter returns 0 out of bounds rather than reverting, matching the style of
///      `RedeemManagerV1Harness`. Rules must bound the index themselves before reading.
contract RedeemManagerSERLHarness is RedeemManagerV1 {
    // ---------------------------------------------------------------------------------------------
    // Rate mark stack
    // ---------------------------------------------------------------------------------------------

    function getRateMarkHeight(uint32 id) external view returns (uint256) {
        if (id >= RateMarkStack.get().length) return 0;
        return RateMarkStack.get()[id].height;
    }

    function getRateMarkAmount(uint32 id) external view returns (uint256) {
        if (id >= RateMarkStack.get().length) return 0;
        return RateMarkStack.get()[id].amount;
    }

    function getRateMarkEth(uint32 id) external view returns (uint256) {
        if (id >= RateMarkStack.get().length) return 0;
        return RateMarkStack.get()[id].markedEth;
    }

    /// @notice The first LsETH position not yet covered by any rate mark
    function rateMarkCursor() external view returns (uint256) {
        return _rateMarkCursor();
    }

    /// @notice The amount of LsETH demand settled by withdrawal events so far
    function settledHeight() external view returns (uint256) {
        return _settledHeight();
    }

    /// @notice The end position of the redeem queue, i.e. all LsETH ever queued for redemption
    /// @dev Mirrors the computation in `reportStoppedEarning`. Invariant across a request's lifetime,
    ///      because a claim raises `height` and lowers `amount` by the same value.
    function totalRequestedHeight() external view returns (uint256) {
        RedeemQueueV2.RedeemRequest[] storage redeemRequests = RedeemQueueV2.get();
        uint256 requestCount = redeemRequests.length;
        if (requestCount == 0) return 0;
        RedeemQueueV2.RedeemRequest storage lastRequest = redeemRequests[requestCount - 1];
        return lastRequest.height + lastRequest.amount;
    }

    /// @notice Whether any mark starts at or before `height` (first return of `_findRateMarkAtOrBefore`)
    function rateMarkFoundAtOrBefore(uint256 height) external view returns (bool found) {
        (found,) = _findRateMarkAtOrBefore(height);
    }

    /// @notice The index of the last mark starting at or before `height` (second return of
    ///         `_findRateMarkAtOrBefore`); meaningless unless `rateMarkFoundAtOrBefore` is true
    function rateMarkIndexAtOrBefore(uint256 height) external view returns (uint256 index) {
        (, index) = _findRateMarkAtOrBefore(height);
    }

    // ---------------------------------------------------------------------------------------------
    // Redeem request anchors
    // ---------------------------------------------------------------------------------------------

    /// @notice The LsETH leg of a request's request-time valuation; 0 means the request predates the upgrade
    function getAnchorLsETH(uint32 id) external view returns (uint256) {
        return RedeemRequestAnchor.get()[id].lsETHAtRequest;
    }

    /// @notice The ETH leg of a request's request-time valuation
    function getAnchorEth(uint32 id) external view returns (uint256) {
        return RedeemRequestAnchor.get()[id].ethAtRequest;
    }

    // ---------------------------------------------------------------------------------------------
    // Slice cap
    // ---------------------------------------------------------------------------------------------

    /// @notice `_sliceCap` with the anchor passed as loose fields so a rule can quantify over it
    ///         without needing a request to exist
    function sliceCap(uint256 lsETHAtRequest, uint256 ethAtRequest, uint256 sliceStart, uint256 sliceAmount)
        external
        view
        returns (uint256)
    {
        return _sliceCap(
            RedeemRequestAnchor.Anchor({lsETHAtRequest: lsETHAtRequest, ethAtRequest: ethAtRequest}),
            sliceStart,
            sliceAmount
        );
    }

    /// @notice The cap the claim path would apply to a slice of a live request, including the
    ///         pre-upgrade branch taken when the anchor is unset
    /// @dev Mirrors the cap selection in `_claimRedeemRequest` exactly, so a rule can compare the two
    ///      branches without stepping through a claim.
    function capForRequestSlice(uint32 id, uint256 matchingAmount) external view returns (uint256) {
        RedeemQueueV2.RedeemRequest[] storage redeemRequests = RedeemQueueV2.get();
        if (id >= redeemRequests.length) return 0;
        RedeemQueueV2.RedeemRequest storage request = redeemRequests[id];
        RedeemRequestAnchor.Anchor memory anchor = RedeemRequestAnchor.get()[id];
        if (anchor.lsETHAtRequest == 0) {
            if (request.amount == 0) return 0;
            return (matchingAmount * request.maxRedeemableEth) / request.amount;
        }
        return _sliceCap(anchor, request.height, matchingAmount);
    }

    // ---------------------------------------------------------------------------------------------
    // Redeem queue / withdrawal stack scalars
    // ---------------------------------------------------------------------------------------------

    function getRedeemRequestHeight(uint32 id) external view returns (uint256) {
        if (id >= RedeemQueueV2.get().length) return 0;
        return RedeemQueueV2.get()[id].height;
    }

    function getRedeemRequestAmount(uint32 id) external view returns (uint256) {
        if (id >= RedeemQueueV2.get().length) return 0;
        return RedeemQueueV2.get()[id].amount;
    }

    function getRedeemRequestMaxRedeemableEth(uint32 id) external view returns (uint256) {
        if (id >= RedeemQueueV2.get().length) return 0;
        return RedeemQueueV2.get()[id].maxRedeemableEth;
    }

    function getWithdrawalEventHeight(uint32 id) external view returns (uint256) {
        if (id >= WithdrawalStack.get().length) return 0;
        return WithdrawalStack.get()[id].height;
    }

    function getWithdrawalEventAmount(uint32 id) external view returns (uint256) {
        if (id >= WithdrawalStack.get().length) return 0;
        return WithdrawalStack.get()[id].amount;
    }

    function getWithdrawalEventWithdrawnEth(uint32 id) external view returns (uint256) {
        if (id >= WithdrawalStack.get().length) return 0;
        return WithdrawalStack.get()[id].withdrawnEth;
    }

    // ---------------------------------------------------------------------------------------------
    // Claim status constants
    // ---------------------------------------------------------------------------------------------

    function get_CLAIM_FULLY_CLAIMED() external pure returns (uint8) {
        return CLAIM_FULLY_CLAIMED;
    }

    function get_CLAIM_PARTIALLY_CLAIMED() external pure returns (uint8) {
        return CLAIM_PARTIALLY_CLAIMED;
    }

    function get_CLAIM_SKIPPED() external pure returns (uint8) {
        return CLAIM_SKIPPED;
    }
}
