//SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.34;

import "forge-std/Test.sol";

import "../../../src/TUPProxy.sol";
import "../../../src/OperatorsRegistry.1.sol";
import {
    ITransparentUpgradeableProxy
} from "openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

/// @notice Drives the full V1 → V2 → V3 operator migration against a pre-V1_1 mainnet fork using the
/// @notice production initializers: initOperatorsRegistryV1_1 (V1 → V2) then initOperatorsRegistryV1_2
/// @notice (V2 → V3). Both initializers ship on the mainnet OperatorsRegistryV1 implementation.
contract OperatorsMigrationV1ToV3 is Test {
    bool internal _skip = false;

    function setUp() external {
        try vm.envString("MAINNET_FORK_RPC_URL") returns (string memory rpcUrl) {
            vm.createSelectFork(rpcUrl, 16690000);
            console.log("2.operatorsMigrationV1toV3.t.sol is active");
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

        OperatorsRegistryV1 migrationImplementation = new OperatorsRegistryV1();

        // Run V1 → V2 migration (initOperatorsRegistryV1_1 migrates the operator structs from V1 to V2)
        vm.prank(OPERATORS_REGISTRY_MAINNET_PROXY_ADMIN_ADDRESS);
        ITransparentUpgradeableProxy(address(orProxy))
            .upgradeToAndCall(
                address(migrationImplementation), abi.encodeCall(OperatorsRegistryV1.initOperatorsRegistryV1_1, ())
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
            bytes32 withdrawSlot = bytes32(uint256(keccak256("river.state.withdrawAddress")) - 1);
            assertEq(
                vm.load(address(orProxy), withdrawSlot),
                bytes32(uint256(uint160(address(1)))),
                "WithdrawAddress not stored correctly after migration"
            );
        }
        {
            (uint256 totalExitedETH,) = or.getExitedAndRequestedETHExits();
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
