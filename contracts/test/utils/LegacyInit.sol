// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../../src/Allowlist.1.sol";
import "../../src/CoverageFund.1.sol";
import "../../src/ELFeeRecipient.1.sol";
import "../../src/OperatorsRegistry.1.sol";
import "../../src/Oracle.1.sol";
import "../../src/ProtocolMetrics.1.sol";
import "../../src/RedeemManager.1.sol";
import "../../src/Withdraw.1.sol";

// The V1-format state libraries are no longer referenced by contracts/src — the only readers
// left are the migration bodies restored below.
import "../../src/state/operatorsRegistry/Operators.1.sol";
import "../../src/state/redeemManager/RedeemQueue.1.sol";

/// @title LegacyInit (test-only)
/// @author Alluvial Finance Inc.
/// @notice Test subclasses that add back the initializers removed from the production contracts.
/// @dev Every deployed proxy has already advanced past these `init(N)` versions (or, for TLC, past the
///      OpenZeppelin `_initialized` value), so the production implementations no longer ship them —
///      they can never be re-run onchain and only cost bytecode. The bodies below are byte-for-byte
///      copies of what previously lived in contracts/src, kept so tests can still bootstrap fresh
///      instances from genesis state and so the fork tests can replay the historical migrations.
///      Keep them in lockstep with the mainnet initialization sequence; do not "improve" them.
///
///      This mirrors the pattern already established for River in RiverV1WithLegacyInit.sol.

/// @notice AllowlistV1 with the v1.0 and v1.1 initializers restored.
contract AllowlistV1WithLegacyInit is AllowlistV1 {
    function initAllowlistV1(address _admin, address _allower) external init(0) {
        _setAdmin(_admin);
        AllowerAddress.set(_allower);
        emit SetAllower(_allower);
    }

    function initAllowlistV1_1(address _denier) external init(1) {
        DenierAddress.set(_denier);
        emit SetDenier(_denier);
    }
}

/// @notice CoverageFundV1 with the v1.0 initializer restored.
contract CoverageFundV1WithLegacyInit is CoverageFundV1 {
    function initCoverageFundV1(address _riverAddress) external init(0) {
        RiverAddress.set(_riverAddress);
        emit SetRiver(_riverAddress);
    }
}

/// @notice ELFeeRecipientV1 with the v1.0 initializer restored.
contract ELFeeRecipientV1WithLegacyInit is ELFeeRecipientV1 {
    function initELFeeRecipientV1(address _riverAddress) external init(0) {
        RiverAddress.set(_riverAddress);
        emit SetRiver(_riverAddress);
    }
}

/// @notice ProtocolMetricsV1 with the v1.0 initializer restored.
contract ProtocolMetricsV1WithLegacyInit is ProtocolMetricsV1 {
    function initProtocolMetricsV1(address river) external init(0) {
        RiverAddress.set(river);
    }
}

/// @notice OracleV1 with the v1.0 and v1.1 initializers restored.
contract OracleV1WithLegacyInit is OracleV1 {
    function initOracleV1(
        address _riverAddress,
        address _administratorAddress,
        uint64 _epochsPerFrame,
        uint64 _slotsPerEpoch,
        uint64 _secondsPerSlot,
        uint64 _genesisTime,
        uint256 _annualAprUpperBound,
        uint256 _relativeLowerBound
    ) external init(0) {
        _setAdmin(_administratorAddress);
        RiverAddress.set(_riverAddress);
        emit SetRiver(_riverAddress);
        CLSpec.set(
            CLSpec.CLSpecStruct({
                epochsPerFrame: _epochsPerFrame,
                slotsPerEpoch: _slotsPerEpoch,
                secondsPerSlot: _secondsPerSlot,
                genesisTime: _genesisTime,
                epochsToAssumedFinality: 0
            })
        );
        emit SetSpec(_epochsPerFrame, _slotsPerEpoch, _secondsPerSlot, _genesisTime);
        ReportBounds.set(
            ReportBounds.ReportBoundsStruct({
                annualAprUpperBound: _annualAprUpperBound, relativeLowerBound: _relativeLowerBound
            })
        );
        emit SetBounds(_annualAprUpperBound, _relativeLowerBound);
        Quorum.set(0);
        emit SetQuorum(0);
    }

    function initOracleV1_1() external init(1) {
        _clearReports();
    }
}

/// @notice OperatorsRegistryV1 with the v1.0 and v1.1 initializers restored.
/// @dev The V1 -> V2 operator migration lives here too: it is only reachable through
///      `initOperatorsRegistryV1_1`, which mainnet ran long ago.
contract OperatorsRegistryV1WithLegacyInit is OperatorsRegistryV1 {
    function initOperatorsRegistryV1(address _admin, address _river) external init(0) {
        _setAdmin(_admin);
        RiverAddress.set(_river);
        emit SetRiver(_river);
    }

    function initOperatorsRegistryV1_1() external init(1) {
        _migrateOperators_V1_1();
    }

    /// @notice Internal utility to migrate the operators from V1 to V2 format
    function _migrateOperators_V1_1() internal {
        uint256 opCount = OperatorsV1.getCount();

        for (uint256 idx = 0; idx < opCount; ++idx) {
            OperatorsV1.Operator memory oldOperatorValue = OperatorsV1.get(idx);

            OperatorsV2.push(
                OperatorsV2.Operator({
                    limit: uint32(oldOperatorValue.limit),
                    funded: uint32(oldOperatorValue.funded),
                    requestedExits: 0,
                    keys: uint32(oldOperatorValue.keys),
                    latestKeysEditBlockNumber: uint64(oldOperatorValue.latestKeysEditBlockNumber),
                    active: oldOperatorValue.active,
                    name: oldOperatorValue.name,
                    operator: oldOperatorValue.operator
                })
            );
        }
    }
}

/// @notice RedeemManagerV1 with the v1.0 and v1.2 initializers restored.
/// @dev The RedeemQueueV1 -> V2 migration lives here too: it is only reachable through
///      `initializeRedeemManagerV1_2`, which mainnet ran long ago.
contract RedeemManagerV1WithLegacyInit is RedeemManagerV1 {
    function initializeRedeemManagerV1(address _river) external init(0) {
        RiverAddress.set(_river);
        emit SetRiver(_river);
    }

    function initializeRedeemManagerV1_2() external init(1) {
        _redeemQueueMigrationV1_2();
    }

    function _redeemQueueMigrationV1_2() internal {
        RedeemQueueV1.RedeemRequest[] memory oldQueue = RedeemQueueV1.get();
        uint256 oldQueueLen = oldQueue.length;
        RedeemQueueV2.RedeemRequest[] storage newQueue = RedeemQueueV2.get();

        // Migrate from v1 to v2
        for (uint256 i = 0; i < oldQueueLen; ++i) {
            newQueue[i] = RedeemQueueV2.RedeemRequest({
                amount: oldQueue[i].amount,
                maxRedeemableEth: oldQueue[i].maxRedeemableEth,
                recipient: oldQueue[i].recipient,
                height: oldQueue[i].height,
                initiator: oldQueue[i].recipient
            });
        }
    }
}

/// @notice WithdrawV1 with the v1.0 initializer restored.
contract WithdrawV1WithLegacyInit is WithdrawV1 {
    function initializeWithdrawV1(address _river) external init(0) {
        _setRiver(_river);
    }
}
