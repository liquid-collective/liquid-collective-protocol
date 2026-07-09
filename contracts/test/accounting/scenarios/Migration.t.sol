// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "forge-std/Test.sol";
import "../../../src/OperatorsRegistry.1.sol";
import "../../../src/interfaces/IOperatorRegistry.1.sol";
import "../../../src/state/operatorsRegistry/Operators.2.sol";
import "../../../src/state/operatorsRegistry/Operators.3.sol";
import "../../utils/LibImplementationUnbricker.sol";

/// @dev Subclass of OperatorsRegistryV1 that exposes internal V2 storage writes for migration testing.
contract MigrationOperatorsRegistry is OperatorsRegistryV1 {
    /// @dev Push a V2 operator directly into OperatorsV2 storage.
    function sudoPushV2Operator(
        string calldata _name,
        address _operator,
        uint32 _funded,
        uint32 _requestedExits,
        uint32 _limit,
        uint32 _keys
    ) external {
        OperatorsV2.push(
            OperatorsV2.Operator({
                limit: _limit,
                funded: _funded,
                requestedExits: _requestedExits,
                keys: _keys,
                latestKeysEditBlockNumber: uint64(block.number),
                active: true,
                name: _name,
                operator: _operator
            })
        );
    }

    /// @dev Set the stopped validators array in V2 storage.
    ///      Format: [total, op0StoppedCount, op1StoppedCount, ...]
    function sudoSetStoppedValidators(uint32[] calldata _stoppedValidators) external {
        OperatorsV2.setRawStoppedValidators(_stoppedValidators);
    }
}

contract MigrationTest is Test {
    MigrationOperatorsRegistry internal registry;

    address internal admin = makeAddr("admin");
    address internal river = makeAddr("river");
    address internal op1Addr = makeAddr("op1");
    address internal op2Addr = makeAddr("op2");

    /// @notice Deploys a fresh `MigrationOperatorsRegistry`, unblocks the initializer proxy,
    ///         and initializes the registry with a fixed admin and river address.
    function setUp() public {
        // Step 1: Deploy the registry implementation and unblock the proxy for testing.
        registry = new MigrationOperatorsRegistry();
        LibImplementationUnbricker.unbrick(vm, address(registry));
        // Step 2: Initialize the registry with the test admin and river addresses.
        registry.initOperatorsRegistryV1(admin, river);
    }

    /// @notice Verifies the V2 → V3 migration for two operators with known funded and stopped
    ///         validator counts. After calling `initOperatorsRegistryV1_2`, all V3 state
    ///         (funded ETH, exited ETH per operator, and aggregate exited ETH) must be correctly
    ///         scaled from validator counts to ETH amounts (×32 ETH per validator).
    function testMigrationV2toV3() public {
        // Op0: funded=3 validators, stopped=1 validator
        // Op1: funded=5 validators, stopped=2 validators
        uint32 op0Funded = 3;
        uint32 op1Funded = 5;
        uint32 op0Stopped = 1;
        uint32 op1Stopped = 2;

        // Push two V2 operators directly
        registry.sudoPushV2Operator("OpAlpha", op1Addr, op0Funded, 0, op0Funded, op0Funded);
        registry.sudoPushV2Operator("OpBeta", op2Addr, op1Funded, 0, op1Funded, op1Funded);

        // Set stopped validators array: [total, op0Stopped, op1Stopped]
        uint32 totalStopped = op0Stopped + op1Stopped;
        uint32[] memory stopped = new uint32[](3);
        stopped[0] = totalStopped;
        stopped[1] = op0Stopped;
        stopped[2] = op1Stopped;
        registry.sudoSetStoppedValidators(stopped);

        // V1_1 runs the V1→V2 operator migration; V1 storage is empty here, so it only advances the
        // init version 1→2 so the V1_2 init(2) check passes
        registry.initOperatorsRegistryV1_1();
        // V1_2 migrates V2 → V3 (scales by 32 ether)
        registry.initOperatorsRegistryV1_2(makeAddr("withdraw"));

        // Validate V3 state
        assertEq(registry.getOperatorCount(), 2, "operator count");

        OperatorsV3.Operator memory v3Op0 = registry.getOperator(0);
        assertEq(v3Op0.funded, uint256(op0Funded) * 32 ether, "op0 funded ETH");
        assertEq(v3Op0.active, true, "op0 active");
        assertEq(v3Op0.activeCLETH, 0, "op0 activeCLETH must be zero post-migration");

        OperatorsV3.Operator memory v3Op1 = registry.getOperator(1);
        assertEq(v3Op1.funded, uint256(op1Funded) * 32 ether, "op1 funded ETH");
        assertEq(v3Op1.active, true, "op1 active");
        assertEq(v3Op1.activeCLETH, 0, "op1 activeCLETH must be zero post-migration");

        // Validate exited ETH per operator
        uint256[] memory exitedPerOp = registry.getExitedETHPerOperator();
        assertEq(exitedPerOp.length, 2, "exitedPerOp length");
        assertEq(exitedPerOp[0], uint256(op0Stopped) * 32 ether, "op0 exited ETH");
        assertEq(exitedPerOp[1], uint256(op1Stopped) * 32 ether, "op1 exited ETH");

        // Validate aggregate exited ETH
        (uint256 totalExited,) = registry.getExitedAndRequestedETHExits();
        assertEq(totalExited, uint256(totalStopped) * 32 ether, "total exited ETH");
    }

    /// @notice Verifies that running the full V1_1 → V1_2 migration on an empty registry
    ///         (no operators ever registered) produces a valid empty V3 state with zero operators.
    function testMigrationEmptyState() public {
        registry.initOperatorsRegistryV1_1();
        // Step 2: Run the V1_2 migration (V2 → V3 scaling) and assert no operators were created.
        registry.initOperatorsRegistryV1_2(makeAddr("withdraw"));
        assertEq(registry.getOperatorCount(), 0, "no operators after empty migration");
    }

    /// @notice Verifies that a single operator with funded validators and zero stopped validators
    ///         migrates cleanly from V2 to V3, with funded ETH correctly scaled and exited ETH
    ///         remaining zero.
    function testMigrationSingleOperatorNoStops() public {
        uint32 funded = 4;
        registry.sudoPushV2Operator("Solo", op1Addr, funded, 0, funded, funded);

        // Set stopped validators to all zeros: [total=0, op0=0]
        uint32[] memory stopped = new uint32[](2);
        stopped[0] = 0;
        stopped[1] = 0;
        registry.sudoSetStoppedValidators(stopped);

        registry.initOperatorsRegistryV1_1();
        registry.initOperatorsRegistryV1_2(makeAddr("withdraw"));

        assertEq(registry.getOperatorCount(), 1, "one operator");
        OperatorsV3.Operator memory op = registry.getOperator(0);
        assertEq(op.funded, uint256(funded) * 32 ether, "funded scaled");
        assertEq(op.activeCLETH, 0, "activeCLETH must be zero post-migration");

        uint256[] memory exitedPerOp = registry.getExitedETHPerOperator();
        assertEq(exitedPerOp.length, 1, "one entry");
        assertEq(exitedPerOp[0], 0, "no exited ETH");
    }

    /// @notice Verifies that the V2 → V3 migration reverts with `InvalidOperatorState` when an
    ///         operator has more requested exit ETH than funded ETH after scaling the legacy V2
    ///         validator counts.
    function testMigrationRevertsOnInvalidOperatorState() public {
        uint32 op0FundedValidatorCount = 2;
        uint32 op0RequestedExitCount = 2;
        uint32 op1FundedValidatorCount = 1;
        uint32 op1RequestedExitCount = 3;

        // Op0 is valid; Op1 triggers the revert. The error reports ETH values, not V2 counts.
        registry.sudoPushV2Operator(
            "OpAlpha",
            op1Addr,
            op0FundedValidatorCount,
            op0RequestedExitCount,
            op0FundedValidatorCount,
            op0FundedValidatorCount
        );
        registry.sudoPushV2Operator(
            "OpBeta",
            op2Addr,
            op1FundedValidatorCount,
            op1RequestedExitCount,
            op1FundedValidatorCount,
            op1FundedValidatorCount
        );

        registry.initOperatorsRegistryV1_1();

        uint256 op1FundedETH = uint256(op1FundedValidatorCount) * 32 ether;
        uint256 op1RequestedExitETH = uint256(op1RequestedExitCount) * 32 ether;
        vm.expectRevert(
            abi.encodeWithSelector(
                IOperatorsRegistryV1.InvalidOperatorState.selector, 1, op1FundedETH, op1RequestedExitETH
            )
        );
        registry.initOperatorsRegistryV1_2(makeAddr("withdraw"));
    }
}
