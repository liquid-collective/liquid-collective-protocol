//SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.33;

import "forge-std/Test.sol";

import "./OperatorAllocationTestBase.sol";
import "../src/libraries/LibBytes.sol";
import "./utils/UserFactory.sol";
import "./utils/BytesGenerator.sol";
import "./utils/LibImplementationUnbricker.sol";

import "../src/OperatorsRegistry.1.sol";

contract OperatorsRegistryInitializableV1 is OperatorsRegistryV1 {
    /// @dev Override to allow tests to call pickNextValidatorsToDeposit without pranking as river
    modifier onlyRiver() override {
        _;
    }

    function sudoSetFunded(uint256 _index, uint32 _funded) external {
        OperatorsV2.Operator storage operator = OperatorsV2.get(_index);
        operator.funded = _funded;
    }

    function sudoSetKeys(uint256 _operatorIndex, uint32 _keyCount) external {
        OperatorsV2.setKeys(_operatorIndex, _keyCount);
    }

    function sudoExitRequests(uint256 _operatorIndex, uint32 _requestedExits) external {
        OperatorsV2.get(_operatorIndex).requestedExits = _requestedExits;
    }

    function sudoStoppedValidatorCounts(uint32[] calldata stoppedValidatorCount, uint256 depositedValidatorCount)
        external
    {
        _setStoppedValidatorCounts(stoppedValidatorCount, depositedValidatorCount);
    }
}

/// @dev Harness that injects a key-count mismatch to test the InvalidKeyCount guard in pickNextValidatorsToDepositFromActiveOperators.
contract OperatorsRegistryMismatchedKeysV1 is OperatorsRegistryV1 {
    modifier onlyRiver() override {
        _;
    }

    function sudoSetFunded(uint256 _index, uint32 _funded) external {
        OperatorsV2.Operator storage operator = OperatorsV2.get(_index);
        operator.funded = _funded;
    }

    function sudoSetKeys(uint256 _operatorIndex, uint32 _keyCount) external {
        OperatorsV2.setKeys(_operatorIndex, _keyCount);
    }

    function _getPerOperatorValidatorKeysForAllocations(OperatorAllocation[] memory _allocations)
        internal
        view
        override
        returns (bytes[][] memory perOperatorKeys, bytes[][] memory perOperatorSigs)
    {
        uint256 len = _allocations.length;
        perOperatorKeys = new bytes[][](len);
        perOperatorSigs = new bytes[][](len);
        for (uint256 i = 0; i < len; ++i) {
            // Return one fewer key than requested to trigger the mismatch guard
            uint256 wrongCount = _allocations[i].validatorCount > 0 ? _allocations[i].validatorCount - 1 : 0;
            perOperatorKeys[i] = new bytes[](wrongCount);
            perOperatorSigs[i] = new bytes[](wrongCount);
        }
    }
}

/// @dev Same as OperatorsRegistryInitializableV1 but does NOT override onlyRiver; use for tests that assert Unauthorized
contract OperatorsRegistryStrictRiverV1 is OperatorsRegistryV1 {
    function sudoSetFunded(uint256 _index, uint32 _funded) external {
        OperatorsV2.Operator storage operator = OperatorsV2.get(_index);
        operator.funded = _funded;
    }

    function sudoSetKeys(uint256 _operatorIndex, uint32 _keyCount) external {
        OperatorsV2.setKeys(_operatorIndex, _keyCount);
    }

    function sudoExitRequests(uint256 _operatorIndex, uint32 _requestedExits) external {
        OperatorsV2.get(_operatorIndex).requestedExits = _requestedExits;
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

    event AddedValidatorKeys(uint256 indexed index, bytes publicKeys);
    event RemovedValidatorKey(uint256 indexed index, bytes publicKey);
    event SetRiver(address indexed river);
    event OperatorLimitUnchanged(uint256 indexed operatorIndex, uint256 limit);
    event OperatorEditsAfterSnapshot(
        uint256 indexed index,
        uint256 currentLimit,
        uint256 newLimit,
        uint256 indexed lastEdit,
        uint256 indexed snapshotBlock
    );

    event SetOperatorLimit(uint256 indexed index, uint256 newLimit);
    event AddedValidatorKeys(uint256 indexed index, uint256 amount);
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

    function testPickNextValidatorsToDepositRevertsWithUnauthorizedWhenNotRiver() public {
        vm.expectRevert(abi.encodeWithSignature("Unauthorized(address)", address(this)));
        operatorsRegistry.pickNextValidatorsToDepositFromActiveOperators(_createAllocation(0, 10));
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

    function testGetKeysAsUnauthorized() public {
        vm.startPrank(admin);
        operatorsRegistry.addOperator("operatorZero", makeAddr("operatorZero"));
        operatorsRegistry.addValidators(0, 10, genBytes((48 + 96) * 10));
        uint256[] memory operators = new uint256[](1);
        uint32[] memory limits = new uint32[](1);
        operators[0] = 0;
        limits[0] = 10;
        operatorsRegistry.setOperatorLimits(operators, limits, block.number);
        vm.stopPrank();

        vm.prank(address(0x123));
        vm.expectRevert(abi.encodeWithSignature("Unauthorized(address)", address(0x123)));
        operatorsRegistry.pickNextValidatorsToDepositFromActiveOperators(_createAllocation(0, 10));
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

    function testForceFundedValidatorKeysEventEmission() public {
        operatorsRegistry.getOperatorCount();
        operatorsRegistry.forceFundedValidatorKeysEventEmission(100);

        bytes32 operatorIndex = vm.load(
            address(operatorsRegistry),
            bytes32(
                uint256(keccak256("river.state.migration.operatorsRegistry.fundedKeyEventRebroadcasting.operatorIndex"))
                    - 1
            )
        );
        assertEq(uint256(operatorIndex), type(uint256).max);
    }

    function testInternalSetKeys(uint256 _nodeOperatorAddressSalt, bytes32 _name, uint32 _keyCount, uint32 _blockRoll)
        public
    {
        address _nodeOperatorAddress = uf._new(_nodeOperatorAddressSalt);
        vm.startPrank(admin);
        uint256 operatorIndex = operatorsRegistry.addOperator(string(abi.encodePacked(_name)), _nodeOperatorAddress);
        OperatorsV2.Operator memory newOperator = operatorsRegistry.getOperator(operatorIndex);
        assert(newOperator.keys == 0);
        assert(newOperator.latestKeysEditBlockNumber == block.number);
        vm.roll(block.number + _blockRoll);
        OperatorsRegistryInitializableV1(address(operatorsRegistry)).sudoSetKeys(0, _keyCount);
        newOperator = operatorsRegistry.getOperator(operatorIndex);
        assert(newOperator.keys == _keyCount);
        assert(newOperator.latestKeysEditBlockNumber == block.number);
    }

    function testAddNodeOperator(uint256 _nodeOperatorAddressSalt, bytes32 _name) public {
        address _nodeOperatorAddress = uf._new(_nodeOperatorAddressSalt);
        vm.startPrank(admin);
        uint256 operatorIndex = operatorsRegistry.addOperator(string(abi.encodePacked(_name)), _nodeOperatorAddress);
        OperatorsV2.Operator memory newOperator = operatorsRegistry.getOperator(operatorIndex);
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

    function testSetOperatorLimitTooHigh(uint256 _nodeOperatorAddressSalt) public {
        address _nodeOperatorAddress = uf._new(_nodeOperatorAddressSalt);
        vm.startPrank(admin);
        operatorsRegistry.addOperator(string(abi.encodePacked(_nodeOperatorAddress)), _nodeOperatorAddress);
        uint256[] memory indexes = new uint256[](1);
        indexes[0] = 0;
        uint32[] memory limits = new uint32[](1);
        limits[0] = 1;
        vm.expectRevert(abi.encodeWithSignature("OperatorLimitTooHigh(uint256,uint256,uint256)", 0, 1, 0));
        operatorsRegistry.setOperatorLimits(indexes, limits, block.number);
        vm.stopPrank();
    }

    function testSetOperatorInvariantChecksSkipped(uint256 _nodeOperatorAddressSalt) public {
        vm.roll(1);
        address _nodeOperatorAddress = uf._new(_nodeOperatorAddressSalt);
        vm.startPrank(admin);
        operatorsRegistry.addOperator(string(abi.encodePacked(_nodeOperatorAddress)), _nodeOperatorAddress);
        uint256[] memory indexes = new uint256[](1);
        indexes[0] = 0;
        uint32[] memory limits = new uint32[](1);
        limits[0] = 1;
        vm.expectEmit(true, true, true, true);
        emit OperatorEditsAfterSnapshot(0, 0, 1, 1, 0);
        operatorsRegistry.setOperatorLimits(indexes, limits, 0);
        vm.stopPrank();
    }

    function testSetOperatorLimitTooLow(uint256 _nodeOperatorAddressSalt) public {
        address _nodeOperatorAddress = uf._new(_nodeOperatorAddressSalt);
        vm.startPrank(admin);
        operatorsRegistry.addOperator(string(abi.encodePacked(_nodeOperatorAddress)), _nodeOperatorAddress);
        vm.stopPrank();
        vm.startPrank(_nodeOperatorAddress);
        operatorsRegistry.addValidators(0, 1, genBytes(48 + 96));
        vm.stopPrank();
        vm.startPrank(admin);
        uint256[] memory indexes = new uint256[](1);
        indexes[0] = 0;
        uint32[] memory limits = new uint32[](1);
        limits[0] = 1;
        operatorsRegistry.setOperatorLimits(indexes, limits, block.number);
        OperatorsRegistryInitializableV1(address(operatorsRegistry)).sudoSetFunded(0, 1);
        limits[0] = 0;
        vm.expectRevert(abi.encodeWithSignature("OperatorLimitTooLow(uint256,uint256,uint256)", 0, 0, 1));
        operatorsRegistry.setOperatorLimits(indexes, limits, block.number);
        vm.stopPrank();
    }

    function testSetOperatorAddressesAsAdmin(bytes32 _name, uint256 _firstAddressSalt, uint256 _secondAddressSalt)
        public
    {
        address _firstAddress = uf._new(_firstAddressSalt);
        address _secondAddress = uf._new(_secondAddressSalt);
        vm.startPrank(admin);
        uint256 index = operatorsRegistry.addOperator(string(abi.encodePacked(_name)), _firstAddress);
        OperatorsV2.Operator memory newOperator = operatorsRegistry.getOperator(index);
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
        OperatorsV2.Operator memory newOperator = operatorsRegistry.getOperator(index);
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
        OperatorsV2.Operator memory newOperator = operatorsRegistry.getOperator(index);
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
        OperatorsV2.Operator memory newOperator = operatorsRegistry.getOperator(index);
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
        OperatorsV2.Operator memory newOperator = operatorsRegistry.getOperator(index);
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
        OperatorsV2.Operator memory newOperator = operatorsRegistry.getOperator(index);
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
        OperatorsV2.Operator memory newOperator = operatorsRegistry.getOperator(index);
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
        OperatorsV2.Operator memory newOperator = operatorsRegistry.getOperator(index);
        assert(keccak256(bytes(newOperator.name)) == keccak256(bytes(string(abi.encodePacked(_name)))));
        vm.startPrank(address(this));
        vm.expectRevert(abi.encodeWithSignature("Unauthorized(address)", address(this)));
        operatorsRegistry.setOperatorName(index, string(abi.encodePacked(_nextName)));
        vm.stopPrank();
    }

    function testSetOperatorStatusAsAdmin(bytes32 _name, uint256 _firstAddressSalt) public {
        address _firstAddress = uf._new(_firstAddressSalt);
        vm.startPrank(admin);
        uint256 index = operatorsRegistry.addOperator(string(abi.encodePacked(_name)), _firstAddress);
        OperatorsV2.Operator memory newOperator = operatorsRegistry.getOperator(index);
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
        OperatorsV2.Operator memory newOperator = operatorsRegistry.getOperator(index);
        assert(newOperator.active == true);
        vm.stopPrank();
        vm.startPrank(address(this));
        vm.expectRevert(abi.encodeWithSignature("Unauthorized(address)", address(this)));
        operatorsRegistry.setOperatorStatus(index, false);
    }

    function testSetOperatorLimitCountAsAdmin(bytes32 _name, uint256 _firstAddressSalt, uint32 _limit) public {
        address _firstAddress = uf._new(_firstAddressSalt);
        _limit = _limit % 11; // 10 is max
        vm.startPrank(admin);
        uint256 index = operatorsRegistry.addOperator(string(abi.encodePacked(_name)), _firstAddress);

        bytes memory tenKeys = genBytes((48 + 96) * 10);

        operatorsRegistry.addValidators(index, 10, tenKeys);

        OperatorsV2.Operator memory newOperator = operatorsRegistry.getOperator(index);
        assert(newOperator.limit == 0);
        uint256[] memory operatorIndexes = new uint256[](1);
        operatorIndexes[0] = index;
        uint32[] memory operatorLimits = new uint32[](1);
        operatorLimits[0] = _limit;
        operatorsRegistry.setOperatorLimits(operatorIndexes, operatorLimits, block.number);
        newOperator = operatorsRegistry.getOperator(index);
        assert(newOperator.limit == _limit);
        operatorLimits[0] = 0;
        operatorsRegistry.setOperatorLimits(operatorIndexes, operatorLimits, block.number);
        newOperator = operatorsRegistry.getOperator(index);
        assert(newOperator.limit == 0);
    }

    function testSetOperatorLimitCountNoOp(bytes32 _name, uint256 _firstAddressSalt, uint32 _limit) public {
        address _firstAddress = uf._new(_firstAddressSalt);
        _limit = _limit % 11; // 10 is max
        vm.assume(_limit > 0);
        vm.startPrank(admin);
        uint256 index = operatorsRegistry.addOperator(string(abi.encodePacked(_name)), _firstAddress);

        bytes memory tenKeys = genBytes((48 + 96) * 10);

        operatorsRegistry.addValidators(index, 10, tenKeys);

        OperatorsV2.Operator memory newOperator = operatorsRegistry.getOperator(index);
        assert(newOperator.limit == 0);
        uint256[] memory operatorIndexes = new uint256[](1);
        operatorIndexes[0] = index;
        uint32[] memory operatorLimits = new uint32[](1);
        operatorLimits[0] = _limit;
        vm.record();
        operatorsRegistry.setOperatorLimits(operatorIndexes, operatorLimits, block.number);
        (, bytes32[] memory writes) = vm.accesses(address(operatorsRegistry));
        assert(writes.length == 1);
        newOperator = operatorsRegistry.getOperator(index);
        assert(newOperator.limit == _limit);
        vm.expectEmit(true, true, true, true);
        emit OperatorLimitUnchanged(0, _limit);
        vm.record();
        operatorsRegistry.setOperatorLimits(operatorIndexes, operatorLimits, block.number);
        (, writes) = vm.accesses(address(operatorsRegistry));
        assert(writes.length == 0);
    }

    function testSetOperatorLimitCountSnapshotTooLow(bytes32 _name, uint256 _firstAddressSalt, uint32 _limit) public {
        address _firstAddress = uf._new(_firstAddressSalt);
        _limit = 1 + _limit % 10; // 10 is max, 1 is min
        vm.startPrank(admin);
        uint256 index = operatorsRegistry.addOperator(string(abi.encodePacked(_name)), _firstAddress);

        bytes memory tenKeys = genBytes((48 + 96) * 10);

        uint256 bn = 1_000_000;
        vm.roll(bn);

        operatorsRegistry.addValidators(index, 10, tenKeys);

        OperatorsV2.Operator memory newOperator = operatorsRegistry.getOperator(index);
        assert(newOperator.limit == 0);
        uint256[] memory operatorIndexes = new uint256[](1);
        operatorIndexes[0] = index;
        uint32[] memory operatorLimits = new uint32[](1);
        operatorLimits[0] = _limit;
        vm.expectEmit(true, true, true, true);
        emit OperatorEditsAfterSnapshot(index, 0, _limit, bn, bn - 1);
        operatorsRegistry.setOperatorLimits(operatorIndexes, operatorLimits, bn - 1);
        newOperator = operatorsRegistry.getOperator(index);
        assert(newOperator.limit == 0);
    }

    function testSetOperatorLimitDecreaseSkipsSnapshotCheck(bytes32 _name, uint256 _firstAddressSalt) public {
        address _firstAddress = uf._new(_firstAddressSalt);
        vm.startPrank(admin);
        uint256 index = operatorsRegistry.addOperator(string(abi.encodePacked(_name)), _firstAddress);

        bytes memory tenKeys = genBytes((48 + 96) * 10);

        uint256 bn = 1_000_000;
        vm.roll(bn);

        operatorsRegistry.addValidators(index, 10, tenKeys);

        OperatorsV2.Operator memory newOperator = operatorsRegistry.getOperator(index);
        assert(newOperator.limit == 0);
        uint256[] memory operatorIndexes = new uint256[](1);
        operatorIndexes[0] = index;
        uint32[] memory operatorLimits = new uint32[](1);
        operatorLimits[0] = 10;
        vm.expectEmit(true, true, true, true);
        emit SetOperatorLimit(index, 10);
        operatorsRegistry.setOperatorLimits(operatorIndexes, operatorLimits, bn);
        newOperator = operatorsRegistry.getOperator(index);
        assert(newOperator.limit == 10);
        operatorLimits[0] = 5;
        vm.expectEmit(true, true, true, true);
        emit SetOperatorLimit(index, 5);
        operatorsRegistry.setOperatorLimits(operatorIndexes, operatorLimits, bn - 1);
        newOperator = operatorsRegistry.getOperator(index);
        assert(newOperator.limit == 5);
    }

    function testSetOperatorLimitCountAsUnauthorized(bytes32 _name, uint256 _firstAddressSalt, uint32 _limit) public {
        address _firstAddress = uf._new(_firstAddressSalt);
        vm.startPrank(admin);
        uint256 index = operatorsRegistry.addOperator(string(abi.encodePacked(_name)), _firstAddress);
        OperatorsV2.Operator memory newOperator = operatorsRegistry.getOperator(index);
        assert(newOperator.limit == 0);
        vm.stopPrank();
        vm.startPrank(address(this));
        uint256[] memory operatorIndexes = new uint256[](1);
        operatorIndexes[0] = index;
        uint32[] memory operatorLimits = new uint32[](1);
        operatorLimits[0] = _limit;
        vm.expectRevert(abi.encodeWithSignature("Unauthorized(address)", address(this)));
        operatorsRegistry.setOperatorLimits(operatorIndexes, operatorLimits, block.number);
    }

    function testSetOperatorLimitUnorderedOperators(
        bytes32 _name,
        uint256 _firstAddressSalt,
        uint256 _secondAddressSalt
    ) public {
        address _firstAddress = uf._new(_firstAddressSalt);
        address _secondAddress = uf._new(_secondAddressSalt);
        vm.startPrank(admin);
        uint256 index0 = operatorsRegistry.addOperator(string(abi.encodePacked(_name)), _firstAddress);
        uint256 index1 = operatorsRegistry.addOperator(string(abi.encodePacked(_name)), _secondAddress);
        uint256[] memory operatorIndexes = new uint256[](2);
        operatorIndexes[0] = index1;
        operatorIndexes[1] = index0;
        uint32[] memory operatorLimits = new uint32[](2);
        operatorLimits[0] = 0;
        operatorLimits[1] = 0;
        vm.expectRevert(abi.encodeWithSignature("UnorderedOperatorList()"));
        operatorsRegistry.setOperatorLimits(operatorIndexes, operatorLimits, block.number);
        vm.stopPrank();
    }

    function testSetOperatorLimitDuplicateOperators(bytes32 _name, uint256 _firstAddressSalt) public {
        address _firstAddress = uf._new(_firstAddressSalt);
        vm.startPrank(admin);
        uint256 index = operatorsRegistry.addOperator(string(abi.encodePacked(_name)), _firstAddress);
        uint256[] memory operatorIndexes = new uint256[](2);
        operatorIndexes[0] = index;
        operatorIndexes[1] = index;
        uint32[] memory operatorLimits = new uint32[](2);
        operatorLimits[0] = 0;
        operatorLimits[1] = 0;
        vm.expectRevert(abi.encodeWithSignature("UnorderedOperatorList()"));
        operatorsRegistry.setOperatorLimits(operatorIndexes, operatorLimits, block.number);
        vm.stopPrank();
    }

    function testAddValidatorsAsOperator(bytes32 _name, uint256 _firstAddressSalt) public {
        address _firstAddress = uf._new(_firstAddressSalt);
        vm.startPrank(admin);
        uint256 index = operatorsRegistry.addOperator(string(abi.encodePacked(_name)), _firstAddress);

        bytes memory tenKeys = genBytes((48 + 96) * 10);

        vm.stopPrank();
        vm.startPrank(_firstAddress);
        vm.expectEmit(true, true, true, true);
        emit AddedValidatorKeys(index, tenKeys);
        operatorsRegistry.addValidators(index, 10, tenKeys);

        OperatorsV2.Operator memory operator = operatorsRegistry.getOperator(index);
        assert(operator.keys == 10);

        (,, bool funded) = operatorsRegistry.getValidator(index, 0);
        assert(funded == false);
        (,, funded) = operatorsRegistry.getValidator(index, 1);
        assert(funded == false);

        OperatorsRegistryInitializableV1(address(operatorsRegistry)).sudoSetFunded(index, 1);

        (,, funded) = operatorsRegistry.getValidator(index, 0);
        assert(funded == true);
        (,, funded) = operatorsRegistry.getValidator(index, 1);
        assert(funded == false);
    }

    function testGetKeysAsRiver(bytes32 _name, uint256 _firstAddressSalt) public {
        address _firstAddress = uf._new(_firstAddressSalt);
        vm.startPrank(admin);
        uint256 index = operatorsRegistry.addOperator(string(abi.encodePacked(_name)), _firstAddress);

        bytes memory tenKeys = genBytes((48 + 96) * 10);

        vm.stopPrank();
        vm.startPrank(_firstAddress);
        operatorsRegistry.addValidators(index, 10, tenKeys);
        vm.stopPrank();

        vm.startPrank(admin);
        uint256[] memory operatorIndexes = new uint256[](1);
        operatorIndexes[0] = index;
        uint32[] memory limits = new uint32[](1);
        limits[0] = 10;
        operatorsRegistry.setOperatorLimits(operatorIndexes, limits, block.number);
        vm.stopPrank();

        vm.startPrank(river);
        (bytes[] memory publicKeys, bytes[] memory signatures) =
            operatorsRegistry.pickNextValidatorsToDepositFromActiveOperators(_createAllocation(index, 10));
        vm.stopPrank();
        assert(publicKeys.length == 10);
        assert(keccak256(publicKeys[0]) == keccak256(LibBytes.slice(tenKeys, 0, 48)));
        assert(keccak256(signatures[0]) == keccak256(LibBytes.slice(tenKeys, 48, 96)));
    }

    function testGetKeysAsRiverLimitTest(bytes32 _name, uint256 _firstAddressSalt) public {
        address _firstAddress = uf._new(_firstAddressSalt);
        vm.startPrank(admin);
        uint256 index = operatorsRegistry.addOperator(string(abi.encodePacked(_name)), _firstAddress);

        bytes memory tenKeys = genBytes((48 + 96) * 10);

        vm.stopPrank();
        vm.startPrank(_firstAddress);
        operatorsRegistry.addValidators(index, 10, tenKeys);
        vm.stopPrank();

        vm.startPrank(admin);
        uint256[] memory operatorIndexes = new uint256[](1);
        operatorIndexes[0] = index;
        uint32[] memory limits = new uint32[](1);
        limits[0] = 5;
        operatorsRegistry.setOperatorLimits(operatorIndexes, limits, block.number);
        vm.stopPrank();

        vm.startPrank(river);
        // Request 10 but limit is 5, so should revert with InvalidOperatorAllocation
        vm.expectRevert(
            abi.encodeWithSignature("OperatorHasInsufficientFundableKeys(uint256,uint256,uint256)", index, 10, 5)
        );
        operatorsRegistry.pickNextValidatorsToDepositFromActiveOperators(_createAllocation(index, 10));
        vm.stopPrank();

        // Request within limit
        vm.startPrank(river);
        (bytes[] memory publicKeys, bytes[] memory signatures) =
            operatorsRegistry.pickNextValidatorsToDepositFromActiveOperators(_createAllocation(index, 5));
        vm.stopPrank();
        assert(publicKeys.length == 5);
        assert(keccak256(publicKeys[0]) == keccak256(LibBytes.slice(tenKeys, 0, 48)));
        assert(keccak256(signatures[0]) == keccak256(LibBytes.slice(tenKeys, 48, 96)));
    }

    function testGetKeysDistribution(uint256 _operatorOneSalt, uint256 _operatorTwoSalt, uint256 _operatorThreeSalt)
        external
    {
        address _operatorOne = uf._new(_operatorOneSalt);
        address _operatorTwo = uf._new(_operatorTwoSalt);
        address _operatorThree = uf._new(_operatorThreeSalt);
        vm.startPrank(admin);
        operatorsRegistry.addOperator(string(abi.encodePacked(_operatorOne)), _operatorOne);
        operatorsRegistry.addOperator(string(abi.encodePacked(_operatorTwo)), _operatorTwo);
        operatorsRegistry.addOperator(string(abi.encodePacked(_operatorThree)), _operatorThree);
        vm.stopPrank();

        assert(operatorsRegistry.getOperatorCount() == 3);

        {
            bytes memory fiftyKeys = genBytes(50 * (48 + 96));

            vm.prank(_operatorOne);
            operatorsRegistry.addValidators(0, 50, fiftyKeys);
        }
        {
            bytes memory fiftyKeys = genBytes(50 * (48 + 96));

            vm.prank(_operatorTwo);
            operatorsRegistry.addValidators(1, 50, fiftyKeys);
        }
        {
            bytes memory fiftyKeys = genBytes(50 * (48 + 96));

            vm.prank(_operatorThree);
            operatorsRegistry.addValidators(2, 50, fiftyKeys);
        }

        uint256[] memory indexes = new uint256[](3);
        indexes[0] = 0;
        indexes[1] = 1;
        indexes[2] = 2;
        uint32[] memory limits = new uint32[](3);
        limits[0] = 50;
        limits[1] = 50;
        limits[2] = 50;
        vm.prank(admin);
        operatorsRegistry.setOperatorLimits(indexes, limits, block.number);

        // Create allocation for 2 validators from each of 3 operators = 6 total
        uint32[] memory allocationCounts = new uint32[](3);
        allocationCounts[0] = 2;
        allocationCounts[1] = 2;
        allocationCounts[2] = 2;
        IOperatorsRegistryV1.OperatorAllocation[] memory allocation = _createMultiAllocation(indexes, allocationCounts);

        vm.prank(river);
        (bytes[] memory publicKeys, bytes[] memory signatures) =
            operatorsRegistry.pickNextValidatorsToDepositFromActiveOperators(allocation);

        assert(publicKeys.length == 6);
        assert(signatures.length == 6);

        {
            OperatorsV2.Operator memory op = operatorsRegistry.getOperator(0);
            assert(op.limit == 50);
            assert(op.funded == 2);
            assert(op.keys == 50);
            assert(op.requestedExits == 0);
        }

        {
            OperatorsV2.Operator memory op = operatorsRegistry.getOperator(1);
            assert(op.limit == 50);
            assert(op.funded == 2);
            assert(op.keys == 50);
            assert(op.requestedExits == 0);
        }

        {
            OperatorsV2.Operator memory op = operatorsRegistry.getOperator(2);
            assert(op.limit == 50);
            assert(op.funded == 2);
            assert(op.keys == 50);
            assert(op.requestedExits == 0);
        }

        // Second allocation: 2 more from each = 6 total
        vm.prank(river);
        (publicKeys, signatures) = operatorsRegistry.pickNextValidatorsToDepositFromActiveOperators(allocation);

        assert(publicKeys.length == 6);
        assert(signatures.length == 6);

        {
            OperatorsV2.Operator memory op = operatorsRegistry.getOperator(0);
            assert(op.limit == 50);
            assert(op.funded == 4);
            assert(op.keys == 50);
            assert(op.requestedExits == 0);
        }

        {
            OperatorsV2.Operator memory op = operatorsRegistry.getOperator(1);
            assert(op.limit == 50);
            assert(op.funded == 4);
            assert(op.keys == 50);
            assert(op.requestedExits == 0);
        }

        {
            OperatorsV2.Operator memory op = operatorsRegistry.getOperator(2);
            assert(op.limit == 50);
            assert(op.funded == 4);
            assert(op.keys == 50);
            assert(op.requestedExits == 0);
        }

        // Third allocation: 20 from each operator = 60 total
        allocationCounts[0] = 20;
        allocationCounts[1] = 20;
        allocationCounts[2] = 20;
        IOperatorsRegistryV1.OperatorAllocation[] memory largeAllocation =
            _createMultiAllocation(indexes, allocationCounts);

        vm.prank(river);
        (publicKeys, signatures) = operatorsRegistry.pickNextValidatorsToDepositFromActiveOperators(largeAllocation);

        assert(publicKeys.length == 60);
        assert(signatures.length == 60);

        {
            OperatorsV2.Operator memory op = operatorsRegistry.getOperator(0);
            assert(op.limit == 50);
            assert(op.funded == 24);
            assert(op.keys == 50);
            assert(op.requestedExits == 0);
        }

        {
            OperatorsV2.Operator memory op = operatorsRegistry.getOperator(1);
            assert(op.funded == 24);
            assert(op.keys == 50);
            assert(op.requestedExits == 0);
        }

        {
            OperatorsV2.Operator memory op = operatorsRegistry.getOperator(2);
            assert(op.limit == 50);
            assert(op.funded == 24);
            assert(op.keys == 50);
            assert(op.requestedExits == 0);
        }

        // Fourth allocation: remaining validators (26 from each = 78 total)
        allocationCounts[0] = 26;
        allocationCounts[1] = 26;
        allocationCounts[2] = 26;
        IOperatorsRegistryV1.OperatorAllocation[] memory finalAllocation =
            _createMultiAllocation(indexes, allocationCounts);

        vm.prank(river);
        (publicKeys, signatures) = operatorsRegistry.pickNextValidatorsToDepositFromActiveOperators(finalAllocation);

        assert(publicKeys.length == 78);
        assert(signatures.length == 78);

        {
            OperatorsV2.Operator memory op = operatorsRegistry.getOperator(0);
            assert(op.limit == 50);
            assert(op.funded == 50);
            assert(op.keys == 50);
            assert(op.requestedExits == 0);
        }

        {
            OperatorsV2.Operator memory op = operatorsRegistry.getOperator(1);
            assert(op.limit == 50);
            assert(op.funded == 50);
            assert(op.keys == 50);
            assert(op.requestedExits == 0);
        }

        {
            OperatorsV2.Operator memory op = operatorsRegistry.getOperator(2);
            assert(op.limit == 50);
            assert(op.funded == 50);
            assert(op.keys == 50);
            assert(op.requestedExits == 0);
        }
    }

    function testGetAllActiveOperators(bytes32 _name, uint256 _firstAddressSalt, uint256 _count) public {
        vm.assume(_count < 1000);
        address[] memory _firstAddress = new address[](_count);
        _firstAddress = uf._newMulti(_firstAddressSalt, _count);
        vm.startPrank(admin);
        for (uint256 i; i < _count; i++) {
            operatorsRegistry.addOperator(string(abi.encodePacked(_name)), _firstAddress[i]);
        }

        OperatorsV2.Operator[] memory operators = operatorsRegistry.listActiveOperators();

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
        for (uint256 i; i < _count; i++) {
            vm.startPrank(admin);
            uint256 index = operatorsRegistry.addOperator(string(abi.encodePacked(_name)), _firstAddress[i]);

            operatorsRegistry.setOperatorStatus(index, false);
        }

        OperatorsV2.Operator[] memory operators = operatorsRegistry.listActiveOperators();

        assert(operators.length == 0);
    }

    function testPickKeysAsRiverNoKeys() public {
        // Create an allocation for an operator that doesn't exist or has no keys
        // This should succeed but return empty arrays since count is 0 for non-existent operators
        vm.prank(admin);
        operatorsRegistry.addOperator("operatorZero", makeAddr("operatorZero"));
        IOperatorsRegistryV1.OperatorAllocation[] memory allocation = new IOperatorsRegistryV1.OperatorAllocation[](1);
        allocation[0] = IOperatorsRegistryV1.OperatorAllocation({operatorIndex: 0, validatorCount: 10});
        vm.prank(river);
        vm.expectRevert(
            abi.encodeWithSignature("OperatorHasInsufficientFundableKeys(uint256,uint256,uint256)", 0, 10, 0)
        );
        operatorsRegistry.pickNextValidatorsToDepositFromActiveOperators(allocation);
    }

    function testAddValidatorsAsAdmin(bytes32 _name, uint256 _firstAddressSalt) public {
        address _firstAddress = uf._new(_firstAddressSalt);
        vm.startPrank(admin);
        uint256 index = operatorsRegistry.addOperator(string(abi.encodePacked(_name)), _firstAddress);

        bytes memory tenKeys = genBytes((48 + 96) * 10);

        vm.expectEmit(true, true, true, true);
        emit AddedValidatorKeys(index, tenKeys);
        operatorsRegistry.addValidators(index, 10, tenKeys);

        OperatorsV2.Operator memory operator = operatorsRegistry.getOperator(index);
        assert(operator.keys == 10);
    }

    function testAddValidatorsAsAdminUnknownOperator(uint256 _index) public {
        vm.startPrank(admin);

        bytes memory tenKeys = genBytes((48 + 96) * 10);

        vm.expectRevert(abi.encodeWithSignature("OperatorNotFound(uint256)", _index));
        operatorsRegistry.addValidators(_index, 10, tenKeys);
    }

    function testAddValidatorsAsUnauthorized(bytes32 _name, uint256 _firstAddressSalt) public {
        address _firstAddress = uf._new(_firstAddressSalt);
        vm.startPrank(admin);
        uint256 index = operatorsRegistry.addOperator(string(abi.encodePacked(_name)), _firstAddress);

        bytes memory tenKeys = genBytes((48 + 96) * 10);

        vm.stopPrank();
        vm.startPrank(address(this));
        vm.expectRevert(abi.encodeWithSignature("Unauthorized(address)", address(this)));
        operatorsRegistry.addValidators(index, 10, tenKeys);
    }

    function testAddValidatorsInvalidKeySize(bytes32 _name, uint256 _firstAddressSalt) public {
        address _firstAddress = uf._new(_firstAddressSalt);
        vm.startPrank(admin);
        uint256 index = operatorsRegistry.addOperator(string(abi.encodePacked(_name)), _firstAddress);

        bytes memory tenKeys = genBytes((48 + 96) * 9);

        vm.expectRevert(abi.encodeWithSignature("InvalidKeysLength()"));
        operatorsRegistry.addValidators(index, 10, tenKeys);
    }

    function testAddValidatorsInvalidCount(bytes32 _name, uint256 _firstAddressSalt) public {
        address _firstAddress = uf._new(_firstAddressSalt);
        vm.startPrank(admin);
        uint256 index = operatorsRegistry.addOperator(string(abi.encodePacked(_name)), _firstAddress);
        vm.expectRevert(abi.encodeWithSignature("InvalidKeyCount()"));
        operatorsRegistry.addValidators(index, 0, "");
    }

    function testRemoveValidatorsAsOperator(bytes32 _name, uint256 _firstAddressSalt) public {
        address _firstAddress = uf._new(_firstAddressSalt);
        vm.startPrank(admin);
        uint256 index = operatorsRegistry.addOperator(string(abi.encodePacked(_name)), _firstAddress);

        bytes memory tenKeys = genBytes((48 + 96) * 10);

        vm.stopPrank();
        vm.startPrank(_firstAddress);
        operatorsRegistry.addValidators(index, 10, tenKeys);

        OperatorsV2.Operator memory operator = operatorsRegistry.getOperator(index);
        assert(operator.keys == 10);

        uint256[] memory indexes = new uint256[](10);

        indexes[0] = 9;
        indexes[1] = 8;
        indexes[2] = 7;
        indexes[3] = 6;
        indexes[4] = 5;
        indexes[5] = 4;
        indexes[6] = 3;
        indexes[7] = 2;
        indexes[8] = 1;
        indexes[9] = 0;

        vm.expectEmit(true, true, true, true);
        emit RemovedValidatorKey(index, LibBytes.slice(tenKeys, 0, 48));
        operatorsRegistry.removeValidators(index, indexes);
        operator = operatorsRegistry.getOperator(index);
        assert(operator.keys == 0);
        assert(operator.limit == 0);

        operatorsRegistry.addValidators(index, 10, tenKeys);
        operator = operatorsRegistry.getOperator(index);
        assert(operator.keys == 10);
    }

    function testRemoveHalfValidatorsEvenCaseAsOperator(bytes32 _name, uint256 _firstAddressSalt) public {
        address _firstAddress = uf._new(_firstAddressSalt);
        vm.startPrank(admin);
        uint256 index = operatorsRegistry.addOperator(string(abi.encodePacked(_name)), _firstAddress);

        bytes memory tenKeys = genBytes((48 + 96) * 10);

        vm.stopPrank();
        vm.startPrank(_firstAddress);
        operatorsRegistry.addValidators(index, 10, tenKeys);
        vm.stopPrank();
        vm.startPrank(admin);
        uint256[] memory operators = new uint256[](1);
        uint32[] memory limits = new uint32[](1);
        operators[0] = index;
        limits[0] = 10;
        operatorsRegistry.setOperatorLimits(operators, limits, block.number);
        vm.stopPrank();
        vm.startPrank(_firstAddress);

        OperatorsV2.Operator memory operator = operatorsRegistry.getOperator(index);
        assert(operator.keys == 10);

        uint256[] memory indexes = new uint256[](5);

        indexes[0] = 8;
        indexes[1] = 6;
        indexes[2] = 4;
        indexes[3] = 2;
        indexes[4] = 0;

        vm.expectEmit(true, true, true, true);
        emit RemovedValidatorKey(index, LibBytes.slice(tenKeys, 0, 48));
        operatorsRegistry.removeValidators(index, indexes);
        operator = operatorsRegistry.getOperator(index);
        assert(operator.keys == 5);
        assert(operator.limit == 5);

        operatorsRegistry.addValidators(index, 10, tenKeys);
        operator = operatorsRegistry.getOperator(index);
        assert(operator.keys == 15);
    }

    function testRemoveHalfValidatorsConservativeCaseAsOperator(bytes32 _name, uint256 _firstAddressSalt) public {
        address _firstAddress = uf._new(_firstAddressSalt);
        vm.startPrank(admin);
        uint256 index = operatorsRegistry.addOperator(string(abi.encodePacked(_name)), _firstAddress);

        bytes memory tenKeys = genBytes((48 + 96) * 10);

        vm.stopPrank();
        vm.startPrank(_firstAddress);
        operatorsRegistry.addValidators(index, 10, tenKeys);
        vm.stopPrank();
        vm.startPrank(admin);
        uint256[] memory operators = new uint256[](1);
        uint32[] memory limits = new uint32[](1);
        operators[0] = index;
        limits[0] = 8;
        operatorsRegistry.setOperatorLimits(operators, limits, block.number);
        vm.stopPrank();
        vm.startPrank(_firstAddress);

        OperatorsV2.Operator memory operator = operatorsRegistry.getOperator(index);
        assert(operator.keys == 10);

        uint256[] memory indexes = new uint256[](5);

        indexes[0] = 8;
        indexes[1] = 6;
        indexes[2] = 4;
        indexes[3] = 2;
        indexes[4] = 0;

        vm.expectEmit(true, true, true, true);
        emit RemovedValidatorKey(index, LibBytes.slice(tenKeys, 0, 48));
        operatorsRegistry.removeValidators(index, indexes);
        operator = operatorsRegistry.getOperator(index);
        assert(operator.keys == 5);
        assert(operator.limit == 0);

        operatorsRegistry.addValidators(index, 10, tenKeys);
        operator = operatorsRegistry.getOperator(index);
        assert(operator.keys == 15);
    }

    function testRemoveValidatorsAsAdmin(bytes32 _name, uint256 _firstAddressSalt) public {
        address _firstAddress = uf._new(_firstAddressSalt);
        vm.startPrank(admin);
        uint256 index = operatorsRegistry.addOperator(string(abi.encodePacked(_name)), _firstAddress);

        bytes memory tenKeys = genBytes((48 + 96) * 10);

        operatorsRegistry.addValidators(index, 10, tenKeys);

        OperatorsV2.Operator memory operator = operatorsRegistry.getOperator(index);
        assert(operator.keys == 10);

        uint256[] memory indexes = new uint256[](10);

        indexes[0] = 9;
        indexes[1] = 8;
        indexes[2] = 7;
        indexes[3] = 6;
        indexes[4] = 5;
        indexes[5] = 4;
        indexes[6] = 3;
        indexes[7] = 2;
        indexes[8] = 1;
        indexes[9] = 0;

        operatorsRegistry.removeValidators(index, indexes);
        operator = operatorsRegistry.getOperator(index);
        assert(operator.keys == 0);

        operatorsRegistry.addValidators(index, 10, tenKeys);
        operator = operatorsRegistry.getOperator(index);
        assert(operator.keys == 10);
    }

    function testRemoveValidatorsUnauthorized(bytes32 _name, uint256 _firstAddressSalt) public {
        address _firstAddress = uf._new(_firstAddressSalt);
        vm.startPrank(admin);
        uint256 index = operatorsRegistry.addOperator(string(abi.encodePacked(_name)), _firstAddress);

        bytes memory tenKeys = genBytes((48 + 96) * 10);

        operatorsRegistry.addValidators(index, 10, tenKeys);

        OperatorsV2.Operator memory operator = operatorsRegistry.getOperator(index);
        assert(operator.keys == 10);

        uint256[] memory indexes = new uint256[](10);

        indexes[0] = 9;
        indexes[1] = 8;
        indexes[2] = 7;
        indexes[3] = 6;
        indexes[4] = 5;
        indexes[5] = 4;
        indexes[6] = 3;
        indexes[7] = 2;
        indexes[8] = 1;
        indexes[9] = 0;

        vm.stopPrank();
        vm.startPrank(address(this));

        vm.expectRevert(abi.encodeWithSignature("Unauthorized(address)", address(this)));
        operatorsRegistry.removeValidators(index, indexes);
    }

    function testRemoveValidatorsAndRetrieveAsAdmin(bytes32 _name, uint256 _firstAddressSalt) public {
        address _firstAddress = uf._new(_firstAddressSalt);
        vm.startPrank(admin);
        uint256 index = operatorsRegistry.addOperator(string(abi.encodePacked(_name)), _firstAddress);

        bytes memory tenKeys = genBytes((48 + 96) * 10);

        operatorsRegistry.addValidators(index, 10, tenKeys);

        OperatorsV2.Operator memory operator = operatorsRegistry.getOperator(index);
        assert(operator.keys == 10);

        uint256[] memory indexes = new uint256[](1);

        indexes[0] = 0;

        (bytes memory pk, bytes memory s,) = operatorsRegistry.getValidator(index, 9);

        operatorsRegistry.removeValidators(index, indexes);
        operator = operatorsRegistry.getOperator(index);
        assert(operator.keys == 9);
        (bytes memory pkAfter, bytes memory sAfter,) = operatorsRegistry.getValidator(index, 0);

        assert(keccak256(pkAfter) == keccak256(pk));
        assert(keccak256(sAfter) == keccak256(s));
    }

    function testRemoveValidatorsFundedKeyRemovalAttempt(bytes32 _name, uint256 _firstAddressSalt) public {
        address _firstAddress = uf._new(_firstAddressSalt);
        vm.startPrank(admin);
        uint256 index = operatorsRegistry.addOperator(string(abi.encodePacked(_name)), _firstAddress);

        bytes memory tenKeys = genBytes((48 + 96) * 10);

        operatorsRegistry.addValidators(index, 10, tenKeys);

        OperatorsV2.Operator memory operator = operatorsRegistry.getOperator(index);
        assert(operator.keys == 10);

        uint256[] memory indexes = new uint256[](10);

        indexes[0] = 9;
        indexes[1] = 8;
        indexes[2] = 7;
        indexes[3] = 6;
        indexes[4] = 5;
        indexes[5] = 4;
        indexes[6] = 3;
        indexes[7] = 2;
        indexes[8] = 1;
        indexes[9] = 0;

        OperatorsRegistryInitializableV1(address(operatorsRegistry)).sudoSetFunded(index, 10);

        vm.expectRevert(abi.encodeWithSignature("InvalidFundedKeyDeletionAttempt()"));
        operatorsRegistry.removeValidators(index, indexes);
    }

    function testRemoveValidatorsKeyOutOfBounds(bytes32 _name, uint256 _firstAddressSalt) public {
        address _firstAddress = uf._new(_firstAddressSalt);
        vm.startPrank(admin);
        uint256 index = operatorsRegistry.addOperator(string(abi.encodePacked(_name)), _firstAddress);

        bytes memory tenKeys = genBytes((48 + 96) * 10);

        operatorsRegistry.addValidators(index, 10, tenKeys);

        OperatorsV2.Operator memory operator = operatorsRegistry.getOperator(index);
        assert(operator.keys == 10);

        uint256[] memory indexes = new uint256[](10);

        indexes[0] = 10;
        indexes[1] = 8;
        indexes[2] = 7;
        indexes[3] = 6;
        indexes[4] = 5;
        indexes[5] = 4;
        indexes[6] = 3;
        indexes[7] = 2;
        indexes[8] = 1;
        indexes[9] = 0;

        vm.expectRevert(abi.encodeWithSignature("InvalidIndexOutOfBounds()"));
        operatorsRegistry.removeValidators(index, indexes);
    }

    function testRemoveValidatorsUnsortedIndexes(bytes32 _name, uint256 _firstAddressSalt) public {
        address _firstAddress = uf._new(_firstAddressSalt);
        vm.startPrank(admin);
        uint256 index = operatorsRegistry.addOperator(string(abi.encodePacked(_name)), _firstAddress);

        bytes memory tenKeys = genBytes((48 + 96) * 10);

        operatorsRegistry.addValidators(index, 10, tenKeys);

        OperatorsV2.Operator memory operator = operatorsRegistry.getOperator(index);
        assert(operator.keys == 10);

        uint256[] memory indexes = new uint256[](10);

        indexes[0] = 9;
        indexes[1] = 1;
        indexes[2] = 7;
        indexes[3] = 6;
        indexes[4] = 5;
        indexes[5] = 4;
        indexes[6] = 3;
        indexes[7] = 2;
        indexes[8] = 1;
        indexes[9] = 0;

        vm.expectRevert(abi.encodeWithSignature("InvalidUnsortedIndexes()"));
        operatorsRegistry.removeValidators(index, indexes);
    }

    function testRemoveValidatorFail() public {
        vm.startPrank(admin);
        uint256 index;
        uint256[] memory indexes = new uint256[](0);
        vm.expectRevert(abi.encodeWithSignature("InvalidKeyCount()"));
        operatorsRegistry.removeValidators(index, indexes);
    }

    function testGetOperator(bytes32 _name, uint256 _firstAddressSalt) public {
        address _firstAddress = uf._new(_firstAddressSalt);
        vm.startPrank(admin);
        uint256 index = operatorsRegistry.addOperator(string(abi.encodePacked(_name)), _firstAddress);

        OperatorsV2.Operator memory operator = operatorsRegistry.getOperator(index);
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

    /// @dev Allocation to an inactive operator reverts with InactiveOperator
    function testAllocationToInactiveOperatorReverts() public {
        address opAddr = uf._new(0);
        vm.startPrank(admin);
        uint256 index = operatorsRegistry.addOperator("op", opAddr);
        vm.stopPrank();

        bytes memory tenKeys = genBytes(10 * (48 + 96));
        vm.prank(opAddr);
        operatorsRegistry.addValidators(index, 10, tenKeys);
        vm.prank(admin);
        uint256[] memory indexes = new uint256[](1);
        indexes[0] = index;
        uint32[] memory limits = new uint32[](1);
        limits[0] = 10;
        operatorsRegistry.setOperatorLimits(indexes, limits, block.number);

        vm.prank(admin);
        operatorsRegistry.setOperatorStatus(index, false);

        vm.expectRevert(abi.encodeWithSignature("InactiveOperator(uint256)", index));
        operatorsRegistry.getNextValidatorsToDepositFromActiveOperators(_createAllocation(index, 5));
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
            if (stoppedValidatorCounts[idx] > 0) {
                vm.prank(admin);
                operatorsRegistry.addValidators(
                    idx - 1, stoppedValidatorCounts[idx], genBytes((48 + 96) * stoppedValidatorCounts[idx])
                );
            }
            limits[idx - 1] = stoppedValidatorCounts[idx];
            operators[idx - 1] = idx - 1;
        }

        vm.prank(admin);
        operatorsRegistry.setOperatorLimits(operators, limits, block.number);

        OperatorsRegistryInitializableV1(address(operatorsRegistry))
            .pickNextValidatorsToDepositFromActiveOperators(_createMultiAllocation(operators, limits));

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
            if (stoppedValidators[idx] > 0) {
                vm.prank(admin);
                operatorsRegistry.addValidators(
                    idx - 1, stoppedValidators[idx], genBytes((48 + 96) * stoppedValidators[idx])
                );
            }
            limits[idx - 1] = stoppedValidators[idx];
            operators[idx - 1] = idx - 1;
        }

        vm.prank(admin);
        operatorsRegistry.setOperatorLimits(operators, limits, block.number);

        OperatorsRegistryInitializableV1(address(operatorsRegistry))
            .pickNextValidatorsToDepositFromActiveOperators(_createMultiAllocation(operators, limits));

        stoppedValidators[0] -= 1;

        vm.prank(river);
        vm.expectRevert(abi.encodeWithSignature("InvalidStoppedValidatorCountsSum()"));
        operatorsRegistry.reportStoppedValidatorCounts(stoppedValidators, 0);
    }

    // Tests to improve branch coverage of _updateCountOfPickedValidatorsForEachOperator
    // These ensure the loop iterates past non-matching operators before finding the target

    function testPickValidatorsFromSecondOperatorOnly(
        uint256 _operatorOneSalt,
        uint256 _operatorTwoSalt,
        uint256 _operatorThreeSalt
    ) public {
        // Setup: Add 3 operators with keys and limits
        address _operatorOne = uf._new(_operatorOneSalt);
        address _operatorTwo = uf._new(_operatorTwoSalt);
        address _operatorThree = uf._new(_operatorThreeSalt);
        vm.startPrank(admin);
        operatorsRegistry.addOperator(string(abi.encodePacked(_operatorOne)), _operatorOne);
        operatorsRegistry.addOperator(string(abi.encodePacked(_operatorTwo)), _operatorTwo);
        operatorsRegistry.addOperator(string(abi.encodePacked(_operatorThree)), _operatorThree);
        vm.stopPrank();

        assertEq(operatorsRegistry.getOperatorCount(), 3);

        bytes memory tenKeys = genBytes(10 * (48 + 96));

        vm.prank(_operatorOne);
        operatorsRegistry.addValidators(0, 10, tenKeys);

        vm.prank(_operatorTwo);
        operatorsRegistry.addValidators(1, 10, tenKeys);

        vm.prank(_operatorThree);
        operatorsRegistry.addValidators(2, 10, tenKeys);

        uint256[] memory indexes = new uint256[](3);
        indexes[0] = 0;
        indexes[1] = 1;
        indexes[2] = 2;
        uint32[] memory limits = new uint32[](3);
        limits[0] = 10;
        limits[1] = 10;
        limits[2] = 10;
        vm.prank(admin);
        operatorsRegistry.setOperatorLimits(indexes, limits, block.number);

        // Allocate ONLY to operator 1 (not the first fundable operator)
        // This forces the loop to iterate past operator 0 before finding operator 1
        vm.prank(river);
        (bytes[] memory publicKeys, bytes[] memory signatures) =
            operatorsRegistry.pickNextValidatorsToDepositFromActiveOperators(_createAllocation(1, 5));

        assertEq(publicKeys.length, 5);
        assertEq(signatures.length, 5);

        // Verify only operator 1 was funded
        assertEq(operatorsRegistry.getOperator(0).funded, 0);
        assertEq(operatorsRegistry.getOperator(1).funded, 5);
        assertEq(operatorsRegistry.getOperator(2).funded, 0);
    }

    function testPickValidatorsFromLastOperatorOnly(
        uint256 _operatorOneSalt,
        uint256 _operatorTwoSalt,
        uint256 _operatorThreeSalt
    ) public {
        // Setup: Add 3 operators with keys and limits
        address _operatorOne = uf._new(_operatorOneSalt);
        address _operatorTwo = uf._new(_operatorTwoSalt);
        address _operatorThree = uf._new(_operatorThreeSalt);
        vm.startPrank(admin);
        operatorsRegistry.addOperator(string(abi.encodePacked(_operatorOne)), _operatorOne);
        operatorsRegistry.addOperator(string(abi.encodePacked(_operatorTwo)), _operatorTwo);
        operatorsRegistry.addOperator(string(abi.encodePacked(_operatorThree)), _operatorThree);
        vm.stopPrank();

        assertEq(operatorsRegistry.getOperatorCount(), 3);

        bytes memory tenKeys = genBytes(10 * (48 + 96));

        vm.prank(_operatorOne);
        operatorsRegistry.addValidators(0, 10, tenKeys);

        vm.prank(_operatorTwo);
        operatorsRegistry.addValidators(1, 10, tenKeys);

        vm.prank(_operatorThree);
        operatorsRegistry.addValidators(2, 10, tenKeys);

        uint256[] memory indexes = new uint256[](3);
        indexes[0] = 0;
        indexes[1] = 1;
        indexes[2] = 2;
        uint32[] memory limits = new uint32[](3);
        limits[0] = 10;
        limits[1] = 10;
        limits[2] = 10;
        vm.prank(admin);
        operatorsRegistry.setOperatorLimits(indexes, limits, block.number);

        // Allocate ONLY to operator 2 (the last fundable operator)
        // This forces the loop to iterate past operators 0 and 1
        vm.prank(river);
        (bytes[] memory publicKeys, bytes[] memory signatures) =
            operatorsRegistry.pickNextValidatorsToDepositFromActiveOperators(_createAllocation(2, 5));

        assertEq(publicKeys.length, 5);
        assertEq(signatures.length, 5);

        // Verify only operator 2 was funded
        assertEq(operatorsRegistry.getOperator(0).funded, 0);
        assertEq(operatorsRegistry.getOperator(1).funded, 0);
        assertEq(operatorsRegistry.getOperator(2).funded, 5);
    }

    function testGetNextValidatorsFromNonFirstOperator(
        uint256 _operatorOneSalt,
        uint256 _operatorTwoSalt,
        uint256 _operatorThreeSalt
    ) public {
        // Setup: Add 3 operators with keys and limits
        address _operatorOne = uf._new(_operatorOneSalt);
        address _operatorTwo = uf._new(_operatorTwoSalt);
        address _operatorThree = uf._new(_operatorThreeSalt);
        vm.startPrank(admin);
        operatorsRegistry.addOperator(string(abi.encodePacked(_operatorOne)), _operatorOne);
        operatorsRegistry.addOperator(string(abi.encodePacked(_operatorTwo)), _operatorTwo);
        operatorsRegistry.addOperator(string(abi.encodePacked(_operatorThree)), _operatorThree);
        vm.stopPrank();

        assertEq(operatorsRegistry.getOperatorCount(), 3);

        bytes memory tenKeys = genBytes(10 * (48 + 96));

        vm.prank(_operatorOne);
        operatorsRegistry.addValidators(0, 10, tenKeys);

        vm.prank(_operatorTwo);
        operatorsRegistry.addValidators(1, 10, tenKeys);

        vm.prank(_operatorThree);
        operatorsRegistry.addValidators(2, 10, tenKeys);

        uint256[] memory indexes = new uint256[](3);
        indexes[0] = 0;
        indexes[1] = 1;
        indexes[2] = 2;
        uint32[] memory limits = new uint32[](3);
        limits[0] = 10;
        limits[1] = 10;
        limits[2] = 10;
        vm.prank(admin);
        operatorsRegistry.setOperatorLimits(indexes, limits, block.number);

        // Test the view function with allocation to operator 2 only
        // This also exercises _updateCountOfPickedValidatorsForEachOperator
        IOperatorsRegistryV1.OperatorAllocation[] memory allocation = new IOperatorsRegistryV1.OperatorAllocation[](1);
        allocation[0] = IOperatorsRegistryV1.OperatorAllocation({operatorIndex: 2, validatorCount: 5});

        (bytes[] memory publicKeys, bytes[] memory signatures) =
            operatorsRegistry.getNextValidatorsToDepositFromActiveOperators(allocation);

        assertEq(publicKeys.length, 5);
        assertEq(signatures.length, 5);
    }

    // Deterministic test to ensure full branch coverage of the operator lookup loop
    // This test uses fixed addresses (not fuzzed) to ensure consistent coverage
    function testPickValidatorsIteratesLoopCorrectly() public {
        // Setup 3 operators with specific addresses (not fuzzed)
        address op0 = makeAddr("operator0");
        address op1 = makeAddr("operator1");
        address op2 = makeAddr("operator2");

        vm.startPrank(admin);
        operatorsRegistry.addOperator("Operator 0", op0);
        operatorsRegistry.addOperator("Operator 1", op1);
        operatorsRegistry.addOperator("Operator 2", op2);
        vm.stopPrank();

        assertEq(operatorsRegistry.getOperatorCount(), 3);

        bytes memory tenKeys = genBytes(10 * (48 + 96));

        vm.prank(op0);
        operatorsRegistry.addValidators(0, 10, tenKeys);
        vm.prank(op1);
        operatorsRegistry.addValidators(1, 10, tenKeys);
        vm.prank(op2);
        operatorsRegistry.addValidators(2, 10, tenKeys);

        uint256[] memory indexes = new uint256[](3);
        indexes[0] = 0;
        indexes[1] = 1;
        indexes[2] = 2;
        uint32[] memory limits = new uint32[](3);
        limits[0] = 10;
        limits[1] = 10;
        limits[2] = 10;
        vm.prank(admin);
        operatorsRegistry.setOperatorLimits(indexes, limits, block.number);

        // Test 1: Allocate to operator 2 only (forces loop to iterate twice with false before true)
        vm.prank(river);
        (bytes[] memory publicKeys, bytes[] memory signatures) =
            operatorsRegistry.pickNextValidatorsToDepositFromActiveOperators(_createAllocation(2, 3));
        assertEq(publicKeys.length, 3);
        assertEq(signatures.length, 3);
        assertEq(operatorsRegistry.getOperator(0).funded, 0);
        assertEq(operatorsRegistry.getOperator(1).funded, 0);
        assertEq(operatorsRegistry.getOperator(2).funded, 3);

        // Test 2: Now allocate to operator 1 (forces loop to iterate once with false before true)
        vm.prank(river);
        (publicKeys, signatures) =
            operatorsRegistry.pickNextValidatorsToDepositFromActiveOperators(_createAllocation(1, 2));
        assertEq(publicKeys.length, 2);
        assertEq(signatures.length, 2);
        assertEq(operatorsRegistry.getOperator(0).funded, 0);
        assertEq(operatorsRegistry.getOperator(1).funded, 2);
        assertEq(operatorsRegistry.getOperator(2).funded, 3);

        // Test 3: Allocate to operator 0 (first match, no false iterations needed)
        vm.prank(river);
        (publicKeys, signatures) =
            operatorsRegistry.pickNextValidatorsToDepositFromActiveOperators(_createAllocation(0, 1));
        assertEq(publicKeys.length, 1);
        assertEq(signatures.length, 1);
        assertEq(operatorsRegistry.getOperator(0).funded, 1);
        assertEq(operatorsRegistry.getOperator(1).funded, 2);
        assertEq(operatorsRegistry.getOperator(2).funded, 3);
    }

    // Additional deterministic test for the view function
    function testGetNextValidatorsIteratesLoopCorrectly() public {
        address op0 = makeAddr("operator0");
        address op1 = makeAddr("operator1");
        address op2 = makeAddr("operator2");

        vm.startPrank(admin);
        operatorsRegistry.addOperator("Operator 0", op0);
        operatorsRegistry.addOperator("Operator 1", op1);
        operatorsRegistry.addOperator("Operator 2", op2);
        vm.stopPrank();

        bytes memory tenKeys = genBytes(10 * (48 + 96));

        vm.prank(op0);
        operatorsRegistry.addValidators(0, 10, tenKeys);
        vm.prank(op1);
        operatorsRegistry.addValidators(1, 10, tenKeys);
        vm.prank(op2);
        operatorsRegistry.addValidators(2, 10, tenKeys);

        uint256[] memory indexes = new uint256[](3);
        indexes[0] = 0;
        indexes[1] = 1;
        indexes[2] = 2;
        uint32[] memory limits = new uint32[](3);
        limits[0] = 10;
        limits[1] = 10;
        limits[2] = 10;
        vm.prank(admin);
        operatorsRegistry.setOperatorLimits(indexes, limits, block.number);

        // Test with allocation to operator 2 using the view function
        IOperatorsRegistryV1.OperatorAllocation[] memory allocation = new IOperatorsRegistryV1.OperatorAllocation[](1);
        allocation[0] = IOperatorsRegistryV1.OperatorAllocation({operatorIndex: 2, validatorCount: 5});

        (bytes[] memory publicKeys, bytes[] memory signatures) =
            operatorsRegistry.getNextValidatorsToDepositFromActiveOperators(allocation);
        assertEq(publicKeys.length, 5);
        assertEq(signatures.length, 5);

        // Test with allocation to operator 1 using the view function
        allocation[0] = IOperatorsRegistryV1.OperatorAllocation({operatorIndex: 1, validatorCount: 3});
        (publicKeys, signatures) = operatorsRegistry.getNextValidatorsToDepositFromActiveOperators(allocation);
        assertEq(publicKeys.length, 3);
        assertEq(signatures.length, 3);

        // Test with allocation to operator 0 using the view function
        allocation[0] = IOperatorsRegistryV1.OperatorAllocation({operatorIndex: 0, validatorCount: 2});
        (publicKeys, signatures) = operatorsRegistry.getNextValidatorsToDepositFromActiveOperators(allocation);
        assertEq(publicKeys.length, 2);
        assertEq(signatures.length, 2);
    }
}

contract OperatorsRegistryV1TestDistribution is OperatorAllocationTestBase {
    UserFactory internal uf = new UserFactory();

    OperatorsRegistryV1 internal operatorsRegistry;
    address internal admin;
    address internal river;
    string internal firstName = "Operator One";
    string internal secondName = "Operator Two";
    address internal operatorOne;
    address internal operatorTwo;
    address internal operatorThree;
    address internal operatorFour;
    address internal operatorFive;
    address internal keeper;

    event AddedValidatorKeys(uint256 indexed index, bytes publicKeys);
    event RemovedValidatorKey(uint256 indexed index, bytes publicKey);
    event RequestedValidatorExits(uint256 indexed index, uint256 count);
    event FundedValidatorKeys(uint256 indexed index, bytes[] publicKeys, bool deferred);

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

        operatorOne = makeAddr("operatorOne");
        operatorTwo = makeAddr("operatorTwo");
        operatorThree = makeAddr("operatorThree");
        operatorFour = makeAddr("operatorFour");
        operatorFive = makeAddr("operatorFive");

        operatorsRegistry = new OperatorsRegistryInitializableV1();
        LibImplementationUnbricker.unbrick(vm, address(operatorsRegistry));
        operatorsRegistry.initOperatorsRegistryV1(admin, river);

        vm.startPrank(admin);
        operatorsRegistry.addOperator("operatorOne", operatorOne);
        operatorsRegistry.addOperator("operatorTwo", operatorTwo);
        operatorsRegistry.addOperator("operatorThree", operatorThree);
        operatorsRegistry.addOperator("operatorFour", operatorFour);
        operatorsRegistry.addOperator("operatorFive", operatorFive);
        vm.stopPrank();
    }

    /// @notice Multiple active operators with an inactive operator in the middle; allocation only to active ops
    /// @dev Allocation [op0, op2] with op1 inactive must succeed and return keys from op0 and op2 only
    function testPickNextValidatorsToDepositSucceedsWithInactiveOperatorInMiddle() public {
        address op0 = makeAddr("op0");
        address op1 = makeAddr("op1");
        address op2 = makeAddr("op2");

        vm.startPrank(admin);
        operatorsRegistry.addOperator("Op0", op0);
        operatorsRegistry.addOperator("Op1", op1);
        operatorsRegistry.addOperator("Op2", op2);

        bytes memory keys0 = genBytes(5 * (48 + 96));
        bytes memory keys2 = genBytes(5 * (48 + 96));

        operatorsRegistry.addValidators(0, 5, keys0);
        operatorsRegistry.addValidators(1, 5, genBytes(5 * (48 + 96)));
        operatorsRegistry.addValidators(2, 5, keys2);

        uint256[] memory indexes = new uint256[](3);
        indexes[0] = 0;
        indexes[1] = 1;
        indexes[2] = 2;
        uint32[] memory limits = new uint32[](3);
        limits[0] = 5;
        limits[1] = 5;
        limits[2] = 5;
        operatorsRegistry.setOperatorLimits(indexes, limits, block.number);

        operatorsRegistry.setOperatorStatus(1, false);
        vm.stopPrank();

        IOperatorsRegistryV1.OperatorAllocation[] memory allocation = new IOperatorsRegistryV1.OperatorAllocation[](2);
        allocation[0] = IOperatorsRegistryV1.OperatorAllocation({operatorIndex: 0, validatorCount: 2});
        allocation[1] = IOperatorsRegistryV1.OperatorAllocation({operatorIndex: 2, validatorCount: 3});

        vm.prank(river);
        (bytes[] memory publicKeys, bytes[] memory signatures) =
            operatorsRegistry.pickNextValidatorsToDepositFromActiveOperators(allocation);

        assertEq(publicKeys.length, 5, "expected 2 + 3 keys");
        assertEq(signatures.length, 5);
        assertEq(operatorsRegistry.getOperator(0).funded, 2);
        assertEq(operatorsRegistry.getOperator(1).funded, 0, "inactive op1 must not be funded");
        assertEq(operatorsRegistry.getOperator(2).funded, 3);

        for (uint256 i = 0; i < 2; ++i) {
            assertEq(
                keccak256(publicKeys[i]),
                keccak256(LibBytes.slice(keys0, i * (48 + 96), 48)),
                "first two keys must be from op0"
            );
        }
        for (uint256 i = 0; i < 3; ++i) {
            assertEq(
                keccak256(publicKeys[2 + i]),
                keccak256(LibBytes.slice(keys2, i * (48 + 96), 48)),
                "next three keys must be from op2"
            );
        }
    }

    /// @notice Allocation only to inactive operators reverts with InactiveOperator
    function testPickNextValidatorsToDepositRevertsWhenAllAllocationsAreToInactiveOperators() public {
        vm.startPrank(admin);
        operatorsRegistry.addOperator("Op0", makeAddr("op0"));
        operatorsRegistry.addOperator("Op1", makeAddr("op1"));
        bytes memory tenKeys = genBytes(10 * (48 + 96));
        operatorsRegistry.addValidators(0, 10, tenKeys);
        operatorsRegistry.addValidators(1, 10, tenKeys);
        vm.stopPrank();

        uint256[] memory indexes = new uint256[](2);
        indexes[0] = 0;
        indexes[1] = 1;
        uint32[] memory limits = new uint32[](2);
        limits[0] = 10;
        limits[1] = 10;
        vm.prank(admin);
        operatorsRegistry.setOperatorLimits(indexes, limits, block.number);

        vm.startPrank(admin);
        operatorsRegistry.setOperatorStatus(0, false);
        operatorsRegistry.setOperatorStatus(1, false);
        vm.stopPrank();

        IOperatorsRegistryV1.OperatorAllocation[] memory allocation = new IOperatorsRegistryV1.OperatorAllocation[](1);
        allocation[0] = IOperatorsRegistryV1.OperatorAllocation({operatorIndex: 0, validatorCount: 5});

        vm.prank(river);
        vm.expectRevert(abi.encodeWithSignature("InactiveOperator(uint256)", 0));
        operatorsRegistry.pickNextValidatorsToDepositFromActiveOperators(allocation);
    }

    /// @notice Allocation only to non-fundable operators (limit already reached) reverts
    function testPickNextValidatorsToDepositRevertsWhenAllAllocationsAreToNonFundableOperators() public {
        vm.startPrank(admin);
        operatorsRegistry.addOperator("Op0", makeAddr("op0"));
        operatorsRegistry.addOperator("Op1", makeAddr("op1"));
        bytes memory tenKeys = genBytes(10 * (48 + 96));
        operatorsRegistry.addValidators(0, 10, tenKeys);
        operatorsRegistry.addValidators(1, 10, tenKeys);

        uint256[] memory indexes = new uint256[](1);
        indexes[0] = 0;
        uint32[] memory limits = new uint32[](1);
        limits[0] = 10;
        operatorsRegistry.setOperatorLimits(indexes, limits, block.number);
        vm.stopPrank();

        vm.prank(river);
        operatorsRegistry.pickNextValidatorsToDepositFromActiveOperators(_createAllocation(0, 10));

        IOperatorsRegistryV1.OperatorAllocation[] memory allocation = new IOperatorsRegistryV1.OperatorAllocation[](1);
        allocation[0] = IOperatorsRegistryV1.OperatorAllocation({operatorIndex: 0, validatorCount: 1});

        vm.prank(river);
        vm.expectRevert(
            abi.encodeWithSignature("OperatorHasInsufficientFundableKeys(uint256,uint256,uint256)", 0, 1, 0)
        );
        operatorsRegistry.pickNextValidatorsToDepositFromActiveOperators(allocation);
    }

    /// @notice Multi-operator allocation with second operator inactive reverts on that entry
    function testPickNextValidatorsToDepositRevertsWhenSecondOperatorInAllocationIsInactive() public {
        vm.startPrank(admin);
        operatorsRegistry.addOperator("Op0", makeAddr("op0"));
        operatorsRegistry.addOperator("Op1", makeAddr("op1"));
        bytes memory tenKeys = genBytes(10 * (48 + 96));
        operatorsRegistry.addValidators(0, 10, tenKeys);
        operatorsRegistry.addValidators(1, 10, tenKeys);
        vm.stopPrank();

        uint256[] memory indexes = new uint256[](2);
        indexes[0] = 0;
        indexes[1] = 1;
        uint32[] memory limits = new uint32[](2);
        limits[0] = 10;
        limits[1] = 10;
        vm.prank(admin);
        operatorsRegistry.setOperatorLimits(indexes, limits, block.number);

        vm.prank(admin);
        operatorsRegistry.setOperatorStatus(1, false);

        IOperatorsRegistryV1.OperatorAllocation[] memory allocation = new IOperatorsRegistryV1.OperatorAllocation[](2);
        allocation[0] = IOperatorsRegistryV1.OperatorAllocation({operatorIndex: 0, validatorCount: 2});
        allocation[1] = IOperatorsRegistryV1.OperatorAllocation({operatorIndex: 1, validatorCount: 3});

        vm.prank(river);
        vm.expectRevert(abi.encodeWithSignature("InactiveOperator(uint256)", 1));
        operatorsRegistry.pickNextValidatorsToDepositFromActiveOperators(allocation);
    }

    /// @notice Allocation to operator with limit zero has no fundable keys
    function testPickNextValidatorsToDepositRevertsWhenOperatorHasLimitZero() public {
        vm.startPrank(admin);
        operatorsRegistry.addOperator("Op0", makeAddr("op0"));
        operatorsRegistry.addOperator("Op1", makeAddr("op1"));
        bytes memory tenKeys = genBytes(10 * (48 + 96));
        operatorsRegistry.addValidators(0, 10, tenKeys);
        operatorsRegistry.addValidators(1, 10, tenKeys);

        uint256[] memory indexes = new uint256[](1);
        indexes[0] = 0;
        uint32[] memory limits = new uint32[](1);
        limits[0] = 0;
        operatorsRegistry.setOperatorLimits(indexes, limits, block.number);
        vm.stopPrank();

        IOperatorsRegistryV1.OperatorAllocation[] memory allocation = new IOperatorsRegistryV1.OperatorAllocation[](1);
        allocation[0] = IOperatorsRegistryV1.OperatorAllocation({operatorIndex: 0, validatorCount: 1});

        vm.prank(river);
        vm.expectRevert(
            abi.encodeWithSignature("OperatorHasInsufficientFundableKeys(uint256,uint256,uint256)", 0, 1, 0)
        );
        operatorsRegistry.pickNextValidatorsToDepositFromActiveOperators(allocation);
    }

    function _bytesToPublicKeysArray(bytes memory raw, uint256 start, uint256 end)
        internal
        pure
        returns (bytes[] memory res)
    {
        if ((end - start) % (ValidatorKeys.PUBLIC_KEY_LENGTH + ValidatorKeys.SIGNATURE_LENGTH) != 0) {
            revert();
        }
        uint256 count = (end - start) / (ValidatorKeys.PUBLIC_KEY_LENGTH + ValidatorKeys.SIGNATURE_LENGTH);
        res = new bytes[](count);
        for (uint256 idx = 0; idx < count; ++idx) {
            res[idx] = LibBytes.slice(
                raw,
                start + (idx * (ValidatorKeys.PUBLIC_KEY_LENGTH + ValidatorKeys.SIGNATURE_LENGTH)),
                ValidatorKeys.PUBLIC_KEY_LENGTH
            );
        }
    }

    function testRegularDepositDistribution() external {
        bytes[] memory rawKeys = new bytes[](5);

        rawKeys[0] = genBytes((48 + 96) * 50);
        rawKeys[1] = genBytes((48 + 96) * 50);
        rawKeys[2] = genBytes((48 + 96) * 50);
        rawKeys[3] = genBytes((48 + 96) * 50);
        rawKeys[4] = genBytes((48 + 96) * 50);

        vm.startPrank(admin);
        operatorsRegistry.addValidators(0, 50, rawKeys[0]);
        operatorsRegistry.addValidators(1, 50, rawKeys[1]);
        operatorsRegistry.addValidators(2, 50, rawKeys[2]);
        operatorsRegistry.addValidators(3, 50, rawKeys[3]);
        operatorsRegistry.addValidators(4, 50, rawKeys[4]);
        vm.stopPrank();

        uint32[] memory limits = new uint32[](5);
        limits[0] = 50;
        limits[1] = 50;
        limits[2] = 50;
        limits[3] = 50;
        limits[4] = 50;

        uint256[] memory operators = new uint256[](5);
        operators[0] = 0;
        operators[1] = 1;
        operators[2] = 2;
        operators[3] = 3;
        operators[4] = 4;

        vm.prank(admin);
        operatorsRegistry.setOperatorLimits(operators, limits, block.number);

        {
            vm.expectEmit(true, true, true, true);
            emit FundedValidatorKeys(
                0,
                _bytesToPublicKeysArray(
                    rawKeys[0], 0, 10 * (ValidatorKeys.PUBLIC_KEY_LENGTH + ValidatorKeys.SIGNATURE_LENGTH)
                ),
                false
            );
            vm.expectEmit(true, true, true, true);
            emit FundedValidatorKeys(
                1,
                _bytesToPublicKeysArray(
                    rawKeys[1], 0, 10 * (ValidatorKeys.PUBLIC_KEY_LENGTH + ValidatorKeys.SIGNATURE_LENGTH)
                ),
                false
            );
            vm.expectEmit(true, true, true, true);
            emit FundedValidatorKeys(
                2,
                _bytesToPublicKeysArray(
                    rawKeys[2], 0, 10 * (ValidatorKeys.PUBLIC_KEY_LENGTH + ValidatorKeys.SIGNATURE_LENGTH)
                ),
                false
            );
            vm.expectEmit(true, true, true, true);
            emit FundedValidatorKeys(
                3,
                _bytesToPublicKeysArray(
                    rawKeys[3], 0, 10 * (ValidatorKeys.PUBLIC_KEY_LENGTH + ValidatorKeys.SIGNATURE_LENGTH)
                ),
                false
            );
            vm.expectEmit(true, true, true, true);
            emit FundedValidatorKeys(
                4,
                _bytesToPublicKeysArray(
                    rawKeys[4], 0, 10 * (ValidatorKeys.PUBLIC_KEY_LENGTH + ValidatorKeys.SIGNATURE_LENGTH)
                ),
                false
            );
            uint32[] memory allocCounts = new uint32[](5);
            allocCounts[0] = 10;
            allocCounts[1] = 10;
            allocCounts[2] = 10;
            allocCounts[3] = 10;
            allocCounts[4] = 10;
            (bytes[] memory publicKeys, bytes[] memory signatures) = OperatorsRegistryInitializableV1(
                    address(operatorsRegistry)
                ).pickNextValidatorsToDepositFromActiveOperators(_createAllocation(operators, allocCounts));

            assert(publicKeys.length == 50);
            assert(signatures.length == 50);

            assert(operatorsRegistry.getOperator(0).funded == 10);
            assert(operatorsRegistry.getOperator(1).funded == 10);
            assert(operatorsRegistry.getOperator(2).funded == 10);
            assert(operatorsRegistry.getOperator(3).funded == 10);
            assert(operatorsRegistry.getOperator(4).funded == 10);
        }
        {
            vm.expectEmit(true, true, true, true);
            emit FundedValidatorKeys(
                0,
                _bytesToPublicKeysArray(
                    rawKeys[0],
                    10 * (ValidatorKeys.PUBLIC_KEY_LENGTH + ValidatorKeys.SIGNATURE_LENGTH),
                    50 * (ValidatorKeys.PUBLIC_KEY_LENGTH + ValidatorKeys.SIGNATURE_LENGTH)
                ),
                false
            );
            vm.expectEmit(true, true, true, true);
            emit FundedValidatorKeys(
                1,
                _bytesToPublicKeysArray(
                    rawKeys[1],
                    10 * (ValidatorKeys.PUBLIC_KEY_LENGTH + ValidatorKeys.SIGNATURE_LENGTH),
                    50 * (ValidatorKeys.PUBLIC_KEY_LENGTH + ValidatorKeys.SIGNATURE_LENGTH)
                ),
                false
            );
            vm.expectEmit(true, true, true, true);
            emit FundedValidatorKeys(
                2,
                _bytesToPublicKeysArray(
                    rawKeys[2],
                    10 * (ValidatorKeys.PUBLIC_KEY_LENGTH + ValidatorKeys.SIGNATURE_LENGTH),
                    50 * (ValidatorKeys.PUBLIC_KEY_LENGTH + ValidatorKeys.SIGNATURE_LENGTH)
                ),
                false
            );
            vm.expectEmit(true, true, true, true);
            emit FundedValidatorKeys(
                3,
                _bytesToPublicKeysArray(
                    rawKeys[3],
                    10 * (ValidatorKeys.PUBLIC_KEY_LENGTH + ValidatorKeys.SIGNATURE_LENGTH),
                    50 * (ValidatorKeys.PUBLIC_KEY_LENGTH + ValidatorKeys.SIGNATURE_LENGTH)
                ),
                false
            );
            vm.expectEmit(true, true, true, true);
            emit FundedValidatorKeys(
                4,
                _bytesToPublicKeysArray(
                    rawKeys[4],
                    10 * (ValidatorKeys.PUBLIC_KEY_LENGTH + ValidatorKeys.SIGNATURE_LENGTH),
                    50 * (ValidatorKeys.PUBLIC_KEY_LENGTH + ValidatorKeys.SIGNATURE_LENGTH)
                ),
                false
            );
            uint32[] memory allocCounts2 = new uint32[](5);
            allocCounts2[0] = 40;
            allocCounts2[1] = 40;
            allocCounts2[2] = 40;
            allocCounts2[3] = 40;
            allocCounts2[4] = 40;
            (bytes[] memory publicKeys, bytes[] memory signatures) = OperatorsRegistryInitializableV1(
                    address(operatorsRegistry)
                ).pickNextValidatorsToDepositFromActiveOperators(_createAllocation(operators, allocCounts2));

            assert(publicKeys.length == 200);
            assert(signatures.length == 200);

            assert(operatorsRegistry.getOperator(0).funded == 50);
            assert(operatorsRegistry.getOperator(1).funded == 50);
            assert(operatorsRegistry.getOperator(2).funded == 50);
            assert(operatorsRegistry.getOperator(3).funded == 50);
            assert(operatorsRegistry.getOperator(4).funded == 50);
        }
    }

    function testDepositDistributionWithZeroCountAllocationFails() external {
        // Setup: add validators to operators
        bytes[] memory rawKeys = new bytes[](3);
        rawKeys[0] = genBytes((48 + 96) * 10);
        rawKeys[1] = genBytes((48 + 96) * 10);
        rawKeys[2] = genBytes((48 + 96) * 10);

        vm.startPrank(admin);
        operatorsRegistry.addValidators(0, 10, rawKeys[0]);
        operatorsRegistry.addValidators(1, 10, rawKeys[1]);
        operatorsRegistry.addValidators(2, 10, rawKeys[2]);
        vm.stopPrank();

        // Set limits for all operators
        uint32[] memory limits = new uint32[](3);
        limits[0] = 10;
        limits[1] = 10;
        limits[2] = 10;

        uint256[] memory operators = new uint256[](3);
        operators[0] = 0;
        operators[1] = 1;
        operators[2] = 2;

        vm.prank(admin);
        operatorsRegistry.setOperatorLimits(operators, limits, block.number);

        // Create allocation with operator 1 having validatorCount = 0
        // This should revert with AllocationWithZeroValidatorCount
        uint32[] memory allocCounts = new uint32[](3);
        allocCounts[0] = 5; // operator 0 gets 5 validators
        allocCounts[1] = 0; // operator 1 gets 0 validators (should cause revert)
        allocCounts[2] = 3; // operator 2 gets 3 validators

        vm.expectRevert(abi.encodeWithSelector(IOperatorsRegistryV1.AllocationWithZeroValidatorCount.selector));
        OperatorsRegistryInitializableV1(address(operatorsRegistry))
            .pickNextValidatorsToDepositFromActiveOperators(_createAllocation(operators, allocCounts));
    }

    function testInactiveDepositDistribution() external {
        vm.startPrank(admin);
        operatorsRegistry.addValidators(0, 50, genBytes((48 + 96) * 50));
        operatorsRegistry.addValidators(1, 50, genBytes((48 + 96) * 50));
        operatorsRegistry.addValidators(2, 50, genBytes((48 + 96) * 50));
        operatorsRegistry.addValidators(3, 50, genBytes((48 + 96) * 50));
        operatorsRegistry.addValidators(4, 50, genBytes((48 + 96) * 50));

        vm.stopPrank();

        uint32[] memory limits = new uint32[](3);
        limits[0] = 50;
        limits[1] = 50;
        limits[2] = 50;

        uint256[] memory activeOperators = new uint256[](3);
        activeOperators[0] = 0;
        activeOperators[1] = 2;
        activeOperators[2] = 4;

        uint256[] memory allOperators = new uint256[](5);
        allOperators[0] = 0;
        allOperators[1] = 1;
        allOperators[2] = 2;
        allOperators[3] = 3;
        allOperators[4] = 4;

        uint32[] memory allLimits = new uint32[](5);
        allLimits[0] = 50;
        allLimits[1] = 50;
        allLimits[2] = 50;
        allLimits[3] = 50;
        allLimits[4] = 50;

        vm.startPrank(admin);
        operatorsRegistry.setOperatorLimits(allOperators, allLimits, block.number);
        operatorsRegistry.setOperatorStatus(1, false);
        operatorsRegistry.setOperatorStatus(3, false);
        vm.stopPrank();

        {
            (bytes[] memory publicKeys, bytes[] memory signatures) = OperatorsRegistryInitializableV1(
                    address(operatorsRegistry)
                ).pickNextValidatorsToDepositFromActiveOperators(_createAllocation(activeOperators, limits));

            assert(publicKeys.length == 150);
            assert(signatures.length == 150);

            assert(operatorsRegistry.getOperator(0).funded == 50);
            assert(operatorsRegistry.getOperator(1).funded == 0);
            assert(operatorsRegistry.getOperator(2).funded == 50);
            assert(operatorsRegistry.getOperator(3).funded == 0);
            assert(operatorsRegistry.getOperator(4).funded == 50);
        }
    }

    function testStoppedDepositDistribution() external {
        vm.startPrank(admin);
        operatorsRegistry.addValidators(0, 50, genBytes((48 + 96) * 50));
        operatorsRegistry.addValidators(1, 50, genBytes((48 + 96) * 50));
        operatorsRegistry.addValidators(2, 50, genBytes((48 + 96) * 50));
        operatorsRegistry.addValidators(3, 50, genBytes((48 + 96) * 50));
        operatorsRegistry.addValidators(4, 50, genBytes((48 + 96) * 50));

        vm.stopPrank();

        uint32[] memory limits = new uint32[](3);
        limits[0] = 50;
        limits[1] = 50;
        limits[2] = 50;

        uint256[] memory operators = new uint256[](3);
        operators[0] = 0;
        operators[1] = 2;
        operators[2] = 4;

        vm.startPrank(admin);
        operatorsRegistry.setOperatorLimits(operators, limits, block.number);
        vm.stopPrank();

        {
            uint32[] memory allocCounts = new uint32[](3);
            allocCounts[0] = 25;
            allocCounts[1] = 25;
            allocCounts[2] = 25;
            OperatorsRegistryInitializableV1(address(operatorsRegistry))
                .pickNextValidatorsToDepositFromActiveOperators(_createAllocation(operators, allocCounts));
        }
        assert(operatorsRegistry.getOperator(0).funded == 25);
        assert(operatorsRegistry.getOperator(1).funded == 0);
        assert(operatorsRegistry.getOperator(2).funded == 25);
        assert(operatorsRegistry.getOperator(3).funded == 0);
        assert(operatorsRegistry.getOperator(4).funded == 25);

        vm.startPrank(admin);

        uint32[] memory stoppedValidatorCounts = new uint32[](6);
        stoppedValidatorCounts[0] = 75;
        stoppedValidatorCounts[1] = 25;
        stoppedValidatorCounts[3] = 25;
        stoppedValidatorCounts[5] = 25;

        RiverMock(address(river)).sudoSetDepositedValidatorsCount(75);
        OperatorsRegistryInitializableV1(address(operatorsRegistry))
            .sudoStoppedValidatorCounts(stoppedValidatorCounts, 75);

        limits = new uint32[](2);
        limits[0] = 50;
        limits[1] = 50;

        operators = new uint256[](2);
        operators[0] = 1;
        operators[1] = 3;

        operatorsRegistry.setOperatorLimits(operators, limits, block.number);

        vm.stopPrank();

        {
            uint256[] memory allOps = new uint256[](5);
            allOps[0] = 0;
            allOps[1] = 1;
            allOps[2] = 2;
            allOps[3] = 3;
            allOps[4] = 4;
            uint32[] memory allocCounts = new uint32[](5);
            allocCounts[0] = 10;
            allocCounts[1] = 10;
            allocCounts[2] = 10;
            allocCounts[3] = 10;
            allocCounts[4] = 10;
            (bytes[] memory publicKeys, bytes[] memory signatures) = OperatorsRegistryInitializableV1(
                    address(operatorsRegistry)
                ).pickNextValidatorsToDepositFromActiveOperators(_createAllocation(allOps, allocCounts));

            assert(publicKeys.length == 50);
            assert(signatures.length == 50);

            assert(operatorsRegistry.getOperator(0).funded == 35);
            assert(operatorsRegistry.getOperator(1).funded == 10);
            assert(operatorsRegistry.getOperator(2).funded == 35);
            assert(operatorsRegistry.getOperator(3).funded == 10);
            assert(operatorsRegistry.getOperator(4).funded == 35);
        }
    }

    function testDepositDistributionWithOperatorsWithPositiveStoppedDelta() external {
        vm.startPrank(admin);
        operatorsRegistry.addValidators(0, 50, genBytes((48 + 96) * 50));
        operatorsRegistry.addValidators(1, 50, genBytes((48 + 96) * 50));
        operatorsRegistry.addValidators(2, 50, genBytes((48 + 96) * 50));
        operatorsRegistry.addValidators(3, 50, genBytes((48 + 96) * 50));
        operatorsRegistry.addValidators(4, 50, genBytes((48 + 96) * 50));
        vm.stopPrank();

        uint32[] memory limits = new uint32[](5);
        limits[0] = 50;
        limits[1] = 50;
        limits[2] = 50;
        limits[3] = 50;
        limits[4] = 50;

        uint256[] memory operators = new uint256[](5);
        operators[0] = 0;
        operators[1] = 1;
        operators[2] = 2;
        operators[3] = 3;
        operators[4] = 4;

        vm.prank(admin);
        operatorsRegistry.setOperatorLimits(operators, limits, block.number);

        {
            uint32[] memory allocCounts = new uint32[](5);
            allocCounts[0] = 10;
            allocCounts[1] = 10;
            allocCounts[2] = 10;
            allocCounts[3] = 10;
            allocCounts[4] = 10;
            OperatorsRegistryInitializableV1(address(operatorsRegistry))
                .pickNextValidatorsToDepositFromActiveOperators(_createAllocation(operators, allocCounts));
        }
        assert(operatorsRegistry.getOperator(0).funded == 10);
        assert(operatorsRegistry.getOperator(1).funded == 10);
        assert(operatorsRegistry.getOperator(2).funded == 10);
        assert(operatorsRegistry.getOperator(3).funded == 10);
        assert(operatorsRegistry.getOperator(4).funded == 10);

        vm.prank(river);
        operatorsRegistry.demandValidatorExits(50, 250);

        limits[0] = 10;
        limits[1] = 10;
        limits[2] = 10;
        limits[3] = 10;
        limits[4] = 10;

        vm.expectEmit(true, true, true, true);
        emit RequestedValidatorExits(0, 10);
        vm.expectEmit(true, true, true, true);
        emit RequestedValidatorExits(1, 10);
        vm.expectEmit(true, true, true, true);
        emit RequestedValidatorExits(2, 10);
        vm.expectEmit(true, true, true, true);
        emit RequestedValidatorExits(3, 10);
        vm.expectEmit(true, true, true, true);
        emit RequestedValidatorExits(4, 10);
        vm.prank(keeper);
        operatorsRegistry.requestValidatorExits(_createAllocation(operators, limits));

        assert(operatorsRegistry.getOperator(0).requestedExits == 10);
        assert(operatorsRegistry.getOperator(1).requestedExits == 10);
        assert(operatorsRegistry.getOperator(2).requestedExits == 10);
        assert(operatorsRegistry.getOperator(3).requestedExits == 10);
        assert(operatorsRegistry.getOperator(4).requestedExits == 10);

        uint32[] memory stoppedValidatorCounts = new uint32[](6);
        stoppedValidatorCounts[0] = 47;
        stoppedValidatorCounts[1] = 9;
        stoppedValidatorCounts[2] = 10;
        stoppedValidatorCounts[3] = 9;
        stoppedValidatorCounts[4] = 10;
        stoppedValidatorCounts[5] = 9;

        RiverMock(river).sudoSetDepositedValidatorsCount(47);
        OperatorsRegistryInitializableV1(address(operatorsRegistry))
            .sudoStoppedValidatorCounts(stoppedValidatorCounts, 47);

        {
            uint32[] memory allocCounts = new uint32[](2);
            uint256[] memory alloOperators = new uint256[](2);
            alloOperators[0] = 1;
            alloOperators[1] = 3;
            allocCounts[0] = 25;
            allocCounts[1] = 25;
            OperatorsRegistryInitializableV1(address(operatorsRegistry))
                .pickNextValidatorsToDepositFromActiveOperators(_createAllocation(alloOperators, allocCounts));
        }
        assert(operatorsRegistry.getOperator(0).funded == 10);
        assert(operatorsRegistry.getOperator(1).funded == 35);
        assert(operatorsRegistry.getOperator(2).funded == 10);
        assert(operatorsRegistry.getOperator(3).funded == 35);
        assert(operatorsRegistry.getOperator(4).funded == 10);
    }

    event SetTotalValidatorExitsRequested(uint256 previousTotalRequestedExits, uint256 newTotalRequestedExits);

    function testNonKeeperCantRequestExits() external {
        vm.startPrank(admin);
        operatorsRegistry.addValidators(0, 50, genBytes((48 + 96) * 50));
        operatorsRegistry.addValidators(1, 50, genBytes((48 + 96) * 50));
        operatorsRegistry.addValidators(2, 50, genBytes((48 + 96) * 50));
        operatorsRegistry.addValidators(3, 50, genBytes((48 + 96) * 50));
        operatorsRegistry.addValidators(4, 50, genBytes((48 + 96) * 50));
        vm.stopPrank();

        uint32[] memory limits = new uint32[](5);
        limits[0] = 50;
        limits[1] = 50;
        limits[2] = 50;
        limits[3] = 50;
        limits[4] = 50;

        uint256[] memory operators = new uint256[](5);
        operators[0] = 0;
        operators[1] = 1;
        operators[2] = 2;
        operators[3] = 3;
        operators[4] = 4;

        vm.prank(admin);
        operatorsRegistry.setOperatorLimits(operators, limits, block.number);

        vm.expectRevert(abi.encodeWithSignature("OnlyKeeper()"));
        operatorsRegistry.requestValidatorExits(_createAllocation(operators, limits));
    }

    function testRequestValidatorNoExits() external {
        uint32[] memory limits = new uint32[](5);
        limits[0] = 50;
        limits[1] = 50;
        limits[2] = 50;
        limits[3] = 50;
        limits[4] = 50;

        uint256[] memory operators = new uint256[](5);
        operators[0] = 0;
        operators[1] = 1;
        operators[2] = 2;
        operators[3] = 3;
        operators[4] = 4;
        vm.expectRevert(abi.encodeWithSignature("NoExitRequestsToPerform()"));
        vm.prank(keeper);
        operatorsRegistry.requestValidatorExits(_createAllocation(operators, limits));
    }

    function testRequestExitsWithInactiveOperator() external {
        vm.startPrank(admin);
        operatorsRegistry.addValidators(0, 50, genBytes((48 + 96) * 50));
        operatorsRegistry.addValidators(1, 50, genBytes((48 + 96) * 50));
        operatorsRegistry.addValidators(2, 50, genBytes((48 + 96) * 50));
        operatorsRegistry.addValidators(3, 50, genBytes((48 + 96) * 50));
        operatorsRegistry.addValidators(4, 50, genBytes((48 + 96) * 50));
        vm.stopPrank();

        uint32[] memory limits = new uint32[](5);
        limits[0] = 50;
        limits[1] = 50;
        limits[2] = 50;
        limits[3] = 50;
        limits[4] = 50;

        uint256[] memory operators = new uint256[](5);
        operators[0] = 0;
        operators[1] = 1;
        operators[2] = 2;
        operators[3] = 3;
        operators[4] = 4;

        vm.prank(river);
        operatorsRegistry.demandValidatorExits(250, 250);

        vm.prank(admin);
        operatorsRegistry.setOperatorLimits(operators, limits, block.number);
        vm.prank(admin);
        operatorsRegistry.setOperatorStatus(0, false);

        vm.prank(keeper);
        vm.expectRevert(abi.encodeWithSignature("InactiveOperator(uint256)", 0));
        operatorsRegistry.requestValidatorExits(_createAllocation(operators, limits));
    }

    function testRequestExitsWithMoreRequestsThanDemand() external {
        vm.startPrank(admin);
        operatorsRegistry.addValidators(0, 50, genBytes((48 + 96) * 50));
        operatorsRegistry.addValidators(1, 50, genBytes((48 + 96) * 50));
        operatorsRegistry.addValidators(2, 50, genBytes((48 + 96) * 50));
        operatorsRegistry.addValidators(3, 50, genBytes((48 + 96) * 50));
        operatorsRegistry.addValidators(4, 50, genBytes((48 + 96) * 50));
        vm.stopPrank();

        uint32[] memory limits = new uint32[](5);
        limits[0] = 50;
        limits[1] = 50;
        limits[2] = 50;
        limits[3] = 50;
        limits[4] = 50;

        uint256[] memory operators = new uint256[](5);
        operators[0] = 0;
        operators[1] = 1;
        operators[2] = 2;
        operators[3] = 3;
        operators[4] = 4;

        vm.prank(admin);
        operatorsRegistry.setOperatorLimits(operators, limits, block.number);
        OperatorsRegistryInitializableV1(address(operatorsRegistry))
            .pickNextValidatorsToDepositFromActiveOperators(_createAllocation(operators, limits));
        assert(operatorsRegistry.getOperator(0).funded == 50);
        assert(operatorsRegistry.getOperator(1).funded == 50);
        assert(operatorsRegistry.getOperator(2).funded == 50);
        assert(operatorsRegistry.getOperator(3).funded == 50);
        assert(operatorsRegistry.getOperator(4).funded == 50);

        RiverMock(address(river)).sudoSetDepositedValidatorsCount(250);

        assertEq(operatorsRegistry.getCurrentValidatorExitsDemand(), 0);
        assertEq(operatorsRegistry.getTotalValidatorExitsRequested(), 0);

        vm.prank(river);
        operatorsRegistry.demandValidatorExits(250, 250);

        limits[0] = 60;

        vm.prank(keeper);
        vm.expectRevert(
            abi.encodeWithSignature("ExitsRequestedExceedAvailableFundedCount(uint256,uint256,uint256)", 0, 60, 50)
        );
        operatorsRegistry.requestValidatorExits(_createAllocation(operators, limits));
    }

    function testRequestExitsRequestedExceedDemand() external {
        vm.startPrank(admin);
        operatorsRegistry.addValidators(0, 50, genBytes((48 + 96) * 50));
        operatorsRegistry.addValidators(1, 50, genBytes((48 + 96) * 50));
        operatorsRegistry.addValidators(2, 50, genBytes((48 + 96) * 50));
        operatorsRegistry.addValidators(3, 50, genBytes((48 + 96) * 50));
        operatorsRegistry.addValidators(4, 50, genBytes((48 + 96) * 50));
        vm.stopPrank();

        uint32[] memory limits = new uint32[](5);
        limits[0] = 50;
        limits[1] = 50;
        limits[2] = 50;
        limits[3] = 50;
        limits[4] = 50;

        uint256[] memory operators = new uint256[](5);
        operators[0] = 0;
        operators[1] = 1;
        operators[2] = 2;
        operators[3] = 3;
        operators[4] = 4;

        vm.prank(admin);
        operatorsRegistry.setOperatorLimits(operators, limits, block.number);
        OperatorsRegistryInitializableV1(address(operatorsRegistry))
            .pickNextValidatorsToDepositFromActiveOperators(_createAllocation(operators, limits));
        assert(operatorsRegistry.getOperator(0).funded == 50);
        assert(operatorsRegistry.getOperator(1).funded == 50);
        assert(operatorsRegistry.getOperator(2).funded == 50);
        assert(operatorsRegistry.getOperator(3).funded == 50);
        assert(operatorsRegistry.getOperator(4).funded == 50);

        RiverMock(address(river)).sudoSetDepositedValidatorsCount(250);

        assertEq(operatorsRegistry.getCurrentValidatorExitsDemand(), 0);
        assertEq(operatorsRegistry.getTotalValidatorExitsRequested(), 0);

        vm.prank(river);
        operatorsRegistry.demandValidatorExits(10, 250);

        limits[0] = 50;

        vm.prank(keeper);
        vm.expectRevert(abi.encodeWithSignature("ExitsRequestedExceedDemand(uint256,uint256)", 250, 10));
        operatorsRegistry.requestValidatorExits(_createAllocation(operators, limits));
    }

    function testRequestExitsWithUnorderedOperators() external {
        vm.startPrank(admin);
        operatorsRegistry.addValidators(0, 50, genBytes((48 + 96) * 50));
        operatorsRegistry.addValidators(1, 50, genBytes((48 + 96) * 50));
        operatorsRegistry.addValidators(2, 50, genBytes((48 + 96) * 50));
        operatorsRegistry.addValidators(3, 50, genBytes((48 + 96) * 50));
        operatorsRegistry.addValidators(4, 50, genBytes((48 + 96) * 50));
        vm.stopPrank();

        uint32[] memory limits = new uint32[](5);
        limits[0] = 50;
        limits[1] = 50;
        limits[2] = 50;
        limits[3] = 50;
        limits[4] = 50;

        uint256[] memory operators = new uint256[](5);
        operators[0] = 0;
        operators[1] = 1;
        operators[2] = 2;
        operators[3] = 3;
        operators[4] = 4;

        vm.prank(admin);
        operatorsRegistry.setOperatorLimits(operators, limits, block.number);
        OperatorsRegistryInitializableV1(address(operatorsRegistry))
            .pickNextValidatorsToDepositFromActiveOperators(_createAllocation(operators, limits));
        assert(operatorsRegistry.getOperator(0).funded == 50);
        assert(operatorsRegistry.getOperator(1).funded == 50);
        assert(operatorsRegistry.getOperator(2).funded == 50);
        assert(operatorsRegistry.getOperator(3).funded == 50);
        assert(operatorsRegistry.getOperator(4).funded == 50);

        RiverMock(address(river)).sudoSetDepositedValidatorsCount(250);

        assertEq(operatorsRegistry.getCurrentValidatorExitsDemand(), 0);
        assertEq(operatorsRegistry.getTotalValidatorExitsRequested(), 0);

        vm.prank(river);
        operatorsRegistry.demandValidatorExits(250, 250);

        operators[0] = 1;
        operators[1] = 0;
        operators[2] = 2;
        operators[3] = 3;
        operators[4] = 4;

        vm.prank(keeper);
        vm.expectRevert(abi.encodeWithSignature("UnorderedOperatorList()"));
        operatorsRegistry.requestValidatorExits(_createAllocation(operators, limits));
    }

    function testRequestExitsWithInvalidEmptyArray() external {
        vm.prank(river);
        operatorsRegistry.demandValidatorExits(250, 250);

        vm.prank(keeper);
        vm.expectRevert(abi.encodeWithSignature("InvalidEmptyArray()"));
        operatorsRegistry.requestValidatorExits(_createAllocation(new uint256[](0), new uint32[](0)));
    }

    function testRequestExitsWithAllocationWithZeroValidatorCount() external {
        vm.prank(river);
        operatorsRegistry.demandValidatorExits(250, 250);

        uint256[] memory operators = new uint256[](1);
        operators[0] = 0;
        uint32[] memory exitCounts = new uint32[](1);
        exitCounts[0] = 0;

        vm.prank(keeper);
        vm.expectRevert(abi.encodeWithSignature("AllocationWithZeroValidatorCount()"));
        operatorsRegistry.requestValidatorExits(_createAllocation(operators, exitCounts));
    }

    function testRegularExitDistribution() external {
        vm.startPrank(admin);
        operatorsRegistry.addValidators(0, 50, genBytes((48 + 96) * 50));
        operatorsRegistry.addValidators(1, 50, genBytes((48 + 96) * 50));
        operatorsRegistry.addValidators(2, 50, genBytes((48 + 96) * 50));
        operatorsRegistry.addValidators(3, 50, genBytes((48 + 96) * 50));
        operatorsRegistry.addValidators(4, 50, genBytes((48 + 96) * 50));
        vm.stopPrank();

        uint32[] memory limits = new uint32[](5);
        limits[0] = 50;
        limits[1] = 50;
        limits[2] = 50;
        limits[3] = 50;
        limits[4] = 50;

        uint256[] memory operators = new uint256[](5);
        operators[0] = 0;
        operators[1] = 1;
        operators[2] = 2;
        operators[3] = 3;
        operators[4] = 4;

        vm.prank(admin);
        operatorsRegistry.setOperatorLimits(operators, limits, block.number);
        OperatorsRegistryInitializableV1(address(operatorsRegistry))
            .pickNextValidatorsToDepositFromActiveOperators(_createAllocation(operators, limits));
        assert(operatorsRegistry.getOperator(0).funded == 50);
        assert(operatorsRegistry.getOperator(1).funded == 50);
        assert(operatorsRegistry.getOperator(2).funded == 50);
        assert(operatorsRegistry.getOperator(3).funded == 50);
        assert(operatorsRegistry.getOperator(4).funded == 50);

        RiverMock(address(river)).sudoSetDepositedValidatorsCount(250);

        assertEq(operatorsRegistry.getCurrentValidatorExitsDemand(), 0);
        assertEq(operatorsRegistry.getTotalValidatorExitsRequested(), 0);

        vm.prank(river);
        operatorsRegistry.demandValidatorExits(250, 250);

        assertEq(operatorsRegistry.getCurrentValidatorExitsDemand(), 250);
        assertEq(operatorsRegistry.getTotalValidatorExitsRequested(), 0);

        vm.expectEmit(true, true, true, true);
        emit RequestedValidatorExits(0, 50);
        vm.expectEmit(true, true, true, true);
        emit RequestedValidatorExits(1, 50);
        vm.expectEmit(true, true, true, true);
        emit RequestedValidatorExits(2, 50);
        vm.expectEmit(true, true, true, true);
        emit RequestedValidatorExits(3, 50);
        vm.expectEmit(true, true, true, true);
        emit RequestedValidatorExits(4, 50);
        vm.expectEmit(true, true, true, true);
        emit SetTotalValidatorExitsRequested(0, 250);
        uint32[] memory exitCounts = new uint32[](5);
        exitCounts[0] = 50;
        exitCounts[1] = 50;
        exitCounts[2] = 50;
        exitCounts[3] = 50;
        exitCounts[4] = 50;
        vm.prank(keeper);
        operatorsRegistry.requestValidatorExits(_createMultiAllocation(operators, exitCounts));

        assert(operatorsRegistry.getOperator(0).requestedExits == 50);
        assert(operatorsRegistry.getOperator(1).requestedExits == 50);
        assert(operatorsRegistry.getOperator(2).requestedExits == 50);
        assert(operatorsRegistry.getOperator(3).requestedExits == 50);
        assert(operatorsRegistry.getOperator(4).requestedExits == 50);

        assertEq(operatorsRegistry.getCurrentValidatorExitsDemand(), 0);
        assertEq(operatorsRegistry.getTotalValidatorExitsRequested(), 250);
    }

    function testExitDistributionUnevenFunded() external {
        vm.startPrank(admin);
        operatorsRegistry.addValidators(0, 50, genBytes((48 + 96) * 50));
        operatorsRegistry.addValidators(1, 40, genBytes((48 + 96) * 40));
        operatorsRegistry.addValidators(2, 30, genBytes((48 + 96) * 30));
        operatorsRegistry.addValidators(3, 30, genBytes((48 + 96) * 30));
        operatorsRegistry.addValidators(4, 10, genBytes((48 + 96) * 10));
        vm.stopPrank();

        uint32[] memory limits = new uint32[](5);
        limits[0] = 50;
        limits[1] = 40;
        limits[2] = 30;
        limits[3] = 30;
        limits[4] = 10;

        uint256[] memory operators = new uint256[](5);
        operators[0] = 0;
        operators[1] = 1;
        operators[2] = 2;
        operators[3] = 3;
        operators[4] = 4;

        vm.prank(admin);
        operatorsRegistry.setOperatorLimits(operators, limits, block.number);

        OperatorsRegistryInitializableV1(address(operatorsRegistry))
            .pickNextValidatorsToDepositFromActiveOperators(_createMultiAllocation(operators, limits));
        assert(operatorsRegistry.getOperator(0).funded == 50);
        assert(operatorsRegistry.getOperator(1).funded == 40);
        assert(operatorsRegistry.getOperator(2).funded == 30);
        assert(operatorsRegistry.getOperator(3).funded == 30);
        assert(operatorsRegistry.getOperator(4).funded == 10);

        vm.prank(river);
        operatorsRegistry.demandValidatorExits(30, 250);
        vm.expectEmit(true, true, true, true);
        emit RequestedValidatorExits(0, 20);
        vm.expectEmit(true, true, true, true);
        emit RequestedValidatorExits(1, 10);
        operators = new uint256[](2);
        operators[0] = 0;
        operators[1] = 1;

        limits = new uint32[](2);

        limits[0] = 20;
        limits[1] = 10;

        vm.prank(keeper);
        operatorsRegistry.requestValidatorExits(_createMultiAllocation(operators, limits));

        assert(operatorsRegistry.getOperator(0).requestedExits == 20);
        assert(operatorsRegistry.getOperator(1).requestedExits == 10);
        assert(operatorsRegistry.getOperator(2).requestedExits == 0);
        assert(operatorsRegistry.getOperator(3).requestedExits == 0);
        assert(operatorsRegistry.getOperator(4).requestedExits == 0);

        assert(operatorsRegistry.getTotalValidatorExitsRequested() == 30);

        vm.prank(river);
        operatorsRegistry.demandValidatorExits(70, 250);
        operators = new uint256[](4);
        operators[0] = 0;
        operators[1] = 1;
        operators[2] = 2;
        operators[3] = 3;
        limits = new uint32[](4);
        limits[0] = 30;
        limits[1] = 20;
        limits[2] = 10;
        limits[3] = 10;

        vm.expectEmit(true, true, true, true);
        emit RequestedValidatorExits(0, 50);
        vm.expectEmit(true, true, true, true);
        emit RequestedValidatorExits(1, 30);
        vm.expectEmit(true, true, true, true);
        emit RequestedValidatorExits(2, 10);
        vm.expectEmit(true, true, true, true);
        emit RequestedValidatorExits(3, 10);
        vm.prank(keeper);
        operatorsRegistry.requestValidatorExits(_createMultiAllocation(operators, limits));
    }

    function testExitDistributionWithUnsollicitedExits() external {
        vm.startPrank(admin);
        operatorsRegistry.addValidators(0, 50, genBytes((48 + 96) * 50));
        operatorsRegistry.addValidators(1, 50, genBytes((48 + 96) * 50));
        operatorsRegistry.addValidators(2, 50, genBytes((48 + 96) * 50));
        operatorsRegistry.addValidators(3, 50, genBytes((48 + 96) * 50));
        operatorsRegistry.addValidators(4, 50, genBytes((48 + 96) * 50));
        vm.stopPrank();

        uint32[] memory limits = new uint32[](5);
        limits[0] = 50;
        limits[1] = 50;
        limits[2] = 50;
        limits[3] = 50;
        limits[4] = 50;

        uint256[] memory operators = new uint256[](5);
        operators[0] = 0;
        operators[1] = 1;
        operators[2] = 2;
        operators[3] = 3;
        operators[4] = 4;

        vm.prank(admin);
        operatorsRegistry.setOperatorLimits(operators, limits, block.number);
        OperatorsRegistryInitializableV1(address(operatorsRegistry))
            .pickNextValidatorsToDepositFromActiveOperators(_createAllocation(operators, limits));
        assert(operatorsRegistry.getOperator(0).funded == 50);
        assert(operatorsRegistry.getOperator(1).funded == 50);
        assert(operatorsRegistry.getOperator(2).funded == 50);
        assert(operatorsRegistry.getOperator(3).funded == 50);
        assert(operatorsRegistry.getOperator(4).funded == 50);

        RiverMock(address(river)).sudoSetDepositedValidatorsCount(250);

        assertEq(operatorsRegistry.getCurrentValidatorExitsDemand(), 0);
        assertEq(operatorsRegistry.getTotalValidatorExitsRequested(), 0);

        vm.prank(river);
        operatorsRegistry.demandValidatorExits(250, 250);

        uint32[] memory stoppedValidatorCounts = new uint32[](6);
        stoppedValidatorCounts[0] = 100;
        stoppedValidatorCounts[1] = 20;
        stoppedValidatorCounts[2] = 20;
        stoppedValidatorCounts[3] = 20;
        stoppedValidatorCounts[4] = 20;
        stoppedValidatorCounts[5] = 20;

        assertEq(operatorsRegistry.getCurrentValidatorExitsDemand(), 250);

        OperatorsRegistryInitializableV1(address(operatorsRegistry))
            .sudoStoppedValidatorCounts(stoppedValidatorCounts, 250);

        assertEq(operatorsRegistry.getCurrentValidatorExitsDemand(), 150);
        assertEq(operatorsRegistry.getTotalValidatorExitsRequested(), 100);

        vm.expectEmit(true, true, true, true);
        emit RequestedValidatorExits(0, 50);
        vm.expectEmit(true, true, true, true);
        emit RequestedValidatorExits(1, 50);
        vm.expectEmit(true, true, true, true);
        emit RequestedValidatorExits(2, 50);
        vm.expectEmit(true, true, true, true);
        emit RequestedValidatorExits(3, 50);
        vm.expectEmit(true, true, true, true);
        emit RequestedValidatorExits(4, 50);
        vm.expectEmit(true, true, true, true);
        emit SetTotalValidatorExitsRequested(100, 250);
        vm.expectEmit(true, true, true, true);
        emit SetCurrentValidatorExitsDemand(150, 0);
        uint32[] memory exitCounts = new uint32[](5);
        exitCounts[0] = 30;
        exitCounts[1] = 30;
        exitCounts[2] = 30;
        exitCounts[3] = 30;
        exitCounts[4] = 30;
        vm.prank(keeper);
        operatorsRegistry.requestValidatorExits(_createMultiAllocation(operators, exitCounts));

        assert(operatorsRegistry.getOperator(0).requestedExits == 50);
        assert(operatorsRegistry.getOperator(1).requestedExits == 50);
        assert(operatorsRegistry.getOperator(2).requestedExits == 50);
        assert(operatorsRegistry.getOperator(3).requestedExits == 50);
        assert(operatorsRegistry.getOperator(4).requestedExits == 50);

        assertEq(operatorsRegistry.getCurrentValidatorExitsDemand(), 0);
        assertEq(operatorsRegistry.getTotalValidatorExitsRequested(), 250);
    }

    function testOneExitDistribution() external {
        vm.startPrank(admin);
        operatorsRegistry.addValidators(0, 50, genBytes((48 + 96) * 50));
        operatorsRegistry.addValidators(1, 50, genBytes((48 + 96) * 50));
        operatorsRegistry.addValidators(2, 50, genBytes((48 + 96) * 50));
        operatorsRegistry.addValidators(3, 50, genBytes((48 + 96) * 50));
        operatorsRegistry.addValidators(4, 50, genBytes((48 + 96) * 50));
        vm.stopPrank();

        uint32[] memory limits = new uint32[](5);
        limits[0] = 50;
        limits[1] = 50;
        limits[2] = 50;
        limits[3] = 50;
        limits[4] = 50;

        uint256[] memory operators = new uint256[](5);
        operators[0] = 0;
        operators[1] = 1;
        operators[2] = 2;
        operators[3] = 3;
        operators[4] = 4;

        vm.prank(admin);
        operatorsRegistry.setOperatorLimits(operators, limits, block.number);

        OperatorsRegistryInitializableV1(address(operatorsRegistry))
            .pickNextValidatorsToDepositFromActiveOperators(_createAllocation(operators, limits));
        assert(operatorsRegistry.getOperator(0).funded == 50);
        assert(operatorsRegistry.getOperator(1).funded == 50);
        assert(operatorsRegistry.getOperator(2).funded == 50);
        assert(operatorsRegistry.getOperator(3).funded == 50);
        assert(operatorsRegistry.getOperator(4).funded == 50);

        vm.prank(river);
        operatorsRegistry.demandValidatorExits(5, 250);

        limits[0] = 1;
        limits[1] = 1;
        limits[2] = 1;
        limits[3] = 1;
        limits[4] = 1;

        vm.expectEmit(true, true, true, true);
        emit RequestedValidatorExits(0, 1);
        vm.prank(keeper);
        operatorsRegistry.requestValidatorExits(_createAllocation(operators, limits));

        assert(operatorsRegistry.getOperator(0).requestedExits == 1);
        assert(operatorsRegistry.getOperator(1).requestedExits == 1);
        assert(operatorsRegistry.getOperator(2).requestedExits == 1);
        assert(operatorsRegistry.getOperator(3).requestedExits == 1);
        assert(operatorsRegistry.getOperator(4).requestedExits == 1);
        assert(operatorsRegistry.getTotalValidatorExitsRequested() == 5);
    }

    event UpdatedRequestedValidatorExitsUponStopped(
        uint256 indexed index, uint32 oldRequestedExits, uint32 newRequestedExits
    );

    event SetCurrentValidatorExitsDemand(uint256 previousValidatorExitsDemand, uint256 nextValidatorExitsDemand);

    function testUnevenExitDistribution() external {
        vm.startPrank(admin);
        operatorsRegistry.addValidators(0, 50, genBytes((48 + 96) * 50));
        operatorsRegistry.addValidators(1, 50, genBytes((48 + 96) * 50));
        operatorsRegistry.addValidators(2, 50, genBytes((48 + 96) * 50));
        operatorsRegistry.addValidators(3, 50, genBytes((48 + 96) * 50));
        operatorsRegistry.addValidators(4, 50, genBytes((48 + 96) * 50));
        vm.stopPrank();

        uint32[] memory limits = new uint32[](5);
        limits[0] = 50;
        limits[1] = 50;
        limits[2] = 50;
        limits[3] = 50;
        limits[4] = 50;

        uint256[] memory operators = new uint256[](5);
        operators[0] = 0;
        operators[1] = 1;
        operators[2] = 2;
        operators[3] = 3;
        operators[4] = 4;

        vm.prank(admin);
        operatorsRegistry.setOperatorLimits(operators, limits, block.number);

        OperatorsRegistryInitializableV1(address(operatorsRegistry))
            .pickNextValidatorsToDepositFromActiveOperators(_createAllocation(operators, limits));
        assert(operatorsRegistry.getOperator(0).funded == 50);
        assert(operatorsRegistry.getOperator(1).funded == 50);
        assert(operatorsRegistry.getOperator(2).funded == 50);
        assert(operatorsRegistry.getOperator(3).funded == 50);
        assert(operatorsRegistry.getOperator(4).funded == 50);

        vm.prank(river);
        operatorsRegistry.demandValidatorExits(14, 250);

        limits[0] = 3;
        limits[1] = 3;
        limits[2] = 3;
        limits[3] = 3;
        limits[4] = 2;

        vm.expectEmit(true, true, true, true);
        emit RequestedValidatorExits(0, 3);
        vm.expectEmit(true, true, true, true);
        emit RequestedValidatorExits(1, 3);
        vm.expectEmit(true, true, true, true);
        emit RequestedValidatorExits(2, 3);
        vm.expectEmit(true, true, true, true);
        emit RequestedValidatorExits(3, 3);
        vm.expectEmit(true, true, true, true);
        emit RequestedValidatorExits(4, 2);
        vm.prank(keeper);
        operatorsRegistry.requestValidatorExits(_createAllocation(operators, limits));

        assert(operatorsRegistry.getOperator(0).requestedExits == 3);
        assert(operatorsRegistry.getOperator(1).requestedExits == 3);
        assert(operatorsRegistry.getOperator(2).requestedExits == 3);
        assert(operatorsRegistry.getOperator(3).requestedExits == 3);
        assert(operatorsRegistry.getOperator(4).requestedExits == 2);

        assert(operatorsRegistry.getTotalValidatorExitsRequested() == 14);
    }

    function testDecreasingStoppedValidatorCounts(uint8 decreasingIndex, uint8[5] memory fuzzedStoppedValidatorCount)
        external
    {
        fuzzedStoppedValidatorCount[0] = uint8(bound(fuzzedStoppedValidatorCount[0], 1, 50));
        fuzzedStoppedValidatorCount[1] = uint8(bound(fuzzedStoppedValidatorCount[1], 1, 50));
        fuzzedStoppedValidatorCount[2] = uint8(bound(fuzzedStoppedValidatorCount[2], 1, 50));
        fuzzedStoppedValidatorCount[3] = uint8(bound(fuzzedStoppedValidatorCount[3], 1, 50));
        fuzzedStoppedValidatorCount[4] = uint8(bound(fuzzedStoppedValidatorCount[4], 1, 50));

        vm.startPrank(admin);
        operatorsRegistry.addValidators(
            0, fuzzedStoppedValidatorCount[0], genBytes((48 + 96) * uint256(fuzzedStoppedValidatorCount[0]))
        );
        operatorsRegistry.addValidators(
            1, fuzzedStoppedValidatorCount[1], genBytes((48 + 96) * uint256(fuzzedStoppedValidatorCount[1]))
        );
        operatorsRegistry.addValidators(
            2, fuzzedStoppedValidatorCount[2], genBytes((48 + 96) * uint256(fuzzedStoppedValidatorCount[2]))
        );
        operatorsRegistry.addValidators(
            3, fuzzedStoppedValidatorCount[3], genBytes((48 + 96) * uint256(fuzzedStoppedValidatorCount[3]))
        );
        operatorsRegistry.addValidators(
            4, fuzzedStoppedValidatorCount[4], genBytes((48 + 96) * uint256(fuzzedStoppedValidatorCount[4]))
        );
        vm.stopPrank();

        uint32[] memory limits = new uint32[](5);
        limits[0] = fuzzedStoppedValidatorCount[0];
        limits[1] = fuzzedStoppedValidatorCount[1];
        limits[2] = fuzzedStoppedValidatorCount[2];
        limits[3] = fuzzedStoppedValidatorCount[3];
        limits[4] = fuzzedStoppedValidatorCount[4];

        uint256[] memory operators = new uint256[](5);
        operators[0] = 0;
        operators[1] = 1;
        operators[2] = 2;
        operators[3] = 3;
        operators[4] = 4;

        vm.prank(admin);
        operatorsRegistry.setOperatorLimits(operators, limits, block.number);

        uint32 sum = uint32(fuzzedStoppedValidatorCount[0]) + fuzzedStoppedValidatorCount[1]
            + fuzzedStoppedValidatorCount[2] + fuzzedStoppedValidatorCount[3] + fuzzedStoppedValidatorCount[4];

        OperatorsRegistryInitializableV1(address(operatorsRegistry))
            .pickNextValidatorsToDepositFromActiveOperators(_createAllocation(operators, limits));

        uint32[] memory stoppedValidatorCount = new uint32[](6);

        stoppedValidatorCount[0] = sum;
        stoppedValidatorCount[1] = fuzzedStoppedValidatorCount[0];
        stoppedValidatorCount[2] = fuzzedStoppedValidatorCount[1];
        stoppedValidatorCount[3] = fuzzedStoppedValidatorCount[2];
        stoppedValidatorCount[4] = fuzzedStoppedValidatorCount[3];
        stoppedValidatorCount[5] = fuzzedStoppedValidatorCount[4];

        RiverMock(address(river)).sudoSetDepositedValidatorsCount(sum);

        OperatorsRegistryInitializableV1(address(operatorsRegistry))
            .sudoStoppedValidatorCounts(stoppedValidatorCount, sum);

        decreasingIndex = uint8(bound(decreasingIndex, 1, 5));

        stoppedValidatorCount[decreasingIndex] -= 1;

        vm.expectRevert(abi.encodeWithSignature("StoppedValidatorCountsDecreased()"));
        OperatorsRegistryInitializableV1(address(operatorsRegistry))
            .sudoStoppedValidatorCounts(stoppedValidatorCount, sum);
    }

    function testStoppedValidatorCountAboveFundedCount(
        uint8 decreasingIndex,
        uint8[5] memory fuzzedStoppedValidatorCount
    ) external {
        fuzzedStoppedValidatorCount[0] = uint8(bound(fuzzedStoppedValidatorCount[0], 1, 50));
        fuzzedStoppedValidatorCount[1] = uint8(bound(fuzzedStoppedValidatorCount[1], 1, 50));
        fuzzedStoppedValidatorCount[2] = uint8(bound(fuzzedStoppedValidatorCount[2], 1, 50));
        fuzzedStoppedValidatorCount[3] = uint8(bound(fuzzedStoppedValidatorCount[3], 1, 50));
        fuzzedStoppedValidatorCount[4] = uint8(bound(fuzzedStoppedValidatorCount[4], 1, 50));

        vm.startPrank(admin);
        operatorsRegistry.addValidators(
            0, fuzzedStoppedValidatorCount[0], genBytes((48 + 96) * uint256(fuzzedStoppedValidatorCount[0]))
        );
        operatorsRegistry.addValidators(
            1, fuzzedStoppedValidatorCount[1], genBytes((48 + 96) * uint256(fuzzedStoppedValidatorCount[1]))
        );
        operatorsRegistry.addValidators(
            2, fuzzedStoppedValidatorCount[2], genBytes((48 + 96) * uint256(fuzzedStoppedValidatorCount[2]))
        );
        operatorsRegistry.addValidators(
            3, fuzzedStoppedValidatorCount[3], genBytes((48 + 96) * uint256(fuzzedStoppedValidatorCount[3]))
        );
        operatorsRegistry.addValidators(
            4, fuzzedStoppedValidatorCount[4], genBytes((48 + 96) * uint256(fuzzedStoppedValidatorCount[4]))
        );
        vm.stopPrank();

        uint32[] memory limits = new uint32[](5);
        limits[0] = fuzzedStoppedValidatorCount[0];
        limits[1] = fuzzedStoppedValidatorCount[1];
        limits[2] = fuzzedStoppedValidatorCount[2];
        limits[3] = fuzzedStoppedValidatorCount[3];
        limits[4] = fuzzedStoppedValidatorCount[4];

        uint256[] memory operators = new uint256[](5);
        operators[0] = 0;
        operators[1] = 1;
        operators[2] = 2;
        operators[3] = 3;
        operators[4] = 4;

        vm.prank(admin);
        operatorsRegistry.setOperatorLimits(operators, limits, block.number);

        uint32 sum = uint32(fuzzedStoppedValidatorCount[0]) + fuzzedStoppedValidatorCount[1]
            + fuzzedStoppedValidatorCount[2] + fuzzedStoppedValidatorCount[3] + fuzzedStoppedValidatorCount[4];

        OperatorsRegistryInitializableV1(address(operatorsRegistry))
            .pickNextValidatorsToDepositFromActiveOperators(_createAllocation(operators, limits));

        uint32[] memory stoppedValidatorCount = new uint32[](6);

        stoppedValidatorCount[0] = sum;
        stoppedValidatorCount[1] = fuzzedStoppedValidatorCount[0];
        stoppedValidatorCount[2] = fuzzedStoppedValidatorCount[1];
        stoppedValidatorCount[3] = fuzzedStoppedValidatorCount[2];
        stoppedValidatorCount[4] = fuzzedStoppedValidatorCount[3];
        stoppedValidatorCount[5] = fuzzedStoppedValidatorCount[4];

        RiverMock(address(river)).sudoSetDepositedValidatorsCount(sum);

        OperatorsRegistryInitializableV1(address(operatorsRegistry))
            .sudoStoppedValidatorCounts(stoppedValidatorCount, sum);

        decreasingIndex = uint8(bound(decreasingIndex, 1, 5));

        stoppedValidatorCount[decreasingIndex] += 1;
        stoppedValidatorCount[0] += 1;

        vm.expectRevert(
            abi.encodeWithSignature(
                "StoppedValidatorCountAboveFundedCount(uint256,uint32,uint32)",
                decreasingIndex - 1,
                stoppedValidatorCount[decreasingIndex],
                stoppedValidatorCount[decreasingIndex] - 1
            )
        );
        OperatorsRegistryInitializableV1(address(operatorsRegistry))
            .sudoStoppedValidatorCounts(stoppedValidatorCount, sum);
    }

    function testStoppedValidatorCountArrayShrinking(uint8[5] memory fuzzedStoppedValidatorCount) external {
        fuzzedStoppedValidatorCount[0] = uint8(bound(fuzzedStoppedValidatorCount[0], 1, 50));
        fuzzedStoppedValidatorCount[1] = uint8(bound(fuzzedStoppedValidatorCount[1], 1, 50));
        fuzzedStoppedValidatorCount[2] = uint8(bound(fuzzedStoppedValidatorCount[2], 1, 50));
        fuzzedStoppedValidatorCount[3] = uint8(bound(fuzzedStoppedValidatorCount[3], 1, 50));
        fuzzedStoppedValidatorCount[4] = uint8(bound(fuzzedStoppedValidatorCount[4], 1, 50));

        vm.startPrank(admin);
        operatorsRegistry.addValidators(
            0, fuzzedStoppedValidatorCount[0], genBytes((48 + 96) * uint256(fuzzedStoppedValidatorCount[0]))
        );
        operatorsRegistry.addValidators(
            1, fuzzedStoppedValidatorCount[1], genBytes((48 + 96) * uint256(fuzzedStoppedValidatorCount[1]))
        );
        operatorsRegistry.addValidators(
            2, fuzzedStoppedValidatorCount[2], genBytes((48 + 96) * uint256(fuzzedStoppedValidatorCount[2]))
        );
        operatorsRegistry.addValidators(
            3, fuzzedStoppedValidatorCount[3], genBytes((48 + 96) * uint256(fuzzedStoppedValidatorCount[3]))
        );
        operatorsRegistry.addValidators(
            4, fuzzedStoppedValidatorCount[4], genBytes((48 + 96) * uint256(fuzzedStoppedValidatorCount[4]))
        );
        vm.stopPrank();

        uint32[] memory limits = new uint32[](5);
        limits[0] = fuzzedStoppedValidatorCount[0];
        limits[1] = fuzzedStoppedValidatorCount[1];
        limits[2] = fuzzedStoppedValidatorCount[2];
        limits[3] = fuzzedStoppedValidatorCount[3];
        limits[4] = fuzzedStoppedValidatorCount[4];

        uint256[] memory operators = new uint256[](5);
        operators[0] = 0;
        operators[1] = 1;
        operators[2] = 2;
        operators[3] = 3;
        operators[4] = 4;

        vm.prank(admin);
        operatorsRegistry.setOperatorLimits(operators, limits, block.number);

        uint32 sum = uint32(fuzzedStoppedValidatorCount[0]) + fuzzedStoppedValidatorCount[1]
            + fuzzedStoppedValidatorCount[2] + fuzzedStoppedValidatorCount[3] + fuzzedStoppedValidatorCount[4];

        OperatorsRegistryInitializableV1(address(operatorsRegistry))
            .pickNextValidatorsToDepositFromActiveOperators(_createMultiAllocation(operators, limits));

        {
            uint32[] memory stoppedValidatorCount = new uint32[](6);

            stoppedValidatorCount[0] = sum;
            stoppedValidatorCount[1] = fuzzedStoppedValidatorCount[0];
            stoppedValidatorCount[2] = fuzzedStoppedValidatorCount[1];
            stoppedValidatorCount[3] = fuzzedStoppedValidatorCount[2];
            stoppedValidatorCount[4] = fuzzedStoppedValidatorCount[3];
            stoppedValidatorCount[5] = fuzzedStoppedValidatorCount[4];

            RiverMock(address(river)).sudoSetDepositedValidatorsCount(sum);

            OperatorsRegistryInitializableV1(address(operatorsRegistry))
                .sudoStoppedValidatorCounts(stoppedValidatorCount, sum);
        }
        {
            uint32[] memory stoppedValidatorCount = new uint32[](5);

            stoppedValidatorCount[0] = sum - fuzzedStoppedValidatorCount[4];
            stoppedValidatorCount[1] = fuzzedStoppedValidatorCount[0];
            stoppedValidatorCount[2] = fuzzedStoppedValidatorCount[1];
            stoppedValidatorCount[3] = fuzzedStoppedValidatorCount[2];
            stoppedValidatorCount[4] = fuzzedStoppedValidatorCount[3];

            vm.expectRevert(abi.encodeWithSignature("StoppedValidatorCountArrayShrinking()"));
            OperatorsRegistryInitializableV1(address(operatorsRegistry))
                .sudoStoppedValidatorCounts(stoppedValidatorCount, sum);
        }
    }

    function testStoppedValidatorCountAboveFundedCountOnNewArrayElements(uint8[5] memory fuzzedStoppedValidatorCount)
        external
    {
        fuzzedStoppedValidatorCount[0] = uint8(bound(fuzzedStoppedValidatorCount[0], 1, 50));
        fuzzedStoppedValidatorCount[1] = uint8(bound(fuzzedStoppedValidatorCount[1], 1, 50));
        fuzzedStoppedValidatorCount[2] = uint8(bound(fuzzedStoppedValidatorCount[2], 1, 50));
        fuzzedStoppedValidatorCount[3] = uint8(bound(fuzzedStoppedValidatorCount[3], 1, 50));
        fuzzedStoppedValidatorCount[4] = uint8(bound(fuzzedStoppedValidatorCount[4], 1, 50));

        vm.startPrank(admin);
        operatorsRegistry.addValidators(
            0, fuzzedStoppedValidatorCount[0], genBytes((48 + 96) * uint256(fuzzedStoppedValidatorCount[0]))
        );
        operatorsRegistry.addValidators(
            1, fuzzedStoppedValidatorCount[1], genBytes((48 + 96) * uint256(fuzzedStoppedValidatorCount[1]))
        );
        operatorsRegistry.addValidators(
            2, fuzzedStoppedValidatorCount[2], genBytes((48 + 96) * uint256(fuzzedStoppedValidatorCount[2]))
        );
        operatorsRegistry.addValidators(
            3, fuzzedStoppedValidatorCount[3], genBytes((48 + 96) * uint256(fuzzedStoppedValidatorCount[3]))
        );
        operatorsRegistry.addValidators(
            4, fuzzedStoppedValidatorCount[4], genBytes((48 + 96) * uint256(fuzzedStoppedValidatorCount[4]))
        );
        vm.stopPrank();

        uint32[] memory limits = new uint32[](5);
        limits[0] = fuzzedStoppedValidatorCount[0];
        limits[1] = fuzzedStoppedValidatorCount[1];
        limits[2] = fuzzedStoppedValidatorCount[2];
        limits[3] = fuzzedStoppedValidatorCount[3];
        limits[4] = fuzzedStoppedValidatorCount[4];

        uint256[] memory operators = new uint256[](5);
        operators[0] = 0;
        operators[1] = 1;
        operators[2] = 2;
        operators[3] = 3;
        operators[4] = 4;

        vm.prank(admin);
        operatorsRegistry.setOperatorLimits(operators, limits, block.number);

        uint32 sum = uint32(fuzzedStoppedValidatorCount[0]) + fuzzedStoppedValidatorCount[1]
            + fuzzedStoppedValidatorCount[2] + fuzzedStoppedValidatorCount[3] + fuzzedStoppedValidatorCount[4];

        OperatorsRegistryInitializableV1(address(operatorsRegistry))
            .pickNextValidatorsToDepositFromActiveOperators(_createAllocation(operators, limits));

        {
            uint32[] memory stoppedValidatorCount = new uint32[](5);

            stoppedValidatorCount[0] = sum - fuzzedStoppedValidatorCount[4];
            stoppedValidatorCount[1] = fuzzedStoppedValidatorCount[0];
            stoppedValidatorCount[2] = fuzzedStoppedValidatorCount[1];
            stoppedValidatorCount[3] = fuzzedStoppedValidatorCount[2];
            stoppedValidatorCount[4] = fuzzedStoppedValidatorCount[3];

            RiverMock(address(river)).sudoSetDepositedValidatorsCount(sum);

            OperatorsRegistryInitializableV1(address(operatorsRegistry))
                .sudoStoppedValidatorCounts(stoppedValidatorCount, sum);
        }
        {
            uint32[] memory stoppedValidatorCount = new uint32[](6);

            stoppedValidatorCount[0] = sum + 1;
            stoppedValidatorCount[1] = fuzzedStoppedValidatorCount[0];
            stoppedValidatorCount[2] = fuzzedStoppedValidatorCount[1];
            stoppedValidatorCount[3] = fuzzedStoppedValidatorCount[2];
            stoppedValidatorCount[4] = fuzzedStoppedValidatorCount[3];
            stoppedValidatorCount[5] = fuzzedStoppedValidatorCount[4] + 1;

            vm.expectRevert(
                abi.encodeWithSignature(
                    "StoppedValidatorCountAboveFundedCount(uint256,uint32,uint32)",
                    4,
                    fuzzedStoppedValidatorCount[4] + 1,
                    fuzzedStoppedValidatorCount[4]
                )
            );
            OperatorsRegistryInitializableV1(address(operatorsRegistry))
                .sudoStoppedValidatorCounts(stoppedValidatorCount, sum);
        }
    }

    function testDecreasingStoppedValidatorCountsSum(uint16[5] memory fuzzedStoppedValidatorCount) external {
        fuzzedStoppedValidatorCount[0] = uint8(bound(fuzzedStoppedValidatorCount[0], 1, 50));
        fuzzedStoppedValidatorCount[1] = uint8(bound(fuzzedStoppedValidatorCount[1], 1, 50));
        fuzzedStoppedValidatorCount[2] = uint8(bound(fuzzedStoppedValidatorCount[2], 1, 50));
        fuzzedStoppedValidatorCount[3] = uint8(bound(fuzzedStoppedValidatorCount[3], 1, 50));
        fuzzedStoppedValidatorCount[4] = uint8(bound(fuzzedStoppedValidatorCount[4], 1, 50));

        vm.startPrank(admin);
        operatorsRegistry.addValidators(
            0, fuzzedStoppedValidatorCount[0], genBytes((48 + 96) * uint256(fuzzedStoppedValidatorCount[0]))
        );
        operatorsRegistry.addValidators(
            1, fuzzedStoppedValidatorCount[1], genBytes((48 + 96) * uint256(fuzzedStoppedValidatorCount[1]))
        );
        operatorsRegistry.addValidators(
            2, fuzzedStoppedValidatorCount[2], genBytes((48 + 96) * uint256(fuzzedStoppedValidatorCount[2]))
        );
        operatorsRegistry.addValidators(
            3, fuzzedStoppedValidatorCount[3], genBytes((48 + 96) * uint256(fuzzedStoppedValidatorCount[3]))
        );
        operatorsRegistry.addValidators(
            4, fuzzedStoppedValidatorCount[4], genBytes((48 + 96) * uint256(fuzzedStoppedValidatorCount[4]))
        );
        vm.stopPrank();

        uint32[] memory limits = new uint32[](5);
        limits[0] = fuzzedStoppedValidatorCount[0];
        limits[1] = fuzzedStoppedValidatorCount[1];
        limits[2] = fuzzedStoppedValidatorCount[2];
        limits[3] = fuzzedStoppedValidatorCount[3];
        limits[4] = fuzzedStoppedValidatorCount[4];

        uint256[] memory operators = new uint256[](5);
        operators[0] = 0;
        operators[1] = 1;
        operators[2] = 2;
        operators[3] = 3;
        operators[4] = 4;

        vm.prank(admin);
        operatorsRegistry.setOperatorLimits(operators, limits, block.number);

        uint32 sum = uint32(fuzzedStoppedValidatorCount[0]) + fuzzedStoppedValidatorCount[1]
            + fuzzedStoppedValidatorCount[2] + fuzzedStoppedValidatorCount[3] + fuzzedStoppedValidatorCount[4];

        OperatorsRegistryInitializableV1(address(operatorsRegistry))
            .pickNextValidatorsToDepositFromActiveOperators(_createAllocation(operators, limits));

        uint32[] memory stoppedValidatorCount = new uint32[](6);

        stoppedValidatorCount[0] = sum;
        stoppedValidatorCount[1] = fuzzedStoppedValidatorCount[0];
        stoppedValidatorCount[2] = fuzzedStoppedValidatorCount[1];
        stoppedValidatorCount[3] = fuzzedStoppedValidatorCount[2];
        stoppedValidatorCount[4] = fuzzedStoppedValidatorCount[3];
        stoppedValidatorCount[5] = fuzzedStoppedValidatorCount[4];

        RiverMock(address(river)).sudoSetDepositedValidatorsCount(sum);

        OperatorsRegistryInitializableV1(address(operatorsRegistry))
            .sudoStoppedValidatorCounts(stoppedValidatorCount, sum);

        stoppedValidatorCount[0] -= 1;

        vm.expectRevert(abi.encodeWithSignature("InvalidStoppedValidatorCountsSum()"));
        OperatorsRegistryInitializableV1(address(operatorsRegistry))
            .sudoStoppedValidatorCounts(stoppedValidatorCount, sum);
    }

    function testStoppedValidatorCountHigherThanDepositCount() external {
        vm.startPrank(admin);
        operatorsRegistry.addValidators(0, 10, genBytes((48 + 96) * 10));
        operatorsRegistry.addValidators(1, 15, genBytes((48 + 96) * 15));
        operatorsRegistry.addValidators(2, 20, genBytes((48 + 96) * 20));
        operatorsRegistry.addValidators(3, 25, genBytes((48 + 96) * 25));
        operatorsRegistry.addValidators(4, 30, genBytes((48 + 96) * 30));
        vm.stopPrank();

        uint32[] memory limits = new uint32[](5);
        limits[0] = 10;
        limits[1] = 15;
        limits[2] = 20;
        limits[3] = 25;
        limits[4] = 30;

        uint256[] memory operators = new uint256[](5);
        operators[0] = 0;
        operators[1] = 1;
        operators[2] = 2;
        operators[3] = 3;
        operators[4] = 4;

        vm.prank(admin);
        operatorsRegistry.setOperatorLimits(operators, limits, block.number);

        OperatorsRegistryInitializableV1(address(operatorsRegistry))
            .pickNextValidatorsToDepositFromActiveOperators(_createAllocation(operators, limits));
        uint32[] memory stoppedValidatorCount = new uint32[](6);

        stoppedValidatorCount[1] = 10;
        stoppedValidatorCount[2] = 15;
        stoppedValidatorCount[3] = 20;
        stoppedValidatorCount[4] = 25;
        stoppedValidatorCount[5] = 30;
        stoppedValidatorCount[0] = 100;

        RiverMock(address(river)).sudoSetDepositedValidatorsCount(99);
        vm.expectRevert(abi.encodeWithSignature("StoppedValidatorCountsTooHigh()"));
        OperatorsRegistryInitializableV1(address(operatorsRegistry))
            .sudoStoppedValidatorCounts(stoppedValidatorCount, 99);
    }

    function testSetOperatorLimitsFail() public {
        uint256[] memory indexes = new uint256[](0);
        uint32[] memory limits = new uint32[](1);
        limits[0] = 1;
        uint32[] memory limitsZero = new uint32[](0);

        vm.startPrank(admin);

        vm.expectRevert(abi.encodeWithSignature("InvalidArrayLengths()"));
        operatorsRegistry.setOperatorLimits(indexes, limits, 0);

        vm.expectRevert(abi.encodeWithSignature("InvalidEmptyArray()"));
        operatorsRegistry.setOperatorLimits(indexes, limitsZero, 0);

        vm.stopPrank();
    }

    function testGetNextValidatorsToDepositFromActiveOperators() public {
        bytes[] memory rawKeys = new bytes[](5);

        rawKeys[0] = genBytes((48 + 96) * 10);
        rawKeys[1] = genBytes((48 + 96) * 10);
        rawKeys[2] = genBytes((48 + 96) * 10);
        rawKeys[3] = genBytes((48 + 96) * 10);
        rawKeys[4] = genBytes((48 + 96) * 10);

        vm.startPrank(admin);
        operatorsRegistry.addValidators(0, 10, rawKeys[0]);
        operatorsRegistry.addValidators(1, 10, rawKeys[1]);
        operatorsRegistry.addValidators(2, 10, rawKeys[2]);
        operatorsRegistry.addValidators(3, 10, rawKeys[3]);
        operatorsRegistry.addValidators(4, 10, rawKeys[4]);
        vm.stopPrank();

        uint32[] memory limits = new uint32[](5);
        limits[0] = 10;
        limits[1] = 10;
        limits[2] = 10;
        limits[3] = 10;
        limits[4] = 10;

        uint256[] memory operators = new uint256[](5);
        operators[0] = 0;
        operators[1] = 1;
        operators[2] = 2;
        operators[3] = 3;
        operators[4] = 4;

        vm.prank(admin);
        operatorsRegistry.setOperatorLimits(operators, limits, block.number);

        // Create valid allocation requesting exactly 10 validators from each operator
        IOperatorsRegistryV1.OperatorAllocation[] memory allocation = new IOperatorsRegistryV1.OperatorAllocation[](5);
        for (uint256 i = 0; i < 5; ++i) {
            allocation[i] = IOperatorsRegistryV1.OperatorAllocation({operatorIndex: i, validatorCount: 10});
        }

        (bytes[] memory publicKeys, bytes[] memory signatures) =
            operatorsRegistry.getNextValidatorsToDepositFromActiveOperators(allocation);

        // Verify keys are returned (50 total = 10 per operator * 5 operators)
        assert(publicKeys.length == 50);
        assert(signatures.length == 50);
    }

    function testGetNextValidatorsToDepositRevertsWhenExceedingLimit() public {
        bytes[] memory rawKeys = new bytes[](5);

        rawKeys[0] = genBytes((48 + 96) * 10);
        rawKeys[1] = genBytes((48 + 96) * 10);
        rawKeys[2] = genBytes((48 + 96) * 10);
        rawKeys[3] = genBytes((48 + 96) * 10);
        rawKeys[4] = genBytes((48 + 96) * 10);

        vm.startPrank(admin);
        operatorsRegistry.addValidators(0, 10, rawKeys[0]);
        operatorsRegistry.addValidators(1, 10, rawKeys[1]);
        operatorsRegistry.addValidators(2, 10, rawKeys[2]);
        operatorsRegistry.addValidators(3, 10, rawKeys[3]);
        operatorsRegistry.addValidators(4, 10, rawKeys[4]);
        vm.stopPrank();

        uint32[] memory limits = new uint32[](5);
        limits[0] = 10;
        limits[1] = 10;
        limits[2] = 10;
        limits[3] = 10;
        limits[4] = 10;

        uint256[] memory operators = new uint256[](5);
        operators[0] = 0;
        operators[1] = 1;
        operators[2] = 2;
        operators[3] = 3;
        operators[4] = 4;

        vm.prank(admin);
        operatorsRegistry.setOperatorLimits(operators, limits, block.number);

        // Create allocation requesting 11 validators from first operator (exceeds limit of 10)
        IOperatorsRegistryV1.OperatorAllocation[] memory allocation = new IOperatorsRegistryV1.OperatorAllocation[](1);
        allocation[0] = IOperatorsRegistryV1.OperatorAllocation({operatorIndex: 0, validatorCount: 11});

        vm.expectRevert(
            abi.encodeWithSignature("OperatorHasInsufficientFundableKeys(uint256,uint256,uint256)", 0, 11, 10)
        );
        operatorsRegistry.getNextValidatorsToDepositFromActiveOperators(allocation);
    }

    function testPickNextValidatorsToDepositRevertsInactiveOperator() public {
        bytes[] memory rawKeys = new bytes[](1);
        rawKeys[0] = genBytes((48 + 96) * 10);

        vm.startPrank(admin);
        operatorsRegistry.addValidators(0, 10, rawKeys[0]);
        vm.stopPrank();

        uint256[] memory operators = new uint256[](1);
        operators[0] = 0;
        uint32[] memory limits = new uint32[](1);
        limits[0] = 10;
        vm.startPrank(admin);
        operatorsRegistry.setOperatorLimits(operators, limits, block.number);
        operatorsRegistry.setOperatorStatus(2, false);
        vm.stopPrank();

        // Create allocation with operator index that doesn't exist (only operator 0 exists)
        IOperatorsRegistryV1.OperatorAllocation[] memory allocation = new IOperatorsRegistryV1.OperatorAllocation[](1);
        allocation[0] = IOperatorsRegistryV1.OperatorAllocation({operatorIndex: 2, validatorCount: 5});

        vm.prank(river);
        vm.expectRevert(abi.encodeWithSignature("InactiveOperator(uint256)", 2));
        operatorsRegistry.pickNextValidatorsToDepositFromActiveOperators(allocation);
    }

    function testPickNextValidatorsToDepositRevertsInactiveOperatorWithMultipleFundableOperators() public {
        // Setup: 3 operators all with keys and limits (all fundable)
        // This test ensures the loop in _updateCountOfPickedValidatorsForEachOperator
        // iterates through ALL operators (condition false each time) before reverting
        bytes memory tenKeys = genBytes((48 + 96) * 10);

        vm.startPrank(admin);
        operatorsRegistry.addValidators(0, 10, tenKeys);
        operatorsRegistry.addValidators(1, 10, tenKeys);
        operatorsRegistry.addValidators(2, 10, tenKeys);
        vm.stopPrank();

        uint256[] memory operators = new uint256[](3);
        operators[0] = 0;
        operators[1] = 1;
        operators[2] = 2;
        uint32[] memory limits = new uint32[](3);
        limits[0] = 10;
        limits[1] = 10;
        limits[2] = 10;
        vm.startPrank(admin);
        operatorsRegistry.setOperatorLimits(operators, limits, block.number);
        operatorsRegistry.setOperatorStatus(2, false);
        vm.stopPrank();
        // Request operator 99 which doesn't exist
        // This forces the loop to iterate through all 3 fundable operators (all false)
        // before reverting with InactiveOperator
        IOperatorsRegistryV1.OperatorAllocation[] memory allocation = new IOperatorsRegistryV1.OperatorAllocation[](1);
        allocation[0] = IOperatorsRegistryV1.OperatorAllocation({operatorIndex: 2, validatorCount: 5});

        vm.prank(river);
        vm.expectRevert(abi.encodeWithSignature("InactiveOperator(uint256)", 2));
        operatorsRegistry.pickNextValidatorsToDepositFromActiveOperators(allocation);
    }

    function testPickNextValidatorsToDepositFromActiveOperatorsRevertsWhenExceedingLimit() public {
        bytes[] memory rawKeys = new bytes[](5);

        rawKeys[0] = genBytes((48 + 96) * 10);
        rawKeys[1] = genBytes((48 + 96) * 10);
        rawKeys[2] = genBytes((48 + 96) * 10);
        rawKeys[3] = genBytes((48 + 96) * 10);
        rawKeys[4] = genBytes((48 + 96) * 10);

        vm.startPrank(admin);
        operatorsRegistry.addValidators(0, 10, rawKeys[0]);
        operatorsRegistry.addValidators(1, 10, rawKeys[1]);
        operatorsRegistry.addValidators(2, 10, rawKeys[2]);
        operatorsRegistry.addValidators(3, 10, rawKeys[3]);
        operatorsRegistry.addValidators(4, 10, rawKeys[4]);
        vm.stopPrank();

        uint32[] memory limits = new uint32[](5);
        limits[0] = 10;
        limits[1] = 10;
        limits[2] = 10;
        limits[3] = 10;
        limits[4] = 10;

        uint256[] memory operators = new uint256[](5);
        operators[0] = 0;
        operators[1] = 1;
        operators[2] = 2;
        operators[3] = 3;
        operators[4] = 4;

        vm.prank(admin);
        operatorsRegistry.setOperatorLimits(operators, limits, block.number);

        // Create allocation requesting 11 validators from first operator (exceeds limit of 10)
        uint32[] memory allocCounts = new uint32[](1);
        allocCounts[0] = 11;
        uint256[] memory allocOperators = new uint256[](1);
        allocOperators[0] = 0;

        vm.expectRevert(
            abi.encodeWithSignature("OperatorHasInsufficientFundableKeys(uint256,uint256,uint256)", 0, 11, 10)
        );
        OperatorsRegistryInitializableV1(address(operatorsRegistry))
            .pickNextValidatorsToDepositFromActiveOperators(_createAllocation(allocOperators, allocCounts));
    }

    function testGetNextValidatorsToDepositRevertsWithInactiveOperator() public {
        bytes memory rawKeys = genBytes((48 + 96) * 10);

        vm.startPrank(admin);
        operatorsRegistry.addValidators(0, 10, rawKeys);

        uint32[] memory limits = new uint32[](1);
        limits[0] = 10;
        uint256[] memory operators = new uint256[](1);
        operators[0] = 0;
        operatorsRegistry.setOperatorLimits(operators, limits, block.number);

        // Deactivate the operator
        operatorsRegistry.setOperatorStatus(0, false);
        vm.stopPrank();

        // Create allocation for inactive operator - reverts InactiveOperator
        IOperatorsRegistryV1.OperatorAllocation[] memory allocation = new IOperatorsRegistryV1.OperatorAllocation[](1);
        allocation[0] = IOperatorsRegistryV1.OperatorAllocation({operatorIndex: 0, validatorCount: 5});

        vm.expectRevert(abi.encodeWithSignature("InactiveOperator(uint256)", 0));
        operatorsRegistry.getNextValidatorsToDepositFromActiveOperators(allocation);
    }

    function testPickNextValidatorsToDepositRevertsWithInactiveOperator() public {
        bytes memory rawKeys = genBytes((48 + 96) * 10);

        vm.startPrank(admin);
        operatorsRegistry.addValidators(0, 10, rawKeys);

        uint32[] memory limits = new uint32[](1);
        limits[0] = 10;
        uint256[] memory operators = new uint256[](1);
        operators[0] = 0;
        operatorsRegistry.setOperatorLimits(operators, limits, block.number);

        // Deactivate the operator
        operatorsRegistry.setOperatorStatus(0, false);
        vm.stopPrank();

        // Create allocation for inactive operator - reverts InactiveOperator
        IOperatorsRegistryV1.OperatorAllocation[] memory allocation = new IOperatorsRegistryV1.OperatorAllocation[](1);
        allocation[0] = IOperatorsRegistryV1.OperatorAllocation({operatorIndex: 0, validatorCount: 5});

        vm.prank(river);
        vm.expectRevert(abi.encodeWithSignature("InactiveOperator(uint256)", 0));
        OperatorsRegistryInitializableV1(address(operatorsRegistry))
            .pickNextValidatorsToDepositFromActiveOperators(allocation);
    }

    function testGetNextValidatorsToDepositRevertsDuplicateOperatorIndex() public {
        bytes[] memory rawKeys = new bytes[](2);
        rawKeys[0] = genBytes((48 + 96) * 10);
        rawKeys[1] = genBytes((48 + 96) * 10);

        vm.startPrank(admin);
        operatorsRegistry.addValidators(0, 10, rawKeys[0]);
        operatorsRegistry.addValidators(1, 10, rawKeys[1]);
        vm.stopPrank();

        uint256[] memory operators = new uint256[](2);
        operators[0] = 0;
        operators[1] = 1;
        uint32[] memory limits = new uint32[](2);
        limits[0] = 10;
        limits[1] = 10;
        vm.prank(admin);
        operatorsRegistry.setOperatorLimits(operators, limits, block.number);

        // Create allocation with duplicate operator index
        IOperatorsRegistryV1.OperatorAllocation[] memory allocation = new IOperatorsRegistryV1.OperatorAllocation[](2);
        allocation[0] = IOperatorsRegistryV1.OperatorAllocation({operatorIndex: 0, validatorCount: 5});
        allocation[1] = IOperatorsRegistryV1.OperatorAllocation({operatorIndex: 0, validatorCount: 5}); // Duplicate!

        vm.expectRevert(abi.encodeWithSignature("UnorderedOperatorList()"));
        operatorsRegistry.getNextValidatorsToDepositFromActiveOperators(allocation);
    }

    function testGetNextValidatorsToDepositRevertsUnorderedOperatorIndex() public {
        bytes[] memory rawKeys = new bytes[](2);
        rawKeys[0] = genBytes((48 + 96) * 10);
        rawKeys[1] = genBytes((48 + 96) * 10);

        vm.startPrank(admin);
        operatorsRegistry.addValidators(0, 10, rawKeys[0]);
        operatorsRegistry.addValidators(1, 10, rawKeys[1]);
        vm.stopPrank();

        uint256[] memory operators = new uint256[](2);
        operators[0] = 0;
        operators[1] = 1;
        uint32[] memory limits = new uint32[](2);
        limits[0] = 10;
        limits[1] = 10;
        vm.prank(admin);
        operatorsRegistry.setOperatorLimits(operators, limits, block.number);

        // Create allocation with unordered operator indices (1 before 0)
        IOperatorsRegistryV1.OperatorAllocation[] memory allocation = new IOperatorsRegistryV1.OperatorAllocation[](2);
        allocation[0] = IOperatorsRegistryV1.OperatorAllocation({operatorIndex: 1, validatorCount: 5});
        allocation[1] = IOperatorsRegistryV1.OperatorAllocation({operatorIndex: 0, validatorCount: 5}); // Wrong order!

        vm.expectRevert(abi.encodeWithSignature("UnorderedOperatorList()"));
        operatorsRegistry.getNextValidatorsToDepositFromActiveOperators(allocation);
    }

    function testPickNextValidatorsToDepositRevertsDuplicateOperatorIndex() public {
        bytes[] memory rawKeys = new bytes[](2);
        rawKeys[0] = genBytes((48 + 96) * 10);
        rawKeys[1] = genBytes((48 + 96) * 10);

        vm.startPrank(admin);
        operatorsRegistry.addValidators(0, 10, rawKeys[0]);
        operatorsRegistry.addValidators(1, 10, rawKeys[1]);
        vm.stopPrank();

        uint256[] memory operators = new uint256[](2);
        operators[0] = 0;
        operators[1] = 1;
        uint32[] memory limits = new uint32[](2);
        limits[0] = 10;
        limits[1] = 10;
        vm.prank(admin);
        operatorsRegistry.setOperatorLimits(operators, limits, block.number);

        // Create allocation with duplicate operator index
        IOperatorsRegistryV1.OperatorAllocation[] memory allocation = new IOperatorsRegistryV1.OperatorAllocation[](2);
        allocation[0] = IOperatorsRegistryV1.OperatorAllocation({operatorIndex: 0, validatorCount: 5});
        allocation[1] = IOperatorsRegistryV1.OperatorAllocation({operatorIndex: 0, validatorCount: 5}); // Duplicate!

        vm.prank(river);
        vm.expectRevert(abi.encodeWithSignature("UnorderedOperatorList()"));
        operatorsRegistry.pickNextValidatorsToDepositFromActiveOperators(allocation);
    }

    function testPickNextValidatorsToDepositRevertsUnorderedOperatorIndex() public {
        bytes[] memory rawKeys = new bytes[](2);
        rawKeys[0] = genBytes((48 + 96) * 10);
        rawKeys[1] = genBytes((48 + 96) * 10);

        vm.startPrank(admin);
        operatorsRegistry.addValidators(0, 10, rawKeys[0]);
        operatorsRegistry.addValidators(1, 10, rawKeys[1]);
        vm.stopPrank();

        uint256[] memory operators = new uint256[](2);
        operators[0] = 0;
        operators[1] = 1;
        uint32[] memory limits = new uint32[](2);
        limits[0] = 10;
        limits[1] = 10;
        vm.prank(admin);
        operatorsRegistry.setOperatorLimits(operators, limits, block.number);

        // Create allocation with unordered operator indices (1 before 0)
        IOperatorsRegistryV1.OperatorAllocation[] memory allocation = new IOperatorsRegistryV1.OperatorAllocation[](2);
        allocation[0] = IOperatorsRegistryV1.OperatorAllocation({operatorIndex: 1, validatorCount: 5});
        allocation[1] = IOperatorsRegistryV1.OperatorAllocation({operatorIndex: 0, validatorCount: 5}); // Wrong order!

        vm.prank(river);
        vm.expectRevert(abi.encodeWithSignature("UnorderedOperatorList()"));
        operatorsRegistry.pickNextValidatorsToDepositFromActiveOperators(allocation);
    }

    function testGetNextValidatorsToDepositRevertsZeroValidatorCount() public {
        bytes[] memory rawKeys = new bytes[](1);
        rawKeys[0] = genBytes((48 + 96) * 10);

        vm.startPrank(admin);
        operatorsRegistry.addValidators(0, 10, rawKeys[0]);
        vm.stopPrank();

        uint256[] memory operators = new uint256[](1);
        operators[0] = 0;
        uint32[] memory limits = new uint32[](1);
        limits[0] = 10;
        vm.prank(admin);
        operatorsRegistry.setOperatorLimits(operators, limits, block.number);

        // Create allocation with zero validator count
        IOperatorsRegistryV1.OperatorAllocation[] memory allocation = new IOperatorsRegistryV1.OperatorAllocation[](1);
        allocation[0] = IOperatorsRegistryV1.OperatorAllocation({operatorIndex: 0, validatorCount: 0});

        vm.expectRevert(abi.encodeWithSignature("AllocationWithZeroValidatorCount()"));
        operatorsRegistry.getNextValidatorsToDepositFromActiveOperators(allocation);
    }

    function testPickNextValidatorsToDepositRevertsZeroValidatorCount() public {
        bytes[] memory rawKeys = new bytes[](1);
        rawKeys[0] = genBytes((48 + 96) * 10);

        vm.startPrank(admin);
        operatorsRegistry.addValidators(0, 10, rawKeys[0]);
        vm.stopPrank();

        uint256[] memory operators = new uint256[](1);
        operators[0] = 0;
        uint32[] memory limits = new uint32[](1);
        limits[0] = 10;
        vm.prank(admin);
        operatorsRegistry.setOperatorLimits(operators, limits, block.number);

        // Create allocation with zero validator count
        IOperatorsRegistryV1.OperatorAllocation[] memory allocation = new IOperatorsRegistryV1.OperatorAllocation[](1);
        allocation[0] = IOperatorsRegistryV1.OperatorAllocation({operatorIndex: 0, validatorCount: 0});

        vm.prank(river);
        vm.expectRevert(abi.encodeWithSignature("AllocationWithZeroValidatorCount()"));
        operatorsRegistry.pickNextValidatorsToDepositFromActiveOperators(allocation);
    }

    function testGetNextValidatorsToDepositRevertsInactiveOperator() public {
        bytes[] memory rawKeys = new bytes[](1);
        rawKeys[0] = genBytes((48 + 96) * 10);

        vm.startPrank(admin);
        operatorsRegistry.addValidators(0, 10, rawKeys[0]);

        uint256[] memory operators = new uint256[](1);
        operators[0] = 0;
        uint32[] memory limits = new uint32[](1);
        limits[0] = 10;
        operatorsRegistry.setOperatorLimits(operators, limits, block.number);
        operatorsRegistry.setOperatorStatus(2, false);
        vm.stopPrank();

        IOperatorsRegistryV1.OperatorAllocation[] memory allocation = new IOperatorsRegistryV1.OperatorAllocation[](1);
        allocation[0] = IOperatorsRegistryV1.OperatorAllocation({operatorIndex: 2, validatorCount: 5});

        vm.expectRevert(abi.encodeWithSignature("InactiveOperator(uint256)", 2));
        operatorsRegistry.getNextValidatorsToDepositFromActiveOperators(allocation);
    }

    function testGetNextValidatorsToDepositRevertsWithOperatorNotFound() public {
        bytes[] memory rawKeys = new bytes[](1);
        rawKeys[0] = genBytes((48 + 96) * 10);

        vm.startPrank(admin);
        operatorsRegistry.addValidators(0, 10, rawKeys[0]);
        vm.stopPrank();

        uint256[] memory operators = new uint256[](1);
        operators[0] = 0;
        uint32[] memory limits = new uint32[](1);
        limits[0] = 10;
        vm.prank(admin);
        operatorsRegistry.setOperatorLimits(operators, limits, block.number);

        // Create allocation with operator index that doesn't exist (only operator 0 exists)
        IOperatorsRegistryV1.OperatorAllocation[] memory allocation = new IOperatorsRegistryV1.OperatorAllocation[](1);
        allocation[0] = IOperatorsRegistryV1.OperatorAllocation({operatorIndex: 99, validatorCount: 5});

        vm.expectRevert(abi.encodeWithSignature("OperatorNotFound(uint256)", 99));
        operatorsRegistry.getNextValidatorsToDepositFromActiveOperators(allocation);
    }

    function testPickNextValidatorsToDepositRevertsWithOperatorNotFound() public {
        bytes[] memory rawKeys = new bytes[](1);
        rawKeys[0] = genBytes((48 + 96) * 10);

        vm.startPrank(admin);
        operatorsRegistry.addValidators(0, 10, rawKeys[0]);
        vm.stopPrank();

        uint256[] memory operators = new uint256[](1);
        operators[0] = 0;
        uint32[] memory limits = new uint32[](1);
        limits[0] = 10;
        vm.prank(admin);
        operatorsRegistry.setOperatorLimits(operators, limits, block.number);

        // Create allocation with operator index that doesn't exist (only operator 0 exists)
        IOperatorsRegistryV1.OperatorAllocation[] memory allocation = new IOperatorsRegistryV1.OperatorAllocation[](1);
        allocation[0] = IOperatorsRegistryV1.OperatorAllocation({operatorIndex: 99, validatorCount: 5});

        vm.prank(river);
        vm.expectRevert(abi.encodeWithSignature("OperatorNotFound(uint256)", 99));
        operatorsRegistry.pickNextValidatorsToDepositFromActiveOperators(allocation);
    }

    function testPickNextValidatorsToDepositRevertsUnkonwnOperatorWithMultipleFundableOperators() public {
        // Setup: 3 operators all with keys and limits (all fundable)
        // This test ensures the loop in _updateCountOfPickedValidatorsForEachOperator
        // iterates through ALL operators (condition false each time) before reverting
        bytes memory tenKeys = genBytes((48 + 96) * 10);

        vm.startPrank(admin);
        operatorsRegistry.addValidators(0, 10, tenKeys);
        operatorsRegistry.addValidators(1, 10, tenKeys);
        operatorsRegistry.addValidators(2, 10, tenKeys);
        vm.stopPrank();

        uint256[] memory operators = new uint256[](3);
        operators[0] = 0;
        operators[1] = 1;
        operators[2] = 2;
        uint32[] memory limits = new uint32[](3);
        limits[0] = 10;
        limits[1] = 10;
        limits[2] = 10;
        vm.prank(admin);
        operatorsRegistry.setOperatorLimits(operators, limits, block.number);

        // Request operator 99 which doesn't exist - reverts OperatorNotFound
        IOperatorsRegistryV1.OperatorAllocation[] memory allocation = new IOperatorsRegistryV1.OperatorAllocation[](1);
        allocation[0] = IOperatorsRegistryV1.OperatorAllocation({operatorIndex: 99, validatorCount: 5});

        vm.prank(river);
        vm.expectRevert(abi.encodeWithSignature("OperatorNotFound(uint256)", 99));
        operatorsRegistry.pickNextValidatorsToDepositFromActiveOperators(allocation);
    }

    function testVersion() external {
        assertEq(operatorsRegistry.version(), "1.2.1");
    }

    function testGetNextValidatorsToDepositFromActiveOperatorsRevertsWithEmptyAllocation() public {
        // Create an empty allocation array - returns empty arrays
        IOperatorsRegistryV1.OperatorAllocation[] memory allocation = new IOperatorsRegistryV1.OperatorAllocation[](0);

        vm.expectRevert(abi.encodeWithSignature("InvalidEmptyArray()"));
        operatorsRegistry.getNextValidatorsToDepositFromActiveOperators(allocation);
    }

    /// @notice Tests OperatorIgnoredExitRequests when getNextValidatorsToDepositFromActiveOperators is called
    /// for an operator that has requested exits but has not yet had enough validators reported as stopped
    function testGetNextValidatorsToDepositRevertsOperatorIgnoredExitRequests() public {
        bytes memory rawKeys = genBytes((48 + 96) * 10);

        vm.startPrank(admin);
        operatorsRegistry.addValidators(0, 10, rawKeys);
        vm.stopPrank();

        uint256[] memory operators = new uint256[](1);
        operators[0] = 0;
        uint32[] memory limits = new uint32[](1);
        limits[0] = 10;
        vm.prank(admin);
        operatorsRegistry.setOperatorLimits(operators, limits, block.number);

        // Set requestedExits without reporting stopped counts (stopped count stays 0)
        OperatorsRegistryInitializableV1(address(operatorsRegistry)).sudoExitRequests(0, 3);

        IOperatorsRegistryV1.OperatorAllocation[] memory allocation = new IOperatorsRegistryV1.OperatorAllocation[](1);
        allocation[0] = IOperatorsRegistryV1.OperatorAllocation({operatorIndex: 0, validatorCount: 1});

        vm.expectRevert(abi.encodeWithSignature("OperatorIgnoredExitRequests(uint256)", 0));
        operatorsRegistry.getNextValidatorsToDepositFromActiveOperators(allocation);
    }

    /// @notice Tests OperatorIgnoredExitRequests when pickNextValidatorsToDeposit is called
    /// for an operator that has requested exits but has not yet had enough validators reported as stopped
    function testPickNextValidatorsToDepositRevertsOperatorIgnoredExitRequests() public {
        bytes memory rawKeys = genBytes((48 + 96) * 10);

        vm.startPrank(admin);
        operatorsRegistry.addValidators(0, 10, rawKeys);
        vm.stopPrank();

        uint256[] memory operators = new uint256[](1);
        operators[0] = 0;
        uint32[] memory limits = new uint32[](1);
        limits[0] = 10;
        vm.prank(admin);
        operatorsRegistry.setOperatorLimits(operators, limits, block.number);

        // Set requestedExits without reporting stopped counts (stopped count stays 0)
        OperatorsRegistryInitializableV1(address(operatorsRegistry)).sudoExitRequests(0, 3);

        IOperatorsRegistryV1.OperatorAllocation[] memory allocation = new IOperatorsRegistryV1.OperatorAllocation[](1);
        allocation[0] = IOperatorsRegistryV1.OperatorAllocation({operatorIndex: 0, validatorCount: 1});

        vm.prank(river);
        vm.expectRevert(abi.encodeWithSignature("OperatorIgnoredExitRequests(uint256)", 0));
        operatorsRegistry.pickNextValidatorsToDepositFromActiveOperators(allocation);
    }

    /// @notice Tests OperatorIgnoredExitRequests when stopped validator count is reported but below requested exits
    function testOperatorIgnoredExitRequestsWhenStoppedCountBelowRequested() public {
        bytes memory rawKeys = genBytes((48 + 96) * 10);

        vm.startPrank(admin);
        operatorsRegistry.addValidators(0, 10, rawKeys);
        vm.stopPrank();

        uint256[] memory operators = new uint256[](1);
        operators[0] = 0;
        uint32[] memory limits = new uint32[](1);
        limits[0] = 10;
        vm.prank(admin);
        operatorsRegistry.setOperatorLimits(operators, limits, block.number);

        // Fund 5 validators so we can later report up to 5 stopped
        uint256[] memory fundOps = new uint256[](1);
        fundOps[0] = 0;
        uint32[] memory fundCounts = new uint32[](1);
        fundCounts[0] = 5;
        vm.prank(river);
        operatorsRegistry.pickNextValidatorsToDepositFromActiveOperators(_createAllocation(fundOps, fundCounts));

        OperatorsRegistryInitializableV1(address(operatorsRegistry)).sudoExitRequests(0, 5);

        // Report only 2 stopped for operator 0 (requested was 5)
        uint32[] memory stoppedValidatorCounts = new uint32[](2);
        stoppedValidatorCounts[0] = 2;
        stoppedValidatorCounts[1] = 2;
        vm.prank(river);
        operatorsRegistry.reportStoppedValidatorCounts(stoppedValidatorCounts, 5);

        IOperatorsRegistryV1.OperatorAllocation[] memory allocation = new IOperatorsRegistryV1.OperatorAllocation[](1);
        allocation[0] = IOperatorsRegistryV1.OperatorAllocation({operatorIndex: 0, validatorCount: 1});

        vm.expectRevert(abi.encodeWithSignature("OperatorIgnoredExitRequests(uint256)", 0));
        operatorsRegistry.getNextValidatorsToDepositFromActiveOperators(allocation);
    }

    // ============ NEW TESTS FOR BYOV COVERAGE ============

    /// @notice Tests OperatorHasInsufficientFundableKeys when some keys are already funded
    /// This covers the case where availableKeys = limit - funded is less than requested
    function testOperatorHasInsufficientFundableKeysWithPartialFunding() public {
        bytes memory rawKeys = genBytes((48 + 96) * 10);

        vm.startPrank(admin);
        operatorsRegistry.addValidators(0, 10, rawKeys);

        uint256[] memory operators = new uint256[](1);
        operators[0] = 0;
        uint32[] memory limits = new uint32[](1);
        limits[0] = 10;
        operatorsRegistry.setOperatorLimits(operators, limits, block.number);
        vm.stopPrank();

        // First, fund 7 validators so only 3 remain available
        IOperatorsRegistryV1.OperatorAllocation[] memory firstAllocation =
            new IOperatorsRegistryV1.OperatorAllocation[](1);
        firstAllocation[0] = IOperatorsRegistryV1.OperatorAllocation({operatorIndex: 0, validatorCount: 7});

        vm.prank(river);
        operatorsRegistry.pickNextValidatorsToDepositFromActiveOperators(firstAllocation);

        // Verify operator now has 7 funded
        OperatorsV2.Operator memory op = operatorsRegistry.getOperator(0);
        assertEq(op.funded, 7, "Expected 7 funded validators");

        // Now try to allocate 5 more (only 3 available: limit=10 - funded=7 = 3)
        IOperatorsRegistryV1.OperatorAllocation[] memory secondAllocation =
            new IOperatorsRegistryV1.OperatorAllocation[](1);
        secondAllocation[0] = IOperatorsRegistryV1.OperatorAllocation({operatorIndex: 0, validatorCount: 5});

        vm.expectRevert(
            abi.encodeWithSignature("OperatorHasInsufficientFundableKeys(uint256,uint256,uint256)", 0, 5, 3)
        );
        operatorsRegistry.getNextValidatorsToDepositFromActiveOperators(secondAllocation);
    }

    /// @notice Tests InactiveOperator error when operator exists but has been deactivated
    /// This is different from non-existent operator - the operator exists but is inactive
    function testInactiveOperatorWhenOperatorExistsButDeactivated() public {
        bytes memory rawKeys = genBytes((48 + 96) * 10);

        vm.startPrank(admin);
        operatorsRegistry.addValidators(0, 10, rawKeys);

        uint256[] memory operators = new uint256[](1);
        operators[0] = 0;
        uint32[] memory limits = new uint32[](1);
        limits[0] = 10;
        operatorsRegistry.setOperatorLimits(operators, limits, block.number);

        // Deactivate the operator
        operatorsRegistry.setOperatorStatus(0, false);
        vm.stopPrank();

        // Try to allocate to the deactivated operator - should revert InactiveOperator
        IOperatorsRegistryV1.OperatorAllocation[] memory allocation = new IOperatorsRegistryV1.OperatorAllocation[](1);
        allocation[0] = IOperatorsRegistryV1.OperatorAllocation({operatorIndex: 0, validatorCount: 5});

        vm.expectRevert(abi.encodeWithSignature("InactiveOperator(uint256)", 0));
        operatorsRegistry.getNextValidatorsToDepositFromActiveOperators(allocation);
    }

    /// @notice Tests that pickNextValidatorsToDeposit correctly updates funded count and emits FundedValidatorKeys
    function testPickNextValidatorsEmitsFundedValidatorKeysEvent() public {
        bytes memory rawKeys = genBytes((48 + 96) * 5);

        vm.startPrank(admin);
        operatorsRegistry.addValidators(0, 5, rawKeys);

        uint256[] memory operators = new uint256[](1);
        operators[0] = 0;
        uint32[] memory limits = new uint32[](1);
        limits[0] = 5;
        operatorsRegistry.setOperatorLimits(operators, limits, block.number);
        vm.stopPrank();

        IOperatorsRegistryV1.OperatorAllocation[] memory allocation = new IOperatorsRegistryV1.OperatorAllocation[](1);
        allocation[0] = IOperatorsRegistryV1.OperatorAllocation({operatorIndex: 0, validatorCount: 3});

        // Expect the FundedValidatorKeys event to be emitted with false (not migration)
        vm.expectEmit(true, false, false, false);
        emit FundedValidatorKeys(0, new bytes[](3), false);

        vm.prank(river);
        (bytes[] memory publicKeys, bytes[] memory signatures) =
            operatorsRegistry.pickNextValidatorsToDepositFromActiveOperators(allocation);

        assertEq(publicKeys.length, 3, "Expected 3 public keys");
        assertEq(signatures.length, 3, "Expected 3 signatures");

        // Verify funded count was updated
        OperatorsV2.Operator memory op = operatorsRegistry.getOperator(0);
        assertEq(op.funded, 3, "Expected funded to be updated to 3");
    }

    /// @notice Tests multi-operator allocation with correct key ordering
    function testMultiOperatorAllocationKeyOrdering() public {
        bytes memory rawKeys0 = genBytes((48 + 96) * 5);
        bytes memory rawKeys1 = genBytes((48 + 96) * 5);

        vm.startPrank(admin);
        operatorsRegistry.addValidators(0, 5, rawKeys0);
        operatorsRegistry.addValidators(1, 5, rawKeys1);

        uint256[] memory operators = new uint256[](2);
        operators[0] = 0;
        operators[1] = 1;
        uint32[] memory limits = new uint32[](2);
        limits[0] = 5;
        limits[1] = 5;
        operatorsRegistry.setOperatorLimits(operators, limits, block.number);
        vm.stopPrank();

        // Allocate 2 from operator 0 and 3 from operator 1
        IOperatorsRegistryV1.OperatorAllocation[] memory allocation = new IOperatorsRegistryV1.OperatorAllocation[](2);
        allocation[0] = IOperatorsRegistryV1.OperatorAllocation({operatorIndex: 0, validatorCount: 2});
        allocation[1] = IOperatorsRegistryV1.OperatorAllocation({operatorIndex: 1, validatorCount: 3});

        (bytes[] memory publicKeys, bytes[] memory signatures) =
            operatorsRegistry.getNextValidatorsToDepositFromActiveOperators(allocation);

        // Should return 5 total keys (2 + 3)
        assertEq(publicKeys.length, 5, "Expected 5 public keys total");
        assertEq(signatures.length, 5, "Expected 5 signatures total");

        // Combined output must follow allocation order: first 2 from operator 0, then 3 from operator 1
        uint256 keyLen = 48;
        uint256 sigLen = 96;
        uint256 validatorSize = keyLen + sigLen;

        for (uint256 i = 0; i < 2; ++i) {
            uint256 offset = i * validatorSize;
            assertEq(
                keccak256(publicKeys[i]),
                keccak256(LibBytes.slice(rawKeys0, offset, keyLen)),
                "Public key at index must match operator 0 key order"
            );
            assertEq(
                keccak256(signatures[i]),
                keccak256(LibBytes.slice(rawKeys0, offset + keyLen, sigLen)),
                "Signature at index must match operator 0 key order"
            );
        }
        for (uint256 i = 0; i < 3; ++i) {
            uint256 offset = i * validatorSize;
            assertEq(
                keccak256(publicKeys[2 + i]),
                keccak256(LibBytes.slice(rawKeys1, offset, keyLen)),
                "Public key at index must match operator 1 key order"
            );
            assertEq(
                keccak256(signatures[2 + i]),
                keccak256(LibBytes.slice(rawKeys1, offset + keyLen, sigLen)),
                "Signature at index must match operator 1 key order"
            );
        }
    }

    /// @notice Tests that combined validator keys from multi-operator allocation match allocations[] order
    /// (first all keys for allocations[0].operatorIndex, then all for allocations[1], etc.)
    function testMultiOperatorCombinedKeysOrderMatchesAllocationsArray() public {
        bytes memory rawKeys0 = genBytes((48 + 96) * 5);
        bytes memory rawKeys1 = genBytes((48 + 96) * 5);
        bytes memory rawKeys2 = genBytes((48 + 96) * 5);

        vm.startPrank(admin);
        operatorsRegistry.addValidators(0, 5, rawKeys0);
        operatorsRegistry.addValidators(1, 5, rawKeys1);
        operatorsRegistry.addValidators(2, 5, rawKeys2);

        uint256[] memory operators = new uint256[](3);
        operators[0] = 0;
        operators[1] = 1;
        operators[2] = 2;
        uint32[] memory limits = new uint32[](3);
        limits[0] = 5;
        limits[1] = 5;
        limits[2] = 5;
        operatorsRegistry.setOperatorLimits(operators, limits, block.number);
        vm.stopPrank();

        // Allocations: 1 from op0, 2 from op1, 2 from op2 (order must be preserved in combined output)
        IOperatorsRegistryV1.OperatorAllocation[] memory allocation = new IOperatorsRegistryV1.OperatorAllocation[](3);
        allocation[0] = IOperatorsRegistryV1.OperatorAllocation({operatorIndex: 0, validatorCount: 1});
        allocation[1] = IOperatorsRegistryV1.OperatorAllocation({operatorIndex: 1, validatorCount: 2});
        allocation[2] = IOperatorsRegistryV1.OperatorAllocation({operatorIndex: 2, validatorCount: 2});

        (bytes[] memory publicKeys, bytes[] memory signatures) =
            operatorsRegistry.getNextValidatorsToDepositFromActiveOperators(allocation);

        assertEq(publicKeys.length, 5, "Expected 5 keys total (1+2+2)");
        assertEq(signatures.length, 5, "Expected 5 signatures total");

        assertEq(
            keccak256(publicKeys[0]),
            keccak256(LibBytes.slice(rawKeys0, 0, 48)),
            "Key 0 must be first key of operator 0"
        );
        assertEq(
            keccak256(signatures[0]),
            keccak256(LibBytes.slice(rawKeys0, 48, 96)),
            "Sig 0 must be first sig of operator 0"
        );

        assertEq(
            keccak256(publicKeys[1]),
            keccak256(LibBytes.slice(rawKeys1, 0, 48)),
            "Key 1 must be first key of operator 1"
        );
        assertEq(keccak256(signatures[1]), keccak256(LibBytes.slice(rawKeys1, 48, 96)), "Sig 1 must match operator 1");
        assertEq(
            keccak256(publicKeys[2]),
            keccak256(LibBytes.slice(rawKeys1, 144, 48)),
            "Key 2 must be second key of operator 1"
        );
        assertEq(keccak256(signatures[2]), keccak256(LibBytes.slice(rawKeys1, 192, 96)), "Sig 2 must match operator 1");

        assertEq(
            keccak256(publicKeys[3]),
            keccak256(LibBytes.slice(rawKeys2, 0, 48)),
            "Key 3 must be first key of operator 2"
        );
        assertEq(keccak256(signatures[3]), keccak256(LibBytes.slice(rawKeys2, 48, 96)), "Sig 3 must match operator 2");
        assertEq(
            keccak256(publicKeys[4]),
            keccak256(LibBytes.slice(rawKeys2, 144, 48)),
            "Key 4 must be second key of operator 2"
        );
        assertEq(keccak256(signatures[4]), keccak256(LibBytes.slice(rawKeys2, 192, 96)), "Sig 4 must match operator 2");
    }

    /// @notice Tests that sequential allocations to the same operator work correctly
    function testSequentialAllocationsToSameOperator() public {
        bytes memory rawKeys = genBytes((48 + 96) * 10);

        vm.startPrank(admin);
        operatorsRegistry.addValidators(0, 10, rawKeys);

        uint256[] memory operators = new uint256[](1);
        operators[0] = 0;
        uint32[] memory limits = new uint32[](1);
        limits[0] = 10;
        operatorsRegistry.setOperatorLimits(operators, limits, block.number);
        vm.stopPrank();

        // First allocation: fund 3 validators
        IOperatorsRegistryV1.OperatorAllocation[] memory allocation1 = new IOperatorsRegistryV1.OperatorAllocation[](1);
        allocation1[0] = IOperatorsRegistryV1.OperatorAllocation({operatorIndex: 0, validatorCount: 3});

        vm.prank(river);
        operatorsRegistry.pickNextValidatorsToDepositFromActiveOperators(allocation1);

        OperatorsV2.Operator memory op = operatorsRegistry.getOperator(0);
        assertEq(op.funded, 3, "Expected 3 funded after first allocation");

        // Second allocation: fund 4 more validators
        IOperatorsRegistryV1.OperatorAllocation[] memory allocation2 = new IOperatorsRegistryV1.OperatorAllocation[](1);
        allocation2[0] = IOperatorsRegistryV1.OperatorAllocation({operatorIndex: 0, validatorCount: 4});

        vm.prank(river);
        operatorsRegistry.pickNextValidatorsToDepositFromActiveOperators(allocation2);

        op = operatorsRegistry.getOperator(0);
        assertEq(op.funded, 7, "Expected 7 funded after second allocation");

        // Third allocation: try to fund exactly the remaining 3
        IOperatorsRegistryV1.OperatorAllocation[] memory allocation3 = new IOperatorsRegistryV1.OperatorAllocation[](1);
        allocation3[0] = IOperatorsRegistryV1.OperatorAllocation({operatorIndex: 0, validatorCount: 3});

        vm.prank(river);
        operatorsRegistry.pickNextValidatorsToDepositFromActiveOperators(allocation3);

        op = operatorsRegistry.getOperator(0);
        assertEq(op.funded, 10, "Expected 10 funded after third allocation (fully funded)");
    }

    /// @notice Tests allocation when operator has no available keys (limit == funded)
    function testAllocationWhenOperatorFullyFunded() public {
        bytes memory rawKeys = genBytes((48 + 96) * 5);

        vm.startPrank(admin);
        operatorsRegistry.addValidators(0, 5, rawKeys);

        uint256[] memory operators = new uint256[](1);
        operators[0] = 0;
        uint32[] memory limits = new uint32[](1);
        limits[0] = 5;
        operatorsRegistry.setOperatorLimits(operators, limits, block.number);
        vm.stopPrank();

        // Fund all 5 validators
        IOperatorsRegistryV1.OperatorAllocation[] memory allocation1 = new IOperatorsRegistryV1.OperatorAllocation[](1);
        allocation1[0] = IOperatorsRegistryV1.OperatorAllocation({operatorIndex: 0, validatorCount: 5});

        vm.prank(river);
        operatorsRegistry.pickNextValidatorsToDepositFromActiveOperators(allocation1);

        // Now try to allocate more - should revert since operator has no available keys (limit == funded)
        IOperatorsRegistryV1.OperatorAllocation[] memory allocation2 = new IOperatorsRegistryV1.OperatorAllocation[](1);
        allocation2[0] = IOperatorsRegistryV1.OperatorAllocation({operatorIndex: 0, validatorCount: 1});

        vm.expectRevert(
            abi.encodeWithSignature("OperatorHasInsufficientFundableKeys(uint256,uint256,uint256)", 0, 1, 0)
        );
        operatorsRegistry.getNextValidatorsToDepositFromActiveOperators(allocation2);
    }

    /// @notice Tests that getNextValidators (view) doesn't modify state while pickNextValidators does
    function testViewVsStateModifyingBehavior() public {
        bytes memory rawKeys = genBytes((48 + 96) * 10);

        vm.startPrank(admin);
        operatorsRegistry.addValidators(0, 10, rawKeys);

        uint256[] memory operators = new uint256[](1);
        operators[0] = 0;
        uint32[] memory limits = new uint32[](1);
        limits[0] = 10;
        operatorsRegistry.setOperatorLimits(operators, limits, block.number);
        vm.stopPrank();

        IOperatorsRegistryV1.OperatorAllocation[] memory allocation = new IOperatorsRegistryV1.OperatorAllocation[](1);
        allocation[0] = IOperatorsRegistryV1.OperatorAllocation({operatorIndex: 0, validatorCount: 5});

        // Call view function multiple times - should always return same result
        (bytes[] memory keys1,) = operatorsRegistry.getNextValidatorsToDepositFromActiveOperators(allocation);
        (bytes[] memory keys2,) = operatorsRegistry.getNextValidatorsToDepositFromActiveOperators(allocation);

        assertEq(keys1.length, keys2.length, "View function should return same result on repeated calls");

        // Verify funded count hasn't changed
        OperatorsV2.Operator memory op = operatorsRegistry.getOperator(0);
        assertEq(op.funded, 0, "View function should not modify funded count");

        // Now call the state-modifying version
        vm.prank(river);
        operatorsRegistry.pickNextValidatorsToDepositFromActiveOperators(allocation);

        op = operatorsRegistry.getOperator(0);
        assertEq(op.funded, 5, "pickNextValidatorsToDeposit should modify funded count");
    }

    /// @notice Tests that the funded count updated in pickNextValidatorsToDeposit is a storage update:
    ///         it persists beyond the transaction and the next read (or next pick) sees the higher value.
    function testFundedCountPersistsInStorageAndIsUsedOnNextCall() public {
        bytes memory rawKeys = genBytes((48 + 96) * 10);

        vm.startPrank(admin);
        operatorsRegistry.addValidators(0, 10, rawKeys);

        uint256[] memory operators = new uint256[](1);
        operators[0] = 0;
        uint32[] memory limits = new uint32[](1);
        limits[0] = 10;
        operatorsRegistry.setOperatorLimits(operators, limits, block.number);
        vm.stopPrank();

        // Before any pick: funded is 0
        uint32 fundedBefore = operatorsRegistry.getOperator(0).funded;
        assertEq(fundedBefore, 0, "funded should be 0 before any pick");

        // First pick: fund 3 validators (updates storage)
        IOperatorsRegistryV1.OperatorAllocation[] memory allocation1 = new IOperatorsRegistryV1.OperatorAllocation[](1);
        allocation1[0] = IOperatorsRegistryV1.OperatorAllocation({operatorIndex: 0, validatorCount: 3});

        vm.prank(river);
        operatorsRegistry.pickNextValidatorsToDepositFromActiveOperators(allocation1);

        // Assert funded was updated in storage (first read after the transaction that wrote it)
        uint32 fundedAfterFirst = operatorsRegistry.getOperator(0).funded;
        assertEq(fundedAfterFirst, 3, "funded should be 3 in storage after first pick");

        // Second read: value must still be 3 (proves it is storage, not transient)
        uint32 fundedOnSecondRead = operatorsRegistry.getOperator(0).funded;
        assertEq(fundedOnSecondRead, 3, "funded must persist when read again");

        // Second pick: fund 2 more. If funded were only in memory, this would start from 0 and we'd get 2.
        // Because it is storage, we get 3 + 2 = 5.
        IOperatorsRegistryV1.OperatorAllocation[] memory allocation2 = new IOperatorsRegistryV1.OperatorAllocation[](1);
        allocation2[0] = IOperatorsRegistryV1.OperatorAllocation({operatorIndex: 0, validatorCount: 2});

        vm.prank(river);
        operatorsRegistry.pickNextValidatorsToDepositFromActiveOperators(allocation2);

        // Next use of funded must see the cumulative value (3 + 2 = 5)
        uint32 fundedAfterSecond = operatorsRegistry.getOperator(0).funded;
        assertEq(fundedAfterSecond, 5, "funded must be cumulative (5) when used on next call");
    }

    /// @notice Tests allocation with multiple operators where one has partially funded keys
    function testMultiOperatorWithPartialFunding() public {
        bytes memory rawKeys = genBytes((48 + 96) * 10);

        vm.startPrank(admin);
        operatorsRegistry.addValidators(0, 10, rawKeys);
        operatorsRegistry.addValidators(1, 10, rawKeys);

        uint256[] memory operators = new uint256[](2);
        operators[0] = 0;
        operators[1] = 1;
        uint32[] memory limits = new uint32[](2);
        limits[0] = 10;
        limits[1] = 10;
        operatorsRegistry.setOperatorLimits(operators, limits, block.number);
        vm.stopPrank();

        // Fund 6 validators from operator 0
        IOperatorsRegistryV1.OperatorAllocation[] memory allocation1 = new IOperatorsRegistryV1.OperatorAllocation[](1);
        allocation1[0] = IOperatorsRegistryV1.OperatorAllocation({operatorIndex: 0, validatorCount: 6});

        vm.prank(river);
        operatorsRegistry.pickNextValidatorsToDepositFromActiveOperators(allocation1);

        // Now allocate from both operators: 4 from op0 (has 4 remaining) and 5 from op1 (has 10)
        IOperatorsRegistryV1.OperatorAllocation[] memory allocation2 = new IOperatorsRegistryV1.OperatorAllocation[](2);
        allocation2[0] = IOperatorsRegistryV1.OperatorAllocation({operatorIndex: 0, validatorCount: 4});
        allocation2[1] = IOperatorsRegistryV1.OperatorAllocation({operatorIndex: 1, validatorCount: 5});

        vm.prank(river);
        (bytes[] memory publicKeys, bytes[] memory signatures) =
            operatorsRegistry.pickNextValidatorsToDepositFromActiveOperators(allocation2);

        assertEq(publicKeys.length, 9, "Expected 9 public keys (4 + 5)");
        assertEq(signatures.length, 9, "Expected 9 signatures");

        OperatorsV2.Operator memory op0 = operatorsRegistry.getOperator(0);
        OperatorsV2.Operator memory op1 = operatorsRegistry.getOperator(1);
        assertEq(op0.funded, 10, "Operator 0 should be fully funded");
        assertEq(op1.funded, 5, "Operator 1 should have 5 funded");
    }

    /// @notice Tests that pick reverts with OperatorHasInsufficientFundableKeys for second operator in multi-allocation
    function testMultiOperatorSecondOperatorExceedsLimit() public {
        bytes memory rawKeys = genBytes((48 + 96) * 5);

        vm.startPrank(admin);
        operatorsRegistry.addValidators(0, 5, rawKeys);
        operatorsRegistry.addValidators(1, 5, rawKeys);

        uint256[] memory operators = new uint256[](2);
        operators[0] = 0;
        operators[1] = 1;
        uint32[] memory limits = new uint32[](2);
        limits[0] = 5;
        limits[1] = 3; // Only 3 available for operator 1
        operatorsRegistry.setOperatorLimits(operators, limits, block.number);
        vm.stopPrank();

        // Try to allocate: 2 from op0 (ok) and 5 from op1 (exceeds limit of 3)
        IOperatorsRegistryV1.OperatorAllocation[] memory allocation = new IOperatorsRegistryV1.OperatorAllocation[](2);
        allocation[0] = IOperatorsRegistryV1.OperatorAllocation({operatorIndex: 0, validatorCount: 2});
        allocation[1] = IOperatorsRegistryV1.OperatorAllocation({operatorIndex: 1, validatorCount: 5});

        vm.expectRevert(
            abi.encodeWithSignature("OperatorHasInsufficientFundableKeys(uint256,uint256,uint256)", 1, 5, 3)
        );
        operatorsRegistry.getNextValidatorsToDepositFromActiveOperators(allocation);
    }

    /// @notice Tests the _pickNextValidatorsToDepositFromActiveOperators returns empty when no fundable operators
    function testPickNextValidatorsToDepositReturnsEmptyAllocation() public {
        // No operators have keys or limits set, so none are fundable
        IOperatorsRegistryV1.OperatorAllocation[] memory allocation = new IOperatorsRegistryV1.OperatorAllocation[](0);

        vm.prank(river);
        vm.expectRevert(abi.encodeWithSignature("InvalidEmptyArray()"));
        operatorsRegistry.pickNextValidatorsToDepositFromActiveOperators(allocation);
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
        uint256 entrySize = ValidatorKeys.PUBLIC_KEY_LENGTH + ValidatorKeys.SIGNATURE_LENGTH; // 144
        return LibBytes.slice(rawKeysByOperator[operatorIdx], validatorIdx * entrySize, ValidatorKeys.PUBLIC_KEY_LENGTH);
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

            bytes memory keys =
                genBytes(uint256(keysPerOp) * (ValidatorKeys.PUBLIC_KEY_LENGTH + ValidatorKeys.SIGNATURE_LENGTH));
            rawKeysByOperator.push(keys);
            operatorsRegistry.addValidators(i, keysPerOp, keys);

            indexes[i] = i;
            limits[i] = keysPerOp;
        }
        operatorsRegistry.setOperatorLimits(indexes, limits, block.number);
        vm.stopPrank();
    }

    // ──────────────────────────────────────────────────────────────────────
    // TEST 1: Returned keys match operator key sets (content verification)
    // ──────────────────────────────────────────────────────────────────────

    /// @notice Verifies that keys returned from a multi-operator allocation actually belong
    ///         to the correct operators by comparing against the registered key material.
    function testReturnedKeysMatchCorrectOperators() external {
        _setupOperators(3, 10);

        // Allocate 2 from op0, 3 from op1, 1 from op2
        IOperatorsRegistryV1.OperatorAllocation[] memory alloc = new IOperatorsRegistryV1.OperatorAllocation[](3);
        alloc[0] = IOperatorsRegistryV1.OperatorAllocation({operatorIndex: 0, validatorCount: 2});
        alloc[1] = IOperatorsRegistryV1.OperatorAllocation({operatorIndex: 1, validatorCount: 3});
        alloc[2] = IOperatorsRegistryV1.OperatorAllocation({operatorIndex: 2, validatorCount: 1});

        vm.prank(river);
        (bytes[] memory publicKeys,) = operatorsRegistry.pickNextValidatorsToDepositFromActiveOperators(alloc);

        assertEq(publicKeys.length, 6, "Expected 6 total keys");

        // Keys 0-1 should be operator 0's first 2 keys
        assertEq(publicKeys[0], _extractPublicKey(0, 0), "Key 0 should be op0 validator 0");
        assertEq(publicKeys[1], _extractPublicKey(0, 1), "Key 1 should be op0 validator 1");

        // Keys 2-4 should be operator 1's first 3 keys
        assertEq(publicKeys[2], _extractPublicKey(1, 0), "Key 2 should be op1 validator 0");
        assertEq(publicKeys[3], _extractPublicKey(1, 1), "Key 3 should be op1 validator 1");
        assertEq(publicKeys[4], _extractPublicKey(1, 2), "Key 4 should be op1 validator 2");

        // Key 5 should be operator 2's first key
        assertEq(publicKeys[5], _extractPublicKey(2, 0), "Key 5 should be op2 validator 0");
    }

    // ──────────────────────────────────────────────────────────────────────
    // TEST 2: Asymmetric multi-operator allocation with content verification
    // ──────────────────────────────────────────────────────────────────────

    /// @notice Allocate heavily uneven counts (1 to op0, 8 to op1, 1 to op2) and verify
    ///         each key belongs to the correct operator's registered key set.
    function testAsymmetricAllocationKeyContent() external {
        _setupOperators(3, 10);

        IOperatorsRegistryV1.OperatorAllocation[] memory alloc = new IOperatorsRegistryV1.OperatorAllocation[](3);
        alloc[0] = IOperatorsRegistryV1.OperatorAllocation({operatorIndex: 0, validatorCount: 1});
        alloc[1] = IOperatorsRegistryV1.OperatorAllocation({operatorIndex: 1, validatorCount: 8});
        alloc[2] = IOperatorsRegistryV1.OperatorAllocation({operatorIndex: 2, validatorCount: 1});

        vm.prank(river);
        (bytes[] memory publicKeys,) = operatorsRegistry.pickNextValidatorsToDepositFromActiveOperators(alloc);

        assertEq(publicKeys.length, 10, "Expected 10 total keys");

        // Key 0: op0 validator 0
        assertEq(publicKeys[0], _extractPublicKey(0, 0), "Key 0 should be op0 validator 0");

        // Keys 1-8: op1 validators 0-7
        for (uint256 i = 0; i < 8; ++i) {
            assertEq(
                publicKeys[1 + i],
                _extractPublicKey(1, i),
                string(abi.encodePacked("Key should be op1 validator ", vm.toString(i)))
            );
        }

        // Key 9: op2 validator 0
        assertEq(publicKeys[9], _extractPublicKey(2, 0), "Key 9 should be op2 validator 0");

        // Verify funded counts
        assertEq(operatorsRegistry.getOperator(0).funded, 1, "Op0 should have 1 funded");
        assertEq(operatorsRegistry.getOperator(1).funded, 8, "Op1 should have 8 funded");
        assertEq(operatorsRegistry.getOperator(2).funded, 1, "Op2 should have 1 funded");
    }

    // ──────────────────────────────────────────────────────────────────────
    // TEST 3: Large operator set (15 operators, sparse allocation)
    // ──────────────────────────────────────────────────────────────────────

    /// @notice 15 operators registered, only 3 receive allocations. Verifies that the linear
    ///         search in _updateCountOfPickedValidatorsForEachOperator correctly finds operators
    ///         deep in the array and that non-allocated operators remain unfunded.
    function testLargeOperatorSetSparseAllocation() external {
        _setupOperators(15, 10);

        // Allocate only to operators 3, 7, and 14
        IOperatorsRegistryV1.OperatorAllocation[] memory alloc = new IOperatorsRegistryV1.OperatorAllocation[](3);
        alloc[0] = IOperatorsRegistryV1.OperatorAllocation({operatorIndex: 3, validatorCount: 5});
        alloc[1] = IOperatorsRegistryV1.OperatorAllocation({operatorIndex: 7, validatorCount: 2});
        alloc[2] = IOperatorsRegistryV1.OperatorAllocation({operatorIndex: 14, validatorCount: 8});

        vm.prank(river);
        (bytes[] memory publicKeys,) = operatorsRegistry.pickNextValidatorsToDepositFromActiveOperators(alloc);

        assertEq(publicKeys.length, 15, "Expected 15 total keys (5+2+8)");

        // Verify all 15 operators' funded counts
        for (uint256 i = 0; i < 15; ++i) {
            uint32 expectedFunded = 0;
            if (i == 3) expectedFunded = 5;
            else if (i == 7) expectedFunded = 2;
            else if (i == 14) expectedFunded = 8;

            assertEq(
                operatorsRegistry.getOperator(i).funded,
                expectedFunded,
                string(abi.encodePacked("Op ", vm.toString(i), " funded mismatch"))
            );
        }

        // Verify key content for the 3 allocated operators
        uint256 keyIdx = 0;
        // Op3 keys
        for (uint256 i = 0; i < 5; ++i) {
            assertEq(publicKeys[keyIdx], _extractPublicKey(3, i), "Op3 key content mismatch");
            keyIdx++;
        }
        // Op7 keys
        for (uint256 i = 0; i < 2; ++i) {
            assertEq(publicKeys[keyIdx], _extractPublicKey(7, i), "Op7 key content mismatch");
            keyIdx++;
        }
        // Op14 keys
        for (uint256 i = 0; i < 8; ++i) {
            assertEq(publicKeys[keyIdx], _extractPublicKey(14, i), "Op14 key content mismatch");
            keyIdx++;
        }
    }

    // ──────────────────────────────────────────────────────────────────────
    // TEST 4: Non-contiguous allocation (skip active operators)
    // ──────────────────────────────────────────────────────────────────────

    /// @notice All 5 operators are active and fundable, but allocation only targets op0 and op4.
    ///         Verifies that ops 1,2,3 remain at funded=0 despite being active.
    function testNonContiguousAllocationSkipsActiveOperators() external {
        _setupOperators(5, 10);

        IOperatorsRegistryV1.OperatorAllocation[] memory alloc = new IOperatorsRegistryV1.OperatorAllocation[](2);
        alloc[0] = IOperatorsRegistryV1.OperatorAllocation({operatorIndex: 0, validatorCount: 3});
        alloc[1] = IOperatorsRegistryV1.OperatorAllocation({operatorIndex: 4, validatorCount: 7});

        vm.prank(river);
        (bytes[] memory publicKeys,) = operatorsRegistry.pickNextValidatorsToDepositFromActiveOperators(alloc);

        assertEq(publicKeys.length, 10, "Expected 10 total keys (3+7)");

        assertEq(operatorsRegistry.getOperator(0).funded, 3, "Op0 should have 3 funded");
        assertEq(operatorsRegistry.getOperator(1).funded, 0, "Op1 should remain unfunded");
        assertEq(operatorsRegistry.getOperator(2).funded, 0, "Op2 should remain unfunded");
        assertEq(operatorsRegistry.getOperator(3).funded, 0, "Op3 should remain unfunded");
        assertEq(operatorsRegistry.getOperator(4).funded, 7, "Op4 should have 7 funded");

        // Verify key content
        for (uint256 i = 0; i < 3; ++i) {
            assertEq(publicKeys[i], _extractPublicKey(0, i), "Op0 key content mismatch");
        }
        for (uint256 i = 0; i < 7; ++i) {
            assertEq(publicKeys[3 + i], _extractPublicKey(4, i), "Op4 key content mismatch");
        }
    }

    // ──────────────────────────────────────────────────────────────────────
    // TEST 5: Sequential allocations preserve key offset correctness
    // ──────────────────────────────────────────────────────────────────────

    /// @notice Two sequential allocations to the same operator. The second allocation must
    ///         return keys starting from where the first left off (funded offset).
    function testSequentialAllocationsReturnCorrectKeyOffsets() external {
        _setupOperators(2, 10);

        // First allocation: 3 from op0, 2 from op1
        IOperatorsRegistryV1.OperatorAllocation[] memory alloc1 = new IOperatorsRegistryV1.OperatorAllocation[](2);
        alloc1[0] = IOperatorsRegistryV1.OperatorAllocation({operatorIndex: 0, validatorCount: 3});
        alloc1[1] = IOperatorsRegistryV1.OperatorAllocation({operatorIndex: 1, validatorCount: 2});

        vm.prank(river);
        (bytes[] memory keys1,) = operatorsRegistry.pickNextValidatorsToDepositFromActiveOperators(alloc1);

        assertEq(keys1.length, 5);
        // First batch: op0 keys 0,1,2 and op1 keys 0,1
        assertEq(keys1[0], _extractPublicKey(0, 0));
        assertEq(keys1[1], _extractPublicKey(0, 1));
        assertEq(keys1[2], _extractPublicKey(0, 2));
        assertEq(keys1[3], _extractPublicKey(1, 0));
        assertEq(keys1[4], _extractPublicKey(1, 1));

        // Second allocation: 2 more from op0, 3 more from op1
        IOperatorsRegistryV1.OperatorAllocation[] memory alloc2 = new IOperatorsRegistryV1.OperatorAllocation[](2);
        alloc2[0] = IOperatorsRegistryV1.OperatorAllocation({operatorIndex: 0, validatorCount: 2});
        alloc2[1] = IOperatorsRegistryV1.OperatorAllocation({operatorIndex: 1, validatorCount: 3});

        vm.prank(river);
        (bytes[] memory keys2,) = operatorsRegistry.pickNextValidatorsToDepositFromActiveOperators(alloc2);

        assertEq(keys2.length, 5);
        // Second batch must start from funded offset: op0 keys 3,4 and op1 keys 2,3,4
        assertEq(keys2[0], _extractPublicKey(0, 3), "Second alloc op0 should start at key index 3");
        assertEq(keys2[1], _extractPublicKey(0, 4), "Second alloc op0 should have key index 4");
        assertEq(keys2[2], _extractPublicKey(1, 2), "Second alloc op1 should start at key index 2");
        assertEq(keys2[3], _extractPublicKey(1, 3), "Second alloc op1 should have key index 3");
        assertEq(keys2[4], _extractPublicKey(1, 4), "Second alloc op1 should have key index 4");

        assertEq(operatorsRegistry.getOperator(0).funded, 5);
        assertEq(operatorsRegistry.getOperator(1).funded, 5);
    }

    // ──────────────────────────────────────────────────────────────────────
    // TEST 6: Single operator gets entire allocation
    // ──────────────────────────────────────────────────────────────────────

    /// @notice With multiple active operators, allocate everything to just one.
    ///         Verifies the others are untouched and the keys are correct.
    function testEntireAllocationToSingleOperatorAmongMany() external {
        _setupOperators(5, 10);

        IOperatorsRegistryV1.OperatorAllocation[] memory alloc = new IOperatorsRegistryV1.OperatorAllocation[](1);
        alloc[0] = IOperatorsRegistryV1.OperatorAllocation({operatorIndex: 2, validatorCount: 10});

        vm.prank(river);
        (bytes[] memory publicKeys,) = operatorsRegistry.pickNextValidatorsToDepositFromActiveOperators(alloc);

        assertEq(publicKeys.length, 10);

        for (uint256 i = 0; i < 10; ++i) {
            assertEq(publicKeys[i], _extractPublicKey(2, i), "All keys should belong to op2");
        }

        assertEq(operatorsRegistry.getOperator(0).funded, 0, "Op0 untouched");
        assertEq(operatorsRegistry.getOperator(1).funded, 0, "Op1 untouched");
        assertEq(operatorsRegistry.getOperator(2).funded, 10, "Op2 fully funded");
        assertEq(operatorsRegistry.getOperator(3).funded, 0, "Op3 untouched");
        assertEq(operatorsRegistry.getOperator(4).funded, 0, "Op4 untouched");
    }

    // ──────────────────────────────────────────────────────────────────────
    // TEST 7: FundedValidatorKeys event content matches allocation
    // ──────────────────────────────────────────────────────────────────────

    /// @notice Verifies the FundedValidatorKeys events emitted during allocation carry the
    ///         correct operator index and the correct key bytes for an asymmetric allocation.
    function testFundedValidatorKeysEventContentForAsymmetricAllocation() external {
        _setupOperators(3, 10);

        // Build expected key arrays for events
        bytes[] memory expectedOp0Keys = new bytes[](1);
        expectedOp0Keys[0] = _extractPublicKey(0, 0);

        bytes[] memory expectedOp2Keys = new bytes[](4);
        for (uint256 i = 0; i < 4; ++i) {
            expectedOp2Keys[i] = _extractPublicKey(2, i);
        }

        // Expect events in operator order (0, then 2; op1 has no allocation so no event)
        vm.expectEmit(true, true, true, true);
        emit FundedValidatorKeys(0, expectedOp0Keys, false);
        vm.expectEmit(true, true, true, true);
        emit FundedValidatorKeys(2, expectedOp2Keys, false);

        IOperatorsRegistryV1.OperatorAllocation[] memory alloc = new IOperatorsRegistryV1.OperatorAllocation[](2);
        alloc[0] = IOperatorsRegistryV1.OperatorAllocation({operatorIndex: 0, validatorCount: 1});
        alloc[1] = IOperatorsRegistryV1.OperatorAllocation({operatorIndex: 2, validatorCount: 4});

        vm.prank(river);
        operatorsRegistry.pickNextValidatorsToDepositFromActiveOperators(alloc);
    }

    // ============ NEW TESTS FOR BYOV COVERAGE ============

    /// @notice Tests OperatorHasInsufficientFundableKeys when some keys are already funded
    /// This covers the case where availableKeys = limit - (funded + picked) is less than requested
    function testOperatorHasInsufficientFundableKeysWithPartialFunding() public {
        _setupOperators(1, 10);
        bytes memory rawKeys = genBytes((48 + 96) * 10);

        vm.startPrank(admin);
        operatorsRegistry.addValidators(0, 10, rawKeys);

        uint256[] memory operators = new uint256[](1);
        operators[0] = 0;
        uint32[] memory limits = new uint32[](1);
        limits[0] = 10;
        operatorsRegistry.setOperatorLimits(operators, limits, block.number);
        vm.stopPrank();

        // First, fund 7 validators so only 3 remain available
        IOperatorsRegistryV1.OperatorAllocation[] memory firstAllocation =
            new IOperatorsRegistryV1.OperatorAllocation[](1);
        firstAllocation[0] = IOperatorsRegistryV1.OperatorAllocation({operatorIndex: 0, validatorCount: 7});

        vm.prank(river);
        operatorsRegistry.pickNextValidatorsToDepositFromActiveOperators(firstAllocation);

        // Verify operator now has 7 funded
        OperatorsV2.Operator memory op = operatorsRegistry.getOperator(0);
        assertEq(op.funded, 7, "Expected 7 funded validators");

        // Now try to allocate 5 more (only 3 available: limit=10 - funded=7 = 3)
        IOperatorsRegistryV1.OperatorAllocation[] memory secondAllocation =
            new IOperatorsRegistryV1.OperatorAllocation[](1);
        secondAllocation[0] = IOperatorsRegistryV1.OperatorAllocation({operatorIndex: 0, validatorCount: 5});

        vm.expectRevert(
            abi.encodeWithSignature("OperatorHasInsufficientFundableKeys(uint256,uint256,uint256)", 0, 5, 3)
        );
        operatorsRegistry.getNextValidatorsToDepositFromActiveOperators(secondAllocation);
    }

    /// @notice Tests that pickNextValidatorsToDeposit correctly updates funded count and emits FundedValidatorKeys
    function testPickNextValidatorsEmitsFundedValidatorKeysEvent() public {
        _setupOperators(1, 5);
        bytes memory rawKeys = genBytes((48 + 96) * 5);

        vm.startPrank(admin);
        operatorsRegistry.addValidators(0, 5, rawKeys);

        uint256[] memory operators = new uint256[](1);
        operators[0] = 0;
        uint32[] memory limits = new uint32[](1);
        limits[0] = 5;
        operatorsRegistry.setOperatorLimits(operators, limits, block.number);
        vm.stopPrank();

        IOperatorsRegistryV1.OperatorAllocation[] memory allocation = new IOperatorsRegistryV1.OperatorAllocation[](1);
        allocation[0] = IOperatorsRegistryV1.OperatorAllocation({operatorIndex: 0, validatorCount: 3});

        // Expect the FundedValidatorKeys event to be emitted with false (not migration)
        vm.expectEmit(true, false, false, false);
        emit FundedValidatorKeys(0, new bytes[](3), false);

        vm.prank(river);
        (bytes[] memory publicKeys, bytes[] memory signatures) =
            operatorsRegistry.pickNextValidatorsToDepositFromActiveOperators(allocation);

        assertEq(publicKeys.length, 3, "Expected 3 public keys");
        assertEq(signatures.length, 3, "Expected 3 signatures");

        // Verify funded count was updated
        OperatorsV2.Operator memory op = operatorsRegistry.getOperator(0);
        assertEq(op.funded, 3, "Expected funded to be updated to 3");
    }

    /// @notice Tests multi-operator allocation with correct key ordering
    function testMultiOperatorAllocationKeyOrdering() public {
        _setupOperators(2, 5);
        bytes memory rawKeys0 = genBytes((48 + 96) * 5);
        bytes memory rawKeys1 = genBytes((48 + 96) * 5);

        vm.startPrank(admin);
        operatorsRegistry.addValidators(0, 5, rawKeys0);
        operatorsRegistry.addValidators(1, 5, rawKeys1);

        uint256[] memory operators = new uint256[](2);
        operators[0] = 0;
        operators[1] = 1;
        uint32[] memory limits = new uint32[](2);
        limits[0] = 5;
        limits[1] = 5;
        operatorsRegistry.setOperatorLimits(operators, limits, block.number);
        vm.stopPrank();

        // Allocate 2 from operator 0 and 3 from operator 1
        IOperatorsRegistryV1.OperatorAllocation[] memory allocation = new IOperatorsRegistryV1.OperatorAllocation[](2);
        allocation[0] = IOperatorsRegistryV1.OperatorAllocation({operatorIndex: 0, validatorCount: 2});
        allocation[1] = IOperatorsRegistryV1.OperatorAllocation({operatorIndex: 1, validatorCount: 3});

        (bytes[] memory publicKeys, bytes[] memory signatures) =
            operatorsRegistry.getNextValidatorsToDepositFromActiveOperators(allocation);

        // Should return 5 total keys (2 + 3)
        assertEq(publicKeys.length, 5, "Expected 5 public keys total");
        assertEq(signatures.length, 5, "Expected 5 signatures total");
    }

    /// @notice Tests that sequential allocations to the same operator work correctly
    function testSequentialAllocationsToSameOperator() public {
        _setupOperators(1, 10);
        bytes memory rawKeys = genBytes((48 + 96) * 10);

        vm.startPrank(admin);
        operatorsRegistry.addValidators(0, 10, rawKeys);

        uint256[] memory operators = new uint256[](1);
        operators[0] = 0;
        uint32[] memory limits = new uint32[](1);
        limits[0] = 10;
        operatorsRegistry.setOperatorLimits(operators, limits, block.number);
        vm.stopPrank();

        // First allocation: fund 3 validators
        IOperatorsRegistryV1.OperatorAllocation[] memory allocation1 = new IOperatorsRegistryV1.OperatorAllocation[](1);
        allocation1[0] = IOperatorsRegistryV1.OperatorAllocation({operatorIndex: 0, validatorCount: 3});

        vm.prank(river);
        operatorsRegistry.pickNextValidatorsToDepositFromActiveOperators(allocation1);

        OperatorsV2.Operator memory op = operatorsRegistry.getOperator(0);
        assertEq(op.funded, 3, "Expected 3 funded after first allocation");

        // Second allocation: fund 4 more validators
        IOperatorsRegistryV1.OperatorAllocation[] memory allocation2 = new IOperatorsRegistryV1.OperatorAllocation[](1);
        allocation2[0] = IOperatorsRegistryV1.OperatorAllocation({operatorIndex: 0, validatorCount: 4});

        vm.prank(river);
        operatorsRegistry.pickNextValidatorsToDepositFromActiveOperators(allocation2);

        op = operatorsRegistry.getOperator(0);
        assertEq(op.funded, 7, "Expected 7 funded after second allocation");

        // Third allocation: try to fund exactly the remaining 3
        IOperatorsRegistryV1.OperatorAllocation[] memory allocation3 = new IOperatorsRegistryV1.OperatorAllocation[](1);
        allocation3[0] = IOperatorsRegistryV1.OperatorAllocation({operatorIndex: 0, validatorCount: 3});

        vm.prank(river);
        operatorsRegistry.pickNextValidatorsToDepositFromActiveOperators(allocation3);

        op = operatorsRegistry.getOperator(0);
        assertEq(op.funded, 10, "Expected 10 funded after third allocation (fully funded)");
    }

    /// @notice Tests that getNextValidators (view) doesn't modify state while pickNextValidators does
    function testViewVsStateModifyingBehavior() public {
        _setupOperators(1, 10);
        bytes memory rawKeys = genBytes((48 + 96) * 10);

        vm.startPrank(admin);
        operatorsRegistry.addValidators(0, 10, rawKeys);

        uint256[] memory operators = new uint256[](1);
        operators[0] = 0;
        uint32[] memory limits = new uint32[](1);
        limits[0] = 10;
        operatorsRegistry.setOperatorLimits(operators, limits, block.number);
        vm.stopPrank();

        IOperatorsRegistryV1.OperatorAllocation[] memory allocation = new IOperatorsRegistryV1.OperatorAllocation[](1);
        allocation[0] = IOperatorsRegistryV1.OperatorAllocation({operatorIndex: 0, validatorCount: 5});

        // Call view function multiple times - should always return same result
        (bytes[] memory keys1,) = operatorsRegistry.getNextValidatorsToDepositFromActiveOperators(allocation);
        (bytes[] memory keys2,) = operatorsRegistry.getNextValidatorsToDepositFromActiveOperators(allocation);

        assertEq(keys1.length, keys2.length, "View function should return same result on repeated calls");

        // Verify funded count hasn't changed
        OperatorsV2.Operator memory op = operatorsRegistry.getOperator(0);
        assertEq(op.funded, 0, "View function should not modify funded count");

        // Now call the state-modifying version
        vm.prank(river);
        operatorsRegistry.pickNextValidatorsToDepositFromActiveOperators(allocation);

        op = operatorsRegistry.getOperator(0);
        assertEq(op.funded, 5, "pickNextValidatorsToDeposit should modify funded count");
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

    /// @dev Fund all 5 operators with 50 validators each and set limits
    function _fundAllOperators() internal {
        vm.startPrank(admin);
        for (uint256 i = 0; i < 5; ++i) {
            operatorsRegistry.addValidators(i, 50, genBytes((48 + 96) * 50));
        }
        vm.stopPrank();

        uint256[] memory operators = new uint256[](5);
        uint32[] memory limits = new uint32[](5);
        for (uint256 i = 0; i < 5; ++i) {
            operators[i] = i;
            limits[i] = 50;
        }

        vm.prank(admin);
        operatorsRegistry.setOperatorLimits(operators, limits, block.number);

        OperatorsRegistryInitializableV1(address(operatorsRegistry))
            .pickNextValidatorsToDepositFromActiveOperators(_createAllocation(operators, limits));

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
        operatorsRegistry.requestValidatorExits(_createAllocation(ops1, counts1));

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
        operatorsRegistry.requestValidatorExits(_createAllocation(ops2, counts2));

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
        operatorsRegistry.requestValidatorExits(_createAllocation(ops, counts));

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
        operatorsRegistry.requestValidatorExits(_createAllocation(ops, counts));

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
        operatorsRegistry.requestValidatorExits(_createAllocation(ops, counts));

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
        operatorsRegistry.requestValidatorExits(_createAllocation(ops, exitCounts1));

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
        operatorsRegistry.requestValidatorExits(_createAllocation(ops, exitCounts2));

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

    /// @notice Combined flow: deposit validators via BYOV allocation, then exit some,
    ///         then simulate validators stopping, then deposit more.
    ///         Verifies funded and requestedExits are both correct throughout.
    ///
    ///         Key invariant: getAllFundable() requires stoppedCount >= requestedExits
    ///         for an operator to be eligible for new deposits. This means you can't
    ///         deposit to an operator with pending (unfulfilled) exit requests until
    ///         those validators have actually stopped.
    function testDepositThenExitEndToEnd() external {
        // Setup: add keys and limits for 3 operators
        vm.startPrank(admin);
        for (uint256 i = 0; i < 3; ++i) {
            operatorsRegistry.addValidators(i, 20, genBytes((48 + 96) * 20));
        }
        vm.stopPrank();

        uint256[] memory ops = new uint256[](3);
        uint32[] memory limits = new uint32[](3);
        for (uint256 i = 0; i < 3; ++i) {
            ops[i] = i;
            limits[i] = 20;
        }
        vm.prank(admin);
        operatorsRegistry.setOperatorLimits(ops, limits, block.number);

        // Phase 1: Deposit 10 to op0, 15 to op1, 5 to op2 = 30 total
        uint32[] memory depositCounts = new uint32[](3);
        depositCounts[0] = 10;
        depositCounts[1] = 15;
        depositCounts[2] = 5;

        vm.prank(river);
        operatorsRegistry.pickNextValidatorsToDepositFromActiveOperators(_createAllocation(ops, depositCounts));

        assertEq(operatorsRegistry.getOperator(0).funded, 10, "Op0 should have 10 funded");
        assertEq(operatorsRegistry.getOperator(1).funded, 15, "Op1 should have 15 funded");
        assertEq(operatorsRegistry.getOperator(2).funded, 5, "Op2 should have 5 funded");

        // Phase 2: Request exits -- 5 from op0, 7 from op1, 3 from op2 = 15 total
        RiverMock(river).sudoSetDepositedValidatorsCount(30);
        vm.prank(river);
        operatorsRegistry.demandValidatorExits(15, 30);
        assertEq(operatorsRegistry.getCurrentValidatorExitsDemand(), 15);

        uint32[] memory exitCounts = new uint32[](3);
        exitCounts[0] = 5;
        exitCounts[1] = 7;
        exitCounts[2] = 3;

        vm.prank(keeper);
        operatorsRegistry.requestValidatorExits(_createAllocation(ops, exitCounts));

        assertEq(operatorsRegistry.getOperator(0).funded, 10, "Op0 funded unchanged");
        assertEq(operatorsRegistry.getOperator(1).funded, 15, "Op1 funded unchanged");
        assertEq(operatorsRegistry.getOperator(2).funded, 5, "Op2 funded unchanged");
        assertEq(operatorsRegistry.getOperator(0).requestedExits, 5, "Op0 should have 5 exits");
        assertEq(operatorsRegistry.getOperator(1).requestedExits, 7, "Op1 should have 7 exits");
        assertEq(operatorsRegistry.getOperator(2).requestedExits, 3, "Op2 should have 3 exits");
        assertEq(operatorsRegistry.getCurrentValidatorExitsDemand(), 0, "Demand fully satisfied");
        assertEq(operatorsRegistry.getTotalValidatorExitsRequested(), 15);

        // Phase 3: Before depositing more, the exited validators must actually stop.
        // getAllFundable() requires stoppedCount >= requestedExits for eligibility.
        // Simulate the stopped validators matching the exit requests.
        uint32[] memory stoppedCounts = new uint32[](4);
        stoppedCounts[0] = 15; // total stopped
        stoppedCounts[1] = 5; // op0 stopped
        stoppedCounts[2] = 7; // op1 stopped
        stoppedCounts[3] = 3; // op2 stopped
        OperatorsRegistryInitializableV1(address(operatorsRegistry)).sudoStoppedValidatorCounts(stoppedCounts, 30);

        // Phase 4: Now deposit more to op0 (limit=20, funded=10, stopped >= requestedExits)
        uint32[] memory depositCounts2 = new uint32[](1);
        depositCounts2[0] = 5;
        uint256[] memory singleOp = new uint256[](1);
        singleOp[0] = 0;

        vm.prank(river);
        operatorsRegistry.pickNextValidatorsToDepositFromActiveOperators(_createAllocation(singleOp, depositCounts2));

        assertEq(operatorsRegistry.getOperator(0).funded, 15, "Op0 should now have 15 funded");
        assertEq(operatorsRegistry.getOperator(0).requestedExits, 5, "Op0 exits unchanged by new deposit");

        // Verify the other operators are unchanged
        assertEq(operatorsRegistry.getOperator(1).funded, 15, "Op1 funded unchanged");
        assertEq(operatorsRegistry.getOperator(2).funded, 5, "Op2 funded unchanged");
    }
}

contract OperatorsRegistryV1InvalidKeyCountTests is
    OperatorsRegistryV1TestBase,
    OperatorAllocationTestBase,
    BytesGenerator
{
    function setUp() public {
        admin = makeAddr("admin");
        keeper = makeAddr("keeper");
        river = address(new RiverMock(0));
        RiverMock(river).setKeeper(keeper);
        operatorsRegistry = new OperatorsRegistryMismatchedKeysV1();
        LibImplementationUnbricker.unbrick(vm, address(operatorsRegistry));
        operatorsRegistry.initOperatorsRegistryV1(admin, river);
    }

    function testPickNextValidatorsRevertsOnKeyCountMismatch() public {
        vm.prank(admin);
        operatorsRegistry.addOperator("Operator", makeAddr("operator"));
        bytes memory keys = genBytes(48);
        bytes memory sigs = genBytes(96);
        vm.prank(admin);
        operatorsRegistry.addValidators(0, 1, abi.encodePacked(keys, sigs));
        uint256[] memory ops = new uint256[](1);
        ops[0] = 0;
        uint32[] memory limits = new uint32[](1);
        limits[0] = 1;
        vm.prank(admin);
        operatorsRegistry.setOperatorLimits(ops, limits, block.number);

        vm.expectRevert(abi.encodeWithSelector(IOperatorsRegistryV1.InvalidKeyCount.selector));
        operatorsRegistry.pickNextValidatorsToDepositFromActiveOperators(_createAllocation(0, 1));
    }
}
