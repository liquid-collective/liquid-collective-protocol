//SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.33;

import "forge-std/Test.sol";

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

contract OperatorsRegistryV1Tests is OperatorsRegistryV1TestBase, BytesGenerator {
    function setUp() public {
        admin = makeAddr("admin");
        keeper = makeAddr("keeper");
        river = address(new RiverMock(0));
        RiverMock(river).setKeeper(keeper);
        operatorsRegistry = new OperatorsRegistryInitializableV1();
        LibImplementationUnbricker.unbrick(vm, address(operatorsRegistry));
        operatorsRegistry.initOperatorsRegistryV1(admin, river);
    }

    function _createAllocation(uint256 opIndex, uint256 count)
        internal
        pure
        returns (IOperatorsRegistryV1.OperatorAllocation[] memory)
    {
        IOperatorsRegistryV1.OperatorAllocation[] memory allocations = new IOperatorsRegistryV1.OperatorAllocation[](1);
        allocations[0] = IOperatorsRegistryV1.OperatorAllocation({operatorIndex: opIndex, validatorCount: count});
        return allocations;
    }

    function _createMultiAllocation(uint256[] memory opIndexes, uint32[] memory counts)
        internal
        pure
        returns (IOperatorsRegistryV1.OperatorAllocation[] memory)
    {
        IOperatorsRegistryV1.OperatorAllocation[] memory allocations =
            new IOperatorsRegistryV1.OperatorAllocation[](opIndexes.length);
        for (uint256 i = 0; i < opIndexes.length; ++i) {
            allocations[i] =
                IOperatorsRegistryV1.OperatorAllocation({operatorIndex: opIndexes[i], validatorCount: counts[i]});
        }
        return allocations;
    }

    function testInitializeTwice() public {
        vm.expectRevert(abi.encodeWithSignature("InvalidInitialization(uint256,uint256)", 0, 1));
        operatorsRegistry.initOperatorsRegistryV1(admin, river);
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
            operatorsRegistry.pickNextValidatorsToDeposit(_createAllocation(index, 10));
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
        operatorsRegistry.pickNextValidatorsToDeposit(_createAllocation(index, 10));
        vm.stopPrank();

        // Request within limit
        vm.startPrank(river);
        (bytes[] memory publicKeys, bytes[] memory signatures) =
            operatorsRegistry.pickNextValidatorsToDeposit(_createAllocation(index, 5));
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
            operatorsRegistry.pickNextValidatorsToDeposit(allocation);

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
        (publicKeys, signatures) = operatorsRegistry.pickNextValidatorsToDeposit(allocation);

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
        (publicKeys, signatures) = operatorsRegistry.pickNextValidatorsToDeposit(largeAllocation);

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
        (publicKeys, signatures) = operatorsRegistry.pickNextValidatorsToDeposit(finalAllocation);

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

    function testGetKeysAsRiverNoKeys() public {
        // Create an allocation for an operator that doesn't exist or has no keys
        // This should succeed but return empty arrays since count is 0 for non-existent operators
        IOperatorsRegistryV1.OperatorAllocation[] memory emptyAllocation =
            new IOperatorsRegistryV1.OperatorAllocation[](0);
        vm.startPrank(river);
        (bytes[] memory publicKeys,) = operatorsRegistry.pickNextValidatorsToDeposit(emptyAllocation);
        vm.stopPrank();
        assert(publicKeys.length == 0);
    }

    function testGetKeysAsUnauthorized() public {
        vm.expectRevert(abi.encodeWithSignature("Unauthorized(address)", address(this)));
        operatorsRegistry.pickNextValidatorsToDeposit(_createAllocation(0, 10));
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
            .pickNextValidatorsToDeposit(_createMultiAllocation(operators, limits));

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
            .pickNextValidatorsToDeposit(_createMultiAllocation(operators, limits));

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
            operatorsRegistry.pickNextValidatorsToDeposit(_createAllocation(1, 5));

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
            operatorsRegistry.pickNextValidatorsToDeposit(_createAllocation(2, 5));

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
            operatorsRegistry.pickNextValidatorsToDeposit(_createAllocation(2, 3));
        assertEq(publicKeys.length, 3);
        assertEq(signatures.length, 3);
        assertEq(operatorsRegistry.getOperator(0).funded, 0);
        assertEq(operatorsRegistry.getOperator(1).funded, 0);
        assertEq(operatorsRegistry.getOperator(2).funded, 3);

        // Test 2: Now allocate to operator 1 (forces loop to iterate once with false before true)
        vm.prank(river);
        (publicKeys, signatures) = operatorsRegistry.pickNextValidatorsToDeposit(_createAllocation(1, 2));
        assertEq(publicKeys.length, 2);
        assertEq(signatures.length, 2);
        assertEq(operatorsRegistry.getOperator(0).funded, 0);
        assertEq(operatorsRegistry.getOperator(1).funded, 2);
        assertEq(operatorsRegistry.getOperator(2).funded, 3);

        // Test 3: Allocate to operator 0 (first match, no false iterations needed)
        vm.prank(river);
        (publicKeys, signatures) = operatorsRegistry.pickNextValidatorsToDeposit(_createAllocation(0, 1));
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

contract OperatorsRegistryV1TestDistribution is Test {
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

    function _createAllocation(uint256[] memory opIndexes, uint32[] memory counts)
        internal
        pure
        returns (IOperatorsRegistryV1.OperatorAllocation[] memory)
    {
        IOperatorsRegistryV1.OperatorAllocation[] memory allocations =
            new IOperatorsRegistryV1.OperatorAllocation[](opIndexes.length);
        for (uint256 i = 0; i < opIndexes.length; ++i) {
            allocations[i] =
                IOperatorsRegistryV1.OperatorAllocation({operatorIndex: opIndexes[i], validatorCount: counts[i]});
        }
        return allocations;
    }

    function _createMultiAllocation(uint256[] memory opIndexes, uint32[] memory counts)
        internal
        pure
        returns (IOperatorsRegistryV1.OperatorAllocation[] memory)
    {
        return _createAllocation(opIndexes, counts);
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
                ).pickNextValidatorsToDeposit(_createAllocation(operators, allocCounts));

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
                ).pickNextValidatorsToDeposit(_createAllocation(operators, allocCounts2));

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
            .pickNextValidatorsToDeposit(_createAllocation(operators, allocCounts));
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
                ).pickNextValidatorsToDeposit(_createAllocation(activeOperators, limits));

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
                .pickNextValidatorsToDeposit(_createAllocation(operators, allocCounts));
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
                ).pickNextValidatorsToDeposit(_createAllocation(allOps, allocCounts));

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
                .pickNextValidatorsToDeposit(_createAllocation(operators, allocCounts));
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
                .pickNextValidatorsToDeposit(_createAllocation(alloOperators, allocCounts));
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
            .pickNextValidatorsToDeposit(_createAllocation(operators, limits));
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
        vm.expectRevert(abi.encodeWithSignature("ExitsRequestedExceedsFundedCount(uint256,uint256,uint256)", 0, 60, 50));
        operatorsRegistry.requestValidatorExits(_createAllocation(operators, limits));
    }

    function testRequestExitsRequestedExceedsDemand() external {
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
            .pickNextValidatorsToDeposit(_createAllocation(operators, limits));
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
        vm.expectRevert(abi.encodeWithSignature("ExitsRequestedExceedsDemand(uint256,uint256)", 250, 10));
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
            .pickNextValidatorsToDeposit(_createAllocation(operators, limits));
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
            .pickNextValidatorsToDeposit(_createAllocation(operators, limits));
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
            .pickNextValidatorsToDeposit(_createAllocation(operators, limits));
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
            .pickNextValidatorsToDeposit(_createAllocation(operators, limits));
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
            .pickNextValidatorsToDeposit(_createAllocation(operators, limits));
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
            .pickNextValidatorsToDeposit(_createAllocation(operators, limits));

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
            .pickNextValidatorsToDeposit(_createAllocation(operators, limits));

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
            .pickNextValidatorsToDeposit(_createMultiAllocation(operators, limits));

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
            .pickNextValidatorsToDeposit(_createAllocation(operators, limits));

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
            .pickNextValidatorsToDeposit(_createAllocation(operators, limits));

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
            .pickNextValidatorsToDeposit(_createAllocation(operators, limits));
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
            .pickNextValidatorsToDeposit(_createAllocation(allocOperators, allocCounts));
    }

    function testGetNextValidatorsToDepositReturnsEmptyArraysWhenOperatorInactive() public {
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

    function testPickNextValidatorsToDepositReturnsEmptyArraysWhenOperatorInactive() public {
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
        OperatorsRegistryInitializableV1(address(operatorsRegistry)).pickNextValidatorsToDeposit(allocation);
    }

    function testGetNextValidatorsToDepositForNoOperators() public {
        // Create an allocation with no operators
        IOperatorsRegistryV1.OperatorAllocation[] memory allocation = new IOperatorsRegistryV1.OperatorAllocation[](0);

        (bytes[] memory publicKeys, bytes[] memory signatures) =
            operatorsRegistry.getNextValidatorsToDepositFromActiveOperators(allocation);
        assert(publicKeys.length == 0);
        assert(signatures.length == 0);
    }

    function testPickNextValidatorsToDepositForNoOperators() public {
        // Create an allocation with no operators
        IOperatorsRegistryV1.OperatorAllocation[] memory allocation = new IOperatorsRegistryV1.OperatorAllocation[](0);

        (bytes[] memory publicKeys, bytes[] memory signatures) =
            OperatorsRegistryInitializableV1(address(operatorsRegistry)).pickNextValidatorsToDeposit(allocation);
        assert(publicKeys.length == 0);
        assert(signatures.length == 0);
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
        operatorsRegistry.pickNextValidatorsToDeposit(allocation);
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
        operatorsRegistry.pickNextValidatorsToDeposit(allocation);
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
        operatorsRegistry.pickNextValidatorsToDeposit(allocation);
    }

    function testGetNextValidatorsToDepositRevertsInactiveOperator() public {
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
        vm.prank(admin);
        operatorsRegistry.setOperatorLimits(operators, limits, block.number);

        // Create allocation with operator index that doesn't exist (only operator 0 exists)
        IOperatorsRegistryV1.OperatorAllocation[] memory allocation = new IOperatorsRegistryV1.OperatorAllocation[](1);
        allocation[0] = IOperatorsRegistryV1.OperatorAllocation({operatorIndex: 99, validatorCount: 5});

        vm.prank(river);
        vm.expectRevert(abi.encodeWithSignature("OperatorNotFound(uint256)", 99));
        operatorsRegistry.pickNextValidatorsToDeposit(allocation);
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
        vm.prank(admin);
        operatorsRegistry.setOperatorLimits(operators, limits, block.number);

        // Request operator 99 which doesn't exist - reverts OperatorNotFound
        IOperatorsRegistryV1.OperatorAllocation[] memory allocation = new IOperatorsRegistryV1.OperatorAllocation[](1);
        allocation[0] = IOperatorsRegistryV1.OperatorAllocation({operatorIndex: 99, validatorCount: 5});

        vm.prank(river);
        vm.expectRevert(abi.encodeWithSignature("OperatorNotFound(uint256)", 99));
        operatorsRegistry.pickNextValidatorsToDeposit(allocation);
    }

    function testVersion() external {
        assertEq(operatorsRegistry.version(), "1.2.1");
    }

    function testGetNextValidatorsToDepositFromActiveOperatorsReturnsEmptyWhenNoFundableOperators() public {
        // Create an empty allocation array - returns empty arrays
        IOperatorsRegistryV1.OperatorAllocation[] memory allocation = new IOperatorsRegistryV1.OperatorAllocation[](0);

        (bytes[] memory publicKeys, bytes[] memory signatures) =
            operatorsRegistry.getNextValidatorsToDepositFromActiveOperators(allocation);

        // Should return empty arrays since there are no fundable operators
        assertEq(publicKeys.length, 0, "Expected empty publicKeys array");
        assertEq(signatures.length, 0, "Expected empty signatures array");
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
        operatorsRegistry.pickNextValidatorsToDeposit(allocation);
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
        operatorsRegistry.pickNextValidatorsToDeposit(_createAllocation(fundOps, fundCounts));

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
        operatorsRegistry.pickNextValidatorsToDeposit(firstAllocation);

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
            operatorsRegistry.pickNextValidatorsToDeposit(allocation);

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
        operatorsRegistry.pickNextValidatorsToDeposit(allocation1);

        OperatorsV2.Operator memory op = operatorsRegistry.getOperator(0);
        assertEq(op.funded, 3, "Expected 3 funded after first allocation");

        // Second allocation: fund 4 more validators
        IOperatorsRegistryV1.OperatorAllocation[] memory allocation2 = new IOperatorsRegistryV1.OperatorAllocation[](1);
        allocation2[0] = IOperatorsRegistryV1.OperatorAllocation({operatorIndex: 0, validatorCount: 4});

        vm.prank(river);
        operatorsRegistry.pickNextValidatorsToDeposit(allocation2);

        op = operatorsRegistry.getOperator(0);
        assertEq(op.funded, 7, "Expected 7 funded after second allocation");

        // Third allocation: try to fund exactly the remaining 3
        IOperatorsRegistryV1.OperatorAllocation[] memory allocation3 = new IOperatorsRegistryV1.OperatorAllocation[](1);
        allocation3[0] = IOperatorsRegistryV1.OperatorAllocation({operatorIndex: 0, validatorCount: 3});

        vm.prank(river);
        operatorsRegistry.pickNextValidatorsToDeposit(allocation3);

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
        operatorsRegistry.pickNextValidatorsToDeposit(allocation1);

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
        operatorsRegistry.pickNextValidatorsToDeposit(allocation);

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
        operatorsRegistry.pickNextValidatorsToDeposit(allocation1);

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
        operatorsRegistry.pickNextValidatorsToDeposit(allocation2);

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
        operatorsRegistry.pickNextValidatorsToDeposit(allocation1);

        // Now allocate from both operators: 4 from op0 (has 4 remaining) and 5 from op1 (has 10)
        IOperatorsRegistryV1.OperatorAllocation[] memory allocation2 = new IOperatorsRegistryV1.OperatorAllocation[](2);
        allocation2[0] = IOperatorsRegistryV1.OperatorAllocation({operatorIndex: 0, validatorCount: 4});
        allocation2[1] = IOperatorsRegistryV1.OperatorAllocation({operatorIndex: 1, validatorCount: 5});

        vm.prank(river);
        (bytes[] memory publicKeys, bytes[] memory signatures) =
            operatorsRegistry.pickNextValidatorsToDeposit(allocation2);

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
    function testPickReturnsEmptyWhenNoFundableOperators() public {
        // No operators have keys or limits set, so none are fundable
        IOperatorsRegistryV1.OperatorAllocation[] memory allocation = new IOperatorsRegistryV1.OperatorAllocation[](0);

        vm.prank(river);
        (bytes[] memory publicKeys, bytes[] memory signatures) =
            operatorsRegistry.pickNextValidatorsToDeposit(allocation);

        assertEq(publicKeys.length, 0, "Expected empty publicKeys");
        assertEq(signatures.length, 0, "Expected empty signatures");
    }
}
