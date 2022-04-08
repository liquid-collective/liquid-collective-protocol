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
    event ChangedAllowlistStatus(address indexed account, uint256 status);

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

    /// @notice Sets the allowlisting status for an account
    /// @param _account Account status to edit
    /// @param _status Allowlist status
    function allow(address _account, uint256 _status) external {
        if (msg.sender != AllowerAddress.get() && msg.sender != AdministratorAddress.get()) {
            revert Errors.Unauthorized(msg.sender);
        }

        Allowlist.set(_account, _status);

        emit ChangedAllowlistStatus(_account, _status);
    }

    function _isAllowed(address _account, uint256 _mask) internal view returns (bool) {
        return Allowlist.get(_account) & _mask == _mask;
    }

    function isAllowed(address _account, uint256 _mask) external view returns (bool) {
        return _isAllowed(_account, _mask);
    }
}
