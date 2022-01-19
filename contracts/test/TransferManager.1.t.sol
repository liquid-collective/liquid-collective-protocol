//SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import "./Vm.sol";
import "../src/components/transfer/TransferManager.1.sol";

contract TransferManagerV1DepositTests is TransferManagerV1 {
    Vm internal vm = Vm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function _onDeposit() internal view override {
        this;
    }

    function testDepositWithDedicatedMethod(address _user, uint256 _amount)
        public
    {
        vm.deal(_user, _amount);
        vm.deal(address(this), 0);
        vm.startPrank(_user);

        assert(_user.balance == _amount);
        assert(address(this).balance == 0);

        vm.expectEmit(true, true, true, true);
        emit UserDeposit(_user, address(0), _amount);
        TransferManagerV1(this).deposit{value: _amount}(address(0));

        assert(_user.balance == 0);
        assert(address(this).balance == _amount);
    }

    function testDepositWithDedicatedMethodAndReferral(
        address _user,
        address _referral,
        uint256 _amount
    ) public {
        vm.deal(_user, _amount);
        vm.deal(address(this), 0);
        vm.startPrank(_user);

        assert(_user.balance == _amount);
        assert(address(this).balance == 0);

        vm.expectEmit(true, true, true, true);
        emit UserDeposit(_user, _referral, _amount);
        TransferManagerV1(this).deposit{value: _amount}(_referral);

        assert(_user.balance == 0);
        assert(address(this).balance == _amount);
    }

    function testDepositWithReceiveFallback(address _user, uint256 _amount)
        public
    {
        vm.deal(_user, _amount);
        vm.deal(address(this), 0);
        vm.startPrank(_user);

        assert(_user.balance == _amount);
        assert(address(this).balance == 0);

        vm.expectEmit(true, true, true, true);
        emit UserDeposit(_user, address(0), _amount);
        (bool success, ) = address(this).call{value: _amount}("");
        assert(success == true);

        assert(_user.balance == 0);
        assert(address(this).balance == _amount);
    }

    function testDepositWithCalldataFallback(address _user, uint256 _amount)
        public
    {
        vm.deal(_user, _amount);
        vm.startPrank(_user);

        (bool success, bytes memory returnData) = address(this).call{
            value: _amount
        }("0x1234");
        assert(success == false);
        assert(
            keccak256(returnData) ==
                keccak256(abi.encodeWithSignature("InvalidCall()"))
        );
    }
}

contract TransferManagerV1CallbackTests is TransferManagerV1 {
    Vm internal vm = Vm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    event InternalCallbackCalled();

    function _onDeposit() internal override {
        emit InternalCallbackCalled();
    }

    function testInternalCallback(address _user, uint256 _amount) public {
        vm.deal(_user, _amount);
        vm.startPrank(_user);

        assert(_user.balance == _amount);

        vm.expectEmit(true, true, true, true);
        emit InternalCallbackCalled();
        TransferManagerV1(this).deposit{value: _amount}(address(0));

        assert(_user.balance == 0);
    }
}
