// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../../contracts/src/OperatorsRegistry.1.sol";

/// @title OperatorsRegistryHarness
/// @notice Harness for OperatorsRegistryV1 — exposes internal state for verification.
contract OperatorsRegistryHarness is OperatorsRegistryV1 {

    /// @notice Get operator count
    function getOperatorCountHarness() external view returns (uint256) {
        return OperatorsV2.getCount();
    }

    /// @notice Get operator keys count
    function getOperatorKeys(uint256 _index) external view returns (uint32) {
        return OperatorsV2.get(_index).keys;
    }

    /// @notice Get operator limit
    function getOperatorLimit(uint256 _index) external view returns (uint32) {
        return OperatorsV2.get(_index).limit;
    }

    /// @notice Get operator funded count
    function getOperatorFunded(uint256 _index) external view returns (uint32) {
        return OperatorsV2.get(_index).funded;
    }

    /// @notice Get operator requestedExits count
    function getOperatorRequestedExits(uint256 _index) external view returns (uint32) {
        return OperatorsV2.get(_index).requestedExits;
    }

    /// @notice Get operator active status
    function getOperatorActive(uint256 _index) external view returns (bool) {
        return OperatorsV2.get(_index).active;
    }

    /// @notice Get the River address
    function getRiverHarness() external view returns (address) {
        return RiverAddress.get();
    }

    /// @notice Get admin address
    function getAdminHarness() external view returns (address) {
        return _getAdmin();
    }

    /// @notice Get total validator exits requested
    function getTotalValidatorExitsRequestedHarness() external view returns (uint256) {
        return TotalValidatorExitsRequested.get();
    }

    /// @notice Get current validator exits demand
    function getCurrentValidatorExitsDemandHarness() external view returns (uint256) {
        return CurrentValidatorExitsDemand.get();
    }
}
