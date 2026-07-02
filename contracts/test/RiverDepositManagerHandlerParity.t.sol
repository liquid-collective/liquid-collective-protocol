// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "forge-std/Test.sol";

import "../src/River.1.sol";
import "../src/RiverDepositManager.1.sol";
import "../src/interfaces/IRiver.1.sol";
import "../src/interfaces/IOperatorRegistry.1.sol";
import "../src/state/shared/AdministratorAddress.sol";
import "../src/state/shared/OperatorsRegistryAddress.sol";
import "../src/state/river/LastConsensusLayerReport.sol";
import "./utils/LibImplementationUnbricker.sol";

/// @notice Records the calldata of the last incrementFundedETH call so the two contracts' forwarded
///         payloads can be compared byte-for-byte.
contract RecordingOperatorsRegistry {
    bytes public lastCall;

    function incrementFundedETH(IOperatorsRegistryV1.OperatorFundingDelta[] calldata) external {
        lastCall = msg.data;
    }
}

/// @notice Exposes RiverV1's copies of the ConsensusLayerDepositManagerV1 abstract handlers plus the
///         storage seeders needed to drive them.
contract RiverV1HandlerHarness is RiverV1 {
    function sudoSetAdmin(address _admin) external {
        AdministratorAddress.set(_admin);
    }

    function sudoSetOperatorsRegistry(address _registry) external {
        OperatorsRegistryAddress.set(_registry);
    }

    function sudoSetSlashingContainmentMode(bool _enabled) external {
        LastConsensusLayerReport.get().slashingContainmentMode = _enabled;
    }

    function h_getRiverAdmin() external view returns (address) {
        return _getRiverAdmin();
    }

    function h_setCommittedBalance(uint256 _newCommittedBalance) external {
        _setCommittedBalance(_newCommittedBalance);
    }

    function h_getSlashingContainmentMode() external view returns (bool) {
        return _getSlashingContainmentMode();
    }

    function h_incrementFundedETH(IOperatorsRegistryV1.OperatorFundingDelta[] memory _deltas) external {
        _incrementFundedETH(_deltas);
    }
}

/// @notice Exposes RiverDepositManagerV1's copies of the same handlers with identical seeders.
contract RiverDepositManagerV1HandlerHarness is RiverDepositManagerV1 {
    function sudoSetAdmin(address _admin) external {
        AdministratorAddress.set(_admin);
    }

    function sudoSetOperatorsRegistry(address _registry) external {
        OperatorsRegistryAddress.set(_registry);
    }

    function sudoSetSlashingContainmentMode(bool _enabled) external {
        LastConsensusLayerReport.get().slashingContainmentMode = _enabled;
    }

    function h_getRiverAdmin() external view returns (address) {
        return _getRiverAdmin();
    }

    function h_setCommittedBalance(uint256 _newCommittedBalance) external {
        _setCommittedBalance(_newCommittedBalance);
    }

    function h_getSlashingContainmentMode() external view returns (bool) {
        return _getSlashingContainmentMode();
    }

    function h_incrementFundedETH(IOperatorsRegistryV1.OperatorFundingDelta[] memory _deltas) external {
        _incrementFundedETH(_deltas);
    }
}

/// @title RiverV1 / RiverDepositManagerV1 handler-parity tests
/// @notice RiverDepositManagerV1 runs in River's storage context via delegatecall, so both concrete
///         contracts must resolve the ConsensusLayerDepositManagerV1 abstract handlers identically —
///         otherwise the deposit path and River's own paths would diverge on the storage they share.
///         The bodies live in LibRiverHandlers; these tests pin that both entry points observe the same
///         state writes, events and forwarded calls, guarding against a future re-inline of either copy.
contract RiverDepositManagerHandlerParityTest is Test {
    RiverV1HandlerHarness internal river;
    RiverDepositManagerV1HandlerHarness internal rdm;

    function setUp() public {
        river = new RiverV1HandlerHarness();
        rdm = new RiverDepositManagerV1HandlerHarness();
        LibImplementationUnbricker.unbrick(vm, address(river));
        LibImplementationUnbricker.unbrick(vm, address(rdm));
    }

    /// @notice Both contracts resolve the admin handler to the same configured admin.
    function testParity_getRiverAdmin() public {
        address admin = address(0xA11CE);
        river.sudoSetAdmin(admin);
        rdm.sudoSetAdmin(admin);
        assertEq(river.h_getRiverAdmin(), admin);
        assertEq(rdm.h_getRiverAdmin(), admin);
        assertEq(river.h_getRiverAdmin(), rdm.h_getRiverAdmin());
    }

    /// @notice Both contracts read the slashing-containment flag identically for either value.
    function testParity_getSlashingContainmentMode() public {
        river.sudoSetSlashingContainmentMode(true);
        rdm.sudoSetSlashingContainmentMode(true);
        assertTrue(river.h_getSlashingContainmentMode());
        assertTrue(rdm.h_getSlashingContainmentMode());

        river.sudoSetSlashingContainmentMode(false);
        rdm.sudoSetSlashingContainmentMode(false);
        assertFalse(river.h_getSlashingContainmentMode());
        assertFalse(rdm.h_getSlashingContainmentMode());
    }

    /// @notice Both contracts write the same committed balance and emit an identical
    ///         SetBalanceCommittedToDeposit event (topics + data) for the same transition.
    function testParity_setCommittedBalanceStateAndEvent() public {
        uint256 oldValue = 5 ether;
        uint256 newValue = 12 ether;

        // seed both to the same prior committed balance
        river.h_setCommittedBalance(oldValue);
        rdm.h_setCommittedBalance(oldValue);
        assertEq(river.getCommittedBalance(), oldValue);
        assertEq(rdm.getCommittedBalance(), oldValue);

        vm.recordLogs();
        river.h_setCommittedBalance(newValue);
        Vm.Log[] memory riverLogs = vm.getRecordedLogs();

        vm.recordLogs();
        rdm.h_setCommittedBalance(newValue);
        Vm.Log[] memory rdmLogs = vm.getRecordedLogs();

        // resulting state matches
        assertEq(river.getCommittedBalance(), newValue);
        assertEq(rdm.getCommittedBalance(), newValue);

        // each emits exactly one event, identical in topics and data (emitter address aside)
        assertEq(riverLogs.length, 1);
        assertEq(rdmLogs.length, 1);
        assertEq(riverLogs[0].topics.length, rdmLogs[0].topics.length);
        for (uint256 i = 0; i < riverLogs[0].topics.length; i++) {
            assertEq(riverLogs[0].topics[i], rdmLogs[0].topics[i]);
        }
        assertEq(keccak256(riverLogs[0].data), keccak256(rdmLogs[0].data));

        // and it is the expected SetBalanceCommittedToDeposit(old, new)
        assertEq(riverLogs[0].topics[0], keccak256("SetBalanceCommittedToDeposit(uint256,uint256)"));
        (uint256 loggedOld, uint256 loggedNew) = abi.decode(riverLogs[0].data, (uint256, uint256));
        assertEq(loggedOld, oldValue);
        assertEq(loggedNew, newValue);
    }

    /// @notice Both contracts forward byte-identical calldata to the operators registry.
    function testParity_incrementFundedETHForwarding() public {
        RecordingOperatorsRegistry registry = new RecordingOperatorsRegistry();
        river.sudoSetOperatorsRegistry(address(registry));
        rdm.sudoSetOperatorsRegistry(address(registry));

        IOperatorsRegistryV1.OperatorFundingDelta[] memory deltas =
            new IOperatorsRegistryV1.OperatorFundingDelta[](1);
        deltas[0].operatorIndex = 3;
        deltas[0].fundedETH = 64 ether;
        deltas[0].depositPubkeys = new bytes[](0);
        deltas[0].depositAmounts = new uint256[](0);
        deltas[0].topUpPubkeys = new bytes[](0);
        deltas[0].topUpAmounts = new uint256[](0);

        river.h_incrementFundedETH(deltas);
        bytes32 riverCall = keccak256(registry.lastCall());

        rdm.h_incrementFundedETH(deltas);
        bytes32 rdmCall = keccak256(registry.lastCall());

        assertEq(riverCall, rdmCall);
    }
}
