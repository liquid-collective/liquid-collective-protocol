//SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import "../Vm.sol";
import "../../src/components/OperatorsManager.1.sol";
import "../../src/state/shared/AdministratorAddress.sol";
import "../utils/User.sol";

contract OperatorsManagerInitializableV1 is OperatorsManagerV1 {
    function publicOperatorsManagerInitializeV1(address _admin) external {
        AdministratorAddress.set(_admin);
    }

    function sudoSetFunded(string memory _name, uint256 _funded) external {
        Operators.Operator storage operator = Operators.get(_name);
        operator.funded = _funded;
    }

    function debugGetNextValidatorsFromActiveOperators(uint256 _requestedAmount)
        external
        returns (bytes[] memory publicKeys, bytes[] memory signatures)
    {
        return _getNextValidatorsFromActiveOperators(_requestedAmount);
    }
}

contract OperatorsManagerV1MemberManagementTests {
    Vm internal vm = Vm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    UserFactory internal uf = new UserFactory();

    OperatorsManagerV1 internal operatorsManager;
    address internal admin = address(0xEA674fdDe714fd979de3EdF0F56AA9716B898ec8);

    function setUp() public {
        operatorsManager = new OperatorsManagerInitializableV1();
        OperatorsManagerInitializableV1(address(operatorsManager)).publicOperatorsManagerInitializeV1(admin);
    }

    function testAddNodeOperator(uint256 _nodeOperatorAddressSalt, bytes32 _name) public {
        address _nodeOperatorAddress = uf._new(_nodeOperatorAddressSalt);
        vm.startPrank(admin);
        operatorsManager.addOperator(string(abi.encodePacked(_name)), _nodeOperatorAddress);
        Operators.Operator memory newOperator = operatorsManager.getOperatorByName(string(abi.encodePacked(_name)));
        assert(newOperator.operator == _nodeOperatorAddress);
    }

    function testAddNodeWhileNotAdminOperator(uint256 _nodeOperatorAddressSalt, bytes32 _name) public {
        address _nodeOperatorAddress = uf._new(_nodeOperatorAddressSalt);
        vm.expectRevert(abi.encodeWithSignature("Unauthorized(address)", address(this)));
        operatorsManager.addOperator(string(abi.encodePacked(_name)), _nodeOperatorAddress);
    }

    function testGetInexistingNodeOperator(bytes32 _name) public {
        vm.startPrank(admin);
        vm.expectRevert(abi.encodeWithSignature("OperatorNotFound(string)", string(abi.encodePacked(_name))));
        operatorsManager.getOperatorByName(string(abi.encodePacked(_name)));
    }

    function testSetOperatorAddressAsAdmin(
        bytes32 _name,
        uint256 _firstAddressSalt,
        uint256 _secondAddressSalt
    ) public {
        address _firstAddress = uf._new(_firstAddressSalt);
        address _secondAddress = uf._new(_secondAddressSalt);
        vm.startPrank(admin);
        operatorsManager.addOperator(string(abi.encodePacked(_name)), _firstAddress);
        (int256 _index, ) = operatorsManager.getOperatorDetails(string(abi.encodePacked(_name)));
        assert(_index >= 0);
        uint256 index = uint256(_index);
        Operators.Operator memory newOperator = operatorsManager.getOperator(index);
        assert(newOperator.operator == _firstAddress);
        operatorsManager.setOperatorAddress(index, _secondAddress);
        newOperator = operatorsManager.getOperatorByName(string(abi.encodePacked(_name)));
        assert(newOperator.operator == _secondAddress);
    }

    function testSetOperatorAddressAsOperator(
        bytes32 _name,
        uint256 _firstAddressSalt,
        uint256 _secondAddressSalt
    ) public {
        address _firstAddress = uf._new(_firstAddressSalt);
        address _secondAddress = uf._new(_secondAddressSalt);
        vm.startPrank(admin);
        operatorsManager.addOperator(string(abi.encodePacked(_name)), _firstAddress);
        (int256 _index, ) = operatorsManager.getOperatorDetails(string(abi.encodePacked(_name)));
        assert(_index >= 0);
        uint256 index = uint256(_index);
        Operators.Operator memory newOperator = operatorsManager.getOperator(index);
        assert(newOperator.operator == _firstAddress);
        vm.stopPrank();
        vm.startPrank(_firstAddress);
        operatorsManager.setOperatorAddress(index, _secondAddress);
        newOperator = operatorsManager.getOperatorByName(string(abi.encodePacked(_name)));
        assert(newOperator.operator == _secondAddress);
    }

    function testSetOperatorAddressAsUnauthorized(
        bytes32 _name,
        uint256 _firstAddressSalt,
        uint256 _secondAddressSalt
    ) public {
        address _firstAddress = uf._new(_firstAddressSalt);
        address _secondAddress = uf._new(_secondAddressSalt);
        vm.startPrank(admin);
        operatorsManager.addOperator(string(abi.encodePacked(_name)), _firstAddress);
        (int256 _index, ) = operatorsManager.getOperatorDetails(string(abi.encodePacked(_name)));
        assert(_index >= 0);
        uint256 index = uint256(_index);
        Operators.Operator memory newOperator = operatorsManager.getOperator(index);
        assert(newOperator.operator == _firstAddress);
        vm.stopPrank();
        vm.startPrank(address(this));
        vm.expectRevert(abi.encodeWithSignature("Unauthorized(address)", address(this)));
        operatorsManager.setOperatorAddress(index, _secondAddress);
    }

    function testSetOperatorStatusAsAdmin(bytes32 _name, uint256 _firstAddressSalt) public {
        address _firstAddress = uf._new(_firstAddressSalt);
        vm.startPrank(admin);
        operatorsManager.addOperator(string(abi.encodePacked(_name)), _firstAddress);
        (int256 _index, ) = operatorsManager.getOperatorDetails(string(abi.encodePacked(_name)));
        assert(_index >= 0);
        uint256 index = uint256(_index);
        Operators.Operator memory newOperator = operatorsManager.getOperator(index);
        assert(newOperator.active == true);
        operatorsManager.setOperatorStatus(index, false);
        newOperator = operatorsManager.getOperator(index);
        assert(newOperator.active == false);
        operatorsManager.setOperatorStatus(index, true);
        newOperator = operatorsManager.getOperator(index);
        assert(newOperator.active == true);
    }

    function testSetOperatorStatusAsUnauthorized(bytes32 _name, uint256 _firstAddressSalt) public {
        address _firstAddress = uf._new(_firstAddressSalt);
        vm.startPrank(admin);
        operatorsManager.addOperator(string(abi.encodePacked(_name)), _firstAddress);
        (int256 _index, ) = operatorsManager.getOperatorDetails(string(abi.encodePacked(_name)));
        assert(_index >= 0);
        uint256 index = uint256(_index);
        Operators.Operator memory newOperator = operatorsManager.getOperator(index);
        assert(newOperator.active == true);
        vm.stopPrank();
        vm.startPrank(address(this));
        vm.expectRevert(abi.encodeWithSignature("Unauthorized(address)", address(this)));
        operatorsManager.setOperatorStatus(index, false);
    }

    function testSetOperatorStoppedValidatorCountWhileUnfunded(
        bytes32 _name,
        uint256 _firstAddressSalt,
        uint128 _stoppedCount
    ) public {
        address _firstAddress = uf._new(_firstAddressSalt);
        vm.startPrank(admin);
        operatorsManager.addOperator(string(abi.encodePacked(_name)), _firstAddress);
        (int256 _index, ) = operatorsManager.getOperatorDetails(string(abi.encodePacked(_name)));
        assert(_index >= 0);
        uint256 index = uint256(_index);
        Operators.Operator memory newOperator = operatorsManager.getOperator(index);
        assert(newOperator.stopped == 0);
        if (_stoppedCount > 0) {
            vm.expectRevert(abi.encodeWithSignature("InvalidArgument()"));
        }
        operatorsManager.setOperatorStoppedValidatorCount(index, _stoppedCount);
    }

    function testSetOperatorStoppedValidatorCountAsAdmin(
        bytes32 _name,
        uint256 _firstAddressSalt,
        uint128 _stoppedCount
    ) public {
        address _firstAddress = uf._new(_firstAddressSalt);
        vm.startPrank(admin);
        operatorsManager.addOperator(string(abi.encodePacked(_name)), _firstAddress);
        (int256 _index, ) = operatorsManager.getOperatorDetails(string(abi.encodePacked(_name)));
        assert(_index >= 0);
        uint256 index = uint256(_index);
        Operators.Operator memory newOperator = operatorsManager.getOperator(index);
        assert(newOperator.stopped == 0);
        OperatorsManagerInitializableV1(address(operatorsManager)).sudoSetFunded(
            string(abi.encodePacked(_name)),
            uint256(_stoppedCount) + 1
        );
        operatorsManager.setOperatorStoppedValidatorCount(index, _stoppedCount);
        newOperator = operatorsManager.getOperator(index);
        assert(newOperator.stopped == _stoppedCount);
        operatorsManager.setOperatorStoppedValidatorCount(index, 0);
        newOperator = operatorsManager.getOperator(index);
        assert(newOperator.stopped == 0);
    }

    function testSetOperatorStoppedValidatorCountAsUnauthorized(
        bytes32 _name,
        uint256 _firstAddressSalt,
        uint256 _stoppedCount
    ) public {
        address _firstAddress = uf._new(_firstAddressSalt);
        vm.startPrank(admin);
        operatorsManager.addOperator(string(abi.encodePacked(_name)), _firstAddress);
        (int256 _index, ) = operatorsManager.getOperatorDetails(string(abi.encodePacked(_name)));
        assert(_index >= 0);
        uint256 index = uint256(_index);
        Operators.Operator memory newOperator = operatorsManager.getOperator(index);
        assert(newOperator.stopped == 0);
        vm.stopPrank();
        vm.startPrank(address(this));
        vm.expectRevert(abi.encodeWithSignature("Unauthorized(address)", address(this)));
        operatorsManager.setOperatorStoppedValidatorCount(index, _stoppedCount);
    }

    function testSetOperatorLimitCountAsAdmin(
        bytes32 _name,
        uint256 _firstAddressSalt,
        uint256 _limit
    ) public {
        address _firstAddress = uf._new(_firstAddressSalt);
        vm.startPrank(admin);
        operatorsManager.addOperator(string(abi.encodePacked(_name)), _firstAddress);
        (int256 _index, ) = operatorsManager.getOperatorDetails(string(abi.encodePacked(_name)));
        assert(_index >= 0);
        uint256 index = uint256(_index);
        Operators.Operator memory newOperator = operatorsManager.getOperator(index);
        assert(newOperator.limit == 0);
        operatorsManager.setOperatorLimit(index, _limit);
        newOperator = operatorsManager.getOperator(index);
        assert(newOperator.limit == _limit);
        operatorsManager.setOperatorLimit(index, 0);
        newOperator = operatorsManager.getOperator(index);
        assert(newOperator.limit == 0);
    }

    function testSetOperatorLimitCountAsUnauthorized(
        bytes32 _name,
        uint256 _firstAddressSalt,
        uint256 _limit
    ) public {
        address _firstAddress = uf._new(_firstAddressSalt);
        vm.startPrank(admin);
        operatorsManager.addOperator(string(abi.encodePacked(_name)), _firstAddress);
        (int256 _index, ) = operatorsManager.getOperatorDetails(string(abi.encodePacked(_name)));
        assert(_index >= 0);
        uint256 index = uint256(_index);
        Operators.Operator memory newOperator = operatorsManager.getOperator(index);
        assert(newOperator.limit == 0);
        vm.stopPrank();
        vm.startPrank(address(this));
        vm.expectRevert(abi.encodeWithSignature("Unauthorized(address)", address(this)));
        operatorsManager.setOperatorLimit(index, _limit);
    }

    event AddedValidatorKeys(uint256 indexed index, uint256 amount);

    function testAddValidatorsAsOperator(bytes32 _name, uint256 _firstAddressSalt) public {
        address _firstAddress = uf._new(_firstAddressSalt);
        vm.startPrank(admin);
        operatorsManager.addOperator(string(abi.encodePacked(_name)), _firstAddress);
        (int256 _index, ) = operatorsManager.getOperatorDetails(string(abi.encodePacked(_name)));
        assert(_index >= 0);
        uint256 index = uint256(_index);

        bytes
            memory tenPublicKeys = hex"e18e2e0fff999e38c547fb921bd915a1fef6a46e07db2705a57d17542f0acc6be99fee18fb2c17a7f247fc05edd722b9e95f700adf12dd6f20d65c2e411a6a447cb6f4f7c84b8b6673099385d5dcf964e479a9167c802d977ba0a0a22df2336f83182e83bc198c34c301482f189475209fb93d362704e317709fec266f14b3383e7bac3e0e306b1ac8228482c31d7ffbc7e0f865bd4648c7c45c1361f9cd0f4ccab693068a55e6823a4edd8ef4ced9faa64343866ad7357d488bff347a36f2476cc7b4eaf397c832968548ea70e1de2b2691628399d9f59fdd21a62dd3da50d0255790ec1c15949850a869a37595f8f52cc9d681f2b78748254ba36456f7e65d3c7ed2b64ef502cbd3c2f48d789924a99aedfbd097f4ff5829e787ef29b0b79c817337c08ff68c454a1ddc6359d09c0d48a9298a96691c3558812ca13239d9324f146a6b3bfb7bd3f2b1877929ceb74fa1ed590351801935d1e61c875c7772e74d037b26f972f2dfa0569ae9bf8cc32dee87e980497cd79492bf91edeafacfbd6ad32c642a6564ffc9a5d921d0cc35740314c88986547d8f94e60f5d3a2e0a0b1723d20546beaf064adfd78e5f63b600a6ee5b0bacf6f30bf456afadef451a1c503e428fcd295b5d20ad9e065e1684dced5487fd33270bb68b783a6963eab250";
        bytes
            memory tenSignatures = hex"1d40e9c75a57997aa60105f21d0c68c3be0435f1f68f755c33015110e38ef97b4b5e2008096e75b906ae4d1f5aec6ad505920c58758631a06ac8c7666b582c9b3fa70a67e39a5aec2a6a11756eb2c0dd74c33beafce3ce8396e86671e00528c0f4c6e9ccef87d852ac23e38f3a1585b710e4eeaa919b7040e49a55583b250801f4f54a7fc1d514ee4a89f2a0a31b500065ea383c4ff0d2981da1fc7e047239d1743c2ce0412a424fe7d32628d656c57d56a6f322d696b6099f44f5257e051cbfed1497e89d637a05b2063a30f232ceba1677e571b08c3c8bb84979d5fcab1652ae40c0840e29a32725d9b45fea996edce566ffff5be6d38d056c6a1827fb7b0ba69f1923a0384e8da72dced43b0e83714d2eda54916252859962b659e0a081fcb4ea39240afef5b8ae854eb4a159d1bdd9eed58aa368c690fe816052fd3f270215dd0ec0cc55e386ea43cb52849d00cc6a2efbec1d693619f9dcf64bfbc9c1982d1acc877b898f48d8337b372a338907dc7af4d8d58e08e1302313721fef9d9c1697256b3dc113bfc7860bccf01dc4d28d3ef09e43db4ecdd78c41bdc89ed50130b1b87ba137c33928f9aff8481e204d8ccd86938da666357cbf4d7253ce56eed980dc7ec2d4a610f541d8f7c830592bb39b8048848203ce74db2f585a7b8cd1ae6b47192b1983efddfb42c1ad65a0c9ceae3548565829c1bcd1a06da7ed4e10698fd2e5b2715a3cbae861909d8364f622882e080f0a07e153fb29c7c3abcc27f2011e76d09d013a5b511b0de51cbefc206c58cb9c09e405b5db80f1c98ea414ae2705de213715e01b81cda31c4ec814e50b341723dc4be0a81268cd04be2d306347540be98c2a3192a968dbad68ba2b5c066c684d18bdcb7345f1d2b643f2ff7bb8494c093eaaf31ee192c9a1486b387701c3bda0ed55af872665fcb0267e3e0b9e7d55e13555ec0f8742229898693ca26ddbb8cae390e9ec35fc3e07c21236fa8264974f9d3aea67a059d6e88111f48341ffdfa911ad89a2a2fbb2a790d69f3fc7646c0071b0c1ca25567f8e2b09d3177abb3e0ec38e4ebe0da06dd6cd03551682fd7ab3a772f5fbc5cba2afbd17d1ed064cae8db36b6bc6ab33b803a40fc7bc9fc7eb0327ee6486803672f653659cea6cc55212db194b9f7ecf1e0996117a489c5caf861425743681184ed3dbe5f8de71b5e7479ce13b6e1b5f6368b187185e9e14967ec04bb67d3797e4b0b2f00ee0cc61a7e2b2feff0a5ed98d503de0e8e3f445e328e8e8d45dc4453e10f49a6d642cbd90c06d7e81e64cf8d8562f6ef708a5761f1503e221ffa15a5318a880e25f8e3a7e79ce4bd263fdc6f683fb2cd1";

        vm.stopPrank();
        vm.startPrank(_firstAddress);
        vm.expectEmit(true, true, true, true);
        emit AddedValidatorKeys(index, 10);
        operatorsManager.addValidators(index, 10, tenPublicKeys, tenSignatures);

        Operators.Operator memory operator = operatorsManager.getOperator(index);
        assert(operator.keys == 10);

        (, , bool funded) = operatorsManager.getValidator(index, 0);
        assert(funded == false);
        (, , funded) = operatorsManager.getValidator(index, 1);
        assert(funded == false);

        OperatorsManagerInitializableV1(address(operatorsManager)).sudoSetFunded(string(abi.encodePacked(_name)), 1);

        (, , funded) = operatorsManager.getValidator(index, 0);
        assert(funded == true);
        (, , funded) = operatorsManager.getValidator(index, 1);
        assert(funded == false);
    }

    function testAddValidatorsAsAdmin(bytes32 _name, uint256 _firstAddressSalt) public {
        address _firstAddress = uf._new(_firstAddressSalt);
        vm.startPrank(admin);
        operatorsManager.addOperator(string(abi.encodePacked(_name)), _firstAddress);
        (int256 _index, ) = operatorsManager.getOperatorDetails(string(abi.encodePacked(_name)));
        assert(_index >= 0);
        uint256 index = uint256(_index);

        bytes
            memory tenPublicKeys = hex"e18e2e0fff999e38c547fb921bd915a1fef6a46e07db2705a57d17542f0acc6be99fee18fb2c17a7f247fc05edd722b9e95f700adf12dd6f20d65c2e411a6a447cb6f4f7c84b8b6673099385d5dcf964e479a9167c802d977ba0a0a22df2336f83182e83bc198c34c301482f189475209fb93d362704e317709fec266f14b3383e7bac3e0e306b1ac8228482c31d7ffbc7e0f865bd4648c7c45c1361f9cd0f4ccab693068a55e6823a4edd8ef4ced9faa64343866ad7357d488bff347a36f2476cc7b4eaf397c832968548ea70e1de2b2691628399d9f59fdd21a62dd3da50d0255790ec1c15949850a869a37595f8f52cc9d681f2b78748254ba36456f7e65d3c7ed2b64ef502cbd3c2f48d789924a99aedfbd097f4ff5829e787ef29b0b79c817337c08ff68c454a1ddc6359d09c0d48a9298a96691c3558812ca13239d9324f146a6b3bfb7bd3f2b1877929ceb74fa1ed590351801935d1e61c875c7772e74d037b26f972f2dfa0569ae9bf8cc32dee87e980497cd79492bf91edeafacfbd6ad32c642a6564ffc9a5d921d0cc35740314c88986547d8f94e60f5d3a2e0a0b1723d20546beaf064adfd78e5f63b600a6ee5b0bacf6f30bf456afadef451a1c503e428fcd295b5d20ad9e065e1684dced5487fd33270bb68b783a6963eab250";
        bytes
            memory tenSignatures = hex"1d40e9c75a57997aa60105f21d0c68c3be0435f1f68f755c33015110e38ef97b4b5e2008096e75b906ae4d1f5aec6ad505920c58758631a06ac8c7666b582c9b3fa70a67e39a5aec2a6a11756eb2c0dd74c33beafce3ce8396e86671e00528c0f4c6e9ccef87d852ac23e38f3a1585b710e4eeaa919b7040e49a55583b250801f4f54a7fc1d514ee4a89f2a0a31b500065ea383c4ff0d2981da1fc7e047239d1743c2ce0412a424fe7d32628d656c57d56a6f322d696b6099f44f5257e051cbfed1497e89d637a05b2063a30f232ceba1677e571b08c3c8bb84979d5fcab1652ae40c0840e29a32725d9b45fea996edce566ffff5be6d38d056c6a1827fb7b0ba69f1923a0384e8da72dced43b0e83714d2eda54916252859962b659e0a081fcb4ea39240afef5b8ae854eb4a159d1bdd9eed58aa368c690fe816052fd3f270215dd0ec0cc55e386ea43cb52849d00cc6a2efbec1d693619f9dcf64bfbc9c1982d1acc877b898f48d8337b372a338907dc7af4d8d58e08e1302313721fef9d9c1697256b3dc113bfc7860bccf01dc4d28d3ef09e43db4ecdd78c41bdc89ed50130b1b87ba137c33928f9aff8481e204d8ccd86938da666357cbf4d7253ce56eed980dc7ec2d4a610f541d8f7c830592bb39b8048848203ce74db2f585a7b8cd1ae6b47192b1983efddfb42c1ad65a0c9ceae3548565829c1bcd1a06da7ed4e10698fd2e5b2715a3cbae861909d8364f622882e080f0a07e153fb29c7c3abcc27f2011e76d09d013a5b511b0de51cbefc206c58cb9c09e405b5db80f1c98ea414ae2705de213715e01b81cda31c4ec814e50b341723dc4be0a81268cd04be2d306347540be98c2a3192a968dbad68ba2b5c066c684d18bdcb7345f1d2b643f2ff7bb8494c093eaaf31ee192c9a1486b387701c3bda0ed55af872665fcb0267e3e0b9e7d55e13555ec0f8742229898693ca26ddbb8cae390e9ec35fc3e07c21236fa8264974f9d3aea67a059d6e88111f48341ffdfa911ad89a2a2fbb2a790d69f3fc7646c0071b0c1ca25567f8e2b09d3177abb3e0ec38e4ebe0da06dd6cd03551682fd7ab3a772f5fbc5cba2afbd17d1ed064cae8db36b6bc6ab33b803a40fc7bc9fc7eb0327ee6486803672f653659cea6cc55212db194b9f7ecf1e0996117a489c5caf861425743681184ed3dbe5f8de71b5e7479ce13b6e1b5f6368b187185e9e14967ec04bb67d3797e4b0b2f00ee0cc61a7e2b2feff0a5ed98d503de0e8e3f445e328e8e8d45dc4453e10f49a6d642cbd90c06d7e81e64cf8d8562f6ef708a5761f1503e221ffa15a5318a880e25f8e3a7e79ce4bd263fdc6f683fb2cd1";

        vm.expectEmit(true, true, true, true);
        emit AddedValidatorKeys(index, 10);
        operatorsManager.addValidators(index, 10, tenPublicKeys, tenSignatures);

        Operators.Operator memory operator = operatorsManager.getOperator(index);
        assert(operator.keys == 10);
    }

    function testAddValidatorsAsAdminUnknownOperator(uint256 _index) public {
        vm.startPrank(admin);

        bytes
            memory tenPublicKeys = hex"e18e2e0fff999e38c547fb921bd915a1fef6a46e07db2705a57d17542f0acc6be99fee18fb2c17a7f247fc05edd722b9e95f700adf12dd6f20d65c2e411a6a447cb6f4f7c84b8b6673099385d5dcf964e479a9167c802d977ba0a0a22df2336f83182e83bc198c34c301482f189475209fb93d362704e317709fec266f14b3383e7bac3e0e306b1ac8228482c31d7ffbc7e0f865bd4648c7c45c1361f9cd0f4ccab693068a55e6823a4edd8ef4ced9faa64343866ad7357d488bff347a36f2476cc7b4eaf397c832968548ea70e1de2b2691628399d9f59fdd21a62dd3da50d0255790ec1c15949850a869a37595f8f52cc9d681f2b78748254ba36456f7e65d3c7ed2b64ef502cbd3c2f48d789924a99aedfbd097f4ff5829e787ef29b0b79c817337c08ff68c454a1ddc6359d09c0d48a9298a96691c3558812ca13239d9324f146a6b3bfb7bd3f2b1877929ceb74fa1ed590351801935d1e61c875c7772e74d037b26f972f2dfa0569ae9bf8cc32dee87e980497cd79492bf91edeafacfbd6ad32c642a6564ffc9a5d921d0cc35740314c88986547d8f94e60f5d3a2e0a0b1723d20546beaf064adfd78e5f63b600a6ee5b0bacf6f30bf456afadef451a1c503e428fcd295b5d20ad9e065e1684dced5487fd33270bb68b783a6963eab250";
        bytes
            memory tenSignatures = hex"1d40e9c75a57997aa60105f21d0c68c3be0435f1f68f755c33015110e38ef97b4b5e2008096e75b906ae4d1f5aec6ad505920c58758631a06ac8c7666b582c9b3fa70a67e39a5aec2a6a11756eb2c0dd74c33beafce3ce8396e86671e00528c0f4c6e9ccef87d852ac23e38f3a1585b710e4eeaa919b7040e49a55583b250801f4f54a7fc1d514ee4a89f2a0a31b500065ea383c4ff0d2981da1fc7e047239d1743c2ce0412a424fe7d32628d656c57d56a6f322d696b6099f44f5257e051cbfed1497e89d637a05b2063a30f232ceba1677e571b08c3c8bb84979d5fcab1652ae40c0840e29a32725d9b45fea996edce566ffff5be6d38d056c6a1827fb7b0ba69f1923a0384e8da72dced43b0e83714d2eda54916252859962b659e0a081fcb4ea39240afef5b8ae854eb4a159d1bdd9eed58aa368c690fe816052fd3f270215dd0ec0cc55e386ea43cb52849d00cc6a2efbec1d693619f9dcf64bfbc9c1982d1acc877b898f48d8337b372a338907dc7af4d8d58e08e1302313721fef9d9c1697256b3dc113bfc7860bccf01dc4d28d3ef09e43db4ecdd78c41bdc89ed50130b1b87ba137c33928f9aff8481e204d8ccd86938da666357cbf4d7253ce56eed980dc7ec2d4a610f541d8f7c830592bb39b8048848203ce74db2f585a7b8cd1ae6b47192b1983efddfb42c1ad65a0c9ceae3548565829c1bcd1a06da7ed4e10698fd2e5b2715a3cbae861909d8364f622882e080f0a07e153fb29c7c3abcc27f2011e76d09d013a5b511b0de51cbefc206c58cb9c09e405b5db80f1c98ea414ae2705de213715e01b81cda31c4ec814e50b341723dc4be0a81268cd04be2d306347540be98c2a3192a968dbad68ba2b5c066c684d18bdcb7345f1d2b643f2ff7bb8494c093eaaf31ee192c9a1486b387701c3bda0ed55af872665fcb0267e3e0b9e7d55e13555ec0f8742229898693ca26ddbb8cae390e9ec35fc3e07c21236fa8264974f9d3aea67a059d6e88111f48341ffdfa911ad89a2a2fbb2a790d69f3fc7646c0071b0c1ca25567f8e2b09d3177abb3e0ec38e4ebe0da06dd6cd03551682fd7ab3a772f5fbc5cba2afbd17d1ed064cae8db36b6bc6ab33b803a40fc7bc9fc7eb0327ee6486803672f653659cea6cc55212db194b9f7ecf1e0996117a489c5caf861425743681184ed3dbe5f8de71b5e7479ce13b6e1b5f6368b187185e9e14967ec04bb67d3797e4b0b2f00ee0cc61a7e2b2feff0a5ed98d503de0e8e3f445e328e8e8d45dc4453e10f49a6d642cbd90c06d7e81e64cf8d8562f6ef708a5761f1503e221ffa15a5318a880e25f8e3a7e79ce4bd263fdc6f683fb2cd1";

        vm.expectRevert(abi.encodeWithSignature("OperatorNotFoundAtIndex(uint256)", _index));
        operatorsManager.addValidators(_index, 10, tenPublicKeys, tenSignatures);
    }

    function testAddValidatorsAsUnauthorized(bytes32 _name, uint256 _firstAddressSalt) public {
        address _firstAddress = uf._new(_firstAddressSalt);
        vm.startPrank(admin);
        operatorsManager.addOperator(string(abi.encodePacked(_name)), _firstAddress);
        (int256 _index, ) = operatorsManager.getOperatorDetails(string(abi.encodePacked(_name)));
        assert(_index >= 0);
        uint256 index = uint256(_index);

        bytes
            memory tenPublicKeys = hex"e18e2e0fff999e38c547fb921bd915a1fef6a46e07db2705a57d17542f0acc6be99fee18fb2c17a7f247fc05edd722b9e95f700adf12dd6f20d65c2e411a6a447cb6f4f7c84b8b6673099385d5dcf964e479a9167c802d977ba0a0a22df2336f83182e83bc198c34c301482f189475209fb93d362704e317709fec266f14b3383e7bac3e0e306b1ac8228482c31d7ffbc7e0f865bd4648c7c45c1361f9cd0f4ccab693068a55e6823a4edd8ef4ced9faa64343866ad7357d488bff347a36f2476cc7b4eaf397c832968548ea70e1de2b2691628399d9f59fdd21a62dd3da50d0255790ec1c15949850a869a37595f8f52cc9d681f2b78748254ba36456f7e65d3c7ed2b64ef502cbd3c2f48d789924a99aedfbd097f4ff5829e787ef29b0b79c817337c08ff68c454a1ddc6359d09c0d48a9298a96691c3558812ca13239d9324f146a6b3bfb7bd3f2b1877929ceb74fa1ed590351801935d1e61c875c7772e74d037b26f972f2dfa0569ae9bf8cc32dee87e980497cd79492bf91edeafacfbd6ad32c642a6564ffc9a5d921d0cc35740314c88986547d8f94e60f5d3a2e0a0b1723d20546beaf064adfd78e5f63b600a6ee5b0bacf6f30bf456afadef451a1c503e428fcd295b5d20ad9e065e1684dced5487fd33270bb68b783a6963eab250";
        bytes
            memory tenSignatures = hex"1d40e9c75a57997aa60105f21d0c68c3be0435f1f68f755c33015110e38ef97b4b5e2008096e75b906ae4d1f5aec6ad505920c58758631a06ac8c7666b582c9b3fa70a67e39a5aec2a6a11756eb2c0dd74c33beafce3ce8396e86671e00528c0f4c6e9ccef87d852ac23e38f3a1585b710e4eeaa919b7040e49a55583b250801f4f54a7fc1d514ee4a89f2a0a31b500065ea383c4ff0d2981da1fc7e047239d1743c2ce0412a424fe7d32628d656c57d56a6f322d696b6099f44f5257e051cbfed1497e89d637a05b2063a30f232ceba1677e571b08c3c8bb84979d5fcab1652ae40c0840e29a32725d9b45fea996edce566ffff5be6d38d056c6a1827fb7b0ba69f1923a0384e8da72dced43b0e83714d2eda54916252859962b659e0a081fcb4ea39240afef5b8ae854eb4a159d1bdd9eed58aa368c690fe816052fd3f270215dd0ec0cc55e386ea43cb52849d00cc6a2efbec1d693619f9dcf64bfbc9c1982d1acc877b898f48d8337b372a338907dc7af4d8d58e08e1302313721fef9d9c1697256b3dc113bfc7860bccf01dc4d28d3ef09e43db4ecdd78c41bdc89ed50130b1b87ba137c33928f9aff8481e204d8ccd86938da666357cbf4d7253ce56eed980dc7ec2d4a610f541d8f7c830592bb39b8048848203ce74db2f585a7b8cd1ae6b47192b1983efddfb42c1ad65a0c9ceae3548565829c1bcd1a06da7ed4e10698fd2e5b2715a3cbae861909d8364f622882e080f0a07e153fb29c7c3abcc27f2011e76d09d013a5b511b0de51cbefc206c58cb9c09e405b5db80f1c98ea414ae2705de213715e01b81cda31c4ec814e50b341723dc4be0a81268cd04be2d306347540be98c2a3192a968dbad68ba2b5c066c684d18bdcb7345f1d2b643f2ff7bb8494c093eaaf31ee192c9a1486b387701c3bda0ed55af872665fcb0267e3e0b9e7d55e13555ec0f8742229898693ca26ddbb8cae390e9ec35fc3e07c21236fa8264974f9d3aea67a059d6e88111f48341ffdfa911ad89a2a2fbb2a790d69f3fc7646c0071b0c1ca25567f8e2b09d3177abb3e0ec38e4ebe0da06dd6cd03551682fd7ab3a772f5fbc5cba2afbd17d1ed064cae8db36b6bc6ab33b803a40fc7bc9fc7eb0327ee6486803672f653659cea6cc55212db194b9f7ecf1e0996117a489c5caf861425743681184ed3dbe5f8de71b5e7479ce13b6e1b5f6368b187185e9e14967ec04bb67d3797e4b0b2f00ee0cc61a7e2b2feff0a5ed98d503de0e8e3f445e328e8e8d45dc4453e10f49a6d642cbd90c06d7e81e64cf8d8562f6ef708a5761f1503e221ffa15a5318a880e25f8e3a7e79ce4bd263fdc6f683fb2cd1";

        vm.stopPrank();
        vm.startPrank(address(this));
        vm.expectRevert(abi.encodeWithSignature("Unauthorized(address)", address(this)));
        operatorsManager.addValidators(index, 10, tenPublicKeys, tenSignatures);
    }

    function testAddValidatorsInvalidPublicKeysSize(bytes32 _name, uint256 _firstAddressSalt) public {
        address _firstAddress = uf._new(_firstAddressSalt);
        vm.startPrank(admin);
        operatorsManager.addOperator(string(abi.encodePacked(_name)), _firstAddress);
        (int256 _index, ) = operatorsManager.getOperatorDetails(string(abi.encodePacked(_name)));
        assert(_index >= 0);
        uint256 index = uint256(_index);

        bytes
            memory tenPublicKeys = hex"e18e2e0fff999e38c547fb921bd915a1fef6a46e07db2705a57d17542f0acc6be99fee18fb2c17a7f247fc05edd722b9e95f700adf12dd6f20d65c2e411a6a447cb6f4f7c84b8b6673099385d5dcf964e479a9167c802d977ba0a0a22df2336f83182e83bc198c34c301482f189475209fb93d362704e317709fec266f14b3383e7bac3e0e306b1ac8228482c31d7ffbc7e0f865bd4648c7c45c1361f9cd0f4ccab693068a55e6823a4edd8ef4ced9faa64343866ad7357d488bff347a36f2476cc7b4eaf397c832968548ea70e1de2b2691628399d9f59fdd21a62dd3da50d0255790ec1c15949850a869a37595f8f52cc9d681f2b78748254ba36456f7e65d3c7ed2b64ef502cbd3c2f48d789924a99aedfbd097f4ff5829e787ef29b0b79c817337c08ff68c454a1ddc6359d09c0d48a9298a96691c3558812ca13239d9324f146a6b3bfb7bd3f2b1877929ceb74fa1ed590351801935d1e61c875c7772e74d037b26f972f2dfa0569ae9bf8cc32dee87e980497cd79492bf91edeafacfbd6ad32c642a6564ffc9a5d921d0cc35740314c88986547d8f94e60f5d3a2e0a0b1723d20546beaf064adfd78e5f63b600a6ee5b0bacf6f30bf456afadef451a1c503e428fcd295b5d20ad9e065e1684dced5487fd33270bb68b783a6963eab2";
        bytes
            memory tenSignatures = hex"1d40e9c75a57997aa60105f21d0c68c3be0435f1f68f755c33015110e38ef97b4b5e2008096e75b906ae4d1f5aec6ad505920c58758631a06ac8c7666b582c9b3fa70a67e39a5aec2a6a11756eb2c0dd74c33beafce3ce8396e86671e00528c0f4c6e9ccef87d852ac23e38f3a1585b710e4eeaa919b7040e49a55583b250801f4f54a7fc1d514ee4a89f2a0a31b500065ea383c4ff0d2981da1fc7e047239d1743c2ce0412a424fe7d32628d656c57d56a6f322d696b6099f44f5257e051cbfed1497e89d637a05b2063a30f232ceba1677e571b08c3c8bb84979d5fcab1652ae40c0840e29a32725d9b45fea996edce566ffff5be6d38d056c6a1827fb7b0ba69f1923a0384e8da72dced43b0e83714d2eda54916252859962b659e0a081fcb4ea39240afef5b8ae854eb4a159d1bdd9eed58aa368c690fe816052fd3f270215dd0ec0cc55e386ea43cb52849d00cc6a2efbec1d693619f9dcf64bfbc9c1982d1acc877b898f48d8337b372a338907dc7af4d8d58e08e1302313721fef9d9c1697256b3dc113bfc7860bccf01dc4d28d3ef09e43db4ecdd78c41bdc89ed50130b1b87ba137c33928f9aff8481e204d8ccd86938da666357cbf4d7253ce56eed980dc7ec2d4a610f541d8f7c830592bb39b8048848203ce74db2f585a7b8cd1ae6b47192b1983efddfb42c1ad65a0c9ceae3548565829c1bcd1a06da7ed4e10698fd2e5b2715a3cbae861909d8364f622882e080f0a07e153fb29c7c3abcc27f2011e76d09d013a5b511b0de51cbefc206c58cb9c09e405b5db80f1c98ea414ae2705de213715e01b81cda31c4ec814e50b341723dc4be0a81268cd04be2d306347540be98c2a3192a968dbad68ba2b5c066c684d18bdcb7345f1d2b643f2ff7bb8494c093eaaf31ee192c9a1486b387701c3bda0ed55af872665fcb0267e3e0b9e7d55e13555ec0f8742229898693ca26ddbb8cae390e9ec35fc3e07c21236fa8264974f9d3aea67a059d6e88111f48341ffdfa911ad89a2a2fbb2a790d69f3fc7646c0071b0c1ca25567f8e2b09d3177abb3e0ec38e4ebe0da06dd6cd03551682fd7ab3a772f5fbc5cba2afbd17d1ed064cae8db36b6bc6ab33b803a40fc7bc9fc7eb0327ee6486803672f653659cea6cc55212db194b9f7ecf1e0996117a489c5caf861425743681184ed3dbe5f8de71b5e7479ce13b6e1b5f6368b187185e9e14967ec04bb67d3797e4b0b2f00ee0cc61a7e2b2feff0a5ed98d503de0e8e3f445e328e8e8d45dc4453e10f49a6d642cbd90c06d7e81e64cf8d8562f6ef708a5761f1503e221ffa15a5318a880e25f8e3a7e79ce4bd263fdc6f683fb2cd1";

        vm.expectRevert(abi.encodeWithSignature("InvalidPublicKeysLength()"));
        operatorsManager.addValidators(index, 10, tenPublicKeys, tenSignatures);
    }

    function testAddValidatorsInvalidSignaturesSize(bytes32 _name, uint256 _firstAddressSalt) public {
        address _firstAddress = uf._new(_firstAddressSalt);
        vm.startPrank(admin);
        operatorsManager.addOperator(string(abi.encodePacked(_name)), _firstAddress);
        (int256 _index, ) = operatorsManager.getOperatorDetails(string(abi.encodePacked(_name)));
        assert(_index >= 0);
        uint256 index = uint256(_index);

        bytes
            memory tenPublicKeys = hex"e18e2e0fff999e38c547fb921bd915a1fef6a46e07db2705a57d17542f0acc6be99fee18fb2c17a7f247fc05edd722b9e95f700adf12dd6f20d65c2e411a6a447cb6f4f7c84b8b6673099385d5dcf964e479a9167c802d977ba0a0a22df2336f83182e83bc198c34c301482f189475209fb93d362704e317709fec266f14b3383e7bac3e0e306b1ac8228482c31d7ffbc7e0f865bd4648c7c45c1361f9cd0f4ccab693068a55e6823a4edd8ef4ced9faa64343866ad7357d488bff347a36f2476cc7b4eaf397c832968548ea70e1de2b2691628399d9f59fdd21a62dd3da50d0255790ec1c15949850a869a37595f8f52cc9d681f2b78748254ba36456f7e65d3c7ed2b64ef502cbd3c2f48d789924a99aedfbd097f4ff5829e787ef29b0b79c817337c08ff68c454a1ddc6359d09c0d48a9298a96691c3558812ca13239d9324f146a6b3bfb7bd3f2b1877929ceb74fa1ed590351801935d1e61c875c7772e74d037b26f972f2dfa0569ae9bf8cc32dee87e980497cd79492bf91edeafacfbd6ad32c642a6564ffc9a5d921d0cc35740314c88986547d8f94e60f5d3a2e0a0b1723d20546beaf064adfd78e5f63b600a6ee5b0bacf6f30bf456afadef451a1c503e428fcd295b5d20ad9e065e1684dced5487fd33270bb68b783a6963eab250";
        bytes
            memory tenSignatures = hex"1d40e9c75a57997aa60105f21d0c68c3be0435f1f68f755c33015110e38ef97b4b5e2008096e75b906ae4d1f5aec6ad505920c58758631a06ac8c7666b582c9b3fa70a67e39a5aec2a6a11756eb2c0dd74c33beafce3ce8396e86671e00528c0f4c6e9ccef87d852ac23e38f3a1585b710e4eeaa919b7040e49a55583b250801f4f54a7fc1d514ee4a89f2a0a31b500065ea383c4ff0d2981da1fc7e047239d1743c2ce0412a424fe7d32628d656c57d56a6f322d696b6099f44f5257e051cbfed1497e89d637a05b2063a30f232ceba1677e571b08c3c8bb84979d5fcab1652ae40c0840e29a32725d9b45fea996edce566ffff5be6d38d056c6a1827fb7b0ba69f1923a0384e8da72dced43b0e83714d2eda54916252859962b659e0a081fcb4ea39240afef5b8ae854eb4a159d1bdd9eed58aa368c690fe816052fd3f270215dd0ec0cc55e386ea43cb52849d00cc6a2efbec1d693619f9dcf64bfbc9c1982d1acc877b898f48d8337b372a338907dc7af4d8d58e08e1302313721fef9d9c1697256b3dc113bfc7860bccf01dc4d28d3ef09e43db4ecdd78c41bdc89ed50130b1b87ba137c33928f9aff8481e204d8ccd86938da666357cbf4d7253ce56eed980dc7ec2d4a610f541d8f7c830592bb39b8048848203ce74db2f585a7b8cd1ae6b47192b1983efddfb42c1ad65a0c9ceae3548565829c1bcd1a06da7ed4e10698fd2e5b2715a3cbae861909d8364f622882e080f0a07e153fb29c7c3abcc27f2011e76d09d013a5b511b0de51cbefc206c58cb9c09e405b5db80f1c98ea414ae2705de213715e01b81cda31c4ec814e50b341723dc4be0a81268cd04be2d306347540be98c2a3192a968dbad68ba2b5c066c684d18bdcb7345f1d2b643f2ff7bb8494c093eaaf31ee192c9a1486b387701c3bda0ed55af872665fcb0267e3e0b9e7d55e13555ec0f8742229898693ca26ddbb8cae390e9ec35fc3e07c21236fa8264974f9d3aea67a059d6e88111f48341ffdfa911ad89a2a2fbb2a790d69f3fc7646c0071b0c1ca25567f8e2b09d3177abb3e0ec38e4ebe0da06dd6cd03551682fd7ab3a772f5fbc5cba2afbd17d1ed064cae8db36b6bc6ab33b803a40fc7bc9fc7eb0327ee6486803672f653659cea6cc55212db194b9f7ecf1e0996117a489c5caf861425743681184ed3dbe5f8de71b5e7479ce13b6e1b5f6368b187185e9e14967ec04bb67d3797e4b0b2f00ee0cc61a7e2b2feff0a5ed98d503de0e8e3f445e328e8e8d45dc4453e10f49a6d642cbd90c06d7e81e64cf8d8562f6ef708a5761f1503e221ffa15a5318a880e25f8e3a7e79ce4bd263fdc6f683fb2c";

        vm.expectRevert(abi.encodeWithSignature("InvalidSignatureLength()"));
        operatorsManager.addValidators(index, 10, tenPublicKeys, tenSignatures);
    }

    function testAddValidatorsInvalidCount(bytes32 _name, uint256 _firstAddressSalt) public {
        address _firstAddress = uf._new(_firstAddressSalt);
        vm.startPrank(admin);
        operatorsManager.addOperator(string(abi.encodePacked(_name)), _firstAddress);
        (int256 _index, ) = operatorsManager.getOperatorDetails(string(abi.encodePacked(_name)));
        assert(_index >= 0);
        uint256 index = uint256(_index);
        vm.expectRevert(abi.encodeWithSignature("InvalidKeyCount()"));
        operatorsManager.addValidators(index, 0, "", "");
    }

    function testRemoveValidatorsAsOperator(bytes32 _name, uint256 _firstAddressSalt) public {
        address _firstAddress = uf._new(_firstAddressSalt);
        vm.startPrank(admin);
        operatorsManager.addOperator(string(abi.encodePacked(_name)), _firstAddress);
        (int256 _index, ) = operatorsManager.getOperatorDetails(string(abi.encodePacked(_name)));
        assert(_index >= 0);
        uint256 index = uint256(_index);

        bytes
            memory tenPublicKeys = hex"e18e2e0fff999e38c547fb921bd915a1fef6a46e07db2705a57d17542f0acc6be99fee18fb2c17a7f247fc05edd722b9e95f700adf12dd6f20d65c2e411a6a447cb6f4f7c84b8b6673099385d5dcf964e479a9167c802d977ba0a0a22df2336f83182e83bc198c34c301482f189475209fb93d362704e317709fec266f14b3383e7bac3e0e306b1ac8228482c31d7ffbc7e0f865bd4648c7c45c1361f9cd0f4ccab693068a55e6823a4edd8ef4ced9faa64343866ad7357d488bff347a36f2476cc7b4eaf397c832968548ea70e1de2b2691628399d9f59fdd21a62dd3da50d0255790ec1c15949850a869a37595f8f52cc9d681f2b78748254ba36456f7e65d3c7ed2b64ef502cbd3c2f48d789924a99aedfbd097f4ff5829e787ef29b0b79c817337c08ff68c454a1ddc6359d09c0d48a9298a96691c3558812ca13239d9324f146a6b3bfb7bd3f2b1877929ceb74fa1ed590351801935d1e61c875c7772e74d037b26f972f2dfa0569ae9bf8cc32dee87e980497cd79492bf91edeafacfbd6ad32c642a6564ffc9a5d921d0cc35740314c88986547d8f94e60f5d3a2e0a0b1723d20546beaf064adfd78e5f63b600a6ee5b0bacf6f30bf456afadef451a1c503e428fcd295b5d20ad9e065e1684dced5487fd33270bb68b783a6963eab250";
        bytes
            memory tenSignatures = hex"1d40e9c75a57997aa60105f21d0c68c3be0435f1f68f755c33015110e38ef97b4b5e2008096e75b906ae4d1f5aec6ad505920c58758631a06ac8c7666b582c9b3fa70a67e39a5aec2a6a11756eb2c0dd74c33beafce3ce8396e86671e00528c0f4c6e9ccef87d852ac23e38f3a1585b710e4eeaa919b7040e49a55583b250801f4f54a7fc1d514ee4a89f2a0a31b500065ea383c4ff0d2981da1fc7e047239d1743c2ce0412a424fe7d32628d656c57d56a6f322d696b6099f44f5257e051cbfed1497e89d637a05b2063a30f232ceba1677e571b08c3c8bb84979d5fcab1652ae40c0840e29a32725d9b45fea996edce566ffff5be6d38d056c6a1827fb7b0ba69f1923a0384e8da72dced43b0e83714d2eda54916252859962b659e0a081fcb4ea39240afef5b8ae854eb4a159d1bdd9eed58aa368c690fe816052fd3f270215dd0ec0cc55e386ea43cb52849d00cc6a2efbec1d693619f9dcf64bfbc9c1982d1acc877b898f48d8337b372a338907dc7af4d8d58e08e1302313721fef9d9c1697256b3dc113bfc7860bccf01dc4d28d3ef09e43db4ecdd78c41bdc89ed50130b1b87ba137c33928f9aff8481e204d8ccd86938da666357cbf4d7253ce56eed980dc7ec2d4a610f541d8f7c830592bb39b8048848203ce74db2f585a7b8cd1ae6b47192b1983efddfb42c1ad65a0c9ceae3548565829c1bcd1a06da7ed4e10698fd2e5b2715a3cbae861909d8364f622882e080f0a07e153fb29c7c3abcc27f2011e76d09d013a5b511b0de51cbefc206c58cb9c09e405b5db80f1c98ea414ae2705de213715e01b81cda31c4ec814e50b341723dc4be0a81268cd04be2d306347540be98c2a3192a968dbad68ba2b5c066c684d18bdcb7345f1d2b643f2ff7bb8494c093eaaf31ee192c9a1486b387701c3bda0ed55af872665fcb0267e3e0b9e7d55e13555ec0f8742229898693ca26ddbb8cae390e9ec35fc3e07c21236fa8264974f9d3aea67a059d6e88111f48341ffdfa911ad89a2a2fbb2a790d69f3fc7646c0071b0c1ca25567f8e2b09d3177abb3e0ec38e4ebe0da06dd6cd03551682fd7ab3a772f5fbc5cba2afbd17d1ed064cae8db36b6bc6ab33b803a40fc7bc9fc7eb0327ee6486803672f653659cea6cc55212db194b9f7ecf1e0996117a489c5caf861425743681184ed3dbe5f8de71b5e7479ce13b6e1b5f6368b187185e9e14967ec04bb67d3797e4b0b2f00ee0cc61a7e2b2feff0a5ed98d503de0e8e3f445e328e8e8d45dc4453e10f49a6d642cbd90c06d7e81e64cf8d8562f6ef708a5761f1503e221ffa15a5318a880e25f8e3a7e79ce4bd263fdc6f683fb2cd1";

        vm.stopPrank();
        vm.startPrank(_firstAddress);
        operatorsManager.addValidators(index, 10, tenPublicKeys, tenSignatures);

        Operators.Operator memory operator = operatorsManager.getOperator(index);
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

        operatorsManager.removeValidators(index, indexes);
        operator = operatorsManager.getOperator(index);
        assert(operator.keys == 0);

        operatorsManager.addValidators(index, 10, tenPublicKeys, tenSignatures);
        operator = operatorsManager.getOperator(index);
        assert(operator.keys == 10);
    }

    function testRemoveValidatorsAsAdmin(bytes32 _name, uint256 _firstAddressSalt) public {
        address _firstAddress = uf._new(_firstAddressSalt);
        vm.startPrank(admin);
        operatorsManager.addOperator(string(abi.encodePacked(_name)), _firstAddress);
        (int256 _index, ) = operatorsManager.getOperatorDetails(string(abi.encodePacked(_name)));
        assert(_index >= 0);
        uint256 index = uint256(_index);

        bytes
            memory tenPublicKeys = hex"e18e2e0fff999e38c547fb921bd915a1fef6a46e07db2705a57d17542f0acc6be99fee18fb2c17a7f247fc05edd722b9e95f700adf12dd6f20d65c2e411a6a447cb6f4f7c84b8b6673099385d5dcf964e479a9167c802d977ba0a0a22df2336f83182e83bc198c34c301482f189475209fb93d362704e317709fec266f14b3383e7bac3e0e306b1ac8228482c31d7ffbc7e0f865bd4648c7c45c1361f9cd0f4ccab693068a55e6823a4edd8ef4ced9faa64343866ad7357d488bff347a36f2476cc7b4eaf397c832968548ea70e1de2b2691628399d9f59fdd21a62dd3da50d0255790ec1c15949850a869a37595f8f52cc9d681f2b78748254ba36456f7e65d3c7ed2b64ef502cbd3c2f48d789924a99aedfbd097f4ff5829e787ef29b0b79c817337c08ff68c454a1ddc6359d09c0d48a9298a96691c3558812ca13239d9324f146a6b3bfb7bd3f2b1877929ceb74fa1ed590351801935d1e61c875c7772e74d037b26f972f2dfa0569ae9bf8cc32dee87e980497cd79492bf91edeafacfbd6ad32c642a6564ffc9a5d921d0cc35740314c88986547d8f94e60f5d3a2e0a0b1723d20546beaf064adfd78e5f63b600a6ee5b0bacf6f30bf456afadef451a1c503e428fcd295b5d20ad9e065e1684dced5487fd33270bb68b783a6963eab250";
        bytes
            memory tenSignatures = hex"1d40e9c75a57997aa60105f21d0c68c3be0435f1f68f755c33015110e38ef97b4b5e2008096e75b906ae4d1f5aec6ad505920c58758631a06ac8c7666b582c9b3fa70a67e39a5aec2a6a11756eb2c0dd74c33beafce3ce8396e86671e00528c0f4c6e9ccef87d852ac23e38f3a1585b710e4eeaa919b7040e49a55583b250801f4f54a7fc1d514ee4a89f2a0a31b500065ea383c4ff0d2981da1fc7e047239d1743c2ce0412a424fe7d32628d656c57d56a6f322d696b6099f44f5257e051cbfed1497e89d637a05b2063a30f232ceba1677e571b08c3c8bb84979d5fcab1652ae40c0840e29a32725d9b45fea996edce566ffff5be6d38d056c6a1827fb7b0ba69f1923a0384e8da72dced43b0e83714d2eda54916252859962b659e0a081fcb4ea39240afef5b8ae854eb4a159d1bdd9eed58aa368c690fe816052fd3f270215dd0ec0cc55e386ea43cb52849d00cc6a2efbec1d693619f9dcf64bfbc9c1982d1acc877b898f48d8337b372a338907dc7af4d8d58e08e1302313721fef9d9c1697256b3dc113bfc7860bccf01dc4d28d3ef09e43db4ecdd78c41bdc89ed50130b1b87ba137c33928f9aff8481e204d8ccd86938da666357cbf4d7253ce56eed980dc7ec2d4a610f541d8f7c830592bb39b8048848203ce74db2f585a7b8cd1ae6b47192b1983efddfb42c1ad65a0c9ceae3548565829c1bcd1a06da7ed4e10698fd2e5b2715a3cbae861909d8364f622882e080f0a07e153fb29c7c3abcc27f2011e76d09d013a5b511b0de51cbefc206c58cb9c09e405b5db80f1c98ea414ae2705de213715e01b81cda31c4ec814e50b341723dc4be0a81268cd04be2d306347540be98c2a3192a968dbad68ba2b5c066c684d18bdcb7345f1d2b643f2ff7bb8494c093eaaf31ee192c9a1486b387701c3bda0ed55af872665fcb0267e3e0b9e7d55e13555ec0f8742229898693ca26ddbb8cae390e9ec35fc3e07c21236fa8264974f9d3aea67a059d6e88111f48341ffdfa911ad89a2a2fbb2a790d69f3fc7646c0071b0c1ca25567f8e2b09d3177abb3e0ec38e4ebe0da06dd6cd03551682fd7ab3a772f5fbc5cba2afbd17d1ed064cae8db36b6bc6ab33b803a40fc7bc9fc7eb0327ee6486803672f653659cea6cc55212db194b9f7ecf1e0996117a489c5caf861425743681184ed3dbe5f8de71b5e7479ce13b6e1b5f6368b187185e9e14967ec04bb67d3797e4b0b2f00ee0cc61a7e2b2feff0a5ed98d503de0e8e3f445e328e8e8d45dc4453e10f49a6d642cbd90c06d7e81e64cf8d8562f6ef708a5761f1503e221ffa15a5318a880e25f8e3a7e79ce4bd263fdc6f683fb2cd1";

        operatorsManager.addValidators(index, 10, tenPublicKeys, tenSignatures);

        Operators.Operator memory operator = operatorsManager.getOperator(index);
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

        operatorsManager.removeValidators(index, indexes);
        operator = operatorsManager.getOperator(index);
        assert(operator.keys == 0);

        operatorsManager.addValidators(index, 10, tenPublicKeys, tenSignatures);
        operator = operatorsManager.getOperator(index);
        assert(operator.keys == 10);
    }

    function testRemoveValidatorsUnauthorized(bytes32 _name, uint256 _firstAddressSalt) public {
        address _firstAddress = uf._new(_firstAddressSalt);
        vm.startPrank(admin);
        operatorsManager.addOperator(string(abi.encodePacked(_name)), _firstAddress);
        (int256 _index, ) = operatorsManager.getOperatorDetails(string(abi.encodePacked(_name)));
        assert(_index >= 0);
        uint256 index = uint256(_index);

        bytes
            memory tenPublicKeys = hex"e18e2e0fff999e38c547fb921bd915a1fef6a46e07db2705a57d17542f0acc6be99fee18fb2c17a7f247fc05edd722b9e95f700adf12dd6f20d65c2e411a6a447cb6f4f7c84b8b6673099385d5dcf964e479a9167c802d977ba0a0a22df2336f83182e83bc198c34c301482f189475209fb93d362704e317709fec266f14b3383e7bac3e0e306b1ac8228482c31d7ffbc7e0f865bd4648c7c45c1361f9cd0f4ccab693068a55e6823a4edd8ef4ced9faa64343866ad7357d488bff347a36f2476cc7b4eaf397c832968548ea70e1de2b2691628399d9f59fdd21a62dd3da50d0255790ec1c15949850a869a37595f8f52cc9d681f2b78748254ba36456f7e65d3c7ed2b64ef502cbd3c2f48d789924a99aedfbd097f4ff5829e787ef29b0b79c817337c08ff68c454a1ddc6359d09c0d48a9298a96691c3558812ca13239d9324f146a6b3bfb7bd3f2b1877929ceb74fa1ed590351801935d1e61c875c7772e74d037b26f972f2dfa0569ae9bf8cc32dee87e980497cd79492bf91edeafacfbd6ad32c642a6564ffc9a5d921d0cc35740314c88986547d8f94e60f5d3a2e0a0b1723d20546beaf064adfd78e5f63b600a6ee5b0bacf6f30bf456afadef451a1c503e428fcd295b5d20ad9e065e1684dced5487fd33270bb68b783a6963eab250";
        bytes
            memory tenSignatures = hex"1d40e9c75a57997aa60105f21d0c68c3be0435f1f68f755c33015110e38ef97b4b5e2008096e75b906ae4d1f5aec6ad505920c58758631a06ac8c7666b582c9b3fa70a67e39a5aec2a6a11756eb2c0dd74c33beafce3ce8396e86671e00528c0f4c6e9ccef87d852ac23e38f3a1585b710e4eeaa919b7040e49a55583b250801f4f54a7fc1d514ee4a89f2a0a31b500065ea383c4ff0d2981da1fc7e047239d1743c2ce0412a424fe7d32628d656c57d56a6f322d696b6099f44f5257e051cbfed1497e89d637a05b2063a30f232ceba1677e571b08c3c8bb84979d5fcab1652ae40c0840e29a32725d9b45fea996edce566ffff5be6d38d056c6a1827fb7b0ba69f1923a0384e8da72dced43b0e83714d2eda54916252859962b659e0a081fcb4ea39240afef5b8ae854eb4a159d1bdd9eed58aa368c690fe816052fd3f270215dd0ec0cc55e386ea43cb52849d00cc6a2efbec1d693619f9dcf64bfbc9c1982d1acc877b898f48d8337b372a338907dc7af4d8d58e08e1302313721fef9d9c1697256b3dc113bfc7860bccf01dc4d28d3ef09e43db4ecdd78c41bdc89ed50130b1b87ba137c33928f9aff8481e204d8ccd86938da666357cbf4d7253ce56eed980dc7ec2d4a610f541d8f7c830592bb39b8048848203ce74db2f585a7b8cd1ae6b47192b1983efddfb42c1ad65a0c9ceae3548565829c1bcd1a06da7ed4e10698fd2e5b2715a3cbae861909d8364f622882e080f0a07e153fb29c7c3abcc27f2011e76d09d013a5b511b0de51cbefc206c58cb9c09e405b5db80f1c98ea414ae2705de213715e01b81cda31c4ec814e50b341723dc4be0a81268cd04be2d306347540be98c2a3192a968dbad68ba2b5c066c684d18bdcb7345f1d2b643f2ff7bb8494c093eaaf31ee192c9a1486b387701c3bda0ed55af872665fcb0267e3e0b9e7d55e13555ec0f8742229898693ca26ddbb8cae390e9ec35fc3e07c21236fa8264974f9d3aea67a059d6e88111f48341ffdfa911ad89a2a2fbb2a790d69f3fc7646c0071b0c1ca25567f8e2b09d3177abb3e0ec38e4ebe0da06dd6cd03551682fd7ab3a772f5fbc5cba2afbd17d1ed064cae8db36b6bc6ab33b803a40fc7bc9fc7eb0327ee6486803672f653659cea6cc55212db194b9f7ecf1e0996117a489c5caf861425743681184ed3dbe5f8de71b5e7479ce13b6e1b5f6368b187185e9e14967ec04bb67d3797e4b0b2f00ee0cc61a7e2b2feff0a5ed98d503de0e8e3f445e328e8e8d45dc4453e10f49a6d642cbd90c06d7e81e64cf8d8562f6ef708a5761f1503e221ffa15a5318a880e25f8e3a7e79ce4bd263fdc6f683fb2cd1";

        operatorsManager.addValidators(index, 10, tenPublicKeys, tenSignatures);

        Operators.Operator memory operator = operatorsManager.getOperator(index);
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
        operatorsManager.removeValidators(index, indexes);
    }

    function testRemoveValidatorsAndRetrieveAsAdmin(bytes32 _name, uint256 _firstAddressSalt) public {
        address _firstAddress = uf._new(_firstAddressSalt);
        vm.startPrank(admin);
        operatorsManager.addOperator(string(abi.encodePacked(_name)), _firstAddress);
        (int256 _index, ) = operatorsManager.getOperatorDetails(string(abi.encodePacked(_name)));
        assert(_index >= 0);
        uint256 index = uint256(_index);

        bytes
            memory tenPublicKeys = hex"e18e2e0fff999e38c547fb921bd915a1fef6a46e07db2705a57d17542f0acc6be99fee18fb2c17a7f247fc05edd722b9e95f700adf12dd6f20d65c2e411a6a447cb6f4f7c84b8b6673099385d5dcf964e479a9167c802d977ba0a0a22df2336f83182e83bc198c34c301482f189475209fb93d362704e317709fec266f14b3383e7bac3e0e306b1ac8228482c31d7ffbc7e0f865bd4648c7c45c1361f9cd0f4ccab693068a55e6823a4edd8ef4ced9faa64343866ad7357d488bff347a36f2476cc7b4eaf397c832968548ea70e1de2b2691628399d9f59fdd21a62dd3da50d0255790ec1c15949850a869a37595f8f52cc9d681f2b78748254ba36456f7e65d3c7ed2b64ef502cbd3c2f48d789924a99aedfbd097f4ff5829e787ef29b0b79c817337c08ff68c454a1ddc6359d09c0d48a9298a96691c3558812ca13239d9324f146a6b3bfb7bd3f2b1877929ceb74fa1ed590351801935d1e61c875c7772e74d037b26f972f2dfa0569ae9bf8cc32dee87e980497cd79492bf91edeafacfbd6ad32c642a6564ffc9a5d921d0cc35740314c88986547d8f94e60f5d3a2e0a0b1723d20546beaf064adfd78e5f63b600a6ee5b0bacf6f30bf456afadef451a1c503e428fcd295b5d20ad9e065e1684dced5487fd33270bb68b783a6963eab250";
        bytes
            memory tenSignatures = hex"1d40e9c75a57997aa60105f21d0c68c3be0435f1f68f755c33015110e38ef97b4b5e2008096e75b906ae4d1f5aec6ad505920c58758631a06ac8c7666b582c9b3fa70a67e39a5aec2a6a11756eb2c0dd74c33beafce3ce8396e86671e00528c0f4c6e9ccef87d852ac23e38f3a1585b710e4eeaa919b7040e49a55583b250801f4f54a7fc1d514ee4a89f2a0a31b500065ea383c4ff0d2981da1fc7e047239d1743c2ce0412a424fe7d32628d656c57d56a6f322d696b6099f44f5257e051cbfed1497e89d637a05b2063a30f232ceba1677e571b08c3c8bb84979d5fcab1652ae40c0840e29a32725d9b45fea996edce566ffff5be6d38d056c6a1827fb7b0ba69f1923a0384e8da72dced43b0e83714d2eda54916252859962b659e0a081fcb4ea39240afef5b8ae854eb4a159d1bdd9eed58aa368c690fe816052fd3f270215dd0ec0cc55e386ea43cb52849d00cc6a2efbec1d693619f9dcf64bfbc9c1982d1acc877b898f48d8337b372a338907dc7af4d8d58e08e1302313721fef9d9c1697256b3dc113bfc7860bccf01dc4d28d3ef09e43db4ecdd78c41bdc89ed50130b1b87ba137c33928f9aff8481e204d8ccd86938da666357cbf4d7253ce56eed980dc7ec2d4a610f541d8f7c830592bb39b8048848203ce74db2f585a7b8cd1ae6b47192b1983efddfb42c1ad65a0c9ceae3548565829c1bcd1a06da7ed4e10698fd2e5b2715a3cbae861909d8364f622882e080f0a07e153fb29c7c3abcc27f2011e76d09d013a5b511b0de51cbefc206c58cb9c09e405b5db80f1c98ea414ae2705de213715e01b81cda31c4ec814e50b341723dc4be0a81268cd04be2d306347540be98c2a3192a968dbad68ba2b5c066c684d18bdcb7345f1d2b643f2ff7bb8494c093eaaf31ee192c9a1486b387701c3bda0ed55af872665fcb0267e3e0b9e7d55e13555ec0f8742229898693ca26ddbb8cae390e9ec35fc3e07c21236fa8264974f9d3aea67a059d6e88111f48341ffdfa911ad89a2a2fbb2a790d69f3fc7646c0071b0c1ca25567f8e2b09d3177abb3e0ec38e4ebe0da06dd6cd03551682fd7ab3a772f5fbc5cba2afbd17d1ed064cae8db36b6bc6ab33b803a40fc7bc9fc7eb0327ee6486803672f653659cea6cc55212db194b9f7ecf1e0996117a489c5caf861425743681184ed3dbe5f8de71b5e7479ce13b6e1b5f6368b187185e9e14967ec04bb67d3797e4b0b2f00ee0cc61a7e2b2feff0a5ed98d503de0e8e3f445e328e8e8d45dc4453e10f49a6d642cbd90c06d7e81e64cf8d8562f6ef708a5761f1503e221ffa15a5318a880e25f8e3a7e79ce4bd263fdc6f683fb2cd1";

        operatorsManager.addValidators(index, 10, tenPublicKeys, tenSignatures);

        Operators.Operator memory operator = operatorsManager.getOperator(index);
        assert(operator.keys == 10);

        uint256[] memory indexes = new uint256[](1);

        indexes[0] = 0;

        (bytes memory pk, bytes memory s, ) = operatorsManager.getValidator(index, 9);

        operatorsManager.removeValidators(index, indexes);
        operator = operatorsManager.getOperator(index);
        assert(operator.keys == 9);
        (bytes memory pkAfter, bytes memory sAfter, ) = operatorsManager.getValidator(index, 0);

        assert(keccak256(pkAfter) == keccak256(pk));
        assert(keccak256(sAfter) == keccak256(s));
    }

    function testRemoveValidatorsFundedKeyRemovalAttempt(bytes32 _name, uint256 _firstAddressSalt) public {
        address _firstAddress = uf._new(_firstAddressSalt);
        vm.startPrank(admin);
        operatorsManager.addOperator(string(abi.encodePacked(_name)), _firstAddress);
        (int256 _index, ) = operatorsManager.getOperatorDetails(string(abi.encodePacked(_name)));
        assert(_index >= 0);
        uint256 index = uint256(_index);

        bytes
            memory tenPublicKeys = hex"e18e2e0fff999e38c547fb921bd915a1fef6a46e07db2705a57d17542f0acc6be99fee18fb2c17a7f247fc05edd722b9e95f700adf12dd6f20d65c2e411a6a447cb6f4f7c84b8b6673099385d5dcf964e479a9167c802d977ba0a0a22df2336f83182e83bc198c34c301482f189475209fb93d362704e317709fec266f14b3383e7bac3e0e306b1ac8228482c31d7ffbc7e0f865bd4648c7c45c1361f9cd0f4ccab693068a55e6823a4edd8ef4ced9faa64343866ad7357d488bff347a36f2476cc7b4eaf397c832968548ea70e1de2b2691628399d9f59fdd21a62dd3da50d0255790ec1c15949850a869a37595f8f52cc9d681f2b78748254ba36456f7e65d3c7ed2b64ef502cbd3c2f48d789924a99aedfbd097f4ff5829e787ef29b0b79c817337c08ff68c454a1ddc6359d09c0d48a9298a96691c3558812ca13239d9324f146a6b3bfb7bd3f2b1877929ceb74fa1ed590351801935d1e61c875c7772e74d037b26f972f2dfa0569ae9bf8cc32dee87e980497cd79492bf91edeafacfbd6ad32c642a6564ffc9a5d921d0cc35740314c88986547d8f94e60f5d3a2e0a0b1723d20546beaf064adfd78e5f63b600a6ee5b0bacf6f30bf456afadef451a1c503e428fcd295b5d20ad9e065e1684dced5487fd33270bb68b783a6963eab250";
        bytes
            memory tenSignatures = hex"1d40e9c75a57997aa60105f21d0c68c3be0435f1f68f755c33015110e38ef97b4b5e2008096e75b906ae4d1f5aec6ad505920c58758631a06ac8c7666b582c9b3fa70a67e39a5aec2a6a11756eb2c0dd74c33beafce3ce8396e86671e00528c0f4c6e9ccef87d852ac23e38f3a1585b710e4eeaa919b7040e49a55583b250801f4f54a7fc1d514ee4a89f2a0a31b500065ea383c4ff0d2981da1fc7e047239d1743c2ce0412a424fe7d32628d656c57d56a6f322d696b6099f44f5257e051cbfed1497e89d637a05b2063a30f232ceba1677e571b08c3c8bb84979d5fcab1652ae40c0840e29a32725d9b45fea996edce566ffff5be6d38d056c6a1827fb7b0ba69f1923a0384e8da72dced43b0e83714d2eda54916252859962b659e0a081fcb4ea39240afef5b8ae854eb4a159d1bdd9eed58aa368c690fe816052fd3f270215dd0ec0cc55e386ea43cb52849d00cc6a2efbec1d693619f9dcf64bfbc9c1982d1acc877b898f48d8337b372a338907dc7af4d8d58e08e1302313721fef9d9c1697256b3dc113bfc7860bccf01dc4d28d3ef09e43db4ecdd78c41bdc89ed50130b1b87ba137c33928f9aff8481e204d8ccd86938da666357cbf4d7253ce56eed980dc7ec2d4a610f541d8f7c830592bb39b8048848203ce74db2f585a7b8cd1ae6b47192b1983efddfb42c1ad65a0c9ceae3548565829c1bcd1a06da7ed4e10698fd2e5b2715a3cbae861909d8364f622882e080f0a07e153fb29c7c3abcc27f2011e76d09d013a5b511b0de51cbefc206c58cb9c09e405b5db80f1c98ea414ae2705de213715e01b81cda31c4ec814e50b341723dc4be0a81268cd04be2d306347540be98c2a3192a968dbad68ba2b5c066c684d18bdcb7345f1d2b643f2ff7bb8494c093eaaf31ee192c9a1486b387701c3bda0ed55af872665fcb0267e3e0b9e7d55e13555ec0f8742229898693ca26ddbb8cae390e9ec35fc3e07c21236fa8264974f9d3aea67a059d6e88111f48341ffdfa911ad89a2a2fbb2a790d69f3fc7646c0071b0c1ca25567f8e2b09d3177abb3e0ec38e4ebe0da06dd6cd03551682fd7ab3a772f5fbc5cba2afbd17d1ed064cae8db36b6bc6ab33b803a40fc7bc9fc7eb0327ee6486803672f653659cea6cc55212db194b9f7ecf1e0996117a489c5caf861425743681184ed3dbe5f8de71b5e7479ce13b6e1b5f6368b187185e9e14967ec04bb67d3797e4b0b2f00ee0cc61a7e2b2feff0a5ed98d503de0e8e3f445e328e8e8d45dc4453e10f49a6d642cbd90c06d7e81e64cf8d8562f6ef708a5761f1503e221ffa15a5318a880e25f8e3a7e79ce4bd263fdc6f683fb2cd1";

        operatorsManager.addValidators(index, 10, tenPublicKeys, tenSignatures);

        Operators.Operator memory operator = operatorsManager.getOperator(index);
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

        OperatorsManagerInitializableV1(address(operatorsManager)).sudoSetFunded(string(abi.encodePacked(_name)), 10);

        vm.expectRevert(abi.encodeWithSignature("InvalidFundedKeyDeletionAttempt()"));
        operatorsManager.removeValidators(index, indexes);
    }

    function testRemoveValidatorsKeyOutOfBounds(bytes32 _name, uint256 _firstAddressSalt) public {
        address _firstAddress = uf._new(_firstAddressSalt);
        vm.startPrank(admin);
        operatorsManager.addOperator(string(abi.encodePacked(_name)), _firstAddress);
        (int256 _index, ) = operatorsManager.getOperatorDetails(string(abi.encodePacked(_name)));
        assert(_index >= 0);
        uint256 index = uint256(_index);

        bytes
            memory tenPublicKeys = hex"e18e2e0fff999e38c547fb921bd915a1fef6a46e07db2705a57d17542f0acc6be99fee18fb2c17a7f247fc05edd722b9e95f700adf12dd6f20d65c2e411a6a447cb6f4f7c84b8b6673099385d5dcf964e479a9167c802d977ba0a0a22df2336f83182e83bc198c34c301482f189475209fb93d362704e317709fec266f14b3383e7bac3e0e306b1ac8228482c31d7ffbc7e0f865bd4648c7c45c1361f9cd0f4ccab693068a55e6823a4edd8ef4ced9faa64343866ad7357d488bff347a36f2476cc7b4eaf397c832968548ea70e1de2b2691628399d9f59fdd21a62dd3da50d0255790ec1c15949850a869a37595f8f52cc9d681f2b78748254ba36456f7e65d3c7ed2b64ef502cbd3c2f48d789924a99aedfbd097f4ff5829e787ef29b0b79c817337c08ff68c454a1ddc6359d09c0d48a9298a96691c3558812ca13239d9324f146a6b3bfb7bd3f2b1877929ceb74fa1ed590351801935d1e61c875c7772e74d037b26f972f2dfa0569ae9bf8cc32dee87e980497cd79492bf91edeafacfbd6ad32c642a6564ffc9a5d921d0cc35740314c88986547d8f94e60f5d3a2e0a0b1723d20546beaf064adfd78e5f63b600a6ee5b0bacf6f30bf456afadef451a1c503e428fcd295b5d20ad9e065e1684dced5487fd33270bb68b783a6963eab250";
        bytes
            memory tenSignatures = hex"1d40e9c75a57997aa60105f21d0c68c3be0435f1f68f755c33015110e38ef97b4b5e2008096e75b906ae4d1f5aec6ad505920c58758631a06ac8c7666b582c9b3fa70a67e39a5aec2a6a11756eb2c0dd74c33beafce3ce8396e86671e00528c0f4c6e9ccef87d852ac23e38f3a1585b710e4eeaa919b7040e49a55583b250801f4f54a7fc1d514ee4a89f2a0a31b500065ea383c4ff0d2981da1fc7e047239d1743c2ce0412a424fe7d32628d656c57d56a6f322d696b6099f44f5257e051cbfed1497e89d637a05b2063a30f232ceba1677e571b08c3c8bb84979d5fcab1652ae40c0840e29a32725d9b45fea996edce566ffff5be6d38d056c6a1827fb7b0ba69f1923a0384e8da72dced43b0e83714d2eda54916252859962b659e0a081fcb4ea39240afef5b8ae854eb4a159d1bdd9eed58aa368c690fe816052fd3f270215dd0ec0cc55e386ea43cb52849d00cc6a2efbec1d693619f9dcf64bfbc9c1982d1acc877b898f48d8337b372a338907dc7af4d8d58e08e1302313721fef9d9c1697256b3dc113bfc7860bccf01dc4d28d3ef09e43db4ecdd78c41bdc89ed50130b1b87ba137c33928f9aff8481e204d8ccd86938da666357cbf4d7253ce56eed980dc7ec2d4a610f541d8f7c830592bb39b8048848203ce74db2f585a7b8cd1ae6b47192b1983efddfb42c1ad65a0c9ceae3548565829c1bcd1a06da7ed4e10698fd2e5b2715a3cbae861909d8364f622882e080f0a07e153fb29c7c3abcc27f2011e76d09d013a5b511b0de51cbefc206c58cb9c09e405b5db80f1c98ea414ae2705de213715e01b81cda31c4ec814e50b341723dc4be0a81268cd04be2d306347540be98c2a3192a968dbad68ba2b5c066c684d18bdcb7345f1d2b643f2ff7bb8494c093eaaf31ee192c9a1486b387701c3bda0ed55af872665fcb0267e3e0b9e7d55e13555ec0f8742229898693ca26ddbb8cae390e9ec35fc3e07c21236fa8264974f9d3aea67a059d6e88111f48341ffdfa911ad89a2a2fbb2a790d69f3fc7646c0071b0c1ca25567f8e2b09d3177abb3e0ec38e4ebe0da06dd6cd03551682fd7ab3a772f5fbc5cba2afbd17d1ed064cae8db36b6bc6ab33b803a40fc7bc9fc7eb0327ee6486803672f653659cea6cc55212db194b9f7ecf1e0996117a489c5caf861425743681184ed3dbe5f8de71b5e7479ce13b6e1b5f6368b187185e9e14967ec04bb67d3797e4b0b2f00ee0cc61a7e2b2feff0a5ed98d503de0e8e3f445e328e8e8d45dc4453e10f49a6d642cbd90c06d7e81e64cf8d8562f6ef708a5761f1503e221ffa15a5318a880e25f8e3a7e79ce4bd263fdc6f683fb2cd1";

        operatorsManager.addValidators(index, 10, tenPublicKeys, tenSignatures);

        Operators.Operator memory operator = operatorsManager.getOperator(index);
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
        operatorsManager.removeValidators(index, indexes);
    }

    function testRemoveValidatorsUnsortedIndexes(bytes32 _name, uint256 _firstAddressSalt) public {
        address _firstAddress = uf._new(_firstAddressSalt);
        vm.startPrank(admin);
        operatorsManager.addOperator(string(abi.encodePacked(_name)), _firstAddress);
        (int256 _index, ) = operatorsManager.getOperatorDetails(string(abi.encodePacked(_name)));
        assert(_index >= 0);
        uint256 index = uint256(_index);

        bytes
            memory tenPublicKeys = hex"e18e2e0fff999e38c547fb921bd915a1fef6a46e07db2705a57d17542f0acc6be99fee18fb2c17a7f247fc05edd722b9e95f700adf12dd6f20d65c2e411a6a447cb6f4f7c84b8b6673099385d5dcf964e479a9167c802d977ba0a0a22df2336f83182e83bc198c34c301482f189475209fb93d362704e317709fec266f14b3383e7bac3e0e306b1ac8228482c31d7ffbc7e0f865bd4648c7c45c1361f9cd0f4ccab693068a55e6823a4edd8ef4ced9faa64343866ad7357d488bff347a36f2476cc7b4eaf397c832968548ea70e1de2b2691628399d9f59fdd21a62dd3da50d0255790ec1c15949850a869a37595f8f52cc9d681f2b78748254ba36456f7e65d3c7ed2b64ef502cbd3c2f48d789924a99aedfbd097f4ff5829e787ef29b0b79c817337c08ff68c454a1ddc6359d09c0d48a9298a96691c3558812ca13239d9324f146a6b3bfb7bd3f2b1877929ceb74fa1ed590351801935d1e61c875c7772e74d037b26f972f2dfa0569ae9bf8cc32dee87e980497cd79492bf91edeafacfbd6ad32c642a6564ffc9a5d921d0cc35740314c88986547d8f94e60f5d3a2e0a0b1723d20546beaf064adfd78e5f63b600a6ee5b0bacf6f30bf456afadef451a1c503e428fcd295b5d20ad9e065e1684dced5487fd33270bb68b783a6963eab250";
        bytes
            memory tenSignatures = hex"1d40e9c75a57997aa60105f21d0c68c3be0435f1f68f755c33015110e38ef97b4b5e2008096e75b906ae4d1f5aec6ad505920c58758631a06ac8c7666b582c9b3fa70a67e39a5aec2a6a11756eb2c0dd74c33beafce3ce8396e86671e00528c0f4c6e9ccef87d852ac23e38f3a1585b710e4eeaa919b7040e49a55583b250801f4f54a7fc1d514ee4a89f2a0a31b500065ea383c4ff0d2981da1fc7e047239d1743c2ce0412a424fe7d32628d656c57d56a6f322d696b6099f44f5257e051cbfed1497e89d637a05b2063a30f232ceba1677e571b08c3c8bb84979d5fcab1652ae40c0840e29a32725d9b45fea996edce566ffff5be6d38d056c6a1827fb7b0ba69f1923a0384e8da72dced43b0e83714d2eda54916252859962b659e0a081fcb4ea39240afef5b8ae854eb4a159d1bdd9eed58aa368c690fe816052fd3f270215dd0ec0cc55e386ea43cb52849d00cc6a2efbec1d693619f9dcf64bfbc9c1982d1acc877b898f48d8337b372a338907dc7af4d8d58e08e1302313721fef9d9c1697256b3dc113bfc7860bccf01dc4d28d3ef09e43db4ecdd78c41bdc89ed50130b1b87ba137c33928f9aff8481e204d8ccd86938da666357cbf4d7253ce56eed980dc7ec2d4a610f541d8f7c830592bb39b8048848203ce74db2f585a7b8cd1ae6b47192b1983efddfb42c1ad65a0c9ceae3548565829c1bcd1a06da7ed4e10698fd2e5b2715a3cbae861909d8364f622882e080f0a07e153fb29c7c3abcc27f2011e76d09d013a5b511b0de51cbefc206c58cb9c09e405b5db80f1c98ea414ae2705de213715e01b81cda31c4ec814e50b341723dc4be0a81268cd04be2d306347540be98c2a3192a968dbad68ba2b5c066c684d18bdcb7345f1d2b643f2ff7bb8494c093eaaf31ee192c9a1486b387701c3bda0ed55af872665fcb0267e3e0b9e7d55e13555ec0f8742229898693ca26ddbb8cae390e9ec35fc3e07c21236fa8264974f9d3aea67a059d6e88111f48341ffdfa911ad89a2a2fbb2a790d69f3fc7646c0071b0c1ca25567f8e2b09d3177abb3e0ec38e4ebe0da06dd6cd03551682fd7ab3a772f5fbc5cba2afbd17d1ed064cae8db36b6bc6ab33b803a40fc7bc9fc7eb0327ee6486803672f653659cea6cc55212db194b9f7ecf1e0996117a489c5caf861425743681184ed3dbe5f8de71b5e7479ce13b6e1b5f6368b187185e9e14967ec04bb67d3797e4b0b2f00ee0cc61a7e2b2feff0a5ed98d503de0e8e3f445e328e8e8d45dc4453e10f49a6d642cbd90c06d7e81e64cf8d8562f6ef708a5761f1503e221ffa15a5318a880e25f8e3a7e79ce4bd263fdc6f683fb2cd1";

        operatorsManager.addValidators(index, 10, tenPublicKeys, tenSignatures);

        Operators.Operator memory operator = operatorsManager.getOperator(index);
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
        operatorsManager.removeValidators(index, indexes);
    }

    function testGetOperatorByName(bytes32 _name, uint256 _firstAddressSalt) public {
        address _firstAddress = uf._new(_firstAddressSalt);
        vm.startPrank(admin);
        operatorsManager.addOperator(string(abi.encodePacked(_name)), _firstAddress);

        Operators.Operator memory operator = operatorsManager.getOperatorByName(string(abi.encodePacked(_name)));
        assert(operator.active == true);
    }

    function testGetOperatorByIndex(bytes32 _name, uint256 _firstAddressSalt) public {
        address _firstAddress = uf._new(_firstAddressSalt);
        vm.startPrank(admin);
        operatorsManager.addOperator(string(abi.encodePacked(_name)), _firstAddress);

        Operators.Operator memory operator = operatorsManager.getOperatorByName(string(abi.encodePacked(_name)));
        Operators.Operator memory operatorByIndex = operatorsManager.getOperator(0);
        assert(operator.active == true);
        assert(keccak256(bytes(operatorByIndex.name)) == keccak256(bytes(operator.name)));
    }

    function testGetOperatorCount(bytes32 _name, uint256 _firstAddressSalt) public {
        address _firstAddress = uf._new(_firstAddressSalt);
        vm.startPrank(admin);
        assert(operatorsManager.getOperatorCount() == 0);
        operatorsManager.addOperator(string(abi.encodePacked(_name)), _firstAddress);
        assert(operatorsManager.getOperatorCount() == 1);
    }
}
