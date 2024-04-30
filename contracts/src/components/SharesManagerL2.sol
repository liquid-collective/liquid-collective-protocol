//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.20;

import {SharesManagerV1} from "./SharesManager.1.sol";
import "../state/river/Shares.sol";
import "../state/river/SharesPerOwner.sol";

abstract contract SharesManagerL2 is SharesManagerV1 {
    /// @notice Internal utility to mint shares for the specified user
    /// @dev This method assumes that funds received are now part of the _assetBalance()
    /// @param _owner Account that should receive the new shares
    /// @param _underlyingAssetValue Value of underlying asset received, to convert into shares
    /// @return sharesToMint The amnount of minted shares
    function _mintShares(address _owner, uint256 _underlyingAssetValue)
        internal
        override
        returns (uint256 sharesToMint)
    {
        // Transfer minted shares, received from bridge, based on the underlying asset value & exchange rate
        sharesToMint = _sharesFromBalance(_underlyingAssetValue);
        _transfer(address(this), _owner, sharesToMint);
    }

    /// @notice Internal utility to mint shares without any conversion, and emits a mint Transfer event
    /// @notice Used only by the bridge to create LsETH on L2
    /// @param _owner Account that should receive the new shares
    /// @param _value Amount of shares to mint
    function _mintRawShares(address _owner, uint256 _value) internal override {
        _setTotalSupply(Shares.get() + _value);
        SharesPerOwner.set(_owner, SharesPerOwner.get(_owner) + _value);
        emit Transfer(address(0), _owner, _value);
    }

    /// @notice Internal utility to burn shares without any conversion, and emits a burn Transfer event
    /// @param _owner Account that should burn its shares
    /// @param _value Amount of shares to burn
    function _burnRawShares(address _owner, uint256 _value) internal override {
        _setTotalSupply(Shares.get() - _value);
        SharesPerOwner.set(_owner, SharesPerOwner.get(_owner) - _value);
        emit Transfer(_owner, address(0), _value);
    }
}
