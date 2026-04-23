//SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.34;

import "forge-std/Test.sol";

import "../../../src/TUPProxy.sol";
import "../../../src/OperatorsRegistry.1.sol";
import {
    ITransparentUpgradeableProxy
} from "openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

/// @notice Mock interface matching the V2 (mainnet-live) OperatorsRegistry ABI
interface IOperatorsRegistryV2 {
    struct OperatorV2 {
        uint32 limit;
        uint32 funded;
        uint32 requestedExits;
        uint32 keys;
        uint64 latestKeysEditBlockNumber;
        bool active;
        string name;
        address operator;
    }

    function getOperator(uint256 _index) external view returns (OperatorV2 memory);
    function getOperatorCount() external view returns (uint256);
    function getOperatorStoppedValidatorCount(uint256 _idx) external view returns (uint32);
    function getTotalDepositedETH() external view returns (uint256);
}

contract OperatorsMigrationV2ToV3 is Test {
    bool internal _skip = false;

    address internal constant OPERATORS_REGISTRY_MAINNET_ADDRESS = 0x1235f1b60df026B2620e48E735C422425E06b725;
    address internal constant OPERATORS_REGISTRY_MAINNET_PROXY_ADMIN_ADDRESS =
        0x1d1FD2d8C87Fed864708bbab84c2Da54254F5a12;

    function setUp() external {
        try vm.envString("MAINNET_FORK_RPC_URL") returns (string memory rpcUrl) {
            vm.createSelectFork(rpcUrl, 21_700_000);
            console.log("2.operatorsMigrationV2ToV3.t.sol is active");
        } catch {
            _skip = true;
        }
    }

    modifier shouldSkip() {
        if (!_skip) {
            _;
        }
    }

    function test_migration_V2_to_V3() external shouldSkip {
        IOperatorsRegistryV2 v2 = IOperatorsRegistryV2(OPERATORS_REGISTRY_MAINNET_ADDRESS);

        // ── Snapshot V2 state before upgrade ──
        uint256 opCount = v2.getOperatorCount();
        assertGt(opCount, 0, "no operators on mainnet");

        IOperatorsRegistryV2.OperatorV2[] memory v2Ops = new IOperatorsRegistryV2.OperatorV2[](opCount);
        uint32[] memory v2StoppedCounts = new uint32[](opCount);

        for (uint256 i = 0; i < opCount; ++i) {
            v2Ops[i] = v2.getOperator(i);
            v2StoppedCounts[i] = v2.getOperatorStoppedValidatorCount(i);
        }

        // ── Upgrade: deploy new implementation and run V1_2 migration (V2 → V3) ──
        TUPProxy orProxy = TUPProxy(payable(OPERATORS_REGISTRY_MAINNET_ADDRESS));
        OperatorsRegistryV1 newImplementation = new OperatorsRegistryV1();

        vm.prank(OPERATORS_REGISTRY_MAINNET_PROXY_ADMIN_ADDRESS);
        ITransparentUpgradeableProxy(address(orProxy))
            .upgradeToAndCall(
                address(newImplementation), abi.encodeCall(OperatorsRegistryV1.initOperatorsRegistryV1_2, (address(1)))
            );

        // ── Verify V3 state matches V2 ──
        OperatorsRegistryV1 v3 = OperatorsRegistryV1(OPERATORS_REGISTRY_MAINNET_ADDRESS);

        assertEq(v3.getOperatorCount(), opCount, "operator count mismatch");

        uint256[] memory v3ExitedETH = v3.getExitedETHPerOperator();

        for (uint256 i = 0; i < opCount; ++i) {
            OperatorsV3.Operator memory op = v3.getOperator(i);

            assertEq(op.funded, uint256(v2Ops[i].funded) * 32 ether, _label("funded", i));
            assertEq(op.requestedExits, uint256(v2Ops[i].requestedExits) * 32 ether, _label("requestedExits", i));
            assertEq(op.active, v2Ops[i].active, _label("active", i));
            assertEq(op.name, v2Ops[i].name, _label("name", i));
            assertEq(op.operator, v2Ops[i].operator, _label("operator", i));
            assertEq(v3ExitedETH[i], uint256(v2StoppedCounts[i]) * 32 ether, _label("stopped", i));
        }
    }

    function test_migration_V2_to_V3_cannotRerun() external shouldSkip {
        TUPProxy orProxy = TUPProxy(payable(OPERATORS_REGISTRY_MAINNET_ADDRESS));
        OperatorsRegistryV1 newImplementation = new OperatorsRegistryV1();

        // First migration should succeed
        vm.prank(OPERATORS_REGISTRY_MAINNET_PROXY_ADMIN_ADDRESS);
        ITransparentUpgradeableProxy(address(orProxy))
            .upgradeToAndCall(
                address(newImplementation), abi.encodeCall(OperatorsRegistryV1.initOperatorsRegistryV1_2, (address(1)))
            );

        // Second call should revert (init version already set)
        vm.prank(OPERATORS_REGISTRY_MAINNET_PROXY_ADMIN_ADDRESS);
        vm.expectRevert();
        ITransparentUpgradeableProxy(address(orProxy))
            .upgradeToAndCall(
                address(newImplementation), abi.encodeCall(OperatorsRegistryV1.initOperatorsRegistryV1_2, (address(1)))
            );
    }

    /// @notice After migration, verify that production functions work correctly on the migrated V3 state.
    ///         A storage slot miscalculation would cause these operations to fail or corrupt data.
    function test_migration_V2_to_V3_postMigrationFunctional() external shouldSkip {
        IOperatorsRegistryV2 v2 = IOperatorsRegistryV2(OPERATORS_REGISTRY_MAINNET_ADDRESS);
        uint256 opCount = v2.getOperatorCount();
        assertGt(opCount, 0, "no operators on mainnet");

        // Snapshot funded count of first active operator before upgrade
        uint256 activeOpIdx;
        uint32 preFunded;
        for (uint256 i = 0; i < opCount; ++i) {
            IOperatorsRegistryV2.OperatorV2 memory op = v2.getOperator(i);
            if (op.active) {
                activeOpIdx = i;
                preFunded = op.funded;
                break;
            }
        }

        // ── Upgrade ──
        TUPProxy orProxy = TUPProxy(payable(OPERATORS_REGISTRY_MAINNET_ADDRESS));
        OperatorsRegistryV1 newImpl = new OperatorsRegistryV1();

        vm.prank(OPERATORS_REGISTRY_MAINNET_PROXY_ADMIN_ADDRESS);
        ITransparentUpgradeableProxy(address(orProxy))
            .upgradeToAndCall(
                address(newImpl), abi.encodeCall(OperatorsRegistryV1.initOperatorsRegistryV1_2, (address(1)))
            );

        OperatorsRegistryV1 v3 = OperatorsRegistryV1(OPERATORS_REGISTRY_MAINNET_ADDRESS);
        address river = v3.getRiver();
        address admin = v3.getAdmin();

        // ── incrementFundedETH works on migrated state ──
        uint256[] memory fundedETH = new uint256[](activeOpIdx + 1);
        bytes[][] memory keys = new bytes[][](activeOpIdx + 1);
        keys[activeOpIdx] = new bytes[](1);
        keys[activeOpIdx][0] = new bytes(48);
        fundedETH[activeOpIdx] = 32 ether;
        vm.prank(river);
        v3.incrementFundedETH(fundedETH, keys);
        assertEq(
            v3.getOperator(activeOpIdx).funded,
            uint256(preFunded) * 32 ether + 32 ether,
            "funded should increment by 32 ether after incrementFundedETH"
        );

        // ── addOperator works on migrated state ──
        uint256 preCount = v3.getOperatorCount();
        vm.prank(admin);
        v3.addOperator("PostMigrationTestOp", address(0xBEEF));
        assertEq(v3.getOperatorCount(), preCount + 1, "operator count should increase by 1");
        OperatorsV3.Operator memory newOp = v3.getOperator(preCount);
        assertEq(newOp.name, "PostMigrationTestOp", "new operator name mismatch");
        assertEq(newOp.operator, address(0xBEEF), "new operator address mismatch");
        assertTrue(newOp.active, "new operator should be active");
        assertEq(newOp.funded, 0, "new operator should have 0 funded");

        // ── setOperatorStatus works on migrated state ──
        vm.prank(admin);
        v3.setOperatorStatus(activeOpIdx, false);
        assertFalse(v3.getOperator(activeOpIdx).active, "operator should be deactivated");
        vm.prank(admin);
        v3.setOperatorStatus(activeOpIdx, true);
        assertTrue(v3.getOperator(activeOpIdx).active, "operator should be reactivated");
    }

    function _label(string memory field, uint256 idx) internal pure returns (string memory) {
        return string.concat(field, " mismatch at operator ", vm.toString(idx));
    }
}
