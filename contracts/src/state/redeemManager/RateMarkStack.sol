//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

/// @title Redeem Manager Rate Mark Stack storage
/// @notice Utility to manage the Rate Mark Stack in the Redeem Manager
/// @dev Records, per oracle report, the slice of pending redeem demand whose backing principal
///      stopped earning in that reporting interval, together with the pool rate at that report.
///      A redeem request's payout cap is raised to the marked rate over the marked slice, which is
///      what lets a redeemer keep the yield their stake earned while it was still in the exit
///      queue, and stop earning exactly where a native staker would.
///
///      Positions are on the same cumulative-LsETH axis as RedeemQueue heights and WithdrawalStack
///      heights, so a request's marked portion is located the same way its withdrawal event is.
///
///      Unlike WithdrawalStack, this stack is NOT contiguous. A report can settle demand that was
///      never marked (a fill funded from the deposit buffer rather than an exit), which advances the
///      settled height past the mark cursor and leaves a permanent gap. Gaps are meaningful: they
///      are exactly the LsETH that is paid at the request-time rate. Consumers must therefore do a
///      predecessor search and must not assume `height == previous.height + previous.amount`.
library RateMarkStack {
    /// @notice Storage slot of the Rate Mark Stack
    bytes32 internal constant RATE_MARK_STACK_SLOT = bytes32(uint256(keccak256("river.state.rateMarkStack")) - 1);

    /// @notice A rate mark records one report's stopped-earning slice of the redeem queue
    struct RateMark {
        /// @custom:attribute The amount of LsETH marked at this rate
        uint256 amount;
        /// @custom:attribute The ETH value of `amount` at the pool rate of the marking report
        uint256 markedEth;
        /// @custom:attribute The start position of this mark on the cumulative LsETH axis
        uint256 height;
    }

    /// @notice Retrieve the Rate Mark Stack array storage pointer
    /// @return data The Rate Mark Stack array storage pointer
    function get() internal pure returns (RateMark[] storage data) {
        bytes32 position = RATE_MARK_STACK_SLOT;
        assembly {
            data.slot := position
        }
    }
}
