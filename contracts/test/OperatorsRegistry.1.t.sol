//SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.34;

import "forge-std/Test.sol";

import "./OperatorAllocationTestBase.sol";
import "../src/libraries/LibBytes.sol";
import "./utils/UserFactory.sol";
import "./utils/BytesGenerator.sol";
import "./utils/LibImplementationUnbricker.sol";

import "../src/OperatorsRegistry.1.sol";
import "../src/state/operatorsRegistry/CurrentValidatorExitsDemand.sol";
import "../src/state/operatorsRegistry/TotalValidatorExitsRequested.sol";

contract OperatorsRegistryInitializableV1 is OperatorsRegistryV1 {
    /// @dev Override to allow tests to call functions without pranking as river
    modifier onlyRiver() override {
        _;
    }

    function sudoSetFunded(uint256 _index, uint256 _funded) external {
        OperatorsV3.Operator storage operator = OperatorsV3.get(_index);
        operator.funded = _funded;
    }

    function sudoExitRequests(uint256 _operatorIndex, uint256 _requestedExits) external {
        OperatorsV3.get(_operatorIndex).requestedExits = _requestedExits;
    }

    function sudoReportExitedETH(uint256[] calldata exitedETH) external {
        _setExitedETH(exitedETH);
    }

    function sudoSetRawExitedETH(uint256[] memory value) external {
        OperatorsV3.setRawExitedETH(value);
    }

    function sudoSetActiveCLETH(uint256 _index, uint256 _activeCLETH) external {
        OperatorsV3.get(_index).activeCLETH = _activeCLETH;
    }
}

/// @dev Same as OperatorsRegistryInitializableV1 but does NOT override onlyRiver; use for tests that assert Unauthorized
contract OperatorsRegistryStrictRiverV1 is OperatorsRegistryV1 {
    function sudoSetFunded(uint256 _index, uint256 _funded) external {
        OperatorsV3.Operator storage operator = OperatorsV3.get(_index);
        operator.funded = _funded;
    }

    function sudoExitRequests(uint256 _operatorIndex, uint256 _requestedExits) external {
        OperatorsV3.get(_operatorIndex).requestedExits = _requestedExits;
    }
}

/// @dev Extension that exposes internal V1/V2 storage writers and onlyRiver override for coverage tests.
contract OperatorsRegistryWithMigrationHelpers is OperatorsRegistryV1 {
    modifier onlyRiver() override {
        _;
    }

    function sudoPushV2Operator(OperatorsV2.Operator memory op) external {
        OperatorsV2.push(op);
    }

    function sudoSetV2StoppedValidators(uint32[] calldata counts) external {
        OperatorsV2.setRawStoppedValidators(counts);
    }

    function sudoSetFundedV3(uint256 opIndex, uint256 amount) external {
        OperatorsV3.get(opIndex).funded = amount;
    }

    /// Test helper: exposes OperatorsV2.getAll() for tests.
    function sudoGetAllV2Length() external view returns (uint256) {
        return OperatorsV2.getAll().length;
    }

    /// Test helper: exposes OperatorsV2.getAllActive() for tests.
    function sudoGetAllActiveV2() external view returns (OperatorsV2.Operator[] memory) {
        return OperatorsV2.getAllActive();
    }

    /// Test helper: exposes OperatorsV2.setKeys() for tests.
    function sudoSetKeysV2(uint256 _index, uint32 _newKeys) external {
        OperatorsV2.setKeys(_index, _newKeys);
    }

    /// Test helper: exposes OperatorsV2._getStoppedValidatorCountAtIndex() for tests.
    function sudoGetStoppedValidatorCountAtIndexV2(uint256 index) external view returns (uint32) {
        return OperatorsV2._getStoppedValidatorCountAtIndex(OperatorsV2.getStoppedValidators(), index);
    }

    /// Test helper: calls OperatorsV2.get(index); use with out-of-bounds index to trigger OperatorNotFound.
    function sudoGetV2OutOfBounds(uint256 index) external view returns (OperatorsV2.Operator memory) {
        return OperatorsV2.get(index);
    }

    function sudoSetActiveCLETH(uint256 _index, uint256 _activeCLETH) external {
        OperatorsV3.get(_index).activeCLETH = _activeCLETH;
    }

    function sudoSetRawExitedETH(uint256[] memory value) external {
        OperatorsV3.setRawExitedETH(value);
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
    event UpdatedExitedETH(uint256[] exitedETH);
    event SetOperatorExitedETH(uint256 operatorIndex, uint256 exitedETH);
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

    function testReportExitedETHUnauthorized(uint256 _salt) public {
        address random = uf._new(_salt);

        uint256[] memory exitedETH = new uint256[](1);
        exitedETH[0] = 0;

        vm.prank(random);
        vm.expectRevert(abi.encodeWithSignature("Unauthorized(address)", random));
        operatorsRegistry.reportExitedETH(exitedETH, 0);
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

    function testGetExitedETH() public {
        uint256[] memory exitedETH = operatorsRegistry.getExitedETHPerOperator();
        assertEq(exitedETH.length, 0);
    }

    function testReportExitedETH(uint8 totalCount, uint8 len) public {
        // Cap len and totalCount to avoid MemoryOOG when adding many validators per operator
        len = uint8(bound(len, 1, 30));
        vm.assume(len > 0 && len < type(uint8).max);
        totalCount = uint8(bound(totalCount, len, 100));

        uint256[] memory exitedETH = new uint256[](len + 1);
        exitedETH[0] = uint256(totalCount) * 32 ether;

        for (uint256 idx = 1; idx < len + 1; ++idx) {
            vm.prank(admin);
            operatorsRegistry.addOperator(string(abi.encodePacked(idx)), address(123));
            uint256 perOperatorCount = (totalCount / len) + (idx - 1 < totalCount % len ? 1 : 0);
            exitedETH[idx] = perOperatorCount * 32 ether;
            // Set funded high enough so exited ETH doesn't exceed funded
            OperatorsRegistryInitializableV1(address(operatorsRegistry))
                .sudoSetFunded(idx - 1, uint256(totalCount) * 32 ether);
        }

        // Pre-initialize exited ETH array and activeCLETH so _setExitedETH doesn't panic.
        OperatorsRegistryInitializableV1(address(operatorsRegistry)).sudoSetRawExitedETH(new uint256[](len + 1));
        for (uint256 idx2 = 0; idx2 < len; ++idx2) {
            OperatorsRegistryInitializableV1(address(operatorsRegistry))
                .sudoSetActiveCLETH(idx2, uint256(totalCount) * 32 ether);
        }

        vm.prank(river);
        operatorsRegistry.reportExitedETH(exitedETH, uint256(totalCount) * 32 ether);

        uint256[] memory rawExitedETH = operatorsRegistry.getExitedETHPerOperator();
        assertEq(rawExitedETH.length, exitedETH.length - 1);

        for (uint256 idx = 1; idx < len + 1; ++idx) {
            assertEq(exitedETH[idx], rawExitedETH[idx - 1]);
        }
    }

    function testReportExitedETHEmptyArray() public {
        uint256[] memory exitedETH = new uint256[](0);
        vm.prank(river);
        vm.expectRevert(abi.encodeWithSignature("InvalidEmptyArray()"));
        operatorsRegistry.reportExitedETH(exitedETH, 0);
    }

    function testReportExitedETHCountTooHigh() public {
        uint256[] memory exitedETH = new uint256[](2);
        vm.prank(river);
        vm.expectRevert(abi.encodeWithSignature("ExitedETHArrayLengthExceedsOperatorCount()"));
        operatorsRegistry.reportExitedETH(exitedETH, 0);
    }

    function testReportExitedETHInvalidSum(uint8 totalCount, uint8 len) public {
        // Cap len and totalCount to avoid MemoryOOG when adding many validators per operator
        len = uint8(bound(len, 1, 30));
        vm.assume(len > 0 && len < type(uint8).max);
        totalCount = uint8(bound(totalCount, len, 100));

        uint256[] memory exitedETH = new uint256[](len + 1);
        exitedETH[0] = uint256(totalCount) * 32 ether;

        for (uint256 idx = 1; idx < len + 1; ++idx) {
            vm.prank(admin);
            operatorsRegistry.addOperator(string(abi.encodePacked(idx)), address(123));
            exitedETH[idx] = ((totalCount / len) + (idx - 1 < totalCount % len ? 1 : 0)) * 32 ether;
            // Set funded high enough so exited ETH doesn't exceed funded
            OperatorsRegistryInitializableV1(address(operatorsRegistry))
                .sudoSetFunded(idx - 1, uint256(totalCount) * 32 ether);
        }

        // Pre-initialize exited ETH array and activeCLETH so _setExitedETH doesn't panic.
        OperatorsRegistryInitializableV1(address(operatorsRegistry)).sudoSetRawExitedETH(new uint256[](len + 1));
        for (uint256 idx2 = 0; idx2 < len; ++idx2) {
            OperatorsRegistryInitializableV1(address(operatorsRegistry))
                .sudoSetActiveCLETH(idx2, uint256(totalCount) * 32 ether);
        }

        // Make the total mismatch
        exitedETH[0] -= 32 ether;

        vm.prank(river);
        vm.expectRevert(abi.encodeWithSignature("ExitedETHSumMismatch()"));
        operatorsRegistry.reportExitedETH(exitedETH, uint256(totalCount) * 32 ether);
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

    event RequestedETHExits(uint256 indexed index, uint256 amount);
    event SetTotalETHExitsRequested(uint256 previousTotalETHExitsRequested, uint256 newTotalETHExitsRequested);
    event SetCurrentETHExitsDemand(uint256 previousETHExitsDemand, uint256 nextETHExitsDemand);

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

    /// @dev Fund all 5 operators with 50 * 32 ETH each (equivalent of 50 validators)
    function _fundAllOperators() internal {
        for (uint256 i = 0; i < 5; ++i) {
            OperatorsRegistryInitializableV1(address(operatorsRegistry)).sudoSetFunded(i, 50 * 32 ether);
            OperatorsRegistryInitializableV1(address(operatorsRegistry)).sudoSetActiveCLETH(i, 50 * 32 ether);
        }
        OperatorsRegistryInitializableV1(address(operatorsRegistry)).sudoSetRawExitedETH(new uint256[](6));
    }

    // ──────────────────────────────────────────────────────────────────────
    // TEST 1: Sequential exit allocations accumulate correctly
    // ──────────────────────────────────────────────────────────────────────

    /// @notice Two rounds of exits to overlapping operators. Verifies requestedExits
    ///         accumulates correctly and demand decrements across both calls.
    function testSequentialExitAllocationsAccumulate() external {
        _fundAllOperators();

        // Set demand to 100 validators (100 * 32 ETH)
        vm.prank(river);
        operatorsRegistry.demandETHExits(100 * 32 ether, 250 * 32 ether);
        assertEq(operatorsRegistry.getCurrentETHExitsDemand(), 100 * 32 ether);

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
        operatorsRegistry.requestETHExits(_createExitAllocation(ops1, counts1));

        assertEq(
            operatorsRegistry.getOperator(0).requestedExits, 10 * 32 ether, "Op0 should have 10 exits after round 1"
        );
        assertEq(
            operatorsRegistry.getOperator(1).requestedExits, 10 * 32 ether, "Op1 should have 10 exits after round 1"
        );
        assertEq(
            operatorsRegistry.getOperator(2).requestedExits, 10 * 32 ether, "Op2 should have 10 exits after round 1"
        );
        assertEq(operatorsRegistry.getOperator(3).requestedExits, 0, "Op3 untouched after round 1");
        assertEq(operatorsRegistry.getOperator(4).requestedExits, 0, "Op4 untouched after round 1");
        assertEq(operatorsRegistry.getCurrentETHExitsDemand(), 70 * 32 ether, "Demand should be 70 after round 1");
        assertEq(operatorsRegistry.getTotalETHExitsRequested(), 30 * 32 ether, "Total exits should be 30 after round 1");

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
        operatorsRegistry.requestETHExits(_createExitAllocation(ops2, counts2));

        assertEq(operatorsRegistry.getOperator(0).requestedExits, 25 * 32 ether, "Op0 should have 10+15=25 exits");
        assertEq(operatorsRegistry.getOperator(1).requestedExits, 25 * 32 ether, "Op1 should have 10+15=25 exits");
        assertEq(operatorsRegistry.getOperator(2).requestedExits, 10 * 32 ether, "Op2 unchanged from round 1");
        assertEq(operatorsRegistry.getOperator(3).requestedExits, 5 * 32 ether, "Op3 should have 5 exits from round 2");
        assertEq(operatorsRegistry.getOperator(4).requestedExits, 0, "Op4 still untouched");
        assertEq(operatorsRegistry.getCurrentETHExitsDemand(), 35 * 32 ether, "Demand should be 100-30-35=35");
        assertEq(operatorsRegistry.getTotalETHExitsRequested(), 65 * 32 ether, "Total exits should be 30+35=65");
    }

    // ──────────────────────────────────────────────────────────────────────
    // TEST 2: Non-contiguous operator exits
    // ──────────────────────────────────────────────────────────────────────

    /// @notice Exit from operators 0 and 4 only, skipping active operators 1,2,3.
    ///         Verifies skipped operators remain at requestedExits=0.
    function testNonContiguousExitAllocations() external {
        _fundAllOperators();

        vm.prank(river);
        operatorsRegistry.demandETHExits(30 * 32 ether, 250 * 32 ether);

        uint256[] memory ops = new uint256[](2);
        ops[0] = 0;
        ops[1] = 4;
        uint32[] memory counts = new uint32[](2);
        counts[0] = 20;
        counts[1] = 10;

        vm.expectEmit(true, true, true, true);
        emit RequestedETHExits(0, 20 * 32 ether);
        vm.expectEmit(true, true, true, true);
        emit RequestedETHExits(4, 10 * 32 ether);

        vm.prank(keeper);
        operatorsRegistry.requestETHExits(_createExitAllocation(ops, counts));

        assertEq(operatorsRegistry.getOperator(0).requestedExits, 20 * 32 ether, "Op0 should have 20 exits");
        assertEq(operatorsRegistry.getOperator(1).requestedExits, 0, "Op1 should remain at 0");
        assertEq(operatorsRegistry.getOperator(2).requestedExits, 0, "Op2 should remain at 0");
        assertEq(operatorsRegistry.getOperator(3).requestedExits, 0, "Op3 should remain at 0");
        assertEq(operatorsRegistry.getOperator(4).requestedExits, 10 * 32 ether, "Op4 should have 10 exits");
        assertEq(operatorsRegistry.getCurrentETHExitsDemand(), 0, "Demand fully satisfied");
        assertEq(operatorsRegistry.getTotalETHExitsRequested(), 30 * 32 ether);
    }

    // ──────────────────────────────────────────────────────────────────────
    // TEST 3: Partial demand fulfillment across multiple calls
    // ──────────────────────────────────────────────────────────────────────

    /// @notice Demand is 100. Keeper fulfills 40 in first call, then 60 in second call.
    ///         Verifies demand decrements correctly and total accumulates.
    function testPartialDemandFulfillmentAcrossMultipleCalls() external {
        _fundAllOperators();

        vm.prank(river);
        operatorsRegistry.demandETHExits(100 * 32 ether, 250 * 32 ether);
        assertEq(operatorsRegistry.getCurrentETHExitsDemand(), 100 * 32 ether);
        assertEq(operatorsRegistry.getTotalETHExitsRequested(), 0);

        // Call 1: fulfill 40 (8 from each operator)
        uint256[] memory ops = new uint256[](5);
        uint32[] memory counts = new uint32[](5);
        for (uint256 i = 0; i < 5; ++i) {
            ops[i] = i;
            counts[i] = 8;
        }

        vm.prank(keeper);
        operatorsRegistry.requestETHExits(_createExitAllocation(ops, counts));

        assertEq(operatorsRegistry.getCurrentETHExitsDemand(), 60 * 32 ether, "Demand should be 60 after first call");
        assertEq(operatorsRegistry.getTotalETHExitsRequested(), 40 * 32 ether, "Total exits should be 40");

        for (uint256 i = 0; i < 5; ++i) {
            assertEq(
                operatorsRegistry.getOperator(i).requestedExits,
                8 * 32 ether,
                string(abi.encodePacked("Op ", vm.toString(i), " should have 8 exits"))
            );
        }

        // Call 2: fulfill remaining 60 (12 from each)
        for (uint256 i = 0; i < 5; ++i) {
            counts[i] = 12;
        }

        vm.prank(keeper);
        operatorsRegistry.requestETHExits(_createExitAllocation(ops, counts));

        assertEq(operatorsRegistry.getCurrentETHExitsDemand(), 0, "Demand should be fully satisfied");
        assertEq(operatorsRegistry.getTotalETHExitsRequested(), 100 * 32 ether, "Total exits should be 100");

        for (uint256 i = 0; i < 5; ++i) {
            assertEq(
                operatorsRegistry.getOperator(i).requestedExits,
                20 * 32 ether,
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

        // Step 1: Create demand for 200 exits (200 * 32 ETH)
        vm.prank(river);
        operatorsRegistry.demandETHExits(200 * 32 ether, 250 * 32 ether);
        assertEq(operatorsRegistry.getCurrentETHExitsDemand(), 200 * 32 ether);
        assertEq(operatorsRegistry.getTotalETHExitsRequested(), 0);

        // Step 2: Report 50 validators worth of exited ETH across operators (reduces demand by 50*32e)
        // exitedETH[0] = total, exitedETH[i+1] = per-operator exited ETH
        uint256[] memory exitedETH1 = new uint256[](6);
        exitedETH1[0] = 50 * 32 ether; // total
        exitedETH1[1] = 10 * 32 ether; // op0
        exitedETH1[2] = 10 * 32 ether; // op1
        exitedETH1[3] = 10 * 32 ether; // op2
        exitedETH1[4] = 10 * 32 ether; // op3
        exitedETH1[5] = 10 * 32 ether; // op4
        OperatorsRegistryInitializableV1(address(operatorsRegistry)).sudoReportExitedETH(exitedETH1);

        assertEq(operatorsRegistry.getCurrentETHExitsDemand(), 150 * 32 ether, "Demand reduced by 50 exited");
        assertEq(operatorsRegistry.getTotalETHExitsRequested(), 50 * 32 ether, "Exited validators count as exits");

        // Step 3: Keeper exits 60 (12 from each operator)
        uint256[] memory ops = new uint256[](5);
        uint32[] memory exitCounts1 = new uint32[](5);
        for (uint256 i = 0; i < 5; ++i) {
            ops[i] = i;
            exitCounts1[i] = 12;
        }

        vm.prank(keeper);
        operatorsRegistry.requestETHExits(_createExitAllocation(ops, exitCounts1));

        assertEq(operatorsRegistry.getCurrentETHExitsDemand(), 90 * 32 ether, "Demand should be 150-60=90");
        assertEq(operatorsRegistry.getTotalETHExitsRequested(), 110 * 32 ether, "Total exits should be 50+60=110");

        for (uint256 i = 0; i < 5; ++i) {
            // requestedExits = 10*32e (from exited) + 12*32e (from keeper) = 22*32e
            assertEq(
                operatorsRegistry.getOperator(i).requestedExits,
                22 * 32 ether,
                string(abi.encodePacked("Op ", vm.toString(i), " should have 22 requestedExits"))
            );
        }

        // Step 4: Report 80 total (cumulative), 16 per operator.
        // Since 16*32e < requestedExits(22*32e) for all ops, no bump occurs and demand stays at 90*32e.
        uint256[] memory exitedETH2 = new uint256[](6);
        exitedETH2[0] = 80 * 32 ether; // total now 80 (was 50)
        exitedETH2[1] = 16 * 32 ether; // op0
        exitedETH2[2] = 16 * 32 ether; // op1
        exitedETH2[3] = 16 * 32 ether; // op2
        exitedETH2[4] = 16 * 32 ether; // op3
        exitedETH2[5] = 16 * 32 ether; // op4
        OperatorsRegistryInitializableV1(address(operatorsRegistry)).sudoReportExitedETH(exitedETH2);

        // Demand unchanged because exitedETH(16*32e) < requestedExits(22*32e) for all operators
        assertEq(
            operatorsRegistry.getCurrentETHExitsDemand(), 90 * 32 ether, "Demand unchanged: exited < requestedExits"
        );
        assertEq(operatorsRegistry.getTotalETHExitsRequested(), 110 * 32 ether, "Total exits unchanged");

        // requestedExits still 22*32e per operator (exited didn't exceed it)
        for (uint256 i = 0; i < 5; ++i) {
            assertEq(
                operatorsRegistry.getOperator(i).requestedExits,
                22 * 32 ether,
                string(abi.encodePacked("Op ", vm.toString(i), " requestedExits unchanged at 22"))
            );
        }

        // Step 5: Keeper exits 12 more from each (total 60)
        uint32[] memory exitCounts2 = new uint32[](5);
        for (uint256 i = 0; i < 5; ++i) {
            exitCounts2[i] = 12;
        }

        vm.prank(keeper);
        operatorsRegistry.requestETHExits(_createExitAllocation(ops, exitCounts2));

        assertEq(operatorsRegistry.getCurrentETHExitsDemand(), 30 * 32 ether, "Demand should be 90-60=30");
        assertEq(operatorsRegistry.getTotalETHExitsRequested(), 170 * 32 ether, "Total exits should be 110+60=170");

        for (uint256 i = 0; i < 5; ++i) {
            // requestedExits = 22*32e + 12*32e = 34*32e
            assertEq(
                operatorsRegistry.getOperator(i).requestedExits,
                34 * 32 ether,
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
    // function testDepositThenExitEndToEnd() external {

    //     // Phase 1: Deposit 10 to op0, 15 to op1, 5 to op2 = 30 total
    //     uint32[] memory depositCounts = new uint32[](3);
    //     depositCounts[0] = 10;
    //     depositCounts[1] = 15;
    //     depositCounts[2] = 5;

    //     vm.prank(river);
    //     operatorsRegistry.pickNextValidatorsToDeposit(_createAllocation(ops, depositCounts));

    //     assertEq(operatorsRegistry.getOperator(0).funded, 10, "Op0 should have 10 funded");
    //     assertEq(operatorsRegistry.getOperator(1).funded, 15, "Op1 should have 15 funded");
    //     assertEq(operatorsRegistry.getOperator(2).funded, 5, "Op2 should have 5 funded");

    //     // Phase 2: Request exits -- 5 from op0, 7 from op1, 3 from op2 = 15 total
    //     RiverMock(river).sudoSetDepositedValidatorsCount(30);
    //     vm.prank(river);
    //     operatorsRegistry.demandValidatorExits(15, 30);
    //     assertEq(operatorsRegistry.getCurrentValidatorExitsDemand(), 15);

    //     uint32[] memory exitCounts = new uint32[](3);
    //     exitCounts[0] = 5;
    //     exitCounts[1] = 7;
    //     exitCounts[2] = 3;

    //     vm.prank(keeper);
    //     operatorsRegistry.requestETHExits(_createExitAllocation(ops, exitCounts));

    //     assertEq(operatorsRegistry.getOperator(0).funded, 10, "Op0 funded unchanged");
    //     assertEq(operatorsRegistry.getOperator(1).funded, 15, "Op1 funded unchanged");
    //     assertEq(operatorsRegistry.getOperator(2).funded, 5, "Op2 funded unchanged");
    //     assertEq(operatorsRegistry.getOperator(0).requestedExits, 5, "Op0 should have 5 exits");
    //     assertEq(operatorsRegistry.getOperator(1).requestedExits, 7, "Op1 should have 7 exits");
    //     assertEq(operatorsRegistry.getOperator(2).requestedExits, 3, "Op2 should have 3 exits");
    //     assertEq(operatorsRegistry.getCurrentValidatorExitsDemand(), 0, "Demand fully satisfied");
    //     assertEq(operatorsRegistry.getTotalValidatorExitsRequested(), 15);

    //     // Phase 3: Before depositing more, the exited validators must actually stop.
    //     // getAllFundable() requires stoppedCount >= requestedExits for eligibility.
    //     // Simulate the stopped validators matching the exit requests.
    //     uint32[] memory stoppedCounts = new uint32[](4);
    //     stoppedCounts[0] = 15; // total stopped
    //     stoppedCounts[1] = 5; // op0 stopped
    //     stoppedCounts[2] = 7; // op1 stopped
    //     stoppedCounts[3] = 3; // op2 stopped
    //     OperatorsRegistryInitializableV1(address(operatorsRegistry)).sudoStoppedValidatorCounts(stoppedCounts, 30);

    //     // Phase 4: Now deposit more to op0 (limit=20, funded=10, stopped >= requestedExits)
    //     uint32[] memory depositCounts2 = new uint32[](1);
    //     depositCounts2[0] = 5;
    //     uint256[] memory singleOp = new uint256[](1);
    //     singleOp[0] = 0;

    //     vm.prank(river);
    //     operatorsRegistry.pickNextValidatorsToDeposit(_createAllocation(singleOp, depositCounts2));

    //     assertEq(operatorsRegistry.getOperator(0).funded, 15, "Op0 should now have 15 funded");
    //     assertEq(operatorsRegistry.getOperator(0).requestedExits, 5, "Op0 exits unchanged by new deposit");

    //     // Verify the other operators are unchanged
    //     assertEq(operatorsRegistry.getOperator(1).funded, 15, "Op1 funded unchanged");
    //     assertEq(operatorsRegistry.getOperator(2).funded, 5, "Op2 funded unchanged");
    // }

    // ──────────────────────────────────────────────────────────────────────
    // TEST 6: ExitsRequestedExceedExitDemand by one
    // ──────────────────────────────────────────────────────────────────────

    /// @notice Demand is 10. Request exactly 11 exits (1 over). Verify the exact error parameters.
    function testExitsRequestedExceedExitDemandByOne() external {
        _fundAllOperators();

        vm.prank(river);
        operatorsRegistry.demandETHExits(10 * 32 ether, 250 * 32 ether);
        assertEq(operatorsRegistry.getCurrentETHExitsDemand(), 10 * 32 ether);

        // Request 11 total (all from op0) -- 1 over demand
        uint256[] memory ops = new uint256[](1);
        ops[0] = 0;
        uint32[] memory counts = new uint32[](1);
        counts[0] = 11;

        vm.expectRevert(
            abi.encodeWithSignature(
                "ExitsRequestedExceedExitDemand(uint256,uint256)", uint256(11) * 32 ether, uint256(10) * 32 ether
            )
        );
        vm.prank(keeper);
        operatorsRegistry.requestETHExits(_createExitAllocation(ops, counts));
    }

    // ──────────────────────────────────────────────────────────────────────
    // TEST 7: ExitsRequestedExceedExitDemand after partial fulfillment
    // ──────────────────────────────────────────────────────────────────────

    /// @notice Demand is 20. First call fulfills 15. Second call tries to exit 10 (5 over remaining 5).
    function testExitsRequestedExceedExitDemandAfterPartialFulfillment() external {
        _fundAllOperators();

        vm.prank(river);
        operatorsRegistry.demandETHExits(20 * 32 ether, 250 * 32 ether);
        assertEq(operatorsRegistry.getCurrentETHExitsDemand(), 20 * 32 ether);

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
        operatorsRegistry.requestETHExits(_createExitAllocation(ops1, counts1));
        assertEq(operatorsRegistry.getCurrentETHExitsDemand(), 5 * 32 ether, "Demand should be 5 after first call");

        // Second call: try to exit 10 from op3 (5 over remaining demand of 5)
        uint256[] memory ops2 = new uint256[](1);
        ops2[0] = 3;
        uint32[] memory counts2 = new uint32[](1);
        counts2[0] = 10;

        vm.expectRevert(
            abi.encodeWithSignature(
                "ExitsRequestedExceedExitDemand(uint256,uint256)", uint256(10) * 32 ether, uint256(5) * 32 ether
            )
        );
        vm.prank(keeper);
        operatorsRegistry.requestETHExits(_createExitAllocation(ops2, counts2));
    }

    // ──────────────────────────────────────────────────────────────────────
    // TEST 8: Exits exactly match demand succeeds
    // ──────────────────────────────────────────────────────────────────────

    /// @notice Demand is 10, request exactly 10 across multiple operators. Verify it succeeds and demand goes to 0.
    function testExitsRequestedExactlyMatchesDemand() external {
        _fundAllOperators();

        vm.prank(river);
        operatorsRegistry.demandETHExits(10 * 32 ether, 250 * 32 ether);
        assertEq(operatorsRegistry.getCurrentETHExitsDemand(), 10 * 32 ether);

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
        operatorsRegistry.requestETHExits(_createExitAllocation(ops, counts));

        assertEq(operatorsRegistry.getCurrentETHExitsDemand(), 0, "Demand should be 0");
        assertEq(operatorsRegistry.getTotalETHExitsRequested(), 10 * 32 ether, "Total exits should be 10");
        assertEq(operatorsRegistry.getOperator(0).requestedExits, 3 * 32 ether, "Op0 should have 3 exits");
        assertEq(operatorsRegistry.getOperator(1).requestedExits, 3 * 32 ether, "Op1 should have 3 exits");
        assertEq(operatorsRegistry.getOperator(2).requestedExits, 4 * 32 ether, "Op2 should have 4 exits");
    }

    // ──────────────────────────────────────────────────────────────────────
    // TEST 9: Stopped validators exceeding requestedExits bumps requestedExits
    // ──────────────────────────────────────────────────────────────────────

    event UpdatedRequestedETHExitsUponStopped(
        uint256 indexed index, uint256 oldRequestedExits, uint256 newRequestedExits
    );

    /// @notice When reported exited ETH exceeds an operator's requestedExits,
    ///         requestedExits is bumped to match the exited ETH, the unsolicited
    ///         delta is added to TotalETHExitsRequested, and
    ///         CurrentETHExitsDemand is reduced by the unsolicited amount.
    ///         This test exercises the FIRST loop in _setExitedETH
    ///         (existing operators path) by making two successive exited-ETH reports.
    function testStoppedCountExceedingRequestedExitsBumpsRequestedExits() external {
        _fundAllOperators();

        // Create demand of 50 validators (50 * 32 ETH)
        vm.prank(river);
        operatorsRegistry.demandETHExits(50 * 32 ether, 250 * 32 ether);
        assertEq(operatorsRegistry.getCurrentETHExitsDemand(), 50 * 32 ether);
        assertEq(operatorsRegistry.getTotalETHExitsRequested(), 0);

        // Keeper requests 5 exits from op0 and op1 only (total 10)
        uint256[] memory ops = new uint256[](2);
        ops[0] = 0;
        ops[1] = 1;
        uint32[] memory exitCounts = new uint32[](2);
        exitCounts[0] = 5;
        exitCounts[1] = 5;

        vm.prank(keeper);
        operatorsRegistry.requestETHExits(_createExitAllocation(ops, exitCounts));

        assertEq(operatorsRegistry.getOperator(0).requestedExits, 5 * 32 ether, "Op0 should have 5 requestedExits");
        assertEq(operatorsRegistry.getOperator(1).requestedExits, 5 * 32 ether, "Op1 should have 5 requestedExits");
        assertEq(operatorsRegistry.getOperator(2).requestedExits, 0, "Op2 should have 0 requestedExits");
        assertEq(operatorsRegistry.getOperator(3).requestedExits, 0, "Op3 should have 0 requestedExits");
        assertEq(operatorsRegistry.getOperator(4).requestedExits, 0, "Op4 should have 0 requestedExits");
        assertEq(operatorsRegistry.getCurrentETHExitsDemand(), 40 * 32 ether, "Demand should be 50-10=40");
        assertEq(operatorsRegistry.getTotalETHExitsRequested(), 10 * 32 ether, "Total exits should be 10");

        // First exited-ETH report: small amounts that do NOT exceed requestedExits
        // for op0 and op1. op2 and op3 get bumped (unsolicited = 2+1 = 3 validators = 3*32e).
        uint256[] memory exitedETH1 = new uint256[](6);
        exitedETH1[0] = 6 * 32 ether; // total: (2+1+2+1+0) * 32e
        exitedETH1[1] = 2 * 32 ether; // op0 (2*32e <= requestedExits 5*32e, no bump)
        exitedETH1[2] = 1 * 32 ether; // op1 (1*32e <= requestedExits 5*32e, no bump)
        exitedETH1[3] = 2 * 32 ether; // op2 (2*32e > requestedExits 0, bumps to 2*32e)
        exitedETH1[4] = 1 * 32 ether; // op3 (1*32e > requestedExits 0, bumps to 1*32e)
        exitedETH1[5] = 0; // op4
        OperatorsRegistryInitializableV1(address(operatorsRegistry)).sudoReportExitedETH(exitedETH1);

        // After first report: op2 bumped 0->2*32e, op3 bumped 0->1*32e (unsolicited = 3*32e)
        assertEq(operatorsRegistry.getOperator(0).requestedExits, 5 * 32 ether, "Op0 unchanged after first report");
        assertEq(operatorsRegistry.getOperator(1).requestedExits, 5 * 32 ether, "Op1 unchanged after first report");
        assertEq(operatorsRegistry.getOperator(2).requestedExits, 2 * 32 ether, "Op2 bumped to 2 after first report");
        assertEq(operatorsRegistry.getOperator(3).requestedExits, 1 * 32 ether, "Op3 bumped to 1 after first report");
        assertEq(operatorsRegistry.getTotalETHExitsRequested(), 13 * 32 ether, "Total exits = 10 + 3 unsolicited");
        assertEq(operatorsRegistry.getCurrentETHExitsDemand(), 37 * 32 ether, "Demand = 40 - 3 unsolicited");

        // Second exited-ETH report: higher amounts that exceed requestedExits.
        //   op0: 8*32e (exceeds requestedExits=5*32e, unsolicited delta = 3*32e)
        //   op1: 3*32e (does NOT exceed requestedExits=5*32e, no bump)
        //   op2: 7*32e (exceeds requestedExits=2*32e, unsolicited delta = 5*32e)
        //   op3: 1*32e (unchanged, does NOT exceed requestedExits=1*32e)
        //   op4: 0 (no change)
        // Total unsolicited = (3+5)*32e = 8*32e
        uint256[] memory exitedETH2 = new uint256[](6);
        exitedETH2[0] = 19 * 32 ether; // total: (8+3+7+1+0) * 32e
        exitedETH2[1] = 8 * 32 ether; // op0
        exitedETH2[2] = 3 * 32 ether; // op1
        exitedETH2[3] = 7 * 32 ether; // op2
        exitedETH2[4] = 1 * 32 ether; // op3
        exitedETH2[5] = 0; // op4

        vm.expectEmit(true, true, true, true);
        emit UpdatedRequestedETHExitsUponStopped(0, 5 * 32 ether, 8 * 32 ether);
        vm.expectEmit(true, true, true, true);
        emit UpdatedRequestedETHExitsUponStopped(2, 2 * 32 ether, 7 * 32 ether);

        OperatorsRegistryInitializableV1(address(operatorsRegistry)).sudoReportExitedETH(exitedETH2);

        // requestedExits bumped for op0 (5->8) and op2 (2->7); others unchanged
        assertEq(operatorsRegistry.getOperator(0).requestedExits, 8 * 32 ether, "Op0 requestedExits bumped");
        assertEq(operatorsRegistry.getOperator(1).requestedExits, 5 * 32 ether, "Op1 requestedExits unchanged");
        assertEq(operatorsRegistry.getOperator(2).requestedExits, 7 * 32 ether, "Op2 requestedExits bumped");
        assertEq(operatorsRegistry.getOperator(3).requestedExits, 1 * 32 ether, "Op3 requestedExits unchanged");
        assertEq(operatorsRegistry.getOperator(4).requestedExits, 0, "Op4 requestedExits unchanged");

        // TotalETHExitsRequested = 13*32e + 8*32e (unsolicited) = 21*32e
        assertEq(operatorsRegistry.getTotalETHExitsRequested(), 21 * 32 ether, "Total exits should include unsolicited");

        // CurrentETHExitsDemand = 37*32e - min(8*32e, 37*32e) = 29*32e
        assertEq(operatorsRegistry.getCurrentETHExitsDemand(), 29 * 32 ether, "Demand reduced by unsolicited exits");
    }

    /// @notice When stopped count exceeds requestedExits and the unsolicited amount
    ///         is larger than the remaining demand, demand is clamped to zero.
    function testStoppedCountExceedingRequestedExitsClampsDemandToZero() external {
        _fundAllOperators();

        // Create small demand of 5 validators (5 * 32 ETH)
        vm.prank(river);
        operatorsRegistry.demandETHExits(5 * 32 ether, 250 * 32 ether);
        assertEq(operatorsRegistry.getCurrentETHExitsDemand(), 5 * 32 ether);

        // No keeper exit requests: all operators have requestedExits = 0

        // Report 20*32e exited ETH on op0 alone — unsolicited delta = 20*32e, exceeds demand of 5*32e
        uint256[] memory exitedETH = new uint256[](6);
        exitedETH[0] = 20 * 32 ether;
        exitedETH[1] = 20 * 32 ether; // op0
        exitedETH[2] = 0;
        exitedETH[3] = 0;
        exitedETH[4] = 0;
        exitedETH[5] = 0;

        vm.expectEmit(true, true, true, true);
        emit UpdatedRequestedETHExitsUponStopped(0, 0, 20 * 32 ether);

        OperatorsRegistryInitializableV1(address(operatorsRegistry)).sudoReportExitedETH(exitedETH);

        assertEq(operatorsRegistry.getOperator(0).requestedExits, 20 * 32 ether, "Op0 requestedExits bumped to 20*32e");
        assertEq(operatorsRegistry.getTotalETHExitsRequested(), 20 * 32 ether, "Total exits = unsolicited 20*32e");
        // Demand clamped: 5*32e - min(20*32e, 5*32e) = 0
        assertEq(operatorsRegistry.getCurrentETHExitsDemand(), 0, "Demand clamped to zero");
    }

    /// @notice When a new operator is added between two stopped-count reports,
    ///         the second report includes the new operator's stopped count which
    ///         triggers the requestedExits bump in the "new operator" loop.
    //     function testStoppedCountExceedingRequestedExitsForNewOperator() external {
    //         _fundAllOperators();

    //         // Initial stopped report for 5 operators (all zeros)
    //         uint32[] memory stoppedCounts1 = new uint32[](6);
    //         stoppedCounts1[0] = 0;
    //         stoppedCounts1[1] = 0;
    //         stoppedCounts1[2] = 0;
    //         stoppedCounts1[3] = 0;
    //         stoppedCounts1[4] = 0;
    //         stoppedCounts1[5] = 0;
    //         OperatorsRegistryInitializableV1(address(operatorsRegistry)).sudoStoppedValidatorCounts(stoppedCounts1, 250);

    //         // Add a 6th operator, fund it
    //         vm.startPrank(admin);
    //         operatorsRegistry.addOperator("operatorSix", makeAddr("op6"));
    //         vm.stopPrank();

    //         uint256[] memory newOps = new uint256[](1);
    //         newOps[0] = 5;

    //         OperatorsRegistryInitializableV1(address(operatorsRegistry))
    //             .pickNextValidatorsToDeposit(_createAllocation(newOps, newLimits));
    //         RiverMock(river).sudoSetDepositedValidatorsCount(300);

    //         // Create demand
    //         vm.prank(river);
    //         operatorsRegistry.demandValidatorExits(10, 300);
    //         assertEq(operatorsRegistry.getCurrentValidatorExitsDemand(), 10);

    //         // Report stopped with 7 entries (includes new op5 at index 6 in the array)
    //         // The new operator (op5) has 0 requestedExits but 5 stopped -> unsolicited = 5
    //         uint32[] memory stoppedCounts2 = new uint32[](7);
    //         stoppedCounts2[0] = 5; // total
    //         stoppedCounts2[1] = 0; // op0
    //         stoppedCounts2[2] = 0; // op1
    //         stoppedCounts2[3] = 0; // op2
    //         stoppedCounts2[4] = 0; // op3
    //         stoppedCounts2[5] = 0; // op4
    //         stoppedCounts2[6] = 5; // op5 (new operator — enters the second loop)

    //         vm.expectEmit(true, true, true, true);
    //         emit UpdatedRequestedValidatorExitsUponStopped(5, 0, 5);

    //         OperatorsRegistryInitializableV1(address(operatorsRegistry)).sudoStoppedValidatorCounts(stoppedCounts2, 300);

    //         assertEq(operatorsRegistry.getOperator(5).requestedExits, 5, "New op requestedExits bumped to stoppedCount");
    //         assertEq(operatorsRegistry.getTotalValidatorExitsRequested(), 5, "Total exits = unsolicited 5");
    //         assertEq(operatorsRegistry.getCurrentValidatorExitsDemand(), 5, "Demand reduced by unsolicited 5");
    //     }
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

    function testIncrementFundedRevertsOperatorIgnoredExitRequests() external {
        _setupOperators(1, 10);

        // Give the operator some funded validators then request exits for all of them
        OperatorsRegistryInitializableV1(address(operatorsRegistry)).sudoSetFunded(0, 5);
        OperatorsRegistryInitializableV1(address(operatorsRegistry)).sudoExitRequests(0, 5);
        // stoppedCount remains 0, so operator has not fulfilled any exits

        uint256[] memory fundedArr = new uint256[](1);
        fundedArr[0] = 32 ether;
        vm.expectRevert(abi.encodeWithSignature("OperatorIgnoredExitRequests(uint256)", 0));
        operatorsRegistry.incrementFundedETH(fundedArr, new bytes[][](1));
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Coverage: state libs CurrentValidatorExitsDemand and TotalValidatorExitsRequested
// (their .set() is not called in production; this wrapper covers the library code)
// ─────────────────────────────────────────────────────────────────────────────

contract ValidatorExitsStateLibWrapper {
    function setCurrentValidatorExitsDemand(uint256 v) external {
        CurrentValidatorExitsDemand.set(v);
    }

    function getCurrentValidatorExitsDemand() external view returns (uint256) {
        return CurrentValidatorExitsDemand.get();
    }

    function setTotalValidatorExitsRequested(uint256 v) external {
        TotalValidatorExitsRequested.set(v);
    }

    function getTotalValidatorExitsRequested() external view returns (uint256) {
        return TotalValidatorExitsRequested.get();
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// OperatorsRegistry coverage tests (100% for changed contracts, no CoverageGaps)
// ─────────────────────────────────────────────────────────────────────────────

contract OperatorsRegistryV1CoverageTests is OperatorsRegistryV1TestBase, OperatorAllocationTestBase {
    OperatorsRegistryWithMigrationHelpers internal reg;

    function setUp() public {
        admin = makeAddr("admin");
        keeper = makeAddr("keeper");
        river = address(new RiverMock(0));
        RiverMock(river).setKeeper(keeper);
        reg = new OperatorsRegistryWithMigrationHelpers();
        LibImplementationUnbricker.unbrick(vm, address(reg));
    }

    /// Asserts that getExitedETHAndRequestedExitAmounts returns zeros when no exited ETH has been reported.
    function testGetExitedETHAndRequestedExitAmountsWhenNoExitedETH() public {
        reg.initOperatorsRegistryV1(admin, river);
        (uint256 exited, uint256 requested) = reg.getExitedETHAndRequestedExitAmounts();
        assertEq(exited, 0);
        assertEq(requested, 0);
    }

    /// Asserts that incrementFundedETH reverts with Unauthorized when caller is not the river.
    function testOnlyRiverRevertsForUnauthorizedCaller() public {
        OperatorsRegistryStrictRiverV1 strictReg = new OperatorsRegistryStrictRiverV1();
        LibImplementationUnbricker.unbrick(vm, address(strictReg));
        strictReg.initOperatorsRegistryV1(admin, river);
        uint256[] memory empty = new uint256[](1);
        vm.prank(makeAddr("random"));
        vm.expectRevert(abi.encodeWithSignature("Unauthorized(address)", makeAddr("random")));
        strictReg.incrementFundedETH(empty, new bytes[][](1));
    }

    /// Exercises V2 operator helpers (getAll, getAllActive, setKeys, stopped validators) after V1->V2 migration.
    function testOperatorsV2HelpersForCoverage() public {
        // Seed one V2 operator so getAll/getAllActive return non-empty results.
        reg.sudoPushV2Operator(
            OperatorsV2.Operator({
                limit: 0,
                funded: 0,
                requestedExits: 0,
                keys: 10,
                latestKeysEditBlockNumber: 0,
                active: true,
                name: "Op1",
                operator: makeAddr("op1")
            })
        );
        // Read V2 operator count and active list.
        assertEq(OperatorsRegistryWithMigrationHelpers(address(reg)).sudoGetAllV2Length(), 1);
        OperatorsV2.Operator[] memory active = OperatorsRegistryWithMigrationHelpers(address(reg)).sudoGetAllActiveV2();
        assertEq(active.length, 1);
        assertEq(active[0].operator, makeAddr("op1"));
        // Update keys for operator 0 and set stopped-validators array.
        OperatorsRegistryWithMigrationHelpers(address(reg)).sudoSetKeysV2(0, 10);
        uint32[] memory stopped = new uint32[](2);
        stopped[0] = 0;
        stopped[1] = 3;
        reg.sudoSetV2StoppedValidators(stopped);
        // Index 0 maps to stopped[1] = 3; index 1 is out of range and returns 0.
        assertEq(OperatorsRegistryWithMigrationHelpers(address(reg)).sudoGetStoppedValidatorCountAtIndexV2(0), 3);
        assertEq(OperatorsRegistryWithMigrationHelpers(address(reg)).sudoGetStoppedValidatorCountAtIndexV2(1), 0);
    }

    /// Asserts that reading a V2 operator by out-of-bounds index reverts with OperatorNotFound.
    function testOperatorsV2GetRevertsOnOutOfBounds() public {
        vm.expectRevert(abi.encodeWithSignature("OperatorNotFound(uint256)", uint256(10)));
        OperatorsRegistryWithMigrationHelpers(address(reg)).sudoGetV2OutOfBounds(10);
    }

    /// Asserts that incrementFundedETH reverts with InvalidEmptyArray when given an empty array.
    function testIncrementFundedETHRevertsOnEmptyArray() public {
        reg.initOperatorsRegistryV1(admin, river);
        uint256[] memory empty = new uint256[](0);
        vm.expectRevert(abi.encodeWithSignature("InvalidEmptyArray()"));
        reg.incrementFundedETH(empty, new bytes[][](0));
    }

    /// Asserts that requestETHExits reverts with OnlyKeeper when caller is not the keeper.
    function testrequestETHExitsRevertsIfNotKeeper() public {
        reg.initOperatorsRegistryV1(admin, river);
        vm.prank(admin);
        reg.addOperator("Op0", makeAddr("op0"));
        reg.sudoSetFundedV3(0, 32 ether);
        reg.demandETHExits(32 ether, 64 ether);
        vm.prank(makeAddr("notKeeper"));
        vm.expectRevert(abi.encodeWithSignature("OnlyKeeper()"));
        reg.requestETHExits(_createExitAllocation(_asArray(0), _asArrayU32(1)));
    }

    /// Asserts that requestETHExits reverts with NoExitRequestsToPerform when there is no exit demand.
    function testrequestETHExitsRevertsWhenNoDemand() public {
        reg.initOperatorsRegistryV1(admin, river);
        vm.prank(admin);
        reg.addOperator("Op0", makeAddr("op0"));
        vm.prank(keeper);
        vm.expectRevert(abi.encodeWithSignature("NoExitRequestsToPerform()"));
        reg.requestETHExits(_createExitAllocation(_asArray(0), _asArrayU32(1)));
    }

    /// Asserts that requestETHExits reverts with InvalidEmptyArray when allocations array is empty.
    function testrequestETHExitsRevertsOnEmptyAllocations() public {
        reg.initOperatorsRegistryV1(admin, river);
        reg.demandETHExits(32 ether, 64 ether);
        IOperatorsRegistryV1.ExitETHAllocation[] memory empty = new IOperatorsRegistryV1.ExitETHAllocation[](0);
        vm.prank(keeper);
        vm.expectRevert(abi.encodeWithSignature("InvalidEmptyArray()"));
        reg.requestETHExits(empty);
    }

    /// Asserts that requestETHExits reverts with AllocationWithIncorrectAmount when an allocation has an incorrect ethAmount.
    function testrequestETHExitsRevertsOnZeroETHAmount() public {
        reg.initOperatorsRegistryV1(admin, river);
        vm.prank(admin);
        reg.addOperator("Op0", makeAddr("op0"));
        reg.demandETHExits(64 ether, 128 ether);
        IOperatorsRegistryV1.ExitETHAllocation[] memory allocs = new IOperatorsRegistryV1.ExitETHAllocation[](1);
        allocs[0] = IOperatorsRegistryV1.ExitETHAllocation({operatorIndex: 0, ethAmount: 0});
        vm.prank(keeper);
        vm.expectRevert(abi.encodeWithSignature("AllocationWithIncorrectAmount(uint256)", 0));
        reg.requestETHExits(allocs);
    }

    /// Asserts that requestETHExits reverts with UnorderedOperatorList when operator indices are not strictly increasing.
    function testrequestETHExitsRevertsOnUnorderedOperators() public {
        reg.initOperatorsRegistryV1(admin, river);
        vm.startPrank(admin);
        reg.addOperator("Op0", makeAddr("op0"));
        reg.addOperator("Op1", makeAddr("op1"));
        vm.stopPrank();
        reg.sudoSetFundedV3(0, 10 * 32 ether);
        reg.sudoSetFundedV3(1, 10 * 32 ether);
        reg.sudoSetActiveCLETH(0, 10 * 32 ether);
        reg.sudoSetActiveCLETH(1, 10 * 32 ether);
        reg.demandETHExits(64 ether, 256 ether);
        IOperatorsRegistryV1.ExitETHAllocation[] memory allocs = new IOperatorsRegistryV1.ExitETHAllocation[](2);
        allocs[0] = IOperatorsRegistryV1.ExitETHAllocation({operatorIndex: 1, ethAmount: 32 ether});
        allocs[1] = IOperatorsRegistryV1.ExitETHAllocation({operatorIndex: 0, ethAmount: 32 ether});
        vm.prank(keeper);
        vm.expectRevert(abi.encodeWithSignature("UnorderedOperatorList()"));
        reg.requestETHExits(allocs);
    }

    /// Asserts that requestETHExits reverts with InactiveOperator when the target operator is inactive.
    function testrequestETHExitsRevertsForInactiveOperator() public {
        reg.initOperatorsRegistryV1(admin, river);
        vm.startPrank(admin);
        reg.addOperator("Op0", makeAddr("op0"));
        reg.setOperatorStatus(0, false);
        vm.stopPrank();
        reg.sudoSetFundedV3(0, 10 * 32 ether);
        reg.demandETHExits(32 ether, 64 ether);
        vm.prank(keeper);
        vm.expectRevert(abi.encodeWithSignature("InactiveOperator(uint256)", 0));
        reg.requestETHExits(_createExitAllocation(_asArray(0), _asArrayU32(1)));
    }

    /// Asserts that requestETHExits reverts when total requested exits would exceed an operator's funded amount.
    function testrequestETHExitsRevertsWhenExceedsAvailable() public {
        reg.initOperatorsRegistryV1(admin, river);
        vm.prank(admin);
        reg.addOperator("Op0", makeAddr("op0"));
        reg.sudoSetFundedV3(0, 1 * 32 ether);
        reg.sudoSetActiveCLETH(0, 1 * 32 ether);
        reg.demandETHExits(4 * 32 ether, 128 ether);
        vm.prank(keeper);
        vm.expectRevert(
            abi.encodeWithSignature(
                "ExitsRequestedExceedAvailableFundedAmount(uint256,uint256,uint256)", 0, 2 * 32 ether, 1 * 32 ether
            )
        );
        reg.requestETHExits(_createExitAllocation(_asArray(0), _asArrayU32(2)));
    }

    /// Asserts that reportExitedETH reverts with ExitedETHArrayShrinking when a shorter array is submitted after a longer one.
    function testReportExitedETHRevertsWhenArrayShrinks() public {
        reg.initOperatorsRegistryV1(admin, river);
        vm.startPrank(admin);
        reg.addOperator("Op0", makeAddr("op0"));
        reg.addOperator("Op1", makeAddr("op1"));
        vm.stopPrank();
        reg.sudoSetFundedV3(0, 5 * 32 ether);
        reg.sudoSetFundedV3(1, 5 * 32 ether);
        reg.sudoSetActiveCLETH(0, 5 * 32 ether);
        reg.sudoSetActiveCLETH(1, 5 * 32 ether);
        reg.sudoSetRawExitedETH(new uint256[](3));
        uint256[] memory first = new uint256[](3);
        first[0] = 2 * 32 ether;
        first[1] = 32 ether;
        first[2] = 32 ether;
        reg.reportExitedETH(first, 10 * 32 ether);
        uint256[] memory shorter = new uint256[](2);
        shorter[0] = 2 * 32 ether;
        shorter[1] = 32 ether;
        vm.expectRevert(abi.encodeWithSignature("ExitedETHArrayShrinking()"));
        reg.reportExitedETH(shorter, 10 * 32 ether);
    }

    /// Asserts that version() returns the expected registry version string.
    function testOperatorsRegistryVersion() public {
        reg.initOperatorsRegistryV1(admin, river);
        assertEq(reg.version(), "1.3.0");
    }

    /// Asserts that the validator-exits state lib wrapper can set and read CurrentValidatorExitsDemand and TotalValidatorExitsRequested.
    function testValidatorExitsStateLibSetters() public {
        ValidatorExitsStateLibWrapper w = new ValidatorExitsStateLibWrapper();
        w.setCurrentValidatorExitsDemand(100);
        assertEq(w.getCurrentValidatorExitsDemand(), 100);
        w.setTotalValidatorExitsRequested(200);
        assertEq(w.getTotalValidatorExitsRequested(), 200);
    }

    function _asArray(uint256 v) internal pure returns (uint256[] memory) {
        uint256[] memory a = new uint256[](1);
        a[0] = v;
        return a;
    }

    function _asArrayU32(uint32 v) internal pure returns (uint32[] memory) {
        uint32[] memory a = new uint32[](1);
        a[0] = v;
        return a;
    }
}
