//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "./Initializable.sol";
import "./libraries/LibErrors.sol";

import "./state/allowlist/AllowerAddress.sol";
import "./state/allowlist/Allowlist.sol";

import "./interfaces/IAllowlist.1.sol";
import "./Administrable.sol";

/// @title Allowlist (v1)
/// @author Kiln
/// @notice This contract handles the list of allowed recipients.
contract AllowlistV1 is IAllowlistV1, Initializable, Administrable {
    uint256 internal constant DENY_MASK = 0x1 << 255;

    /// @notice Initializes the allowlist
    /// @param _admin Address of the Allowlist administrator
    /// @param _allower Address of the allower
    function initAllowlistV1(address _admin, address _allower) external init(0) {
        _setAdmin(_admin);
        AllowerAddress.set(_allower);
        emit SetAllower(_allower);
    }

    /// @notice Changes the allower address
    /// @param _newAllowerAddress New address allowed to edit the allowlist
    function setAllower(address _newAllowerAddress) external onlyAdmin {
        AllowerAddress.set(_newAllowerAddress);
        emit SetAllower(_newAllowerAddress);
    }

    /// @notice Retrieves the allower address
    function getAllower() external view returns (address) {
        return AllowerAddress.get();
    }

    /// @notice Sets the allowlisting status for one or more accounts
    /// @param _accounts Accounts with statuses to edit
    /// @param _permissions Allowlist permissions for each account, in the same order as _accounts
    function allow(address[] calldata _accounts, uint256[] calldata _permissions) external {
        if (msg.sender != AllowerAddress.get() && msg.sender != _getAdmin()) {
            revert LibErrors.Unauthorized(msg.sender);
        }

        if (_accounts.length == 0) {
            revert InvalidAlloweeCount();
        }

        if (_accounts.length != _permissions.length) {
            revert MismatchedAlloweeAndStatusCount();
        }

        for (uint256 i = 0; i < _accounts.length;) {
            LibSanitize._notZeroAddress(_accounts[i]);
            Allowlist.set(_accounts[i], _permissions[i]);
            unchecked {
                ++i;
            }
        }

        emit SetAllowlistPermissions(_accounts, _permissions);
    }

    /// @notice This method should be used as a modifier and is expected to revert
    ///         if the user hasn't got the required permission or if the user is
    ///         in the deny list.
    /// @param _account Recipient to verify
    /// @param _mask Combination of permissions to verify
    function onlyAllowed(address _account, uint256 _mask) external view {
        uint256 userPermissions = Allowlist.get(_account);
        if (userPermissions & DENY_MASK == DENY_MASK) {
            revert Denied(_account);
        }
        if (userPermissions & _mask != _mask) {
            revert Unauthorized(_account);
        }
    }

    /// @notice This method returns true if the user has the expected permission and
    ///         is not in the deny list
    /// @param _account Recipient to verify
    /// @param _mask Combination of permissions to verify
    function isAllowed(address _account, uint256 _mask) external view returns (bool) {
        uint256 userPermissions = Allowlist.get(_account);
        if (userPermissions & DENY_MASK == DENY_MASK) {
            return false;
        }
        return userPermissions & _mask == _mask;
    }

    /// @notice This method returns true if the user is in the deny list
    /// @param _account Recipient to verify
    function isDenied(address _account) external view returns (bool) {
        return Allowlist.get(_account) & DENY_MASK == DENY_MASK;
    }

    /// @notice This method returns true if the user has the expected permission
    ///         ignoring any deny list membership
    /// @param _account Recipient to verify
    /// @param _mask Combination of permissions to verify
    function hasPermission(address _account, uint256 _mask) external view returns (bool) {
        return Allowlist.get(_account) & _mask == _mask;
    }

    /// @notice This method retrieves the raw permission value
    /// @param _account Recipient to verify
    function getPermissions(address _account) external view returns (uint256) {
        return Allowlist.get(_account);
    }
}
