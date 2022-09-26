//SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import "../src/OperatorsRegistry.1.sol";
import "./utils/UserFactory.sol";
import "./utils/BytesGenerator.sol";
import "forge-std/Test.sol";

contract OperatorsRegistryInitializableV1 is OperatorsRegistryV1 {
    function sudoSetFunded(uint256 _index, uint256 _funded) external {
        Operators.Operator storage operator = Operators.get(_index);
        operator.funded = _funded;
    }

    function debugGetNextValidatorsFromActiveOperators(uint256 _requestedAmount)
        external
        returns (bytes[] memory publicKeys, bytes[] memory signatures)
    {
        return _pickNextValidatorsFromActiveOperators(_requestedAmount);
    }
}

contract OperatorsRegistryV1Tests is Test, BytesGenerator {
    UserFactory internal uf = new UserFactory();

    OperatorsRegistryV1 internal operatorsRegistry;
    address internal admin;
    address internal river;
    string internal firstName = "Operator One";
    string internal secondName = "Operator Two";

    event AddedValidatorKeys(uint256 indexed index, bytes publicKeys);
    event RemovedValidatorKey(uint256 indexed index, bytes publicKey);
    event SetRiver(address indexed river);

    function setUp() public {
        admin = makeAddr("admin");
        river = makeAddr("river");
        operatorsRegistry = new OperatorsRegistryInitializableV1();
        operatorsRegistry.initOperatorsRegistryV1(admin, river);
    }

    function testInitializeTwice() public {
        vm.expectRevert(abi.encodeWithSignature("InvalidInitialization(uint256,uint256)", 0, 1));
        operatorsRegistry.initOperatorsRegistryV1(admin, river);
    }

    function testSetRiver(uint256 _newRiverSalt) public {
        address _newRiverAddress = uf._new(_newRiverSalt);
        assert(operatorsRegistry.getRiver() == river);
        vm.startPrank(admin);
        vm.expectEmit(true, true, true, true);
        emit SetRiver(_newRiverAddress);
        operatorsRegistry.setRiver(_newRiverAddress);
        vm.stopPrank();
        assert(operatorsRegistry.getRiver() == _newRiverAddress);
    }

    function testSetRiverUnauthorized(uint256 _newRiverSalt) public {
        address _newRiverAddress = uf._new(_newRiverSalt);
        assert(operatorsRegistry.getRiver() == river);
        vm.expectRevert(abi.encodeWithSignature("Unauthorized(address)", address(this)));
        operatorsRegistry.setRiver(_newRiverAddress);
    }

    function testAddNodeOperator(uint256 _nodeOperatorAddressSalt, bytes32 _name) public {
        address _nodeOperatorAddress = uf._new(_nodeOperatorAddressSalt);
        vm.startPrank(admin);
        uint256 operatorIndex = operatorsRegistry.addOperator(string(abi.encodePacked(_name)), _nodeOperatorAddress);
        Operators.Operator memory newOperator = operatorsRegistry.getOperator(operatorIndex);
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
        uint256[] memory limits = new uint256[](1);
        limits[0] = 1;
        vm.expectRevert(abi.encodeWithSignature("OperatorLimitTooHigh(uint256,uint256)", 1, 0));
        operatorsRegistry.setOperatorLimits(indexes, limits);
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
        uint256[] memory limits = new uint256[](1);
        limits[0] = 1;
        operatorsRegistry.setOperatorLimits(indexes, limits);
        OperatorsRegistryInitializableV1(address(operatorsRegistry)).sudoSetFunded(0, 1);
        limits[0] = 0;
        vm.expectRevert(abi.encodeWithSignature("OperatorLimitTooLow(uint256,uint256)", 0, 1));
        operatorsRegistry.setOperatorLimits(indexes, limits);
        vm.stopPrank();
    }

    function testSetOperatorAddressesAsAdmin(bytes32 _name, uint256 _firstAddressSalt, uint256 _secondAddressSalt)
        public
    {
        address _firstAddress = uf._new(_firstAddressSalt);
        address _secondAddress = uf._new(_secondAddressSalt);
        vm.startPrank(admin);
        uint256 index = operatorsRegistry.addOperator(string(abi.encodePacked(_name)), _firstAddress);
        Operators.Operator memory newOperator = operatorsRegistry.getOperator(index);
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
        Operators.Operator memory newOperator = operatorsRegistry.getOperator(index);
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
        Operators.Operator memory newOperator = operatorsRegistry.getOperator(index);
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
        Operators.Operator memory newOperator = operatorsRegistry.getOperator(index);
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
        Operators.Operator memory newOperator = operatorsRegistry.getOperator(index);
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
        Operators.Operator memory newOperator = operatorsRegistry.getOperator(index);
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
        Operators.Operator memory newOperator = operatorsRegistry.getOperator(index);
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
        Operators.Operator memory newOperator = operatorsRegistry.getOperator(index);
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
        Operators.Operator memory newOperator = operatorsRegistry.getOperator(index);
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
        Operators.Operator memory newOperator = operatorsRegistry.getOperator(index);
        assert(newOperator.active == true);
        vm.stopPrank();
        vm.startPrank(address(this));
        vm.expectRevert(abi.encodeWithSignature("Unauthorized(address)", address(this)));
        operatorsRegistry.setOperatorStatus(index, false);
    }

    function testSetOperatorStoppedValidatorCountWhileUnfunded(
        bytes32 _name,
        uint256 _firstAddressSalt,
        uint128 _stoppedCount
    ) public {
        address _firstAddress = uf._new(_firstAddressSalt);
        vm.startPrank(admin);
        uint256 index = operatorsRegistry.addOperator(string(abi.encodePacked(_name)), _firstAddress);
        Operators.Operator memory newOperator = operatorsRegistry.getOperator(index);
        assert(newOperator.stopped == 0);
        if (_stoppedCount > 0) {
            vm.expectRevert(abi.encodeWithSignature("InvalidArgument()"));
        }
        operatorsRegistry.setOperatorStoppedValidatorCount(index, _stoppedCount);
    }

    function testSetOperatorStoppedValidatorCountAsAdmin(
        bytes32 _name,
        uint256 _firstAddressSalt,
        uint128 _stoppedCount
    ) public {
        address _firstAddress = uf._new(_firstAddressSalt);
        vm.startPrank(admin);
        uint256 index = operatorsRegistry.addOperator(string(abi.encodePacked(_name)), _firstAddress);
        Operators.Operator memory newOperator = operatorsRegistry.getOperator(index);
        assert(newOperator.stopped == 0);
        OperatorsRegistryInitializableV1(address(operatorsRegistry)).sudoSetFunded(index, uint256(_stoppedCount) + 1);
        operatorsRegistry.setOperatorStoppedValidatorCount(index, _stoppedCount);
        newOperator = operatorsRegistry.getOperator(index);
        assert(newOperator.stopped == _stoppedCount);
        operatorsRegistry.setOperatorStoppedValidatorCount(index, 0);
        newOperator = operatorsRegistry.getOperator(index);
        assert(newOperator.stopped == 0);
    }

    function testSetOperatorStoppedValidatorCountAsUnauthorized(
        bytes32 _name,
        uint256 _firstAddressSalt,
        uint256 _stoppedCount
    ) public {
        address _firstAddress = uf._new(_firstAddressSalt);
        vm.startPrank(admin);
        uint256 index = operatorsRegistry.addOperator(string(abi.encodePacked(_name)), _firstAddress);
        Operators.Operator memory newOperator = operatorsRegistry.getOperator(index);
        assert(newOperator.stopped == 0);
        vm.stopPrank();
        vm.startPrank(address(this));
        vm.expectRevert(abi.encodeWithSignature("Unauthorized(address)", address(this)));
        operatorsRegistry.setOperatorStoppedValidatorCount(index, _stoppedCount);
    }

    function testSetOperatorLimitCountAsAdmin(bytes32 _name, uint256 _firstAddressSalt, uint256 _limit) public {
        address _firstAddress = uf._new(_firstAddressSalt);
        _limit = _limit % 11; // 10 is max
        vm.startPrank(admin);
        uint256 index = operatorsRegistry.addOperator(string(abi.encodePacked(_name)), _firstAddress);

        bytes memory tenKeys = genBytes((48 + 96) * 10);

        operatorsRegistry.addValidators(index, 10, tenKeys);

        Operators.Operator memory newOperator = operatorsRegistry.getOperator(index);
        assert(newOperator.limit == 0);
        uint256[] memory operatorIndexes = new uint256[](1);
        operatorIndexes[0] = index;
        uint256[] memory operatorLimits = new uint256[](1);
        operatorLimits[0] = _limit;
        operatorsRegistry.setOperatorLimits(operatorIndexes, operatorLimits);
        newOperator = operatorsRegistry.getOperator(index);
        assert(newOperator.limit == _limit);
        operatorLimits[0] = 0;
        operatorsRegistry.setOperatorLimits(operatorIndexes, operatorLimits);
        newOperator = operatorsRegistry.getOperator(index);
        assert(newOperator.limit == 0);
    }

    function testSetOperatorLimitCountAsUnauthorized(bytes32 _name, uint256 _firstAddressSalt, uint256 _limit) public {
        address _firstAddress = uf._new(_firstAddressSalt);
        vm.startPrank(admin);
        uint256 index = operatorsRegistry.addOperator(string(abi.encodePacked(_name)), _firstAddress);
        Operators.Operator memory newOperator = operatorsRegistry.getOperator(index);
        assert(newOperator.limit == 0);
        vm.stopPrank();
        vm.startPrank(address(this));
        uint256[] memory operatorIndexes = new uint256[](1);
        operatorIndexes[0] = index;
        uint256[] memory operatorLimits = new uint256[](1);
        operatorLimits[0] = _limit;
        vm.expectRevert(abi.encodeWithSignature("Unauthorized(address)", address(this)));
        operatorsRegistry.setOperatorLimits(operatorIndexes, operatorLimits);
    }

    event AddedValidatorKeys(uint256 indexed index, uint256 amount);

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

        Operators.Operator memory operator = operatorsRegistry.getOperator(index);
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
        uint256[] memory limits = new uint256[](1);
        limits[0] = 10;
        operatorsRegistry.setOperatorLimits(operatorIndexes, limits);
        vm.stopPrank();

        vm.startPrank(river);
        (bytes[] memory publicKeys, bytes[] memory signatures) = operatorsRegistry.pickNextValidators(10);
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
        uint256[] memory limits = new uint256[](1);
        limits[0] = 5;
        operatorsRegistry.setOperatorLimits(operatorIndexes, limits);
        vm.stopPrank();

        vm.startPrank(river);
        (bytes[] memory publicKeys, bytes[] memory signatures) = operatorsRegistry.pickNextValidators(10);
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
        uint256[] memory limits = new uint256[](3);
        limits[0] = 50;
        limits[1] = 50;
        limits[2] = 50;
        vm.prank(admin);
        operatorsRegistry.setOperatorLimits(indexes, limits);
        vm.prank(river);
        (bytes[] memory publicKeys, bytes[] memory signatures) = operatorsRegistry.pickNextValidators(6);

        assert(publicKeys.length == 6);
        assert(signatures.length == 6);

        {
            Operators.Operator memory op = operatorsRegistry.getOperator(0);
            assert(op.limit == 50);
            assert(op.funded == 5);
            assert(op.keys == 50);
            assert(op.stopped == 0);
        }

        {
            Operators.Operator memory op = operatorsRegistry.getOperator(1);
            assert(op.limit == 50);
            assert(op.funded == 1);
            assert(op.keys == 50);
            assert(op.stopped == 0);
        }

        {
            Operators.Operator memory op = operatorsRegistry.getOperator(2);
            assert(op.limit == 50);
            assert(op.funded == 0);
            assert(op.keys == 50);
            assert(op.stopped == 0);
        }
        vm.prank(river);
        (publicKeys, signatures) = operatorsRegistry.pickNextValidators(6);

        assert(publicKeys.length == 6);
        assert(signatures.length == 6);

        {
            Operators.Operator memory op = operatorsRegistry.getOperator(0);
            assert(op.limit == 50);
            assert(op.funded == 5);
            assert(op.keys == 50);
            assert(op.stopped == 0);
        }

        {
            Operators.Operator memory op = operatorsRegistry.getOperator(1);
            assert(op.limit == 50);
            assert(op.funded == 2);
            assert(op.keys == 50);
            assert(op.stopped == 0);
        }

        {
            Operators.Operator memory op = operatorsRegistry.getOperator(2);
            assert(op.limit == 50);
            assert(op.funded == 5);
            assert(op.keys == 50);
            assert(op.stopped == 0);
        }

        vm.prank(river);
        (publicKeys, signatures) = operatorsRegistry.pickNextValidators(64);

        assert(publicKeys.length == 64);
        assert(signatures.length == 64);

        {
            Operators.Operator memory op = operatorsRegistry.getOperator(0);
            assert(op.limit == 50);
            assert(op.funded == 25);
            assert(op.keys == 50);
            assert(op.stopped == 0);
        }

        {
            Operators.Operator memory op = operatorsRegistry.getOperator(1);
            assert(op.limit == 50);
            assert(op.funded == 26);
            assert(op.keys == 50);
            assert(op.stopped == 0);
        }

        {
            Operators.Operator memory op = operatorsRegistry.getOperator(2);
            assert(op.limit == 50);
            assert(op.funded == 25);
            assert(op.keys == 50);
            assert(op.stopped == 0);
        }

        vm.prank(river);
        (publicKeys, signatures) = operatorsRegistry.pickNextValidators(74);

        assert(publicKeys.length == 74);
        assert(signatures.length == 74);

        {
            Operators.Operator memory op = operatorsRegistry.getOperator(0);
            assert(op.limit == 50);
            assert(op.funded == 50);
            assert(op.keys == 50);
            assert(op.stopped == 0);
        }

        {
            Operators.Operator memory op = operatorsRegistry.getOperator(1);
            assert(op.limit == 50);
            assert(op.funded == 50);
            assert(op.keys == 50);
            assert(op.stopped == 0);
        }

        {
            Operators.Operator memory op = operatorsRegistry.getOperator(2);
            assert(op.limit == 50);
            assert(op.funded == 50);
            assert(op.keys == 50);
            assert(op.stopped == 0);
        }
    }

    function testGetAllActiveOperators(bytes32 _name, uint256 _firstAddressSalt) public {
        address _firstAddress = uf._new(_firstAddressSalt);
        vm.startPrank(admin);
        operatorsRegistry.addOperator(string(abi.encodePacked(_name)), _firstAddress);

        Operators.Operator[] memory operators = operatorsRegistry.listActiveOperators();

        assert(operators.length == 1);
        assert(keccak256(bytes(operators[0].name)) == keccak256(abi.encodePacked(_name)));
        assert(operators[0].operator == _firstAddress);
    }

    function testGetAllActiveOperatorsWithInactiveOnes(bytes32 _name, uint256 _firstAddressSalt) public {
        address _firstAddress = uf._new(_firstAddressSalt);
        vm.startPrank(admin);
        uint256 index = operatorsRegistry.addOperator(string(abi.encodePacked(_name)), _firstAddress);

        operatorsRegistry.setOperatorStatus(index, false);

        Operators.Operator[] memory operators = operatorsRegistry.listActiveOperators();

        assert(operators.length == 0);
    }

    function testGetKeysAsRiverNoKeys() public {
        vm.startPrank(river);
        (bytes[] memory publicKeys,) = operatorsRegistry.pickNextValidators(10);
        vm.stopPrank();
        assert(publicKeys.length == 0);
    }

    function testGetKeysAsUnauthorized() public {
        vm.expectRevert(abi.encodeWithSignature("Unauthorized(address)", address(this)));
        operatorsRegistry.pickNextValidators(10);
    }

    function testAddValidatorsAsAdmin(bytes32 _name, uint256 _firstAddressSalt) public {
        address _firstAddress = uf._new(_firstAddressSalt);
        vm.startPrank(admin);
        uint256 index = operatorsRegistry.addOperator(string(abi.encodePacked(_name)), _firstAddress);

        bytes memory tenKeys = genBytes((48 + 96) * 10);

        vm.expectEmit(true, true, true, true);
        emit AddedValidatorKeys(index, tenKeys);
        operatorsRegistry.addValidators(index, 10, tenKeys);

        Operators.Operator memory operator = operatorsRegistry.getOperator(index);
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

        Operators.Operator memory operator = operatorsRegistry.getOperator(index);
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
        uint256[] memory limits = new uint256[](1);
        operators[0] = index;
        limits[0] = 10;
        operatorsRegistry.setOperatorLimits(operators, limits);
        vm.stopPrank();
        vm.startPrank(_firstAddress);

        Operators.Operator memory operator = operatorsRegistry.getOperator(index);
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
        uint256[] memory limits = new uint256[](1);
        operators[0] = index;
        limits[0] = 8;
        operatorsRegistry.setOperatorLimits(operators, limits);
        vm.stopPrank();
        vm.startPrank(_firstAddress);

        Operators.Operator memory operator = operatorsRegistry.getOperator(index);
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

        Operators.Operator memory operator = operatorsRegistry.getOperator(index);
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

        Operators.Operator memory operator = operatorsRegistry.getOperator(index);
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

        Operators.Operator memory operator = operatorsRegistry.getOperator(index);
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

        Operators.Operator memory operator = operatorsRegistry.getOperator(index);
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

        Operators.Operator memory operator = operatorsRegistry.getOperator(index);
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

        Operators.Operator memory operator = operatorsRegistry.getOperator(index);
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

    function testGetOperator(bytes32 _name, uint256 _firstAddressSalt) public {
        address _firstAddress = uf._new(_firstAddressSalt);
        vm.startPrank(admin);
        uint256 index = operatorsRegistry.addOperator(string(abi.encodePacked(_name)), _firstAddress);

        Operators.Operator memory operator = operatorsRegistry.getOperator(index);
        assert(operator.active == true);
    }

    function testGetOperatorCount(bytes32 _name, uint256 _firstAddressSalt) public {
        address _firstAddress = uf._new(_firstAddressSalt);
        vm.startPrank(admin);
        assert(operatorsRegistry.getOperatorCount() == 0);
        operatorsRegistry.addOperator(string(abi.encodePacked(_name)), _firstAddress);
        assert(operatorsRegistry.getOperatorCount() == 1);
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

    event AddedValidatorKeys(uint256 indexed index, bytes publicKeys);
    event RemovedValidatorKey(uint256 indexed index, bytes publicKey);

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
        river = makeAddr("river");

        operatorOne = makeAddr("operatorOne");
        operatorTwo = makeAddr("operatorTwo");
        operatorThree = makeAddr("operatorThree");
        operatorFour = makeAddr("operatorFour");
        operatorFive = makeAddr("operatorFive");

        operatorsRegistry = new OperatorsRegistryInitializableV1();
        operatorsRegistry.initOperatorsRegistryV1(admin, river);

        vm.startPrank(admin);
        operatorsRegistry.addOperator("operatorOne", operatorOne);
        operatorsRegistry.addOperator("operatorTwo", operatorTwo);
        operatorsRegistry.addOperator("operatorThree", operatorThree);
        operatorsRegistry.addOperator("operatorFour", operatorFour);
        operatorsRegistry.addOperator("operatorFive", operatorFive);
        vm.stopPrank();
    }

    function testRegularDistribution() external {
        vm.startPrank(admin);
        operatorsRegistry.addValidators(0, 50, genBytes((48 + 96) * 50));
        operatorsRegistry.addValidators(1, 50, genBytes((48 + 96) * 50));
        operatorsRegistry.addValidators(2, 50, genBytes((48 + 96) * 50));
        operatorsRegistry.addValidators(3, 50, genBytes((48 + 96) * 50));
        operatorsRegistry.addValidators(4, 50, genBytes((48 + 96) * 50));
        vm.stopPrank();

        uint256[] memory limits = new uint256[](5);
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
        operatorsRegistry.setOperatorLimits(operators, limits);

        {
            (bytes[] memory publicKeys, bytes[] memory signatures) = OperatorsRegistryInitializableV1(
                address(operatorsRegistry)
            ).debugGetNextValidatorsFromActiveOperators(50);

            assert(publicKeys.length == 50);
            assert(signatures.length == 50);

            assert(operatorsRegistry.getOperator(0).funded == 10);
            assert(operatorsRegistry.getOperator(1).funded == 10);
            assert(operatorsRegistry.getOperator(2).funded == 10);
            assert(operatorsRegistry.getOperator(3).funded == 10);
            assert(operatorsRegistry.getOperator(4).funded == 10);
        }
        {
            (bytes[] memory publicKeys, bytes[] memory signatures) = OperatorsRegistryInitializableV1(
                address(operatorsRegistry)
            ).debugGetNextValidatorsFromActiveOperators(200);

            assert(publicKeys.length == 200);
            assert(signatures.length == 200);

            assert(operatorsRegistry.getOperator(0).funded == 50);
            assert(operatorsRegistry.getOperator(1).funded == 50);
            assert(operatorsRegistry.getOperator(2).funded == 50);
            assert(operatorsRegistry.getOperator(3).funded == 50);
            assert(operatorsRegistry.getOperator(4).funded == 50);
        }
    }

    function testInactiveDistribution() external {
        vm.startPrank(admin);
        operatorsRegistry.addValidators(0, 50, genBytes((48 + 96) * 50));
        operatorsRegistry.addValidators(1, 50, genBytes((48 + 96) * 50));
        operatorsRegistry.addValidators(2, 50, genBytes((48 + 96) * 50));
        operatorsRegistry.addValidators(3, 50, genBytes((48 + 96) * 50));
        operatorsRegistry.addValidators(4, 50, genBytes((48 + 96) * 50));

        vm.stopPrank();

        uint256[] memory limits = new uint256[](5);
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

        vm.startPrank(admin);
        operatorsRegistry.setOperatorLimits(operators, limits);
        operatorsRegistry.setOperatorStatus(1, false);
        operatorsRegistry.setOperatorStatus(3, false);
        vm.stopPrank();

        {
            (bytes[] memory publicKeys, bytes[] memory signatures) = OperatorsRegistryInitializableV1(
                address(operatorsRegistry)
            ).debugGetNextValidatorsFromActiveOperators(250);

            assert(publicKeys.length == 150);
            assert(signatures.length == 150);

            assert(operatorsRegistry.getOperator(0).funded == 50);
            assert(operatorsRegistry.getOperator(1).funded == 0);
            assert(operatorsRegistry.getOperator(2).funded == 50);
            assert(operatorsRegistry.getOperator(3).funded == 0);
            assert(operatorsRegistry.getOperator(4).funded == 50);
        }
    }

    function testStoppedDistribution() external {
        vm.startPrank(admin);
        operatorsRegistry.addValidators(0, 50, genBytes((48 + 96) * 50));
        operatorsRegistry.addValidators(1, 50, genBytes((48 + 96) * 50));
        operatorsRegistry.addValidators(2, 50, genBytes((48 + 96) * 50));
        operatorsRegistry.addValidators(3, 50, genBytes((48 + 96) * 50));
        operatorsRegistry.addValidators(4, 50, genBytes((48 + 96) * 50));

        vm.stopPrank();

        uint256[] memory limits = new uint256[](3);
        limits[0] = 50;
        limits[1] = 50;
        limits[2] = 50;

        uint256[] memory operators = new uint256[](3);
        operators[0] = 0;
        operators[1] = 2;
        operators[2] = 4;

        vm.startPrank(admin);
        operatorsRegistry.setOperatorLimits(operators, limits);
        vm.stopPrank();

        OperatorsRegistryInitializableV1(address(operatorsRegistry)).debugGetNextValidatorsFromActiveOperators(75);
        assert(operatorsRegistry.getOperator(0).funded == 25);
        assert(operatorsRegistry.getOperator(1).funded == 0);
        assert(operatorsRegistry.getOperator(2).funded == 25);
        assert(operatorsRegistry.getOperator(3).funded == 0);
        assert(operatorsRegistry.getOperator(4).funded == 25);

        vm.startPrank(admin);
        operatorsRegistry.setOperatorStoppedValidatorCount(0, 25);
        operatorsRegistry.setOperatorStoppedValidatorCount(2, 25);
        operatorsRegistry.setOperatorStoppedValidatorCount(4, 25);

        limits = new uint256[](2);
        limits[0] = 50;
        limits[1] = 50;

        operators = new uint256[](2);
        operators[0] = 1;
        operators[1] = 3;

        operatorsRegistry.setOperatorLimits(operators, limits);

        vm.stopPrank();

        {
            (bytes[] memory publicKeys, bytes[] memory signatures) = OperatorsRegistryInitializableV1(
                address(operatorsRegistry)
            ).debugGetNextValidatorsFromActiveOperators(50);

            assert(publicKeys.length == 50);
            assert(signatures.length == 50);

            assert(operatorsRegistry.getOperator(0).funded == 35);
            assert(operatorsRegistry.getOperator(1).funded == 10);
            assert(operatorsRegistry.getOperator(2).funded == 35);
            assert(operatorsRegistry.getOperator(3).funded == 10);
            assert(operatorsRegistry.getOperator(4).funded == 35);
        }
    }
}
