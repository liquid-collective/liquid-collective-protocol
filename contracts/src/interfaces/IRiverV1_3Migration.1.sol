//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

/// @title River V1.3 Migration Interface
/// @author Alluvial Finance Inc.
/// @notice Delegatecall target interface for River's one-time V1.3 storage migration.
interface IRiverV1_3Migration {
    function migrate(
        bytes32 _withdrawalCredentials,
        address _consolidationCoverageFund,
        address _attestationVerifier,
        address _consolidationManager,
        address _fundingDeltasBuilder,
        address _depositExecutor
    ) external;
}
