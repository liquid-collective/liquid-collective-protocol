//SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import "forge-std/Test.sol";

import "../utils/UserFactory.sol";

import "../../src/components/UserDepositManager.1.sol";

contract UserDepositManagerV1EmptyDeposit is UserDepositManagerV1 {
    function _onDeposit(address, address, uint256) internal view override {
        this;
    }

    function _onDonation(address) internal view override {
        this;
    }
}

contract UserDepositManagerV1DepositTests is Test {
    UserDepositManagerV1 internal transferManager;
    UserFactory internal uf = new UserFactory();

    error InvalidCall();

    event UserDeposit(address indexed depositor, address indexed recipient, uint256 amount);
    event UserDonation(address indexed donator, uint256 amount);

    function setUp() public {
        transferManager = new UserDepositManagerV1EmptyDeposit();
    }

    function testDepositWithDedicatedMethod(uint256 _userSalt, uint256 _amount) public {
        address _user = uf._new(_userSalt);
        vm.deal(_user, _amount);
        vm.deal(address(transferManager), 0);
        vm.startPrank(_user);

        assert(_user.balance == _amount);
        assert(address(transferManager).balance == 0);

        if (_amount > 0) {
            vm.expectEmit(true, true, true, true);
            emit UserDeposit(_user, _user, _amount);
        } else {
            vm.expectRevert(abi.encodeWithSignature("EmptyDeposit()"));
        }
        transferManager.deposit{value: _amount}();

        assert(_user.balance == 0);
        assert(address(transferManager).balance == _amount);
    }

    function testDepositToAnotherUserWithDedicatedMethod(uint256 _userSalt, uint256 _anotherUserSalt, uint256 _amount)
        public
    {
        address _user = uf._new(_userSalt);
        address _anotherUser = uf._new(_anotherUserSalt);
        vm.deal(_user, _amount);
        vm.deal(address(transferManager), 0);
        vm.startPrank(_user);

        assert(_user.balance == _amount);
        assert(address(transferManager).balance == 0);

        if (_amount > 0) {
            vm.expectEmit(true, true, true, true);
            emit UserDeposit(_user, _anotherUser, _amount);
        } else {
            vm.expectRevert(abi.encodeWithSignature("EmptyDeposit()"));
        }
        transferManager.depositAndTransfer{value: _amount}(_anotherUser);

        assert(_user.balance == 0);
        assert(address(transferManager).balance == _amount);
    }

    function testDepositWithReceiveFallback(uint256 _userSalt, uint256 _amount) public {
        address _user = uf._new(_userSalt);
        vm.deal(_user, _amount);
        vm.deal(address(transferManager), 0);
        vm.startPrank(_user);

        assert(_user.balance == _amount);
        assert(address(transferManager).balance == 0);

        if (_amount > 0) {
            vm.expectEmit(true, true, true, true);
            emit UserDeposit(_user, _user, _amount);
        } else {
            vm.expectRevert(abi.encodeWithSignature("EmptyDeposit()"));
        }
        (bool success,) = address(transferManager).call{value: _amount}("");
        assert(success == true);

        assert(_user.balance == 0);
        assert(address(transferManager).balance == _amount);
    }

    function testDepositWithCalldataFallback(uint256 _userSalt, uint256 _amount) public {
        address _user = uf._new(_userSalt);
        vm.deal(_user, _amount);
        vm.startPrank(_user);

        (bool success, bytes memory returnData) = address(transferManager).call{value: _amount}("0x1234");
        assert(success == false);
        assert(keccak256(returnData) == keccak256(abi.encodeWithSignature("InvalidCall()")));
    }

    function testDonate(uint256 _userSalt, uint256 _amount) public {
        address _user = uf._new(_userSalt);
        vm.deal(_user, _amount);
        vm.deal(address(transferManager), 0);
        vm.startPrank(_user);

        assert(_user.balance == _amount);
        assert(address(transferManager).balance == 0);

        if (_amount > 0) {
            vm.expectEmit(true, true, true, true);
            emit UserDonation(_user, _amount);
        } else {
            vm.expectRevert(abi.encodeWithSignature("EmptyDonation()"));
        }
        transferManager.donate{value: _amount}();

        assert(_user.balance == 0);
        assert(address(transferManager).balance == _amount);
    }
}

contract UserDepositManagerV1CatchableDeposit is UserDepositManagerV1 {
    event InternalCallbackCalled(address depositor, address recipient, uint256 amount);

    function _onDeposit(address depositor, address recipient, uint256 amount) internal override {
        emit InternalCallbackCalled(depositor, recipient, amount);
    }

    function _onDonation(address depositor) internal override {
        emit InternalCallbackCalled(depositor, depositor, msg.value);
    }
}

contract UserDepositManagerV1CallbackTests is Test {
    UserDepositManagerV1 internal transferManager;
    UserFactory internal uf = new UserFactory();

    event InternalCallbackCalled(address depositor, address recipient, uint256 amount);

    function setUp() public {
        transferManager = new UserDepositManagerV1CatchableDeposit();
    }

    function testDepositInternalCallback(uint256 _userSalt, uint256 _amount) public {
        address _user = uf._new(_userSalt);
        vm.deal(_user, _amount);
        vm.startPrank(_user);

        assert(_user.balance == _amount);

        if (_amount > 0) {
            vm.expectEmit(true, true, true, true);
            emit InternalCallbackCalled(_user, _user, _amount);
        } else {
            vm.expectRevert(abi.encodeWithSignature("EmptyDeposit()"));
        }
        transferManager.deposit{value: _amount}();

        assert(_user.balance == 0);
    }

    function testDepositToAnotherUserInternalCallback(uint256 _userSalt, uint256 _anotherUserSalt, uint256 _amount)
        public
    {
        address _user = uf._new(_userSalt);
        address _anotherUser = uf._new(_anotherUserSalt);
        vm.deal(_user, _amount);
        vm.startPrank(_user);

        assert(_user.balance == _amount);

        if (_amount > 0) {
            vm.expectEmit(true, true, true, true);
            emit InternalCallbackCalled(_user, _anotherUser, _amount);
        } else {
            vm.expectRevert(abi.encodeWithSignature("EmptyDeposit()"));
        }
        transferManager.depositAndTransfer{value: _amount}(_anotherUser);

        assert(_user.balance == 0);
    }

    function testDonateInternalCallback(uint256 _userSalt, uint256 _amount) public {
        address _user = uf._new(_userSalt);
        vm.deal(_user, _amount);
        vm.deal(address(transferManager), 0);
        vm.startPrank(_user);

        assert(_user.balance == _amount);
        assert(address(transferManager).balance == 0);

        if (_amount > 0) {
            vm.expectEmit(true, true, true, true);
            emit InternalCallbackCalled(_user, _user, _amount);
        } else {
            vm.expectRevert(abi.encodeWithSignature("EmptyDonation()"));
        }
        transferManager.donate{value: _amount}();

        assert(_user.balance == 0);
        assert(address(transferManager).balance == _amount);
    }
}
