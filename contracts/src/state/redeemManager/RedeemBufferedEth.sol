//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "../../libraries/LibUnstructuredStorage.sol";

/// @title Redeem Buffered Eth Storage
/// @notice Utility to manage the redeem buffered eth Redeem Manager
library RedeemBufferedEth {
    /// @notice Storage slot of the Redeem Buffered Eth
    bytes32 internal constant REDEEM_BUFFERED_ETH_SLOT =
        bytes32(uint256(keccak256("river.state.redeemBufferedEth")) - 1);

    /// @notice Retrieve the Redeem Buffered Eth Value
    /// @return The Redeem Buffered Eth Value
    function get() internal view returns (uint256) {
        return LibUnstructuredStorage.getStorageUint256(REDEEM_BUFFERED_ETH_SLOT);
    }

    /// @notice Sets the Redeem Buffered Eth Value
    /// @param newValue The new value
    function set(uint256 newValue) internal {
        LibUnstructuredStorage.setStorageUint256(REDEEM_BUFFERED_ETH_SLOT, newValue);
    }
}
