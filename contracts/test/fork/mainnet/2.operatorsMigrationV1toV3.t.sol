//SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.34;

import "forge-std/Test.sol";

import "../../../src/TUPProxy.sol";
import "../../../src/OperatorsRegistry.1.sol";
import "../../../src/state/operatorsRegistry/Operators.1.sol";
import "../../../src/state/operatorsRegistry/Operators.2.sol";
import {
    ITransparentUpgradeableProxy
} from "openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

/// @notice Test-only implementation that includes the V1→V2 migration.
/// @dev initOperatorsRegistryV1_1 was made empty in the production contract because it
/// @dev "already ran on mainnet". For fork tests against pre-V1_1 blocks we need the
/// @dev migration to actually execute, so this contract re-implements it.
contract OperatorsRegistryV1WithFullMigration is OperatorsRegistryV1 {
    /// @notice Re-implements the V1→V2 operator migration for fork-test use.
    function migrateV1ToV2() external init(1) {
        uint256 count = OperatorsV1.getCount();
        for (uint256 idx = 0; idx < count; ++idx) {
            OperatorsV1.Operator memory v1op = OperatorsV1.get(idx);
            OperatorsV2.push(
                OperatorsV2.Operator({
                    limit: uint32(v1op.limit),
                    funded: uint32(v1op.funded),
                    requestedExits: 0,
                    keys: uint32(v1op.keys),
                    latestKeysEditBlockNumber: uint64(v1op.latestKeysEditBlockNumber),
                    active: v1op.active,
                    name: v1op.name,
                    operator: v1op.operator
                })
            );
        }
    }
}

contract OperatorsMigrationV1ToV2 is Test {
    bool internal _skip = false;

    function setUp() external {
        try vm.envString("MAINNET_FORK_RPC_URL") returns (string memory rpcUrl) {
            vm.createSelectFork(rpcUrl, 16690000);
            console.log("1.operatorsMigrationV1ToV2.t.sol is active");
        } catch {
            _skip = true;
        }
    }

    modifier shouldSkip() {
        if (!_skip) {
            _;
        }
    }

    address internal constant OPERATORS_REGISTRY_MAINNET_ADDRESS = 0x1235f1b60df026B2620e48E735C422425E06b725;
    address internal constant OPERATORS_REGISTRY_MAINNET_PROXY_ADMIN_ADDRESS =
        0x1d1FD2d8C87Fed864708bbab84c2Da54254F5a12;

    function test_migration() external shouldSkip {
        TUPProxy orProxy = TUPProxy(payable(OPERATORS_REGISTRY_MAINNET_ADDRESS));

        OperatorsRegistryV1WithFullMigration migrationImplementation = new OperatorsRegistryV1WithFullMigration();

        // Run V1→V2 migration (inline in fork-test implementation since initV1_1 is intentionally
        // empty in production — that migration already ran on mainnet but hasn't run at this block)
        vm.prank(OPERATORS_REGISTRY_MAINNET_PROXY_ADMIN_ADDRESS);
        ITransparentUpgradeableProxy(address(orProxy))
            .upgradeToAndCall(
                address(migrationImplementation), abi.encodeCall(OperatorsRegistryV1WithFullMigration.migrateV1ToV2, ())
            );

        OperatorsRegistryV1 or = OperatorsRegistryV1(OPERATORS_REGISTRY_MAINNET_ADDRESS);

        // Run V1_2 migration (V2 → V3 struct, drops limit/keys/latestKeysEditBlockNumber)
        vm.prank(OPERATORS_REGISTRY_MAINNET_PROXY_ADMIN_ADDRESS);
        ITransparentUpgradeableProxy(address(orProxy))
            .upgradeToAndCall(
                address(migrationImplementation),
                abi.encodeCall(OperatorsRegistryV1.initOperatorsRegistryV1_2, (address(1)))
            );

        assertEq(or.getOperatorCount(), 3);
        {
            bytes32 lcWithdrawSlot = bytes32(uint256(keccak256("river.state.lcWithdrawAddress")) - 1);
            assertEq(
                vm.load(address(orProxy), lcWithdrawSlot),
                bytes32(uint256(uint160(address(1)))),
                "LCWithdrawAddress not stored correctly after migration"
            );
        }
        {
            (uint256 totalExitedETH,) = or.getExitedETHAndRequestedExitAmounts();
            assertEq(totalExitedETH, 0);
        }
        {
            // Per-operator exited ETH may be an empty array if no validators have exited yet
            uint256[] memory exitedPerOp = or.getExitedETHPerOperator();
            for (uint256 i = 0; i < exitedPerOp.length; ++i) {
                assertEq(exitedPerOp[i], 0);
            }
        }
        {
            OperatorsV3.Operator memory op0 = or.getOperator(0);
            assertEq(op0.funded, 0);
            assertEq(op0.requestedExits, 0);
            assertEq(op0.active, true);
            assertEq(op0.name, "Figment");
            assertEq(op0.operator, 0xDfB087180Dc5e99655Bf7e61D53dD6d25a023253);
        }

        {
            OperatorsV3.Operator memory op1 = or.getOperator(1);
            assertEq(op1.funded, 1 * 32 ether);
            assertEq(op1.requestedExits, 0);
            assertEq(op1.active, true);
            assertEq(op1.name, "Coinbase Cloud");
            assertEq(op1.operator, 0x75DC82105B5c482402A4267F628036254F380967);
        }

        {
            OperatorsV3.Operator memory op2 = or.getOperator(2);
            assertEq(op2.funded, 0);
            assertEq(op2.requestedExits, 0);
            assertEq(op2.active, true);
            assertEq(op2.name, "Staked");
            assertEq(op2.operator, 0x7070CBfD67fDf8077d27548E86505F9F91C31621);
        }
    }
}
