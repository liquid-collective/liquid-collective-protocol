//SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.34;

import "forge-std/Test.sol";

import "../../../src/TUPProxy.sol";
import "../../../src/OperatorsRegistry.1.sol";
import "../../../src/state/operatorsRegistry/Operators.2.sol";
import {
    ITransparentUpgradeableProxy
} from "openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

/// @notice Test-only subclass exposing V2-format read accessors. After initOperatorsRegistryV1_1
/// @notice (V1 -> V2) the operators live in OperatorsV2 storage, but the production OperatorsRegistryV1
/// @notice is V3-native: its getOperator decodes storage as V3 and the V2 stopped-validator getters were
/// @notice removed. These views let this fork test observe the intermediate V2 state produced by the
/// @notice V1 -> V2 migration in isolation, before the V2 -> V3 step runs.
contract OperatorsRegistryV1WithV2Views is OperatorsRegistryV1 {
    function getOperatorV2(uint256 _index) external view returns (OperatorsV2.Operator memory) {
        return OperatorsV2.get(_index);
    }

    function getOperatorCountV2() external view returns (uint256) {
        return OperatorsV2.getCount();
    }

    function getTotalStoppedValidatorCountV2() external view returns (uint256) {
        uint32[] memory stopped = OperatorsV2.getStoppedValidators();
        return stopped.length == 0 ? 0 : stopped[0];
    }

    function getOperatorStoppedValidatorCountV2(uint256 _index) external view returns (uint32) {
        uint32[] memory stopped = OperatorsV2.getStoppedValidators();
        return stopped.length > _index + 1 ? stopped[_index + 1] : 0;
    }
}

/// @notice Exercises the V1 -> V2 operator migration (initOperatorsRegistryV1_1) against a pre-V1_1
/// @notice mainnet fork and asserts the resulting intermediate V2 operator state.
contract OperatorsMigrationV1ToV2 is Test {
    bool internal _skip = false;

    function setUp() external {
        try vm.envString("MAINNET_FORK_RPC_URL") returns (string memory rpcUrl) {
            vm.createSelectFork(rpcUrl, 16690000);
            console.log("2.operatorsMigrationV1toV2.t.sol is active");
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

        OperatorsRegistryV1WithV2Views newImplementation = new OperatorsRegistryV1WithV2Views();

        // Run V1 -> V2 migration (initOperatorsRegistryV1_1 migrates the operator structs from V1 to V2)
        vm.prank(OPERATORS_REGISTRY_MAINNET_PROXY_ADMIN_ADDRESS);
        ITransparentUpgradeableProxy(address(orProxy))
            .upgradeToAndCall(
                address(newImplementation), abi.encodeCall(OperatorsRegistryV1.initOperatorsRegistryV1_1, ())
            );

        OperatorsRegistryV1WithV2Views or = OperatorsRegistryV1WithV2Views(OPERATORS_REGISTRY_MAINNET_ADDRESS);

        assertEq(or.getOperatorCountV2(), 3);
        assertEq(or.getTotalStoppedValidatorCountV2(), 0);
        {
            OperatorsV2.Operator memory op0 = or.getOperatorV2(0);
            assertEq(op0.limit, 0);
            assertEq(op0.funded, 0);
            assertEq(op0.requestedExits, 0);
            assertEq(op0.keys, 25);
            assertEq(op0.latestKeysEditBlockNumber, 16020173);
            assertEq(op0.active, true);
            assertEq(op0.name, "Figment");
            assertEq(op0.operator, 0xDfB087180Dc5e99655Bf7e61D53dD6d25a023253);

            assertEq(or.getOperatorStoppedValidatorCountV2(0), 0);
        }

        {
            OperatorsV2.Operator memory op1 = or.getOperatorV2(1);
            assertEq(op1.limit, 25);
            assertEq(op1.funded, 1);
            assertEq(op1.requestedExits, 0);
            assertEq(op1.keys, 25);
            assertEq(op1.latestKeysEditBlockNumber, 15990905);
            assertEq(op1.active, true);
            assertEq(op1.name, "Coinbase Cloud");
            assertEq(op1.operator, 0x75DC82105B5c482402A4267F628036254F380967);

            assertEq(or.getOperatorStoppedValidatorCountV2(1), 0);
        }

        {
            OperatorsV2.Operator memory op2 = or.getOperatorV2(2);
            assertEq(op2.limit, 25);
            assertEq(op2.funded, 0);
            assertEq(op2.requestedExits, 0);
            assertEq(op2.keys, 25);
            assertEq(op2.latestKeysEditBlockNumber, 15991176);
            assertEq(op2.active, true);
            assertEq(op2.name, "Staked");
            assertEq(op2.operator, 0x7070CBfD67fDf8077d27548E86505F9F91C31621);

            assertEq(or.getOperatorStoppedValidatorCountV2(2), 0);
        }
    }
}
