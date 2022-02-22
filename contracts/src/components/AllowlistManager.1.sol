//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "../libraries/Errors.sol";

import "../state/shared/AdministratorAddress.sol";
import "../state/river/AllowerAddress.sol";
import "../state/river/Allowlist.sol";

/// @title Allowlist Manager (v1)
/// @author SkillZ
/// @notice This contract handles the allowlist of accounts allowed to own shares
abstract contract AllowlistManagerV1 {
    event ChangedAllowlistStatus(address indexed account, bool status);

    /// @notice Initializes the allower address
    /// @param _allowerAddress Address allowed to edit the allowlist
    function initAllowlistManagerV1(address _allowerAddress) internal {
        AllowerAddress.set(_allowerAddress);
    }

    /// @notice Sets the allowlisting status for an account
    /// @param _account Account status to edit
    /// @param _status Allowlist status
    function allow(address _account, bool _status) external {
        if (msg.sender != AllowerAddress.get() && msg.sender != AdministratorAddress.get()) {
            revert Errors.Unauthorized(msg.sender);
        }

        Allowlist.set(_account, _status);

        emit ChangedAllowlistStatus(_account, _status);
    }

    function _isAllowed(address _account) internal view returns (bool) {
        return Allowlist.get(_account);
    }

    function isAllowed(address _account) external view returns (bool) {
        return _isAllowed(_account);
    }
}
