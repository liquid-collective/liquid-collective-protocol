//SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.34;

import "forge-std/Test.sol";

import "./OperatorAllocationTestBase.sol";
import "../src/libraries/LibBytes.sol";
import "./utils/UserFactory.sol";
import "./utils/BytesGenerator.sol";
import "./utils/LibImplementationUnbricker.sol";

import "../src/OperatorsRegistry.1.sol";

contract OperatorsRegistryInitializableV1 is OperatorsRegistryV1 {
    /// @dev Override to allow tests to call functions without pranking as river
    modifier onlyRiver() override {
        _;
    }

    function sudoSetFunded(uint256 _index, uint32 _funded) external {
        OperatorsV3.Operator storage operator = OperatorsV3.get(_index);
        operator.funded = _funded;
    }

    function sudoExitRequests(uint256 _operatorIndex, uint32 _requestedExits) external {
        OperatorsV3.get(_operatorIndex).requestedExits = _requestedExits;
    }

    function sudoStoppedValidatorCounts(uint32[] calldata stoppedValidatorCount, uint256 depositedValidatorCount)
        external
    {
        _setStoppedValidatorCounts(stoppedValidatorCount, depositedValidatorCount);
    }
}

/// @dev Same as OperatorsRegistryInitializableV1 but does NOT override onlyRiver; use for tests that assert Unauthorized
contract OperatorsRegistryStrictRiverV1 is OperatorsRegistryV1 {
    function sudoSetFunded(uint256 _index, uint32 _funded) external {
        OperatorsV3.Operator storage operator = OperatorsV3.get(_index);
        operator.funded = _funded;
    }

    function sudoExitRequests(uint256 _operatorIndex, uint32 _requestedExits) external {
        OperatorsV3.get(_operatorIndex).requestedExits = _requestedExits;
    }

    function sudoStoppedValidatorCounts(uint32[] calldata stoppedValidatorCount, uint256 depositedValidatorCount)
        external
    {
        _setStoppedValidatorCounts(stoppedValidatorCount, depositedValidatorCount);
    }
}

contract RiverMock {
    uint256 public getDepositedValidatorCount;
    address public keeper;

    constructor(uint256 _getDepositedValidatorsCount) {
        getDepositedValidatorCount = _getDepositedValidatorsCount;
    }

    function sudoSetDepositedValidatorsCount(uint256 _getDepositedValidatorsCount) external {
        getDepositedValidatorCount = _getDepositedValidatorsCount;
    }

    function setKeeper(address _keeper) external {
        keeper = _keeper;
    }

    function getKeeper() external view returns (address) {
        return keeper;
    }
}

abstract contract OperatorsRegistryV1TestBase is Test {
    UserFactory internal uf = new UserFactory();

    OperatorsRegistryV1 internal operatorsRegistry;
    address internal admin;
    address internal river;
    address internal keeper;
    string internal firstName = "Operator One";
    string internal secondName = "Operator Two";

    event SetRiver(address indexed river);
    event UpdatedStoppedValidators(uint32[] stoppedValidatorCounts);
    event SetOperatorStoppedValidatorCount(uint256 indexed index, uint256 newStoppedValidatorCount);
}

contract OperatorsRegistryV1InitializationTests is OperatorsRegistryV1TestBase {
    function setUp() public {
        admin = makeAddr("admin");
        keeper = makeAddr("keeper");
        river = address(new RiverMock(0));
        RiverMock(river).setKeeper(keeper);
        operatorsRegistry = new OperatorsRegistryInitializableV1();
        LibImplementationUnbricker.unbrick(vm, address(operatorsRegistry));
    }

    function testInitialization() public {
        vm.expectEmit(true, true, true, true);
        emit SetRiver(river);
        operatorsRegistry.initOperatorsRegistryV1(admin, river);

        assertEq(river, operatorsRegistry.getRiver());
        assertEq(admin, operatorsRegistry.getAdmin());
    }
}

/// @notice Tests that require real onlyRiver enforcement (expect Unauthorized when not pranking as river)
contract OperatorsRegistryV1StrictRiverTests is
    OperatorsRegistryV1TestBase,
    OperatorAllocationTestBase,
    BytesGenerator
{
    function setUp() public {
        admin = makeAddr("admin");
        keeper = makeAddr("keeper");
        river = address(new RiverMock(0));
        RiverMock(river).setKeeper(keeper);
        operatorsRegistry = new OperatorsRegistryStrictRiverV1();
        LibImplementationUnbricker.unbrick(vm, address(operatorsRegistry));
        operatorsRegistry.initOperatorsRegistryV1(admin, river);
    }

    function testReportStoppedValidatorCountsUnauthorized(uint256 _salt, uint32 totalCount, uint8 len) public {
        address random = uf._new(_salt);
        vm.assume(len > 0 && len < type(uint8).max);
        totalCount = uint32(bound(totalCount, len, type(uint32).max));

        uint32[] memory stoppedValidatorCounts = new uint32[](len + 1);
        stoppedValidatorCounts[0] = totalCount;

        for (uint256 idx = 1; idx < len + 1; ++idx) {
            vm.prank(admin);
            operatorsRegistry.addOperator(string(abi.encodePacked(idx)), address(123));
            stoppedValidatorCounts[idx] = (totalCount / len) + (idx - 1 < totalCount % len ? 1 : 0);
        }

        vm.prank(random);
        vm.expectRevert(abi.encodeWithSignature("Unauthorized(address)", random));
        operatorsRegistry.reportStoppedValidatorCounts(stoppedValidatorCounts, totalCount);
    }
}

contract OperatorsRegistryV1Tests is OperatorsRegistryV1TestBase, OperatorAllocationTestBase, BytesGenerator {
    function setUp() public {
        admin = makeAddr("admin");
        keeper = makeAddr("keeper");
        river = address(new RiverMock(0));
        RiverMock(river).setKeeper(keeper);
        operatorsRegistry = new OperatorsRegistryInitializableV1();
        LibImplementationUnbricker.unbrick(vm, address(operatorsRegistry));
        operatorsRegistry.initOperatorsRegistryV1(admin, river);
    }

    function testInitializeTwice() public {
        vm.expectRevert(abi.encodeWithSignature("InvalidInitialization(uint256,uint256)", 0, 1));
        operatorsRegistry.initOperatorsRegistryV1(admin, river);
    }

    function testAddNodeOperator(uint256 _nodeOperatorAddressSalt, bytes32 _name) public {
        address _nodeOperatorAddress = uf._new(_nodeOperatorAddressSalt);
        vm.startPrank(admin);
        uint256 operatorIndex = operatorsRegistry.addOperator(string(abi.encodePacked(_name)), _nodeOperatorAddress);
        OperatorsV3.Operator memory newOperator = operatorsRegistry.getOperator(operatorIndex);
        assert(newOperator.operator == _nodeOperatorAddress);
    }

    function testAddNodeOperatorInvalidAddress(bytes32 _name) public {
        vm.startPrank(admin);
        vm.expectRevert(abi.encodeWithSignature("InvalidZeroAddress()"));
        operatorsRegistry.addOperator(string(abi.encodePacked(_name)), address(0));
    }

    function testAddNodeOperatorInvalidName(uint256 _nodeOperatorAddressSalt) public {
        address _nodeOperatorAddress = uf._new(_nodeOperatorAddressSalt);
        vm.startPrank(admin);
        vm.expectRevert(abi.encodeWithSignature("InvalidEmptyString()"));
        operatorsRegistry.addOperator("", _nodeOperatorAddress);
    }

    function testAddNodeWhileNotAdminOperator(uint256 _nodeOperatorAddressSalt, bytes32 _name) public {
        address _nodeOperatorAddress = uf._new(_nodeOperatorAddressSalt);
        vm.expectRevert(abi.encodeWithSignature("Unauthorized(address)", address(this)));
        operatorsRegistry.addOperator(string(abi.encodePacked(_name)), _nodeOperatorAddress);
    }

    function testSetOperatorAddressesAsAdmin(bytes32 _name, uint256 _firstAddressSalt, uint256 _secondAddressSalt)
        public
    {
        address _firstAddress = uf._new(_firstAddressSalt);
        address _secondAddress = uf._new(_secondAddressSalt);
        vm.startPrank(admin);
        uint256 index = operatorsRegistry.addOperator(string(abi.encodePacked(_name)), _firstAddress);
        OperatorsV3.Operator memory newOperator = operatorsRegistry.getOperator(index);
        assert(newOperator.operator == _firstAddress);
        operatorsRegistry.setOperatorAddress(index, _secondAddress);
        newOperator = operatorsRegistry.getOperator(index);
        assert(newOperator.operator == _secondAddress);
        vm.stopPrank();
    }

    function testSetOperatorAddressAsOperator(bytes32 _name, uint256 _firstAddressSalt, uint256 _secondAddressSalt)
        public
    {
        address _firstAddress = uf._new(_firstAddressSalt);
        address _secondAddress = uf._new(_secondAddressSalt);
        vm.startPrank(admin);
        uint256 index = operatorsRegistry.addOperator(string(abi.encodePacked(_name)), _firstAddress);
        OperatorsV3.Operator memory newOperator = operatorsRegistry.getOperator(index);
        assert(newOperator.operator == _firstAddress);
        vm.stopPrank();
        vm.startPrank(_firstAddress);
        operatorsRegistry.setOperatorAddress(index, _secondAddress);
        vm.stopPrank();
        newOperator = operatorsRegistry.getOperator(index);
        assert(newOperator.operator == _secondAddress);
    }

    function testSetOperatorAddressZeroAddr(bytes32 _name, uint256 _firstAddressSalt) public {
        address _firstAddress = uf._new(_firstAddressSalt);
        vm.startPrank(admin);
        uint256 index = operatorsRegistry.addOperator(string(abi.encodePacked(_name)), _firstAddress);
        OperatorsV3.Operator memory newOperator = operatorsRegistry.getOperator(index);
        assert(newOperator.operator == _firstAddress);
        vm.stopPrank();
        vm.startPrank(_firstAddress);
        vm.expectRevert(abi.encodeWithSignature("InvalidZeroAddress()"));
        operatorsRegistry.setOperatorAddress(index, address(0));
        vm.stopPrank();
    }

    function testSetOperatorAddressAsUnauthorized(bytes32 _name, uint256 _firstAddressSalt, uint256 _secondAddressSalt)
        public
    {
        address _firstAddress = uf._new(_firstAddressSalt);
        address _secondAddress = uf._new(_secondAddressSalt);
        vm.startPrank(admin);
        uint256 index = operatorsRegistry.addOperator(string(abi.encodePacked(_name)), _firstAddress);
        OperatorsV3.Operator memory newOperator = operatorsRegistry.getOperator(index);
        assert(newOperator.operator == _firstAddress);
        vm.stopPrank();
        vm.startPrank(address(this));
        vm.expectRevert(abi.encodeWithSignature("Unauthorized(address)", address(this)));
        operatorsRegistry.setOperatorAddress(index, _secondAddress);
        vm.stopPrank();
    }

    function testSetOperatorNameAsAdmin(bytes32 _name, uint256 _addressSalt) public {
        address _address = uf._new(_addressSalt);
        bytes32 _nextName = keccak256(abi.encodePacked(_name));
        vm.startPrank(admin);
        uint256 index = operatorsRegistry.addOperator(string(abi.encodePacked(_name)), _address);
        OperatorsV3.Operator memory newOperator = operatorsRegistry.getOperator(index);
        assert(keccak256(bytes(newOperator.name)) == keccak256(bytes(string(abi.encodePacked(_name)))));
        operatorsRegistry.setOperatorName(index, string(abi.encodePacked(_nextName)));
        newOperator = operatorsRegistry.getOperator(index);
        assert(keccak256(bytes(newOperator.name)) == keccak256(bytes(string(abi.encodePacked(_nextName)))));
        vm.stopPrank();
    }

    function testSetOperatorNameAsOperator(bytes32 _name, uint256 _addressSalt) public {
        address _address = uf._new(_addressSalt);
        bytes32 _nextName = keccak256(abi.encodePacked(_name));
        vm.startPrank(admin);
        uint256 index = operatorsRegistry.addOperator(string(abi.encodePacked(_name)), _address);
        vm.stopPrank();
        OperatorsV3.Operator memory newOperator = operatorsRegistry.getOperator(index);
        assert(keccak256(bytes(newOperator.name)) == keccak256(bytes(string(abi.encodePacked(_name)))));
        vm.startPrank(_address);
        operatorsRegistry.setOperatorName(index, string(abi.encodePacked(_nextName)));
        vm.stopPrank();
        newOperator = operatorsRegistry.getOperator(index);
        assert(keccak256(bytes(newOperator.name)) == keccak256(bytes(string(abi.encodePacked(_nextName)))));
    }

    function testSetOperatorNameEmptyString(bytes32 _name, uint256 _addressSalt) public {
        address _address = uf._new(_addressSalt);
        vm.startPrank(admin);
        uint256 index = operatorsRegistry.addOperator(string(abi.encodePacked(_name)), _address);
        vm.stopPrank();
        OperatorsV3.Operator memory newOperator = operatorsRegistry.getOperator(index);
        assert(keccak256(bytes(newOperator.name)) == keccak256(bytes(string(abi.encodePacked(_name)))));
        vm.startPrank(_address);
        vm.expectRevert(abi.encodeWithSignature("InvalidEmptyString()"));
        operatorsRegistry.setOperatorName(index, "");
        vm.stopPrank();
    }

    function testSetOperatorNameAsUnauthorized(bytes32 _name, uint256 _addressSalt) public {
        address _address = uf._new(_addressSalt);
        bytes32 _nextName = keccak256(abi.encodePacked(_name));
        vm.startPrank(admin);
        uint256 index = operatorsRegistry.addOperator(string(abi.encodePacked(_name)), _address);
        vm.stopPrank();
        OperatorsV3.Operator memory newOperator = operatorsRegistry.getOperator(index);
        assert(keccak256(bytes(newOperator.name)) == keccak256(bytes(string(abi.encodePacked(_name)))));
        vm.startPrank(address(this));
        vm.expectRevert(abi.encodeWithSignature("Unauthorized(address)", address(this)));
        operatorsRegistry.setOperatorName(index, string(abi.encodePacked(_nextName)));
        vm.stopPrank();
    }

    // ──────────────────────────────────────────────────────────────────────
    // onlyOperatorOrAdmin modifier
    // ──────────────────────────────────────────────────────────────────────

    function testOnlyOperatorOrAdmin_AdminCanActOnInactiveOperator() public {
        address opAddr = makeAddr("operator");
        vm.startPrank(admin);
        uint256 index = operatorsRegistry.addOperator("InactiveOp", opAddr);
        operatorsRegistry.setOperatorStatus(index, false);

        // Admin should still be able to change the name of an inactive operator
        operatorsRegistry.setOperatorName(index, "RenamedWhileInactive");
        assertEq(operatorsRegistry.getOperator(index).name, "RenamedWhileInactive");

        // Admin should still be able to change the address of an inactive operator
        address newAddr = makeAddr("newOperator");
        operatorsRegistry.setOperatorAddress(index, newAddr);
        assertEq(operatorsRegistry.getOperator(index).operator, newAddr);
        vm.stopPrank();
    }

    function testOnlyOperatorOrAdmin_InactiveOperatorCannotCallItself() public {
        address opAddr = makeAddr("operator");
        vm.startPrank(admin);
        uint256 index = operatorsRegistry.addOperator("InactiveOp", opAddr);
        operatorsRegistry.setOperatorStatus(index, false);
        vm.stopPrank();

        vm.startPrank(opAddr);
        vm.expectRevert(abi.encodeWithSignature("InactiveOperator(uint256)", index));
        operatorsRegistry.setOperatorName(index, "ShouldFail");
        vm.stopPrank();
    }

    function testOnlyOperatorOrAdmin_InactiveOperatorCannotChangeAddress() public {
        address opAddr = makeAddr("operator");
        vm.startPrank(admin);
        uint256 index = operatorsRegistry.addOperator("InactiveOp", opAddr);
        operatorsRegistry.setOperatorStatus(index, false);
        vm.stopPrank();

        vm.startPrank(opAddr);
        vm.expectRevert(abi.encodeWithSignature("InactiveOperator(uint256)", index));
        operatorsRegistry.setOperatorAddress(index, makeAddr("irrelevant"));
        vm.stopPrank();
    }

    function testOnlyOperatorOrAdmin_UnauthorizedOnInactiveOperator() public {
        address opAddr = makeAddr("operator");
        address stranger = makeAddr("stranger");
        vm.startPrank(admin);
        uint256 index = operatorsRegistry.addOperator("InactiveOp", opAddr);
        operatorsRegistry.setOperatorStatus(index, false);
        vm.stopPrank();

        // Stranger hits the inactive check before the operator-address check
        vm.startPrank(stranger);
        vm.expectRevert(abi.encodeWithSignature("InactiveOperator(uint256)", index));
        operatorsRegistry.setOperatorName(index, "ShouldFail");
        vm.stopPrank();
    }

    function testOnlyOperatorOrAdmin_UnauthorizedOnActiveOperator() public {
        address opAddr = makeAddr("operator");
        address stranger = makeAddr("stranger");
        vm.startPrank(admin);
        uint256 index = operatorsRegistry.addOperator("ActiveOp", opAddr);
        vm.stopPrank();

        // Operator is active, so the modifier proceeds past the active check
        // but stranger's address doesn't match → Unauthorized
        vm.startPrank(stranger);
        vm.expectRevert(abi.encodeWithSignature("Unauthorized(address)", stranger));
        operatorsRegistry.setOperatorName(index, "ShouldFail");
        vm.stopPrank();
    }

    function testOnlyOperatorOrAdmin_ActiveOperatorCanCall() public {
        address opAddr = makeAddr("operator");
        vm.startPrank(admin);
        uint256 index = operatorsRegistry.addOperator("ActiveOp", opAddr);
        vm.stopPrank();

        vm.startPrank(opAddr);
        operatorsRegistry.setOperatorName(index, "RenamedByOperator");
        assertEq(operatorsRegistry.getOperator(index).name, "RenamedByOperator");
        vm.stopPrank();
    }

    function testSetOperatorStatusAsAdmin(bytes32 _name, uint256 _firstAddressSalt) public {
        address _firstAddress = uf._new(_firstAddressSalt);
        vm.startPrank(admin);
        uint256 index = operatorsRegistry.addOperator(string(abi.encodePacked(_name)), _firstAddress);
        OperatorsV3.Operator memory newOperator = operatorsRegistry.getOperator(index);
        assert(newOperator.active == true);
        operatorsRegistry.setOperatorStatus(index, false);
        newOperator = operatorsRegistry.getOperator(index);
        assert(newOperator.active == false);
        operatorsRegistry.setOperatorStatus(index, true);
        newOperator = operatorsRegistry.getOperator(index);
        assert(newOperator.active == true);
    }

    function testSetOperatorStatusAsUnauthorized(bytes32 _name, uint256 _firstAddressSalt) public {
        address _firstAddress = uf._new(_firstAddressSalt);
        vm.startPrank(admin);
        uint256 index = operatorsRegistry.addOperator(string(abi.encodePacked(_name)), _firstAddress);
        OperatorsV3.Operator memory newOperator = operatorsRegistry.getOperator(index);
        assert(newOperator.active == true);
        vm.stopPrank();
        vm.startPrank(address(this));
        vm.expectRevert(abi.encodeWithSignature("Unauthorized(address)", address(this)));
        operatorsRegistry.setOperatorStatus(index, false);
    }

    function testGetAllActiveOperators(bytes32 _name, uint256 _firstAddressSalt, uint256 _count) public {
        vm.assume(_count < 1000);
        address[] memory _firstAddress = new address[](_count);
        _firstAddress = uf._newMulti(_firstAddressSalt, _count);
        vm.startPrank(admin);
        for (uint256 i; i < _count; i++) {
            operatorsRegistry.addOperator(string(abi.encodePacked(_name)), _firstAddress[i]);
        }

        OperatorsV3.Operator[] memory operators = operatorsRegistry.listActiveOperators();

        assert(operators.length == _count);
        for (uint256 i; i < _count; i++) {
            assert(keccak256(bytes(operators[i].name)) == keccak256(abi.encodePacked(_name)));
            assert(operators[i].operator == _firstAddress[i]);
        }
    }

    function testGetAllActiveOperatorsWithInactiveOnes(bytes32 _name, uint256 _firstAddressSalt, uint256 _count)
        public
    {
        vm.assume(_count < 1000);
        address[] memory _firstAddress = new address[](_count);
        _firstAddress = uf._newMulti(_firstAddressSalt, _count);
        vm.startPrank(admin);
        for (uint256 i; i < _count; i++) {
            uint256 index = operatorsRegistry.addOperator(string(abi.encodePacked(_name)), _firstAddress[i]);

            operatorsRegistry.setOperatorStatus(index, false);
        }

        OperatorsV3.Operator[] memory operators = operatorsRegistry.listActiveOperators();

        assert(operators.length == 0);
    }

    function testGetOperator(bytes32 _name, uint256 _firstAddressSalt) public {
        address _firstAddress = uf._new(_firstAddressSalt);
        vm.startPrank(admin);
        uint256 index = operatorsRegistry.addOperator(string(abi.encodePacked(_name)), _firstAddress);

        OperatorsV3.Operator memory operator = operatorsRegistry.getOperator(index);
        assert(operator.active == true);
    }

    function testGetOperatorCount(bytes32 _name, uint256 _firstAddressSalt) public {
        address _firstAddress = uf._new(_firstAddressSalt);
        vm.startPrank(admin);
        assert(operatorsRegistry.getOperatorCount() == 0);
        operatorsRegistry.addOperator(string(abi.encodePacked(_name)), _firstAddress);
        assert(operatorsRegistry.getOperatorCount() == 1);
    }

    /// @dev Invariant: operator index equals array position; addOperator returns 0, 1, 2, ...
    function testOperatorIndexEqualsArrayPosition() public {
        address addr0 = uf._new(0);
        address addr1 = uf._new(1);
        address addr2 = uf._new(2);
        vm.startPrank(admin);
        uint256 index0 = operatorsRegistry.addOperator("op0", addr0);
        uint256 index1 = operatorsRegistry.addOperator("op1", addr1);
        uint256 index2 = operatorsRegistry.addOperator("op2", addr2);
        vm.stopPrank();

        assertEq(index0, 0, "first add returns 0");
        assertEq(index1, 1, "second add returns 1");
        assertEq(index2, 2, "third add returns 2");
        assertEq(operatorsRegistry.getOperatorCount(), 3, "count is 3");

        assertEq(operatorsRegistry.getOperator(0).operator, addr0, "index 0 is op0");
        assertEq(operatorsRegistry.getOperator(1).operator, addr1, "index 1 is op1");
        assertEq(operatorsRegistry.getOperator(2).operator, addr2, "index 2 is op2");
    }

    /// @dev Invariant: indices and count are stable after deactivation (operators are never removed)
    function testOperatorIndicesStableAfterDeactivation() public {
        address addr0 = uf._new(0);
        address addr1 = uf._new(1);
        address addr2 = uf._new(2);
        vm.startPrank(admin);
        operatorsRegistry.addOperator("op0", addr0);
        operatorsRegistry.addOperator("op1", addr1);
        operatorsRegistry.addOperator("op2", addr2);
        assertEq(operatorsRegistry.getOperatorCount(), 3);
        operatorsRegistry.setOperatorStatus(1, false);
        vm.stopPrank();

        assertEq(operatorsRegistry.getOperatorCount(), 3, "count unchanged after deactivation");
        assertEq(operatorsRegistry.getOperator(0).operator, addr0, "index 0 still op0");
        assertEq(operatorsRegistry.getOperator(1).operator, addr1, "index 1 still op1");
        assertFalse(operatorsRegistry.getOperator(1).active, "index 1 is inactive");
        assertEq(operatorsRegistry.getOperator(2).operator, addr2, "index 2 still op2");

        vm.prank(admin);
        operatorsRegistry.setOperatorStatus(1, true);
        assertEq(operatorsRegistry.getOperator(0).operator, addr0, "index 0 still op0 after reactivation");
        assertEq(operatorsRegistry.getOperator(1).operator, addr1, "index 1 is still 1 after reactivation");
        assertEq(operatorsRegistry.getOperator(2).operator, addr2, "index 2 still op2 after reactivation");
    }

    /// @dev getOperator(outOfBounds) reverts with OperatorNotFound
    function testGetOperatorOutOfBoundsRevertsWithOperatorNotFound() public {
        vm.startPrank(admin);
        vm.expectRevert(abi.encodeWithSignature("OperatorNotFound(uint256)", 0));
        operatorsRegistry.getOperator(0);

        operatorsRegistry.addOperator("only", uf._new(0));
        vm.expectRevert(abi.encodeWithSignature("OperatorNotFound(uint256)", 1));
        operatorsRegistry.getOperator(1);
        vm.stopPrank();
    }

    /// @dev Fuzz: operator indices stay 0, 1, ..., n-1 after n adds
    function testFuzzOperatorIndicesSequentialAfterMultipleAdds(uint8 _n) public {
        uint256 n = bound(_n, 1, 30);
        address[] memory addrs = new address[](n);
        vm.startPrank(admin);
        for (uint256 i = 0; i < n; ++i) {
            addrs[i] = uf._new(i);
            uint256 idx = operatorsRegistry.addOperator(string(abi.encodePacked("op", i)), addrs[i]);
            assertEq(idx, i, "addOperator returns sequential index");
        }
        vm.stopPrank();

        assertEq(operatorsRegistry.getOperatorCount(), n, "count equals n");
        for (uint256 i = 0; i < n; ++i) {
            assertEq(operatorsRegistry.getOperator(i).operator, addrs[i], "getOperator(i) is operator added at step i");
        }
    }

    function testGetStoppedValidatorCounts() public {
        assertEq(operatorsRegistry.getOperatorStoppedValidatorCount(0), 0);
        assertEq(operatorsRegistry.getTotalStoppedValidatorCount(), 0);
    }

    function testReportStoppedValidatorCounts(uint8 totalCount, uint8 len) public {
        // Cap len and totalCount to avoid MemoryOOG when adding many validators per operator
        // Original: len up to 127, totalCount up to 255
        // Each validator = 144 bytes, limit to ~30 validators per operator max
        len = uint8(bound(len, 1, 30));
        vm.assume(len > 0 && len < type(uint8).max);
        totalCount = uint8(bound(totalCount, len, 100));

        uint32[] memory stoppedValidatorCounts = new uint32[](len + 1);
        uint32[] memory limits = new uint32[](len);
        uint256[] memory operators = new uint256[](len);
        stoppedValidatorCounts[0] = totalCount;

        for (uint256 idx = 1; idx < len + 1; ++idx) {
            vm.prank(admin);
            operatorsRegistry.addOperator(string(abi.encodePacked(idx)), address(123));
            stoppedValidatorCounts[idx] = (totalCount / len) + (idx - 1 < totalCount % len ? 1 : 0);
            operators[idx - 1] = idx - 1;
            // Set funded high enough so stopped counts don't exceed funded
            OperatorsRegistryInitializableV1(address(operatorsRegistry)).sudoSetFunded(idx - 1, totalCount);
        }
        vm.prank(river);
        for (uint256 idx = 1; idx < len + 1; ++idx) {
            vm.expectEmit(true, true, true, true);
            emit SetOperatorStoppedValidatorCount(idx - 1, (totalCount / len) + (idx - 1 < totalCount % len ? 1 : 0));
        }
        vm.expectEmit(true, true, true, true);
        emit UpdatedStoppedValidators(stoppedValidatorCounts);
        operatorsRegistry.reportStoppedValidatorCounts(stoppedValidatorCounts, totalCount);

        assertEq(operatorsRegistry.getTotalStoppedValidatorCount(), totalCount);
        uint32[] memory rawStoppedValidators = operatorsRegistry.getStoppedValidatorCountPerOperator();

        assertEq(rawStoppedValidators.length, stoppedValidatorCounts.length - 1);

        for (uint256 idx = 1; idx < len + 1; ++idx) {
            assertEq(stoppedValidatorCounts[idx], operatorsRegistry.getOperatorStoppedValidatorCount(idx - 1));
            assertEq(stoppedValidatorCounts[idx], rawStoppedValidators[idx - 1]);
        }
    }

    function testReportStoppedValidatorCountsEmptyArray() public {
        uint32[] memory stoppedValidators = new uint32[](0);
        vm.prank(river);
        vm.expectRevert(abi.encodeWithSignature("InvalidEmptyStoppedValidatorCountsArray()"));
        operatorsRegistry.reportStoppedValidatorCounts(stoppedValidators, 0);
    }

    function testReportStoppedValidatorCountsMoreElementsThanOperators() public {
        uint32[] memory stoppedValidators = new uint32[](2);
        vm.prank(river);
        vm.expectRevert(abi.encodeWithSignature("StoppedValidatorCountsTooHigh()"));
        operatorsRegistry.reportStoppedValidatorCounts(stoppedValidators, 0);
    }

    function testReportStoppedValidatorCountsInvalidSum(uint8 totalCount, uint8 len) public {
        // Cap len and totalCount to avoid MemoryOOG when adding many validators per operator
        // Original: len up to 127, totalCount up to 255
        // Each validator = 144 bytes, limit to ~30 validators per operator max
        len = uint8(bound(len, 1, 30));
        vm.assume(len > 0 && len < type(uint8).max);
        totalCount = uint8(bound(totalCount, len, 100));

        uint32[] memory stoppedValidators = new uint32[](len + 1);
        uint32[] memory limits = new uint32[](len);
        uint256[] memory operators = new uint256[](len);
        stoppedValidators[0] = totalCount;

        for (uint256 idx = 1; idx < len + 1; ++idx) {
            vm.prank(admin);
            operatorsRegistry.addOperator(string(abi.encodePacked(idx)), address(123));
            stoppedValidators[idx] = (totalCount / len) + (idx - 1 < totalCount % len ? 1 : 0);
            operators[idx - 1] = idx - 1;
            // Set funded high enough so stopped counts don't exceed funded
            OperatorsRegistryInitializableV1(address(operatorsRegistry)).sudoSetFunded(idx - 1, totalCount);
        }

        stoppedValidators[0] -= 1;

        vm.prank(river);
        vm.expectRevert(abi.encodeWithSignature("InvalidStoppedValidatorCountsSum()"));
        operatorsRegistry.reportStoppedValidatorCounts(stoppedValidators, totalCount);
    }
}

/// @title Allocation Correctness Tests
/// @notice Tests that verify the protocol returns the correct keys for the correct operators
/// @notice when given explicit allocation instructions
contract OperatorsRegistryV1AllocationCorrectnessTests is OperatorAllocationTestBase {
    OperatorsRegistryV1 internal operatorsRegistry;
    address internal admin;
    address internal river;

    event FundedValidatorKeys(uint256 indexed index, bytes[] publicKeys, bool deferred);

    /// @dev Per-operator raw key material, stored so we can verify returned keys match
    bytes[] internal rawKeysByOperator;

    bytes32 salt = bytes32(0);

    function genBytes(uint256 len) internal returns (bytes memory) {
        bytes memory res = "";
        while (res.length < len) {
            salt = keccak256(abi.encodePacked(salt));
            if (len - res.length >= 32) {
                res = bytes.concat(res, abi.encode(salt));
            } else {
                res = bytes.concat(res, LibBytes.slice(abi.encode(salt), 0, len - res.length));
            }
        }
        return res;
    }

    /// @dev Extract the public key at a given validator index from the raw key material for an operator
    function _extractPublicKey(uint256 operatorIdx, uint256 validatorIdx) internal view returns (bytes memory) {
        uint256 entrySize = 48 + 96; // PUBLIC_KEY_LENGTH + SIGNATURE_LENGTH
        return LibBytes.slice(rawKeysByOperator[operatorIdx], validatorIdx * entrySize, 48);
    }

    /// @dev Setup with a configurable number of operators, each with `keysPerOp` keys and limits
    function _setupOperators(uint256 count, uint32 keysPerOp) internal {
        admin = makeAddr("admin");
        river = makeAddr("river");

        operatorsRegistry = new OperatorsRegistryInitializableV1();
        LibImplementationUnbricker.unbrick(vm, address(operatorsRegistry));
        operatorsRegistry.initOperatorsRegistryV1(admin, river);

        uint32[] memory limits = new uint32[](count);

        vm.startPrank(admin);
        for (uint256 i = 0; i < count; ++i) {
            address opAddr = makeAddr(string(abi.encodePacked("op", vm.toString(i))));
            operatorsRegistry.addOperator(string(abi.encodePacked("Operator ", vm.toString(i))), opAddr);
        }
        vm.stopPrank();
    }
}

/// @title Exit Allocation Correctness Tests
/// @notice Tests that verify the exit allocation logic correctly tracks per-operator
///         requestedExits across sequential calls, partial fulfillment, stopped validator
///         interactions, and combined deposit+exit flows.
contract OperatorsRegistryV1ExitCorrectnessTests is OperatorAllocationTestBase {
    OperatorsRegistryV1 internal operatorsRegistry;
    address internal admin;
    address internal river;
    address internal keeper;

    event RequestedValidatorExits(uint256 indexed index, uint256 count);
    event SetTotalValidatorExitsRequested(uint256 previousTotalRequestedExits, uint256 newTotalRequestedExits);
    event SetCurrentValidatorExitsDemand(uint256 previousValidatorExitsDemand, uint256 nextValidatorExitsDemand);

    bytes32 salt = bytes32(0);

    function genBytes(uint256 len) internal returns (bytes memory) {
        bytes memory res = "";
        while (res.length < len) {
            salt = keccak256(abi.encodePacked(salt));
            if (len - res.length >= 32) {
                res = bytes.concat(res, abi.encode(salt));
            } else {
                res = bytes.concat(res, LibBytes.slice(abi.encode(salt), 0, len - res.length));
            }
        }
        return res;
    }

    function setUp() public {
        admin = makeAddr("admin");
        river = address(new RiverMock(0));
        keeper = makeAddr("keeper");
        RiverMock(river).setKeeper(keeper);

        operatorsRegistry = new OperatorsRegistryInitializableV1();
        LibImplementationUnbricker.unbrick(vm, address(operatorsRegistry));
        operatorsRegistry.initOperatorsRegistryV1(admin, river);

        vm.startPrank(admin);
        operatorsRegistry.addOperator("operatorOne", makeAddr("op1"));
        operatorsRegistry.addOperator("operatorTwo", makeAddr("op2"));
        operatorsRegistry.addOperator("operatorThree", makeAddr("op3"));
        operatorsRegistry.addOperator("operatorFour", makeAddr("op4"));
        operatorsRegistry.addOperator("operatorFive", makeAddr("op5"));
        vm.stopPrank();
    }

    /// @dev Fund all 5 operators with 50 validators each
    function _fundAllOperators() internal {
        for (uint256 i = 0; i < 5; ++i) {
            OperatorsRegistryInitializableV1(address(operatorsRegistry)).sudoSetFunded(i, 50);
        }
        RiverMock(river).sudoSetDepositedValidatorsCount(250);
    }

    // ──────────────────────────────────────────────────────────────────────
    // TEST 1: Sequential exit allocations accumulate correctly
    // ──────────────────────────────────────────────────────────────────────

    /// @notice Two rounds of exits to overlapping operators. Verifies requestedExits
    ///         accumulates correctly and demand decrements across both calls.
    function testSequentialExitAllocationsAccumulate() external {
        _fundAllOperators();

        // Set demand to 100
        vm.prank(river);
        operatorsRegistry.demandValidatorExits(100, 250);
        assertEq(operatorsRegistry.getCurrentValidatorExitsDemand(), 100);

        // Round 1: exit 10 from each of ops 0,1,2
        uint256[] memory ops1 = new uint256[](3);
        ops1[0] = 0;
        ops1[1] = 1;
        ops1[2] = 2;
        uint32[] memory counts1 = new uint32[](3);
        counts1[0] = 10;
        counts1[1] = 10;
        counts1[2] = 10;

        vm.prank(keeper);
        operatorsRegistry.requestValidatorExits(_createExitAllocation(ops1, counts1));

        assertEq(operatorsRegistry.getOperator(0).requestedExits, 10, "Op0 should have 10 exits after round 1");
        assertEq(operatorsRegistry.getOperator(1).requestedExits, 10, "Op1 should have 10 exits after round 1");
        assertEq(operatorsRegistry.getOperator(2).requestedExits, 10, "Op2 should have 10 exits after round 1");
        assertEq(operatorsRegistry.getOperator(3).requestedExits, 0, "Op3 untouched after round 1");
        assertEq(operatorsRegistry.getOperator(4).requestedExits, 0, "Op4 untouched after round 1");
        assertEq(operatorsRegistry.getCurrentValidatorExitsDemand(), 70, "Demand should be 70 after round 1");
        assertEq(operatorsRegistry.getTotalValidatorExitsRequested(), 30, "Total exits should be 30 after round 1");

        // Round 2: exit 15 more from ops 0,1 and 5 from op3 (new operator)
        uint256[] memory ops2 = new uint256[](3);
        ops2[0] = 0;
        ops2[1] = 1;
        ops2[2] = 3;
        uint32[] memory counts2 = new uint32[](3);
        counts2[0] = 15;
        counts2[1] = 15;
        counts2[2] = 5;

        vm.prank(keeper);
        operatorsRegistry.requestValidatorExits(_createExitAllocation(ops2, counts2));

        assertEq(operatorsRegistry.getOperator(0).requestedExits, 25, "Op0 should have 10+15=25 exits");
        assertEq(operatorsRegistry.getOperator(1).requestedExits, 25, "Op1 should have 10+15=25 exits");
        assertEq(operatorsRegistry.getOperator(2).requestedExits, 10, "Op2 unchanged from round 1");
        assertEq(operatorsRegistry.getOperator(3).requestedExits, 5, "Op3 should have 5 exits from round 2");
        assertEq(operatorsRegistry.getOperator(4).requestedExits, 0, "Op4 still untouched");
        assertEq(operatorsRegistry.getCurrentValidatorExitsDemand(), 35, "Demand should be 100-30-35=35");
        assertEq(operatorsRegistry.getTotalValidatorExitsRequested(), 65, "Total exits should be 30+35=65");
    }

    // ──────────────────────────────────────────────────────────────────────
    // TEST 2: Non-contiguous operator exits
    // ──────────────────────────────────────────────────────────────────────

    /// @notice Exit from operators 0 and 4 only, skipping active operators 1,2,3.
    ///         Verifies skipped operators remain at requestedExits=0.
    function testNonContiguousExitAllocations() external {
        _fundAllOperators();

        vm.prank(river);
        operatorsRegistry.demandValidatorExits(30, 250);

        uint256[] memory ops = new uint256[](2);
        ops[0] = 0;
        ops[1] = 4;
        uint32[] memory counts = new uint32[](2);
        counts[0] = 20;
        counts[1] = 10;

        vm.expectEmit(true, true, true, true);
        emit RequestedValidatorExits(0, 20);
        vm.expectEmit(true, true, true, true);
        emit RequestedValidatorExits(4, 10);

        vm.prank(keeper);
        operatorsRegistry.requestValidatorExits(_createExitAllocation(ops, counts));

        assertEq(operatorsRegistry.getOperator(0).requestedExits, 20, "Op0 should have 20 exits");
        assertEq(operatorsRegistry.getOperator(1).requestedExits, 0, "Op1 should remain at 0");
        assertEq(operatorsRegistry.getOperator(2).requestedExits, 0, "Op2 should remain at 0");
        assertEq(operatorsRegistry.getOperator(3).requestedExits, 0, "Op3 should remain at 0");
        assertEq(operatorsRegistry.getOperator(4).requestedExits, 10, "Op4 should have 10 exits");
        assertEq(operatorsRegistry.getCurrentValidatorExitsDemand(), 0, "Demand fully satisfied");
        assertEq(operatorsRegistry.getTotalValidatorExitsRequested(), 30);
    }

    // ──────────────────────────────────────────────────────────────────────
    // TEST 3: Partial demand fulfillment across multiple calls
    // ──────────────────────────────────────────────────────────────────────

    /// @notice Demand is 100. Keeper fulfills 40 in first call, then 60 in second call.
    ///         Verifies demand decrements correctly and total accumulates.
    function testPartialDemandFulfillmentAcrossMultipleCalls() external {
        _fundAllOperators();

        vm.prank(river);
        operatorsRegistry.demandValidatorExits(100, 250);
        assertEq(operatorsRegistry.getCurrentValidatorExitsDemand(), 100);
        assertEq(operatorsRegistry.getTotalValidatorExitsRequested(), 0);

        // Call 1: fulfill 40 (8 from each operator)
        uint256[] memory ops = new uint256[](5);
        uint32[] memory counts = new uint32[](5);
        for (uint256 i = 0; i < 5; ++i) {
            ops[i] = i;
            counts[i] = 8;
        }

        vm.prank(keeper);
        operatorsRegistry.requestValidatorExits(_createExitAllocation(ops, counts));

        assertEq(operatorsRegistry.getCurrentValidatorExitsDemand(), 60, "Demand should be 60 after first call");
        assertEq(operatorsRegistry.getTotalValidatorExitsRequested(), 40, "Total exits should be 40");

        for (uint256 i = 0; i < 5; ++i) {
            assertEq(
                operatorsRegistry.getOperator(i).requestedExits,
                8,
                string(abi.encodePacked("Op ", vm.toString(i), " should have 8 exits"))
            );
        }

        // Call 2: fulfill remaining 60 (12 from each)
        for (uint256 i = 0; i < 5; ++i) {
            counts[i] = 12;
        }

        vm.prank(keeper);
        operatorsRegistry.requestValidatorExits(_createExitAllocation(ops, counts));

        assertEq(operatorsRegistry.getCurrentValidatorExitsDemand(), 0, "Demand should be fully satisfied");
        assertEq(operatorsRegistry.getTotalValidatorExitsRequested(), 100, "Total exits should be 100");

        for (uint256 i = 0; i < 5; ++i) {
            assertEq(
                operatorsRegistry.getOperator(i).requestedExits,
                20,
                string(abi.encodePacked("Op ", vm.toString(i), " should have 8+12=20 exits"))
            );
        }
    }

    // ──────────────────────────────────────────────────────────────────────
    // TEST 4: Stopped validators + exits multi-step interaction
    // ──────────────────────────────────────────────────────────────────────

    /// @notice Multi-step: demand exits -> stop some validators (reducing demand) -> exit some
    ///         -> stop more -> exit more. Verifies demand and requestedExits track correctly
    ///         through the interleaved sequence.
    function testStoppedValidatorsAndExitsMultiStep() external {
        _fundAllOperators();

        // Step 1: Create demand for 200 exits
        vm.prank(river);
        operatorsRegistry.demandValidatorExits(200, 250);
        assertEq(operatorsRegistry.getCurrentValidatorExitsDemand(), 200);
        assertEq(operatorsRegistry.getTotalValidatorExitsRequested(), 0);

        // Step 2: Stop 50 validators across operators (reduces demand by 50)
        // stoppedValidatorCounts[0] = totalStopped, then per-operator
        uint32[] memory stoppedCounts1 = new uint32[](6);
        stoppedCounts1[0] = 50; // total
        stoppedCounts1[1] = 10; // op0
        stoppedCounts1[2] = 10; // op1
        stoppedCounts1[3] = 10; // op2
        stoppedCounts1[4] = 10; // op3
        stoppedCounts1[5] = 10; // op4
        OperatorsRegistryInitializableV1(address(operatorsRegistry)).sudoStoppedValidatorCounts(stoppedCounts1, 250);

        assertEq(operatorsRegistry.getCurrentValidatorExitsDemand(), 150, "Demand reduced by 50 stopped");
        assertEq(operatorsRegistry.getTotalValidatorExitsRequested(), 50, "Stopped validators count as exits");

        // Step 3: Keeper exits 60 (12 from each operator)
        uint256[] memory ops = new uint256[](5);
        uint32[] memory exitCounts1 = new uint32[](5);
        for (uint256 i = 0; i < 5; ++i) {
            ops[i] = i;
            exitCounts1[i] = 12;
        }

        vm.prank(keeper);
        operatorsRegistry.requestValidatorExits(_createExitAllocation(ops, exitCounts1));

        assertEq(operatorsRegistry.getCurrentValidatorExitsDemand(), 90, "Demand should be 150-60=90");
        assertEq(operatorsRegistry.getTotalValidatorExitsRequested(), 110, "Total exits should be 50+60=110");

        for (uint256 i = 0; i < 5; ++i) {
            // requestedExits = 10 (from stopped) + 12 (from explicit exit) = 22
            assertEq(
                operatorsRegistry.getOperator(i).requestedExits,
                22,
                string(abi.encodePacked("Op ", vm.toString(i), " should have 22 requestedExits"))
            );
        }

        // Step 4: Stop 30 more validators (total stopped now 80)
        // Each operator goes from 10 stopped to 16 stopped.
        // But requestedExits is already 22 per operator (10 from stopped + 12 from keeper).
        // Since 16 < 22, _setStoppedValidatorCounts does NOT increase requestedExits.
        // The unsolicited exit count is 0 (no operator has stoppedCount > requestedExits).
        // However, the delta from 50 total stopped to 80 total stopped still reduces demand
        // only to the extent that new stopped > old requestedExits per operator.
        // Since 16 < 22 for all operators, unsollicitedExitsSum = 0, so demand stays at 90.
        uint32[] memory stoppedCounts2 = new uint32[](6);
        stoppedCounts2[0] = 80; // total now 80 (was 50)
        stoppedCounts2[1] = 16; // op0
        stoppedCounts2[2] = 16; // op1
        stoppedCounts2[3] = 16; // op2
        stoppedCounts2[4] = 16; // op3
        stoppedCounts2[5] = 16; // op4
        OperatorsRegistryInitializableV1(address(operatorsRegistry)).sudoStoppedValidatorCounts(stoppedCounts2, 250);

        // Demand unchanged because stoppedCount(16) < requestedExits(22) for all operators
        assertEq(operatorsRegistry.getCurrentValidatorExitsDemand(), 90, "Demand unchanged: stopped < requestedExits");
        assertEq(operatorsRegistry.getTotalValidatorExitsRequested(), 110, "Total exits unchanged");

        // requestedExits still 22 per operator (stopped didn't exceed it)
        for (uint256 i = 0; i < 5; ++i) {
            assertEq(
                operatorsRegistry.getOperator(i).requestedExits,
                22,
                string(abi.encodePacked("Op ", vm.toString(i), " requestedExits unchanged at 22"))
            );
        }

        // Step 5: Keeper exits 12 more from each (total 60)
        uint32[] memory exitCounts2 = new uint32[](5);
        for (uint256 i = 0; i < 5; ++i) {
            exitCounts2[i] = 12;
        }

        vm.prank(keeper);
        operatorsRegistry.requestValidatorExits(_createExitAllocation(ops, exitCounts2));

        assertEq(operatorsRegistry.getCurrentValidatorExitsDemand(), 30, "Demand should be 90-60=30");
        assertEq(operatorsRegistry.getTotalValidatorExitsRequested(), 170, "Total exits should be 110+60=170");

        for (uint256 i = 0; i < 5; ++i) {
            // requestedExits = 22 + 12 = 34
            assertEq(
                operatorsRegistry.getOperator(i).requestedExits,
                34,
                string(abi.encodePacked("Op ", vm.toString(i), " should have 22+12=34 requestedExits"))
            );
        }
    }

    // ──────────────────────────────────────────────────────────────────────
    // TEST 5: Deposit then exit end-to-end
    // ──────────────────────────────────────────────────────────────────────

    /// @notice Combined flow: deposit validators via incrementFundedValidators, then exit some,
    ///         then simulate validators stopping, then deposit more.
    ///         Verifies funded and requestedExits are both correct throughout.
    ///
    ///         Key invariant: incrementFundedValidators requires stoppedCount >= requestedExits
    ///         for an operator to be eligible for new deposits. This means you can't
    ///         deposit to an operator with pending (unfulfilled) exit requests until
    ///         those validators have actually stopped.
    function testDepositThenExitEndToEnd() external {
        // Phase 1: Deposit 10 to op0, 15 to op1, 5 to op2 = 30 total
        bytes[] memory keys10 = new bytes[](10);
        for (uint256 i = 0; i < 10; ++i) {
            keys10[i] = new bytes(48);
        }
        operatorsRegistry.incrementFundedValidators(0, keys10);

        bytes[] memory keys15 = new bytes[](15);
        for (uint256 i = 0; i < 15; ++i) {
            keys15[i] = new bytes(48);
        }
        operatorsRegistry.incrementFundedValidators(1, keys15);

        bytes[] memory keys5 = new bytes[](5);
        for (uint256 i = 0; i < 5; ++i) {
            keys5[i] = new bytes(48);
        }
        operatorsRegistry.incrementFundedValidators(2, keys5);

        assertEq(operatorsRegistry.getOperator(0).funded, 10, "Op0 should have 10 funded");
        assertEq(operatorsRegistry.getOperator(1).funded, 15, "Op1 should have 15 funded");
        assertEq(operatorsRegistry.getOperator(2).funded, 5, "Op2 should have 5 funded");

        // Phase 2: Request exits -- 5 from op0, 7 from op1, 3 from op2 = 15 total
        RiverMock(river).sudoSetDepositedValidatorsCount(30);
        vm.prank(river);
        operatorsRegistry.demandValidatorExits(15, 30);
        assertEq(operatorsRegistry.getCurrentValidatorExitsDemand(), 15);

        uint256[] memory ops = new uint256[](3);
        ops[0] = 0;
        ops[1] = 1;
        ops[2] = 2;
        uint32[] memory exitCounts = new uint32[](3);
        exitCounts[0] = 5;
        exitCounts[1] = 7;
        exitCounts[2] = 3;

        vm.prank(keeper);
        operatorsRegistry.requestValidatorExits(_createExitAllocation(ops, exitCounts));

        assertEq(operatorsRegistry.getOperator(0).funded, 10, "Op0 funded unchanged");
        assertEq(operatorsRegistry.getOperator(1).funded, 15, "Op1 funded unchanged");
        assertEq(operatorsRegistry.getOperator(2).funded, 5, "Op2 funded unchanged");
        assertEq(operatorsRegistry.getOperator(0).requestedExits, 5, "Op0 should have 5 exits");
        assertEq(operatorsRegistry.getOperator(1).requestedExits, 7, "Op1 should have 7 exits");
        assertEq(operatorsRegistry.getOperator(2).requestedExits, 3, "Op2 should have 3 exits");
        assertEq(operatorsRegistry.getCurrentValidatorExitsDemand(), 0, "Demand fully satisfied");
        assertEq(operatorsRegistry.getTotalValidatorExitsRequested(), 15);

        // Phase 3: Before depositing more, the exited validators must actually stop.
        // incrementFundedValidators requires stoppedCount >= requestedExits for eligibility.
        // Simulate the stopped validators matching the exit requests.
        uint32[] memory stoppedCounts = new uint32[](4);
        stoppedCounts[0] = 15; // total stopped
        stoppedCounts[1] = 5; // op0 stopped
        stoppedCounts[2] = 7; // op1 stopped
        stoppedCounts[3] = 3; // op2 stopped
        OperatorsRegistryInitializableV1(address(operatorsRegistry)).sudoStoppedValidatorCounts(stoppedCounts, 30);

        // Phase 4: Now deposit more to op0 (funded=10, stopped >= requestedExits so allowed)
        bytes[] memory keys5more = new bytes[](5);
        for (uint256 i = 0; i < 5; ++i) {
            keys5more[i] = new bytes(48);
        }
        operatorsRegistry.incrementFundedValidators(0, keys5more);

        assertEq(operatorsRegistry.getOperator(0).funded, 15, "Op0 should now have 15 funded");
        assertEq(operatorsRegistry.getOperator(0).requestedExits, 5, "Op0 exits unchanged by new deposit");

        // Verify the other operators are unchanged
        assertEq(operatorsRegistry.getOperator(1).funded, 15, "Op1 funded unchanged");
        assertEq(operatorsRegistry.getOperator(2).funded, 5, "Op2 funded unchanged");
    }

    // ──────────────────────────────────────────────────────────────────────
    // TEST 6: ExitsRequestedExceedDemand by one
    // ──────────────────────────────────────────────────────────────────────

    /// @notice Demand is 10. Request exactly 11 exits (1 over). Verify the exact error parameters.
    function testExitsRequestedExceedDemandByOne() external {
        _fundAllOperators();

        vm.prank(river);
        operatorsRegistry.demandValidatorExits(10, 250);
        assertEq(operatorsRegistry.getCurrentValidatorExitsDemand(), 10);

        // Request 11 total (all from op0) -- 1 over demand
        uint256[] memory ops = new uint256[](1);
        ops[0] = 0;
        uint32[] memory counts = new uint32[](1);
        counts[0] = 11;

        vm.expectRevert(abi.encodeWithSignature("ExitsRequestedExceedDemand(uint256,uint256)", 11, 10));
        vm.prank(keeper);
        operatorsRegistry.requestValidatorExits(_createExitAllocation(ops, counts));
    }

    // ──────────────────────────────────────────────────────────────────────
    // TEST 7: ExitsRequestedExceedDemand after partial fulfillment
    // ──────────────────────────────────────────────────────────────────────

    /// @notice Demand is 20. First call fulfills 15. Second call tries to exit 10 (5 over remaining 5).
    function testExitsRequestedExceedDemandAfterPartialFulfillment() external {
        _fundAllOperators();

        vm.prank(river);
        operatorsRegistry.demandValidatorExits(20, 250);
        assertEq(operatorsRegistry.getCurrentValidatorExitsDemand(), 20);

        // First call: fulfill 15 (5 from each of ops 0,1,2)
        uint256[] memory ops1 = new uint256[](3);
        ops1[0] = 0;
        ops1[1] = 1;
        ops1[2] = 2;
        uint32[] memory counts1 = new uint32[](3);
        counts1[0] = 5;
        counts1[1] = 5;
        counts1[2] = 5;

        vm.prank(keeper);
        operatorsRegistry.requestValidatorExits(_createExitAllocation(ops1, counts1));
        assertEq(operatorsRegistry.getCurrentValidatorExitsDemand(), 5, "Demand should be 5 after first call");

        // Second call: try to exit 10 from op3 (5 over remaining demand of 5)
        uint256[] memory ops2 = new uint256[](1);
        ops2[0] = 3;
        uint32[] memory counts2 = new uint32[](1);
        counts2[0] = 10;

        vm.expectRevert(abi.encodeWithSignature("ExitsRequestedExceedDemand(uint256,uint256)", 10, 5));
        vm.prank(keeper);
        operatorsRegistry.requestValidatorExits(_createExitAllocation(ops2, counts2));
    }

    // ──────────────────────────────────────────────────────────────────────
    // TEST 8: Exits exactly match demand succeeds
    // ──────────────────────────────────────────────────────────────────────

    /// @notice Demand is 10, request exactly 10 across multiple operators. Verify it succeeds and demand goes to 0.
    function testExitsRequestedExactlyMatchesDemand() external {
        _fundAllOperators();

        vm.prank(river);
        operatorsRegistry.demandValidatorExits(10, 250);
        assertEq(operatorsRegistry.getCurrentValidatorExitsDemand(), 10);

        // Request exactly 10 total: 3 from op0, 3 from op1, 4 from op2
        uint256[] memory ops = new uint256[](3);
        ops[0] = 0;
        ops[1] = 1;
        ops[2] = 2;
        uint32[] memory counts = new uint32[](3);
        counts[0] = 3;
        counts[1] = 3;
        counts[2] = 4;

        vm.prank(keeper);
        operatorsRegistry.requestValidatorExits(_createExitAllocation(ops, counts));

        assertEq(operatorsRegistry.getCurrentValidatorExitsDemand(), 0, "Demand should be 0");
        assertEq(operatorsRegistry.getTotalValidatorExitsRequested(), 10, "Total exits should be 10");
        assertEq(operatorsRegistry.getOperator(0).requestedExits, 3, "Op0 should have 3 exits");
        assertEq(operatorsRegistry.getOperator(1).requestedExits, 3, "Op1 should have 3 exits");
        assertEq(operatorsRegistry.getOperator(2).requestedExits, 4, "Op2 should have 4 exits");
    }

    // ──────────────────────────────────────────────────────────────────────
    // TEST 9: Stopped validators exceeding requestedExits bumps requestedExits
    // ──────────────────────────────────────────────────────────────────────

    event UpdatedRequestedValidatorExitsUponStopped(
        uint256 indexed index, uint32 oldRequestedExits, uint32 newRequestedExits
    );
    event UpdatedStoppedValidators(uint32[] stoppedValidatorCounts);

    /// @notice When stopped validator count exceeds an operator's requestedExits,
    ///         requestedExits is bumped to match the stopped count, the unsolicited
    ///         delta is added to TotalValidatorExitsRequested, and
    ///         CurrentValidatorExitsDemand is reduced by the unsolicited amount.
    ///         This test exercises the FIRST loop in _setStoppedValidatorCounts
    ///         (existing operators path) by making two successive stopped-count reports.
    function testStoppedCountExceedingRequestedExitsBumpsRequestedExits() external {
        _fundAllOperators();

        // Create demand of 50
        vm.prank(river);
        operatorsRegistry.demandValidatorExits(50, 250);
        assertEq(operatorsRegistry.getCurrentValidatorExitsDemand(), 50);
        assertEq(operatorsRegistry.getTotalValidatorExitsRequested(), 0);

        // Keeper requests 5 exits from op0 and op1 only (total 10)
        uint256[] memory ops = new uint256[](2);
        ops[0] = 0;
        ops[1] = 1;
        uint32[] memory exitCounts = new uint32[](2);
        exitCounts[0] = 5;
        exitCounts[1] = 5;

        vm.prank(keeper);
        operatorsRegistry.requestValidatorExits(_createExitAllocation(ops, exitCounts));

        assertEq(operatorsRegistry.getOperator(0).requestedExits, 5, "Op0 should have 5 requestedExits");
        assertEq(operatorsRegistry.getOperator(1).requestedExits, 5, "Op1 should have 5 requestedExits");
        assertEq(operatorsRegistry.getOperator(2).requestedExits, 0, "Op2 should have 0 requestedExits");
        assertEq(operatorsRegistry.getOperator(3).requestedExits, 0, "Op3 should have 0 requestedExits");
        assertEq(operatorsRegistry.getOperator(4).requestedExits, 0, "Op4 should have 0 requestedExits");
        assertEq(operatorsRegistry.getCurrentValidatorExitsDemand(), 40, "Demand should be 50-10=40");
        assertEq(operatorsRegistry.getTotalValidatorExitsRequested(), 10, "Total exits should be 10");

        // First stopped-count report: small counts that do NOT exceed requestedExits
        // for op0 and op1. op2 and op3 get bumped (unsolicited = 2+1 = 3).
        // This establishes currentStoppedValidatorCounts so the next report iterates
        // through the first loop (existing operators path).
        uint32[] memory stoppedCounts1 = new uint32[](6);
        stoppedCounts1[0] = 6; // total: 2 + 1 + 2 + 1 + 0
        stoppedCounts1[1] = 2; // op0 (2 <= requestedExits 5, no bump)
        stoppedCounts1[2] = 1; // op1 (1 <= requestedExits 5, no bump)
        stoppedCounts1[3] = 2; // op2 (2 > requestedExits 0, bumps to 2)
        stoppedCounts1[4] = 1; // op3 (1 > requestedExits 0, bumps to 1)
        stoppedCounts1[5] = 0; // op4
        OperatorsRegistryInitializableV1(address(operatorsRegistry)).sudoStoppedValidatorCounts(stoppedCounts1, 250);

        // After first report: op2 bumped 0->2, op3 bumped 0->1 (unsolicited = 3)
        assertEq(operatorsRegistry.getOperator(0).requestedExits, 5, "Op0 unchanged after first report");
        assertEq(operatorsRegistry.getOperator(1).requestedExits, 5, "Op1 unchanged after first report");
        assertEq(operatorsRegistry.getOperator(2).requestedExits, 2, "Op2 bumped to 2 after first report");
        assertEq(operatorsRegistry.getOperator(3).requestedExits, 1, "Op3 bumped to 1 after first report");
        assertEq(operatorsRegistry.getTotalValidatorExitsRequested(), 13, "Total exits = 10 + 3 unsolicited");
        assertEq(operatorsRegistry.getCurrentValidatorExitsDemand(), 37, "Demand = 40 - 3 unsolicited");

        // Second stopped-count report: higher counts that exceed requestedExits.
        // All 5 operators are in the first loop (existing operators path) since
        // stoppedCounts1 had 6 entries == stoppedCounts2's 6 entries.
        //   op0: 8 stopped (exceeds requestedExits=5, unsolicited delta = 3)
        //   op1: 3 stopped (does NOT exceed requestedExits=5, no bump)
        //   op2: 7 stopped (exceeds requestedExits=2, unsolicited delta = 5)
        //   op3: 1 stopped (unchanged, does NOT exceed requestedExits=1)
        //   op4: 0 stopped (no change)
        // Total unsolicited = 3 + 5 = 8
        uint32[] memory stoppedCounts2 = new uint32[](6);
        stoppedCounts2[0] = 19; // total: 8 + 3 + 7 + 1 + 0
        stoppedCounts2[1] = 8; // op0
        stoppedCounts2[2] = 3; // op1
        stoppedCounts2[3] = 7; // op2
        stoppedCounts2[4] = 1; // op3
        stoppedCounts2[5] = 0; // op4

        vm.expectEmit(true, true, true, true);
        emit UpdatedRequestedValidatorExitsUponStopped(0, 5, 8);
        vm.expectEmit(true, true, true, true);
        emit UpdatedRequestedValidatorExitsUponStopped(2, 2, 7);

        OperatorsRegistryInitializableV1(address(operatorsRegistry)).sudoStoppedValidatorCounts(stoppedCounts2, 250);

        // requestedExits bumped for op0 (5->8) and op2 (2->7); others unchanged
        assertEq(operatorsRegistry.getOperator(0).requestedExits, 8, "Op0 requestedExits bumped to stoppedCount");
        assertEq(
            operatorsRegistry.getOperator(1).requestedExits, 5, "Op1 requestedExits unchanged (stopped < requested)"
        );
        assertEq(operatorsRegistry.getOperator(2).requestedExits, 7, "Op2 requestedExits bumped to stoppedCount");
        assertEq(operatorsRegistry.getOperator(3).requestedExits, 1, "Op3 requestedExits unchanged");
        assertEq(operatorsRegistry.getOperator(4).requestedExits, 0, "Op4 requestedExits unchanged");

        // TotalValidatorExitsRequested = 13 + 8 (unsolicited) = 21
        assertEq(operatorsRegistry.getTotalValidatorExitsRequested(), 21, "Total exits should include unsolicited");

        // CurrentValidatorExitsDemand = 37 - min(8, 37) = 29
        assertEq(operatorsRegistry.getCurrentValidatorExitsDemand(), 29, "Demand reduced by unsolicited exits");
    }

    /// @notice When stopped count exceeds requestedExits and the unsolicited amount
    ///         is larger than the remaining demand, demand is clamped to zero.
    function testStoppedCountExceedingRequestedExitsClampsDemandToZero() external {
        _fundAllOperators();

        // Create small demand of 5
        vm.prank(river);
        operatorsRegistry.demandValidatorExits(5, 250);
        assertEq(operatorsRegistry.getCurrentValidatorExitsDemand(), 5);

        // No keeper exit requests: all operators have requestedExits = 0

        // Report 20 stopped validators on op0 alone — unsolicited delta = 20, exceeds demand of 5
        uint32[] memory stoppedCounts = new uint32[](6);
        stoppedCounts[0] = 20;
        stoppedCounts[1] = 20; // op0
        stoppedCounts[2] = 0;
        stoppedCounts[3] = 0;
        stoppedCounts[4] = 0;
        stoppedCounts[5] = 0;

        vm.expectEmit(true, true, true, true);
        emit UpdatedRequestedValidatorExitsUponStopped(0, 0, 20);

        OperatorsRegistryInitializableV1(address(operatorsRegistry)).sudoStoppedValidatorCounts(stoppedCounts, 250);

        assertEq(operatorsRegistry.getOperator(0).requestedExits, 20, "Op0 requestedExits bumped to 20");
        assertEq(operatorsRegistry.getTotalValidatorExitsRequested(), 20, "Total exits = unsolicited 20");
        // Demand clamped: 5 - min(20, 5) = 0
        assertEq(operatorsRegistry.getCurrentValidatorExitsDemand(), 0, "Demand clamped to zero");
    }

    /// @notice When a new operator is added between two stopped-count reports,
    ///         the second report includes the new operator's stopped count which
    ///         triggers the requestedExits bump in the "new operator" loop.
    function testStoppedCountExceedingRequestedExitsForNewOperator() external {
        _fundAllOperators();

        // Initial stopped report for 5 operators (all zeros)
        uint32[] memory stoppedCounts1 = new uint32[](6);
        stoppedCounts1[0] = 0;
        stoppedCounts1[1] = 0;
        stoppedCounts1[2] = 0;
        stoppedCounts1[3] = 0;
        stoppedCounts1[4] = 0;
        stoppedCounts1[5] = 0;
        OperatorsRegistryInitializableV1(address(operatorsRegistry)).sudoStoppedValidatorCounts(stoppedCounts1, 250);

        // Add a 6th operator and fund it via sudoSetFunded
        vm.prank(admin);
        operatorsRegistry.addOperator("operatorSix", makeAddr("op6"));
        OperatorsRegistryInitializableV1(address(operatorsRegistry)).sudoSetFunded(5, 50);
        RiverMock(river).sudoSetDepositedValidatorsCount(300);

        // Create demand
        vm.prank(river);
        operatorsRegistry.demandValidatorExits(10, 300);
        assertEq(operatorsRegistry.getCurrentValidatorExitsDemand(), 10);

        // Report stopped with 7 entries (includes new op5 at index 6 in the array)
        // The new operator (op5) has 0 requestedExits but 5 stopped -> unsolicited = 5
        uint32[] memory stoppedCounts2 = new uint32[](7);
        stoppedCounts2[0] = 5; // total
        stoppedCounts2[1] = 0; // op0
        stoppedCounts2[2] = 0; // op1
        stoppedCounts2[3] = 0; // op2
        stoppedCounts2[4] = 0; // op3
        stoppedCounts2[5] = 0; // op4
        stoppedCounts2[6] = 5; // op5 (new operator -- enters the second loop)

        vm.expectEmit(true, true, true, true);
        emit UpdatedRequestedValidatorExitsUponStopped(5, 0, 5);

        OperatorsRegistryInitializableV1(address(operatorsRegistry)).sudoStoppedValidatorCounts(stoppedCounts2, 300);

        assertEq(operatorsRegistry.getOperator(5).requestedExits, 5, "New op requestedExits bumped to stoppedCount");
        assertEq(operatorsRegistry.getTotalValidatorExitsRequested(), 5, "Total exits = unsolicited 5");
        assertEq(operatorsRegistry.getCurrentValidatorExitsDemand(), 5, "Demand reduced by unsolicited 5");
    }
}

// ══════════════════════════════════════════════════════════════════════════
// _flattenByteArrays and _getPerOperatorValidatorKeysForAllocations tests
// ══════════════════════════════════════════════════════════════════════════

/// @notice Tests that exercise _flattenByteArrays and allocation validation logic
///         via the public view function getNextValidatorsToDepositFromActiveOperators.
contract OperatorsRegistryV1FlattenAndAllocationTests is OperatorAllocationTestBase {
    OperatorsRegistryV1 internal operatorsRegistry;
    address internal admin;
    address internal river;

    /// @dev Per-operator raw key material, stored so we can verify returned keys match
    bytes[] internal rawKeysByOperator;

    bytes32 salt = bytes32(0);

    function genBytes(uint256 len) internal returns (bytes memory) {
        bytes memory res = "";
        while (res.length < len) {
            salt = keccak256(abi.encodePacked(salt));
            if (len - res.length >= 32) {
                res = bytes.concat(res, abi.encode(salt));
            } else {
                res = bytes.concat(res, LibBytes.slice(abi.encode(salt), 0, len - res.length));
            }
        }
        return res;
    }

    /// @dev Setup with a configurable number of operators, each with `keysPerOp` keys and limits
    function _setupOperators(uint256 count, uint32 keysPerOp) internal {
        admin = makeAddr("admin");
        river = makeAddr("river");

        operatorsRegistry = new OperatorsRegistryInitializableV1();
        LibImplementationUnbricker.unbrick(vm, address(operatorsRegistry));
        operatorsRegistry.initOperatorsRegistryV1(admin, river);

        uint256[] memory indexes = new uint256[](count);
        uint32[] memory limits = new uint32[](count);

        vm.startPrank(admin);
        for (uint256 i = 0; i < count; ++i) {
            address opAddr = makeAddr(string(abi.encodePacked("op", vm.toString(i))));
            operatorsRegistry.addOperator(string(abi.encodePacked("Operator ", vm.toString(i))), opAddr);
        }
        vm.stopPrank();
    }

    function testIncrementFundedRevertsEmptyPublicKeys() external {
        _setupOperators(1, 10);

        vm.expectRevert(abi.encodeWithSignature("InvalidEmptyArray()"));
        bytes[] memory keys = new bytes[](0);
        operatorsRegistry.incrementFundedValidators(0, keys);
    }

    function testIncrementFundedRevertsOperatorIgnoredExitRequests() external {
        _setupOperators(1, 10);

        // Give the operator some funded validators then request exits for all of them
        OperatorsRegistryInitializableV1(address(operatorsRegistry)).sudoSetFunded(0, 5);
        OperatorsRegistryInitializableV1(address(operatorsRegistry)).sudoExitRequests(0, 5);
        // stoppedCount remains 0, so operator has not fulfilled any exits

        vm.expectRevert(abi.encodeWithSignature("OperatorIgnoredExitRequests(uint256)", 0));
        bytes[] memory keys = new bytes[](1);
        keys[0] = new bytes(48);
        operatorsRegistry.incrementFundedValidators(0, keys);
    }
}

/// @notice Verifies that no production code path writes to the deprecated OperatorsV2 storage slot.
/// Only migration initializers should reference OperatorsV2; all live operations must use OperatorsV3.
contract OperatorsRegistryV1NoV2LeakTests is OperatorsRegistryV1TestBase {
    /// @dev OperatorsV2 storage slot, copied from Operators.2.sol
    bytes32 internal constant OPERATORS_V2_SLOT = bytes32(uint256(keccak256("river.state.v2.operators")) - 1);

    function setUp() public {
        admin = makeAddr("admin");
        keeper = makeAddr("keeper");
        river = address(new RiverMock(0));
        RiverMock(river).setKeeper(keeper);
        operatorsRegistry = new OperatorsRegistryInitializableV1();
        LibImplementationUnbricker.unbrick(vm, address(operatorsRegistry));
        operatorsRegistry.initOperatorsRegistryV1(admin, river);
    }

    /// @dev Reads the raw array length at the OperatorsV2 storage slot
    function _v2OperatorCount() internal view returns (uint256 count) {
        bytes32 slot = OPERATORS_V2_SLOT;
        bytes32 raw = vm.load(address(operatorsRegistry), slot);
        count = uint256(raw);
    }

    /// @dev Adds `count` operators via the admin
    function _addOperators(uint256 count) internal {
        vm.startPrank(admin);
        for (uint256 i = 0; i < count; ++i) {
            address opAddr = makeAddr(string(abi.encodePacked("op", vm.toString(i))));
            operatorsRegistry.addOperator(string(abi.encodePacked("Operator ", vm.toString(i))), opAddr);
        }
        vm.stopPrank();
    }

    function testAddOperatorDoesNotWriteV2() external {
        assertEq(_v2OperatorCount(), 0, "V2 should be empty before addOperator");

        vm.prank(admin);
        operatorsRegistry.addOperator("TestOp", makeAddr("op1"));

        assertEq(_v2OperatorCount(), 0, "V2 must remain empty after addOperator");
        assertEq(operatorsRegistry.getOperatorCount(), 1, "V3 should have 1 operator");
    }

    function testSetOperatorStatusDoesNotWriteV2() external {
        vm.startPrank(admin);
        operatorsRegistry.addOperator("TestOp", makeAddr("op1"));
        operatorsRegistry.setOperatorStatus(0, false);
        vm.stopPrank();

        assertEq(_v2OperatorCount(), 0, "V2 must remain empty after setOperatorStatus");
    }

    function testIncrementFundedDoesNotWriteV2() external {
        _addOperators(1);

        bytes[] memory keys = new bytes[](1);
        keys[0] = new bytes(48);
        operatorsRegistry.incrementFundedValidators(0, keys);

        assertEq(_v2OperatorCount(), 0, "V2 must remain empty after incrementFundedValidators");
    }

    function testReportStoppedValidatorsDoesNotWriteV2() external {
        _addOperators(2);

        OperatorsRegistryInitializableV1(address(operatorsRegistry)).sudoSetFunded(0, 3);
        OperatorsRegistryInitializableV1(address(operatorsRegistry)).sudoSetFunded(1, 2);
        RiverMock(river).sudoSetDepositedValidatorsCount(5);

        uint32[] memory stoppedCounts = new uint32[](3);
        stoppedCounts[0] = 2; // total
        stoppedCounts[1] = 1; // operator 0
        stoppedCounts[2] = 1; // operator 1

        operatorsRegistry.reportStoppedValidatorCounts(stoppedCounts, 5);

        assertEq(_v2OperatorCount(), 0, "V2 must remain empty after reportStoppedValidatorCounts");
    }

    function testDemandValidatorExitsDoesNotWriteV2() external {
        _addOperators(1);
        OperatorsRegistryInitializableV1(address(operatorsRegistry)).sudoSetFunded(0, 3);
        RiverMock(river).sudoSetDepositedValidatorsCount(3);

        operatorsRegistry.demandValidatorExits(1, 3);

        assertEq(_v2OperatorCount(), 0, "V2 must remain empty after demandValidatorExits");
    }

    function testMultipleOperationsNeverWriteV2() external {
        vm.startPrank(admin);
        operatorsRegistry.addOperator("Op1", makeAddr("op1"));
        operatorsRegistry.addOperator("Op2", makeAddr("op2"));
        operatorsRegistry.setOperatorStatus(0, false);
        operatorsRegistry.setOperatorStatus(0, true);
        vm.stopPrank();

        OperatorsRegistryInitializableV1(address(operatorsRegistry)).sudoSetFunded(0, 2);
        OperatorsRegistryInitializableV1(address(operatorsRegistry)).sudoSetFunded(1, 1);
        RiverMock(river).sudoSetDepositedValidatorsCount(3);

        bytes[] memory keys = new bytes[](1);
        keys[0] = new bytes(48);
        operatorsRegistry.incrementFundedValidators(0, keys);

        operatorsRegistry.demandValidatorExits(1, 4);

        assertEq(_v2OperatorCount(), 0, "V2 must remain empty after all production operations");
        assertEq(operatorsRegistry.getOperatorCount(), 2, "V3 should have 2 operators");
    }
}

