//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "../libraries/Errors.sol";

import "../state/shared/AdministratorAddress.sol";
import "../state/river/AllowerAddress.sol";
import "../state/river/Allowlist.sol";
import "../libraries/LibOwnable.sol";

/// @title Allowlist Manager (v1)
/// @author SkillZ
/// @notice This contract handles the allowlist of accounts allowed to own shares
abstract contract AllowlistManagerV1 {
    error InvalidAlloweeCount();
    error MismatchedAlloweeAndStatusCount();

    event ChangedAllowlistStatuses(address[] indexed accounts, bool[] statuses);

    /// @notice Prevents unauthorized calls
    modifier onlyAdmin() virtual {
        if (msg.sender != LibOwnable._getAdmin()) {
            revert Errors.Unauthorized(msg.sender);
        }
        _;
    }

    /// @notice Initializes the allower address
    /// @param _allowerAddress Address allowed to edit the allowlist
    function initAllowlistManagerV1(address _allowerAddress) internal {
        AllowerAddress.set(_allowerAddress);
    }

    /// @notice Changes the allower address
    /// @param _newAllowerAddress New address allowed to edit the allowlist
    function setAllower(address _newAllowerAddress) external onlyAdmin {
        AllowerAddress.set(_newAllowerAddress);
    }

    /// @notice Retrieves the allower address
    function getAllower() external view returns (address) {
        return AllowerAddress.get();
    }

    /// @notice Sets the allowlisting status for one or more accounts
    /// @param _accounts Accounts with statuses to edit
    /// @param _statuses Allowlist statuses for each account, in the same order as _accounts
    function allow(address[] calldata _accounts, bool[] calldata _statuses) external {
        if (msg.sender != AllowerAddress.get() && msg.sender != AdministratorAddress.get()) {
            revert Errors.Unauthorized(msg.sender);
        }

        if (_accounts.length == 0) {
            revert InvalidAlloweeCount();
        }

        if (_accounts.length != _statuses.length) {
            revert MismatchedAlloweeAndStatusCount();
        }

        for (uint256 i = 0; i < _accounts.length; ) {
            Allowlist.set(_accounts[i], _statuses[i]);
            unchecked {
                ++i;
            }
        }

        emit ChangedAllowlistStatuses(_accounts, _statuses);
    }

    function _isAllowed(address _account) internal view returns (bool) {
        return Allowlist.get(_account);
    }

    function isAllowed(address _account) external view returns (bool) {
        return _isAllowed(_account);
    }
}
