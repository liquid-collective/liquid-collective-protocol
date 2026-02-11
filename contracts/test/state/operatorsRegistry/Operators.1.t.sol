//SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.33;

import "forge-std/Test.sol";

import "../../../src/state/operatorsRegistry/Operators.1.sol";
import "../../utils/LibImplementationUnbricker.sol";

/// @title Harness contract to expose internal OperatorsV1 library functions
contract OperatorsV1Harness {
    /// @notice Push a new operator
    function push(OperatorsV1.Operator memory _operator) external returns (uint256) {
        return OperatorsV1.push(_operator);
    }

    /// @notice Get an operator by index
    function get(uint256 _index) external view returns (OperatorsV1.Operator memory) {
        return OperatorsV1.get(_index);
    }

    /// @notice Get the count of operators
    function getCount() external view returns (uint256) {
        return OperatorsV1.getCount();
    }

    /// @notice Get all active operators
    function getAllActive() external view returns (OperatorsV1.Operator[] memory) {
        return OperatorsV1.getAllActive();
    }

    /// @notice Get all fundable operators
    function getAllFundable() external view returns (OperatorsV1.CachedOperator[] memory) {
        return OperatorsV1.getAllFundable();
    }

    /// @notice Set keys for an operator
    function setKeys(uint256 _index, uint256 _newKeys) external {
        OperatorsV1.setKeys(_index, _newKeys);
    }

    /// @notice Check if operator has fundable keys
    function hasFundableKeys(OperatorsV1.Operator memory _operator) external pure returns (bool) {
        return OperatorsV1._hasFundableKeys(_operator);
    }

    /// @notice Helper to set operator fields for testing
    function setOperatorActive(uint256 _index, bool _active) external {
        OperatorsV1.Operator storage op = OperatorsV1.get(_index);
        op.active = _active;
    }

    /// @notice Helper to set operator limit for testing
    function setOperatorLimit(uint256 _index, uint256 _limit) external {
        OperatorsV1.Operator storage op = OperatorsV1.get(_index);
        op.limit = _limit;
    }

    /// @notice Helper to set operator funded for testing
    function setOperatorFunded(uint256 _index, uint256 _funded) external {
        OperatorsV1.Operator storage op = OperatorsV1.get(_index);
        op.funded = _funded;
    }
}

contract OperatorsV1Test is Test {
    OperatorsV1Harness internal harness;

    function setUp() public {
        harness = new OperatorsV1Harness();
    }

    /// @notice Helper to create a valid operator
    function _createOperator(string memory _name, address _addr, bool _active)
        internal
        pure
        returns (OperatorsV1.Operator memory)
    {
        return OperatorsV1.Operator({
            active: _active,
            name: _name,
            operator: _addr,
            limit: 0,
            funded: 0,
            keys: 0,
            stopped: 0,
            latestKeysEditBlockNumber: 0
        });
    }

    // ============ push() tests ============

    function testPushOperator() public {
        OperatorsV1.Operator memory op = _createOperator("Operator One", address(0x1), true);

        uint256 count = harness.push(op);

        assertEq(count, 1, "Expected count to be 1 after push");
        assertEq(harness.getCount(), 1, "Expected getCount to return 1");
    }

    function testPushMultipleOperators() public {
        OperatorsV1.Operator memory op1 = _createOperator("Operator One", address(0x1), true);
        OperatorsV1.Operator memory op2 = _createOperator("Operator Two", address(0x2), true);
        OperatorsV1.Operator memory op3 = _createOperator("Operator Three", address(0x3), false);

        harness.push(op1);
        harness.push(op2);
        uint256 count = harness.push(op3);

        assertEq(count, 3, "Expected count to be 3 after 3 pushes");
    }

    function testPushOperatorZeroAddressReverts() public {
        OperatorsV1.Operator memory op = _createOperator("Operator One", address(0), true);

        vm.expectRevert(abi.encodeWithSignature("InvalidZeroAddress()"));
        harness.push(op);
    }

    function testPushOperatorEmptyNameReverts() public {
        OperatorsV1.Operator memory op = _createOperator("", address(0x1), true);

        vm.expectRevert(abi.encodeWithSignature("InvalidEmptyString()"));
        harness.push(op);
    }

    // ============ get() tests ============

    function testGetOperator() public {
        OperatorsV1.Operator memory op = _createOperator("Operator One", address(0x1), true);
        harness.push(op);

        OperatorsV1.Operator memory retrieved = harness.get(0);

        assertEq(retrieved.name, "Operator One", "Name mismatch");
        assertEq(retrieved.operator, address(0x1), "Operator address mismatch");
        assertTrue(retrieved.active, "Should be active");
    }

    function testGetOperatorNotFoundReverts() public {
        vm.expectRevert(abi.encodeWithSignature("OperatorNotFound(uint256)", 0));
        harness.get(0);
    }

    function testGetOperatorOutOfBoundsReverts() public {
        OperatorsV1.Operator memory op = _createOperator("Operator One", address(0x1), true);
        harness.push(op);

        vm.expectRevert(abi.encodeWithSignature("OperatorNotFound(uint256)", 5));
        harness.get(5);
    }

    // ============ getCount() tests ============

    function testGetCountEmpty() public {
        assertEq(harness.getCount(), 0, "Expected count to be 0 initially");
    }

    function testGetCountAfterPush() public {
        harness.push(_createOperator("Op1", address(0x1), true));
        harness.push(_createOperator("Op2", address(0x2), true));

        assertEq(harness.getCount(), 2, "Expected count to be 2");
    }

    // ============ getAllActive() tests ============

    function testGetAllActiveEmpty() public {
        OperatorsV1.Operator[] memory active = harness.getAllActive();
        assertEq(active.length, 0, "Expected empty array");
    }

    function testGetAllActiveAllActive() public {
        harness.push(_createOperator("Op1", address(0x1), true));
        harness.push(_createOperator("Op2", address(0x2), true));
        harness.push(_createOperator("Op3", address(0x3), true));

        OperatorsV1.Operator[] memory active = harness.getAllActive();

        assertEq(active.length, 3, "Expected 3 active operators");
    }

    function testGetAllActiveWithInactive() public {
        harness.push(_createOperator("Op1", address(0x1), true));
        harness.push(_createOperator("Op2", address(0x2), false));
        harness.push(_createOperator("Op3", address(0x3), true));

        OperatorsV1.Operator[] memory active = harness.getAllActive();

        assertEq(active.length, 2, "Expected 2 active operators");
        assertEq(active[0].name, "Op1", "First active should be Op1");
        assertEq(active[1].name, "Op3", "Second active should be Op3");
    }

    function testGetAllActiveNoneActive() public {
        harness.push(_createOperator("Op1", address(0x1), false));
        harness.push(_createOperator("Op2", address(0x2), false));

        OperatorsV1.Operator[] memory active = harness.getAllActive();

        assertEq(active.length, 0, "Expected no active operators");
    }

    // ============ getAllFundable() tests ============

    function testGetAllFundableEmpty() public {
        OperatorsV1.CachedOperator[] memory fundable = harness.getAllFundable();
        assertEq(fundable.length, 0, "Expected empty array");
    }

    function testGetAllFundableWithFundableOperator() public {
        harness.push(_createOperator("Op1", address(0x1), true));
        harness.setOperatorLimit(0, 10);

        OperatorsV1.CachedOperator[] memory fundable = harness.getAllFundable();

        assertEq(fundable.length, 1, "Expected 1 fundable operator");
        assertEq(fundable[0].limit, 10, "Limit should be 10");
        assertEq(fundable[0].funded, 0, "Funded should be 0");
        assertEq(fundable[0].index, 0, "Index should be 0");
    }

    function testGetAllFundableNotFundableWhenLimitEqualsFunded() public {
        harness.push(_createOperator("Op1", address(0x1), true));
        harness.setOperatorLimit(0, 10);
        harness.setOperatorFunded(0, 10);

        OperatorsV1.CachedOperator[] memory fundable = harness.getAllFundable();

        assertEq(fundable.length, 0, "Expected no fundable operators when limit == funded");
    }

    function testGetAllFundableNotFundableWhenInactive() public {
        harness.push(_createOperator("Op1", address(0x1), false));
        harness.setOperatorLimit(0, 10);

        OperatorsV1.CachedOperator[] memory fundable = harness.getAllFundable();

        assertEq(fundable.length, 0, "Expected no fundable operators when inactive");
    }

    function testGetAllFundableMixed() public {
        // Op0: active, fundable (limit > funded)
        harness.push(_createOperator("Op0", address(0x1), true));
        harness.setOperatorLimit(0, 10);
        harness.setOperatorFunded(0, 5);

        // Op1: active, not fundable (limit == funded)
        harness.push(_createOperator("Op1", address(0x2), true));
        harness.setOperatorLimit(1, 10);
        harness.setOperatorFunded(1, 10);

        // Op2: inactive, would be fundable but inactive
        harness.push(_createOperator("Op2", address(0x3), false));
        harness.setOperatorLimit(2, 10);

        // Op3: active, fundable
        harness.push(_createOperator("Op3", address(0x4), true));
        harness.setOperatorLimit(3, 20);
        harness.setOperatorFunded(3, 15);

        OperatorsV1.CachedOperator[] memory fundable = harness.getAllFundable();

        assertEq(fundable.length, 2, "Expected 2 fundable operators");
        assertEq(fundable[0].index, 0, "First fundable should be index 0");
        assertEq(fundable[1].index, 3, "Second fundable should be index 3");
    }

    // ============ setKeys() tests ============

    function testSetKeys() public {
        harness.push(_createOperator("Op1", address(0x1), true));

        uint256 blockBefore = block.number;
        vm.roll(block.number + 10);

        harness.setKeys(0, 100);

        OperatorsV1.Operator memory op = harness.get(0);
        assertEq(op.keys, 100, "Keys should be 100");
        assertEq(op.latestKeysEditBlockNumber, blockBefore + 10, "Block number should be updated");
    }

    function testSetKeysUpdatesBlockNumber() public {
        harness.push(_createOperator("Op1", address(0x1), true));

        vm.roll(50);
        harness.setKeys(0, 10);

        OperatorsV1.Operator memory op = harness.get(0);
        assertEq(op.latestKeysEditBlockNumber, 50, "Block number should be 50");

        vm.roll(100);
        harness.setKeys(0, 20);

        op = harness.get(0);
        assertEq(op.latestKeysEditBlockNumber, 100, "Block number should be updated to 100");
        assertEq(op.keys, 20, "Keys should be 20");
    }

    function testSetKeysOperatorNotFoundReverts() public {
        vm.expectRevert(abi.encodeWithSignature("OperatorNotFound(uint256)", 0));
        harness.setKeys(0, 100);
    }

    // ============ _hasFundableKeys() tests ============

    function testHasFundableKeysActiveWithAvailableKeys() public {
        OperatorsV1.Operator memory op = OperatorsV1.Operator({
            active: true,
            name: "Op1",
            operator: address(0x1),
            limit: 10,
            funded: 5,
            keys: 10,
            stopped: 0,
            latestKeysEditBlockNumber: 0
        });

        assertTrue(harness.hasFundableKeys(op), "Should be fundable");
    }

    function testHasFundableKeysInactive() public {
        OperatorsV1.Operator memory op = OperatorsV1.Operator({
            active: false,
            name: "Op1",
            operator: address(0x1),
            limit: 10,
            funded: 5,
            keys: 10,
            stopped: 0,
            latestKeysEditBlockNumber: 0
        });

        assertFalse(harness.hasFundableKeys(op), "Should not be fundable when inactive");
    }

    function testHasFundableKeysLimitEqualsFunded() public {
        OperatorsV1.Operator memory op = OperatorsV1.Operator({
            active: true,
            name: "Op1",
            operator: address(0x1),
            limit: 10,
            funded: 10,
            keys: 10,
            stopped: 0,
            latestKeysEditBlockNumber: 0
        });

        assertFalse(harness.hasFundableKeys(op), "Should not be fundable when limit == funded");
    }

    function testHasFundableKeysZeroLimit() public {
        OperatorsV1.Operator memory op = OperatorsV1.Operator({
            active: true,
            name: "Op1",
            operator: address(0x1),
            limit: 0,
            funded: 0,
            keys: 10,
            stopped: 0,
            latestKeysEditBlockNumber: 0
        });

        assertFalse(harness.hasFundableKeys(op), "Should not be fundable when limit is 0");
    }
}
