// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../../contracts/src/Allowlist.1.sol";

/// @title AllowlistHarness
/// @notice Harness for AllowlistV1 that exposes internal state needed for formal verification.
contract AllowlistHarness is AllowlistV1 {

    /// @notice Expose the raw permission value for an account
    function getPermissionsHarness(address _account) external view returns (uint256) {
        return Allowlist.get(_account);
    }

    /// @notice Check if an account has the DENY_MASK bit set
    function isDeniedHarness(address _account) external view returns (bool) {
        return Allowlist.get(_account) & LibAllowlistMasks.DENY_MASK == LibAllowlistMasks.DENY_MASK;
    }

    /// @notice Get the allower address
    function getAllowerHarness() external view returns (address) {
        return AllowerAddress.get();
    }

    /// @notice Get the denier address
    function getDenierHarness() external view returns (address) {
        return DenierAddress.get();
    }

    /// @notice Get the DENY_MASK constant
    function getDenyMask() external pure returns (uint256) {
        return LibAllowlistMasks.DENY_MASK;
    }

    /// @notice Get the admin address
    function getAdminHarness() external view returns (address) {
        return _getAdmin();
    }
}
