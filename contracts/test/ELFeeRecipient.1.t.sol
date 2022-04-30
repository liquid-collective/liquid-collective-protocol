//SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import "./Vm.sol";
import "../src/ELFeeRecipient.1.sol";
import "../src/libraries/Errors.sol";
import "../src/interfaces/IRiverDonationInput.sol";
import "../src/Withdraw.1.sol";
import "./utils/River.setup1.sol";
import "./utils/UserFactory.sol";

contract RiverDonationMock is IRiverDonationInput {
    event Donation(address donator, uint256 amount);

    error EmptyDonation();

    function donate() external payable {
        if (msg.value == 0) {
            revert EmptyDonation();
        }

        emit Donation(msg.sender, msg.value);
    }
}

contract ELFeeRecipientV1Test {
    ELFeeRecipientV1 internal feeRecipient;

    IRiverDonationInput internal donationInput;
    Vm internal vm = Vm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    UserFactory internal uf = new UserFactory();

    event Donation(address donator, uint256 amount);

    function setUp() public {
        donationInput = new RiverDonationMock();
        feeRecipient = new ELFeeRecipientV1();
        feeRecipient.initELFeeRecipientV1(address(donationInput));
    }

    function testReceiveBribeWithTransfer(uint256 _userSalt, uint256 _bribeAmount) public {
        address user = uf._new(_userSalt);
        vm.deal(user, _bribeAmount);

        vm.startPrank(user);
        assert(address(feeRecipient).balance == 0);
        payable(address(feeRecipient)).transfer(_bribeAmount);
        assert(address(feeRecipient).balance == _bribeAmount);
        vm.stopPrank();

        if (_bribeAmount == 0) {
            vm.expectRevert(abi.encodeWithSignature("EmptyDonation()"));
        } else {
            vm.expectEmit(true, true, true, true);
            emit Donation(address(feeRecipient), _bribeAmount);
        }
        feeRecipient.compound();
    }

    function testReceiveBribeWithSend(uint256 _userSalt, uint256 _bribeAmount) public {
        address user = uf._new(_userSalt);
        vm.deal(user, _bribeAmount);

        vm.startPrank(user);
        assert(address(feeRecipient).balance == 0);
        assert(payable(address(feeRecipient)).send(_bribeAmount) == true);
        assert(address(feeRecipient).balance == _bribeAmount);
        vm.stopPrank();

        if (_bribeAmount == 0) {
            vm.expectRevert(abi.encodeWithSignature("EmptyDonation()"));
        } else {
            vm.expectEmit(true, true, true, true);
            emit Donation(address(feeRecipient), _bribeAmount);
        }
        feeRecipient.compound();
    }

    function testReceiveBribeWithCall(uint256 _userSalt, uint256 _bribeAmount) public {
        address user = uf._new(_userSalt);
        vm.deal(user, _bribeAmount);

        vm.startPrank(user);
        assert(address(feeRecipient).balance == 0);
        (bool status, ) = address(feeRecipient).call{value: _bribeAmount}("");
        assert(status == true);
        assert(address(feeRecipient).balance == _bribeAmount);
        vm.stopPrank();

        if (_bribeAmount == 0) {
            vm.expectRevert(abi.encodeWithSignature("EmptyDonation()"));
        } else {
            vm.expectEmit(true, true, true, true);
            emit Donation(address(feeRecipient), _bribeAmount);
        }
        feeRecipient.compound();
    }

    function testReceiveBribeWithInflation(uint256 _bribeAmount) public {
        vm.deal(address(feeRecipient), _bribeAmount);
        assert(address(feeRecipient).balance == _bribeAmount);

        if (_bribeAmount == 0) {
            vm.expectRevert(abi.encodeWithSignature("EmptyDonation()"));
        } else {
            vm.expectEmit(true, true, true, true);
            emit Donation(address(feeRecipient), _bribeAmount);
        }
        feeRecipient.compound();
    }
}
