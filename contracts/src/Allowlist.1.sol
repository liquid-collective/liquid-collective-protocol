//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "./Initializable.sol";
import "./libraries/Errors.sol";
import "./libraries/LibOwnable.sol";
import "./interfaces/IRiverOracleInput.sol";

import "./state/allowlist/AllowerAddress.sol";
import "./state/allowlist/Allowlist.sol";

/// @title Allowlist (v1)
/// @author SkillZ
/// @notice This contract handles the list of allowed recipients.
contract AllowlistV1 is Initializable {
    error InvalidAlloweeCount();
    error MismatchedAlloweeAndStatusCount();
    event ChangedAllowlistStatuses(address[] indexed accounts, uint256[] statuses);

    /// @notice Initializes the allowlist
    /// @param _admin Address of the Allowlist administrator
    /// @param _allower Address of the allower
    function initAllowlistV1(address _admin, address _allower) external init(0) {
        LibOwnable._setAdmin(_admin);
        AllowerAddress.set(_allower);
    }

    /// @notice Prevents unauthorized calls
    modifier onlyAdmin() virtual {
        if (msg.sender != LibOwnable._getAdmin()) {
            revert Errors.Unauthorized(msg.sender);
        }
        _;
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
    function allow(address[] calldata _accounts, uint256[] calldata _statuses) external {
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

    function _isAllowed(address _account, uint256 _mask) internal view returns (bool) {
        return Allowlist.get(_account) & _mask == _mask;
    }

    function isAllowed(address _account, uint256 _mask) external view returns (bool) {
        return _isAllowed(_account, _mask);
    }
}
