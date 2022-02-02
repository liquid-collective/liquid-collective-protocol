//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "../state/WhitelistorAddress.sol";
import "../state/AdministratorAddress.sol";
import "../state/Whitelist.sol";
import "../libraries/Errors.sol";

/// @title Whitelist Manager (v1)
/// @author Iulian Rotaru
/// @notice This contract handles the whitelist of accounts allowed to own shares
abstract contract WhitelistManagerV1 {
    event ChangedWhitelistStatus(address indexed account, bool status);

    /// @notice Initializes the whitelistor address
    /// @param _whitelistorAddress Address allowed to edit the whitelist
    function whitelistManagerInitializeV1(address _whitelistorAddress)
        internal
    {
        WhitelistorAddress.set(_whitelistorAddress);
    }

    /// @notice Sets the whitelisting status for an account
    /// @param _account Account status to edit
    /// @param _status Whitelist status
    function setWhitelistStatus(address _account, bool _status) external {
        if (
            msg.sender != WhitelistorAddress.get() &&
            msg.sender != AdministratorAddress.get()
        ) {
            revert Errors.Unauthorized(msg.sender);
        }

        Whitelist.set(_account, _status);

        emit ChangedWhitelistStatus(_account, _status);
    }

    function _isWhitelisted(address _account) internal view returns (bool) {
        return Whitelist.get(_account);
    }

    function isWhitelisted(address _account) external view returns (bool) {
        return _isWhitelisted(_account);
    }
}
