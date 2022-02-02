//SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import "./Vm.sol";
import "../src/components/TransferManager.1.sol";

contract TransferManagerV1EmptyDeposit is TransferManagerV1 {
    function _onDeposit() internal view override {
        this;
    }
}

contract TransferManagerV1DepositTests {
    Vm internal vm = Vm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    TransferManagerV1 internal transferManager;

    error InvalidCall();

    event UserDeposit(
        address indexed user,
        address indexed referral,
        uint256 amount
    );

    function setUp() public {
        transferManager = new TransferManagerV1EmptyDeposit();
    }

    function testDepositWithDedicatedMethod(address _user, uint256 _amount)
        public
    {
        vm.deal(_user, _amount);
        vm.deal(address(transferManager), 0);
        vm.startPrank(_user);

        assert(_user.balance == _amount);
        assert(address(transferManager).balance == 0);

        vm.expectEmit(true, true, true, true);
        emit UserDeposit(_user, address(0), _amount);
        transferManager.deposit{value: _amount}(address(0));

        assert(_user.balance == 0);
        assert(address(transferManager).balance == _amount);
    }

    function testDepositWithDedicatedMethodAndReferral(
        address _user,
        address _referral,
        uint256 _amount
    ) public {
        vm.deal(_user, _amount);
        vm.deal(address(transferManager), 0);
        vm.startPrank(_user);

        assert(_user.balance == _amount);
        assert(address(transferManager).balance == 0);

        vm.expectEmit(true, true, true, true);
        emit UserDeposit(_user, _referral, _amount);
        transferManager.deposit{value: _amount}(_referral);

        assert(_user.balance == 0);
        assert(address(transferManager).balance == _amount);
    }

    function testDepositWithReceiveFallback(address _user, uint256 _amount)
        public
    {
        vm.deal(_user, _amount);
        vm.deal(address(transferManager), 0);
        vm.startPrank(_user);

        assert(_user.balance == _amount);
        assert(address(transferManager).balance == 0);

        vm.expectEmit(true, true, true, true);
        emit UserDeposit(_user, address(0), _amount);
        (bool success, ) = address(transferManager).call{value: _amount}("");
        assert(success == true);

        assert(_user.balance == 0);
        assert(address(transferManager).balance == _amount);
    }

    function testDepositWithCalldataFallback(address _user, uint256 _amount)
        public
    {
        vm.deal(_user, _amount);
        vm.startPrank(_user);

        (bool success, bytes memory returnData) = address(transferManager).call{
            value: _amount
        }("0x1234");
        assert(success == false);
        assert(
            keccak256(returnData) ==
                keccak256(abi.encodeWithSignature("InvalidCall()"))
        );
    }
}

contract TransferManagerV1CatchableDeposit is TransferManagerV1 {
    event InternalCallbackCalled();

    function _onDeposit() internal override {
        emit InternalCallbackCalled();
    }
}

contract TransferManagerV1CallbackTests {
    Vm internal vm = Vm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    TransferManagerV1 internal transferManager;

    event InternalCallbackCalled();

    function setUp() public {
        transferManager = new TransferManagerV1CatchableDeposit();
    }

    function testInternalCallback(address _user, uint256 _amount) public {
        vm.deal(_user, _amount);
        vm.startPrank(_user);

        assert(_user.balance == _amount);

        vm.expectEmit(true, true, true, true);
        emit InternalCallbackCalled();
        transferManager.deposit{value: _amount}(address(0));

        assert(_user.balance == 0);
    }
}
