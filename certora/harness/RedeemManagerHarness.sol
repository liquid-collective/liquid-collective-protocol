// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../../contracts/src/RedeemManager.1.sol";

/// @title RedeemManagerHarness
/// @notice Harness for RedeemManagerV1 that exposes internal state needed for formal verification.
contract RedeemManagerHarness is RedeemManagerV1 {

    /// @notice Expose the redeem demand
    function getRedeemDemandHarness() external view returns (uint256) {
        return RedeemDemand.get();
    }

    /// @notice Expose the redeem request count
    function getRedeemRequestCountHarness() external view returns (uint256) {
        return RedeemQueueV2.get().length;
    }

    /// @notice Expose the withdrawal event count
    function getWithdrawalEventCountHarness() external view returns (uint256) {
        return WithdrawalStack.get().length;
    }

    /// @notice Expose the River address
    function getRiverHarness() external view returns (address) {
        return RiverAddress.get();
    }

    /// @notice Expose the height field of a redeem request by index
    function getRedeemRequestHeight(uint32 _id) external view returns (uint256) {
        return RedeemQueueV2.get()[_id].height;
    }

    /// @notice Expose the amount field of a redeem request by index
    function getRedeemRequestAmount(uint32 _id) external view returns (uint256) {
        return RedeemQueueV2.get()[_id].amount;
    }

    /// @notice Expose the maxRedeemableEth field of a redeem request by index
    function getRedeemRequestMaxRedeemableEth(uint32 _id) external view returns (uint256) {
        return RedeemQueueV2.get()[_id].maxRedeemableEth;
    }

    /// @notice Expose the BufferedExceedingEth value
    function getBufferedExceedingEthHarness() external view returns (uint256) {
        return BufferedExceedingEth.get();
    }
}
