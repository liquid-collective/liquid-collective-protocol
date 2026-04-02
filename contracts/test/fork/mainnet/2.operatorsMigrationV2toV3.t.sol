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
    function getTotalStoppedValidatorCount() external view returns (uint32);
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
        uint32 v2TotalStopped = v2.getTotalStoppedValidatorCount();

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
                address(newImplementation),
                abi.encodeWithSelector(OperatorsRegistryV1.initOperatorsRegistryV1_2.selector)
            );

        // ── Verify V3 state matches V2 ──
        OperatorsRegistryV1 v3 = OperatorsRegistryV1(OPERATORS_REGISTRY_MAINNET_ADDRESS);

        assertEq(v3.getOperatorCount(), opCount, "operator count mismatch");
        assertEq(v3.getTotalStoppedValidatorCount(), v2TotalStopped, "total stopped mismatch");

        for (uint256 i = 0; i < opCount; ++i) {
            OperatorsV3.Operator memory op = v3.getOperator(i);

            assertEq(op.funded, v2Ops[i].funded, _label("funded", i));
            assertEq(op.requestedExits, v2Ops[i].requestedExits, _label("requestedExits", i));
            assertEq(op.active, v2Ops[i].active, _label("active", i));
            assertEq(op.name, v2Ops[i].name, _label("name", i));
            assertEq(op.operator, v2Ops[i].operator, _label("operator", i));
            assertEq(v3.getOperatorStoppedValidatorCount(i), v2StoppedCounts[i], _label("stopped", i));
        }
    }

    function test_migration_V2_to_V3_cannotRerun() external shouldSkip {
        TUPProxy orProxy = TUPProxy(payable(OPERATORS_REGISTRY_MAINNET_ADDRESS));
        OperatorsRegistryV1 newImplementation = new OperatorsRegistryV1();

        // First migration should succeed
        vm.prank(OPERATORS_REGISTRY_MAINNET_PROXY_ADMIN_ADDRESS);
        ITransparentUpgradeableProxy(address(orProxy))
            .upgradeToAndCall(
                address(newImplementation),
                abi.encodeWithSelector(OperatorsRegistryV1.initOperatorsRegistryV1_2.selector)
            );

        // Second call should revert (init version already set)
        vm.prank(OPERATORS_REGISTRY_MAINNET_PROXY_ADMIN_ADDRESS);
        vm.expectRevert();
        ITransparentUpgradeableProxy(address(orProxy))
            .upgradeToAndCall(
                address(newImplementation),
                abi.encodeWithSelector(OperatorsRegistryV1.initOperatorsRegistryV1_2.selector)
            );
    }

    function _label(string memory field, uint256 idx) internal pure returns (string memory) {
        return string.concat(field, " mismatch at operator ", vm.toString(idx));
    }
}
