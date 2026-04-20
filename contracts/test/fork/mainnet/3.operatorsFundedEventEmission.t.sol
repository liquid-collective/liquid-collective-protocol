// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "forge-std/Test.sol";

import "../../../src/state/migration/OperatorsRegistry_FundedKeyEventRebroadcasting_OperatorIndex.sol";

/// @notice Verifies that the forceFundedValidatorKeysEventEmission migration completed on mainnet
/// before the function was removed. This is a pre-deployment gate: if this test fails, the migration
/// has NOT finished and the removal is unsafe.
contract OperatorsFundedEventEmissionComplete is Test {
    bool internal _skip = false;

    address internal constant OPERATORS_REGISTRY_MAINNET_ADDRESS = 0x1235f1b60df026B2620e48E735C422425E06b725;

    /// @dev Storage slot from OperatorsRegistry_FundedKeyEventRebroadcasting_OperatorIndex
    bytes32 internal constant OPERATOR_INDEX_SLOT = bytes32(
        uint256(keccak256("river.state.migration.operatorsRegistry.fundedKeyEventRebroadcasting.operatorIndex")) - 1
    );

    function setUp() external {
        try vm.envString("MAINNET_FORK_RPC_URL") returns (string memory rpcUrl) {
            vm.createSelectFork(rpcUrl);
            console.log("3.operatorsFundedEventEmission.t.sol is active");
        } catch {
            _skip = true;
        }
    }

    modifier shouldSkip() {
        if (!_skip) {
            _;
        }
    }

    /// @notice The migration is complete when operatorIndex == type(uint256).max.
    /// If this fails, forceFundedValidatorKeysEventEmission has NOT been fully called
    /// and the function must NOT be removed yet.
    function test_fundedKeyEventMigrationIsComplete() external shouldSkip {
        bytes32 raw = vm.load(OPERATORS_REGISTRY_MAINNET_ADDRESS, OPERATOR_INDEX_SLOT);
        uint256 operatorIndex = uint256(raw);

        assertEq(
            operatorIndex,
            type(uint256).max,
            "forceFundedValidatorKeysEventEmission migration is NOT complete on mainnet - do NOT deploy the removal"
        );
    }
}
