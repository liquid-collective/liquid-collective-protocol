//SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import "forge-std/Test.sol";
import "./utils/UserFactory.sol";

import "../src/interfaces/IWithdraw.1.sol";
import "../src/Withdraw.1.sol";

contract RiverMock {
    event DebugReceivedCLFunds(uint256 amount);

    function sendCLFunds() external payable {
        emit DebugReceivedCLFunds(msg.value);
    }

    function debug_pullFunds(address withdrawContract, uint256 amount) external {
        IWithdrawV1(payable(withdrawContract)).pullEth(amount);
    }
}

contract WithdrawV1Tests is Test {
    WithdrawV1 internal withdraw;
    RiverMock internal river;
    UserFactory internal uf = new UserFactory();

    event DebugReceivedCLFunds(uint256 amount);

    function setUp() external {
        river = new RiverMock();

        withdraw = new WithdrawV1();
        withdraw.initializeWithdrawV1(address(river));
    }

    function testReinitialize() external {
        vm.expectRevert(abi.encodeWithSignature("InvalidInitialization(uint256,uint256)", 0, 1));
        withdraw.initializeWithdrawV1(address(river));
    }

    function testGetCredentials() external {
        assertEq(
            withdraw.getCredentials(),
            bytes32(
                uint256(uint160(address(withdraw))) + 0x0100000000000000000000000000000000000000000000000000000000000000
            )
        );
    }

    function testGetRiver() external {
        assertEq(withdraw.getRiver(), address(river));
    }

    function testPullFundsAsRiverPullAll(uint256 _salt, uint128 _amount) external {
        address sender = uf._new(_salt);
        vm.deal(address(withdraw), _amount);

        vm.deal(sender, uint256(_amount) * 4);

        vm.startPrank(sender);
        (bool success,) = address(withdraw).call{value: _amount}("");
        assertTrue(success, "call failed");
        (success,) = address(withdraw).call{value: _amount}(abi.encodeWithSignature("thisMethodDoesNotExist()"));
        assertTrue(success, "call with data failed");
        assertTrue(payable(address(withdraw)).send(_amount), "send failed");
        payable(address(withdraw)).transfer(_amount);
        assertTrue(success, "transfer failed");
        vm.stopPrank();

        assertEq(address(withdraw).balance, uint256(_amount) * 5);
        assertEq(address(river).balance, 0);

        vm.expectEmit(true, true, true, true);
        emit DebugReceivedCLFunds(uint256(_amount) * 5);
        river.debug_pullFunds(address(withdraw), uint256(_amount) * 5);

        assertEq(address(withdraw).balance, 0);
        assertEq(address(river).balance, uint256(_amount) * 5);
    }

    function testPullFundsAsRiverPullPartial(uint256 _salt, uint128 _amount) external {
        vm.assume(_amount > 0);
        address sender = uf._new(_salt);
        vm.deal(address(withdraw), _amount);

        vm.deal(sender, uint256(_amount) * 4);

        vm.startPrank(sender);
        (bool success,) = address(withdraw).call{value: _amount}("");
        assertTrue(success, "call failed");
        (success,) = address(withdraw).call{value: _amount}(abi.encodeWithSignature("thisMethodDoesNotExist()"));
        assertTrue(success, "call with data failed");
        success = payable(address(withdraw)).send(_amount);
        assertTrue(success, "send failed");
        payable(address(withdraw)).transfer(_amount);
        assertTrue(success, "transfer failed");
        vm.stopPrank();

        assertEq(address(withdraw).balance, uint256(_amount) * 5);
        assertEq(address(river).balance, 0);

        uint256 amountToPull = bound(_salt, 1, uint256(_amount) * 5);

        vm.expectEmit(true, true, true, true);
        emit DebugReceivedCLFunds(amountToPull);
        river.debug_pullFunds(address(withdraw), amountToPull);

        assertEq(address(withdraw).balance, uint256(_amount) * 5 - amountToPull);
        assertEq(address(river).balance, amountToPull);
    }

    function testPullFundsAsRandom(uint256 _salt) external {
        address random = uf._new(_salt);

        vm.deal(address(withdraw), 1 ether);

        vm.prank(random);
        vm.expectRevert(abi.encodeWithSignature("Unauthorized(address)", random));
        withdraw.pullEth(1 ether);
    }

    function testPullFundsAmountTooHigh(uint256 _salt, uint256 _amount) external {
        vm.assume(_amount < type(uint256).max);
        address random = uf._new(_salt);

        vm.deal(address(withdraw), _amount);

        vm.prank(random);
        vm.expectRevert(abi.encodeWithSignature("PulledAmountTooHigh(uint256,uint256)", _amount + 1, _amount));
        river.debug_pullFunds(address(withdraw), _amount + 1);
    }
}
