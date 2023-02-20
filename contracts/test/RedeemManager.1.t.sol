//SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import "forge-std/Test.sol";

import "./utils/UserFactory.sol";

import "../src/state/redeemManager/RedeemRequests.sol";
import "../src/state/redeemManager/WithdrawalEvents.sol";
import "../src/RedeemManager.1.sol";
import "../src/Allowlist.1.sol";

contract RiverMock {
    mapping(address => uint256) internal balances;
    mapping(address => mapping(address => uint256)) internal approvals;
    address internal allowlist;

    constructor(address _allowlist) {
        allowlist = _allowlist;
    }

    function approve(address to, uint256 amount) external {
        approvals[msg.sender][to] = amount;
    }

    error ApprovedAmountTooLow();

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        if (approvals[from][msg.sender] < amount) {
            revert ApprovedAmountTooLow();
        }
        if (approvals[from][msg.sender] != type(uint256).max) {
            approvals[from][msg.sender] -= amount;
        }
        balances[from] -= amount;
        balances[to] += amount;
        return true;
    }

    function sudoDeal(address account, uint256 amount) external {
        balances[account] = amount;
    }

    function getAllowlist() external view returns (address) {
        return allowlist;
    }

    function sudoReportWithdraw(address redeemManager, uint256 lsETHAmount) external payable {
        RedeemManagerV1(redeemManager).reportWithdraw{value: msg.value}(lsETHAmount);
    }
}

contract RedeemManagerV1Tests is Test {
    RedeemManagerV1 internal redeemManager;
    AllowlistV1 internal allowlist;
    RiverMock internal river;
    UserFactory internal uf = new UserFactory();
    address internal allowlistAdmin;
    address internal allowlistAllower;

    event RequestedRedeem(address indexed owner, uint256 height, uint256 size, uint32 id);
    event ReportedWithdrawal(uint256 height, uint256 size, uint256 ethAmount, uint32 id);
    event FilledRedeemRequest(
        uint32 indexed id, uint32 withdrawalEventId, uint256 amountFilled, uint256 ethAmountFilled
    );
    event SentRewards(address indexed recipient, uint256 amount);

    function setUp() external {
        allowlistAdmin = makeAddr("allowlistAdmin");
        allowlistAllower = makeAddr("allowlistAllower");
        redeemManager = new RedeemManagerV1();
        allowlist = new AllowlistV1();
        allowlist.initAllowlistV1(allowlistAdmin, allowlistAllower);
        river = new RiverMock(address(allowlist));

        redeemManager.initializeRedeemManagerV1(address(river));
    }

    function _generateAuthorizedUser(uint256 _salt) internal returns (address) {
        address user = uf._new(_salt);

        address[] memory accounts = new address[](1);
        uint256[] memory permissions = new uint256[](1);

        accounts[0] = user;
        permissions[0] = LibAllowlistMasks.REDEEM_MASK;

        vm.prank(allowlistAllower);
        allowlist.allow(accounts, permissions);

        return user;
    }

    function testRequestRedeem(uint256 _salt) external {
        address user = _generateAuthorizedUser(_salt);

        uint128 amount = uint128(bound(_salt, 1, type(uint128).max));

        river.sudoDeal(user, amount);

        vm.prank(user);
        river.approve(address(redeemManager), amount);

        vm.prank(user);
        vm.expectEmit(true, true, true, true);
        emit RequestedRedeem(user, 0, amount, 0);
        redeemManager.requestRedeem(amount, user);

        uint32[] memory requests = redeemManager.listRedeemRequests(user);

        assertEq(requests.length, 1);
        assertEq(requests[0], 0);

        {
            RedeemRequests.RedeemRequest memory rr = redeemManager.getRedeemRequestDetails(0);

            assertEq(rr.height, 0);
            assertEq(rr.size, amount);
            assertEq(rr.owner, user);
        }

        assertEq(redeemManager.getRedeemRequestCount(), 1);
    }

    function testRequestRedeemUnauthorizedUser(uint256 _salt) external {
        address user = uf._new(_salt);

        uint128 amount = uint128(bound(_salt, 1, type(uint128).max));

        river.sudoDeal(user, amount);

        vm.prank(user);
        river.approve(address(redeemManager), amount);

        vm.prank(user);
        vm.expectRevert(abi.encodeWithSignature("Unauthorized(address)", user));
        redeemManager.requestRedeem(amount, user);
    }

    function testRequestRedeemMultiple(uint256 _salt) external {
        address user = _generateAuthorizedUser(_salt);

        uint64 amount = uint64(bound(_salt, 1, type(uint64).max));

        river.sudoDeal(user, uint256(amount) * 2);

        vm.prank(user);
        river.approve(address(redeemManager), uint256(amount) * 2);

        vm.prank(user);
        redeemManager.requestRedeem(amount, user);

        vm.prank(user);
        redeemManager.requestRedeem(amount, user);

        uint32[] memory requests = redeemManager.listRedeemRequests(user);

        assertEq(requests.length, 2);
        assertEq(requests[0], 0);
        assertEq(requests[1], 1);

        {
            RedeemRequests.RedeemRequest memory rr = redeemManager.getRedeemRequestDetails(0);

            assertEq(rr.height, 0);
            assertEq(rr.size, amount);
            assertEq(rr.owner, user);
        }

        {
            RedeemRequests.RedeemRequest memory rr = redeemManager.getRedeemRequestDetails(1);

            assertEq(rr.height, amount);
            assertEq(rr.size, amount);
            assertEq(rr.owner, user);
        }

        assertEq(redeemManager.getRedeemRequestCount(), 2);
    }

    function testRequestRedeemAmountZero(uint256 _salt) external {
        address user = _generateAuthorizedUser(_salt);

        vm.prank(user);
        vm.expectRevert(abi.encodeWithSignature("InvalidZeroAmount()"));
        redeemManager.requestRedeem(0, user);

        assertEq(redeemManager.getRedeemRequestCount(), 0);
    }

    function testRequestRedeemApproveTooLow(uint256 _salt) external {
        address user = _generateAuthorizedUser(_salt);

        uint64 amount = uint64(bound(_salt, 1, type(uint64).max));

        river.sudoDeal(user, amount);

        vm.prank(user);
        river.approve(address(redeemManager), amount - 1);

        vm.prank(user);
        vm.expectRevert(abi.encodeWithSignature("ApprovedAmountTooLow()"));
        redeemManager.requestRedeem(amount, user);

        assertEq(redeemManager.getRedeemRequestCount(), 0);
    }

    function testRequestRedeemZeroRecipient(uint256 _salt) external {
        address user = _generateAuthorizedUser(_salt);

        uint64 amount = uint64(bound(_salt, 1, type(uint64).max));

        river.sudoDeal(user, amount);

        vm.prank(user);
        river.approve(address(redeemManager), amount);

        vm.prank(user);
        vm.expectRevert(abi.encodeWithSignature("InvalidZeroAddress()"));
        redeemManager.requestRedeem(amount, address(0));

        assertEq(redeemManager.getRedeemRequestCount(), 0);
    }

    function testReportWithdraw(uint256 _salt) external {
        uint128 amount = uint128(bound(_salt, 1, type(uint128).max));

        vm.deal(address(this), amount);

        vm.expectEmit(true, true, true, true);
        emit ReportedWithdrawal(0, amount, amount, 0);
        river.sudoReportWithdraw{value: amount}(address(redeemManager), amount);

        assertEq(redeemManager.getWithdrawalEventCount(), 1);

        {
            WithdrawalEvents.WithdrawalEvent memory we = redeemManager.getWithdrawalEventDetails(0);

            assertEq(we.height, 0);
            assertEq(we.size, amount);
            assertEq(we.ethAmount, amount);
        }
    }

    function testReportWithdrawMultiple(uint256 _salt) external {
        uint128 amount = uint128(bound(_salt, 1, type(uint128).max));

        vm.deal(address(this), amount);

        vm.expectEmit(true, true, true, true);
        emit ReportedWithdrawal(0, amount, amount, 0);
        river.sudoReportWithdraw{value: amount}(address(redeemManager), amount);

        vm.deal(address(this), amount);

        vm.expectEmit(true, true, true, true);
        emit ReportedWithdrawal(amount, amount, amount, 1);
        river.sudoReportWithdraw{value: amount}(address(redeemManager), amount);

        assertEq(redeemManager.getWithdrawalEventCount(), 2);

        {
            WithdrawalEvents.WithdrawalEvent memory we = redeemManager.getWithdrawalEventDetails(0);

            assertEq(we.height, 0);
            assertEq(we.size, amount);
            assertEq(we.ethAmount, amount);
        }

        {
            WithdrawalEvents.WithdrawalEvent memory we = redeemManager.getWithdrawalEventDetails(1);

            assertEq(we.height, amount);
            assertEq(we.size, amount);
            assertEq(we.ethAmount, amount);
        }
    }

    function testClaimRewards(uint256 _salt) external {
        uint128 amount = uint128(bound(_salt, 1, type(uint128).max));

        address user = _generateAuthorizedUser(_salt);

        river.sudoDeal(user, uint256(amount));

        vm.prank(user);
        river.approve(address(redeemManager), uint256(amount) * 2);

        vm.prank(user);
        redeemManager.requestRedeem(amount, user);

        vm.deal(address(this), amount);
        river.sudoReportWithdraw{value: amount}(address(redeemManager), amount);

        assertEq(redeemManager.getWithdrawalEventCount(), 1);
        assertEq(redeemManager.getRedeemRequestCount(), 1);

        {
            RedeemRequests.RedeemRequest memory rr = redeemManager.getRedeemRequestDetails(0);

            assertEq(rr.height, 0);
            assertEq(rr.size, amount);
            assertEq(rr.owner, user);
        }

        {
            WithdrawalEvents.WithdrawalEvent memory we = redeemManager.getWithdrawalEventDetails(0);

            assertEq(we.height, 0);
            assertEq(we.size, amount);
            assertEq(we.ethAmount, amount);
        }

        uint32[] memory redeemRequestIds = redeemManager.listRedeemRequests(user);
        uint32[] memory withdrawEventIds = new uint32[](1);

        withdrawEventIds[0] = 0;

        assertEq(redeemRequestIds.length, 1);
        assertEq(address(redeemManager).balance, amount);
        assertEq(user.balance, 0);

        vm.expectEmit(true, true, true, true);
        emit FilledRedeemRequest(0, 0, amount, amount);
        vm.expectEmit(true, true, true, true);
        emit SentRewards(user, amount);
        redeemManager.claimRedeemRequests(redeemRequestIds, withdrawEventIds, true);

        redeemRequestIds = redeemManager.listRedeemRequests(user);

        assertEq(redeemRequestIds.length, 0);
        assertEq(address(redeemManager).balance, 0);
        assertEq(user.balance, amount);

        {
            RedeemRequests.RedeemRequest memory rr = redeemManager.getRedeemRequestDetails(0);

            assertEq(rr.height, amount);
            assertEq(rr.size, 0);
            assertEq(rr.owner, user);
        }

        {
            WithdrawalEvents.WithdrawalEvent memory we = redeemManager.getWithdrawalEventDetails(0);

            assertEq(we.height, 0);
            assertEq(we.size, amount);
            assertEq(we.ethAmount, amount);
        }
    }

    function testClaimRewardsTwiceWithSkipFlag(uint256 _salt) external {
        uint128 amount = uint128(bound(_salt, 1, type(uint128).max));

        address user = _generateAuthorizedUser(_salt);

        river.sudoDeal(user, uint256(amount));

        vm.prank(user);
        river.approve(address(redeemManager), uint256(amount) * 2);

        vm.prank(user);
        redeemManager.requestRedeem(amount, user);

        vm.deal(address(this), amount);
        river.sudoReportWithdraw{value: amount}(address(redeemManager), amount);

        assertEq(redeemManager.getWithdrawalEventCount(), 1);
        assertEq(redeemManager.getRedeemRequestCount(), 1);

        {
            RedeemRequests.RedeemRequest memory rr = redeemManager.getRedeemRequestDetails(0);

            assertEq(rr.height, 0);
            assertEq(rr.size, amount);
            assertEq(rr.owner, user);
        }

        {
            WithdrawalEvents.WithdrawalEvent memory we = redeemManager.getWithdrawalEventDetails(0);

            assertEq(we.height, 0);
            assertEq(we.size, amount);
            assertEq(we.ethAmount, amount);
        }

        uint32[] memory redeemRequestIds = new uint32[](2);
        uint32[] memory withdrawEventIds = new uint32[](2);

        redeemRequestIds[0] = 0;
        redeemRequestIds[1] = 0;
        withdrawEventIds[0] = 0;
        withdrawEventIds[1] = 0;

        assertEq(address(redeemManager).balance, amount);
        assertEq(user.balance, 0);

        vm.expectEmit(true, true, true, true);
        emit FilledRedeemRequest(0, 0, amount, amount);
        vm.expectEmit(true, true, true, true);
        emit SentRewards(user, amount);
        redeemManager.claimRedeemRequests(redeemRequestIds, withdrawEventIds, true);

        redeemRequestIds = redeemManager.listRedeemRequests(user);

        assertEq(redeemRequestIds.length, 0);
        assertEq(address(redeemManager).balance, 0);
        assertEq(user.balance, amount);

        {
            RedeemRequests.RedeemRequest memory rr = redeemManager.getRedeemRequestDetails(0);

            assertEq(rr.height, amount);
            assertEq(rr.size, 0);
            assertEq(rr.owner, user);
        }

        {
            WithdrawalEvents.WithdrawalEvent memory we = redeemManager.getWithdrawalEventDetails(0);

            assertEq(we.height, 0);
            assertEq(we.size, amount);
            assertEq(we.ethAmount, amount);
        }
    }

    function testClaimRewardsTwiceWithoutSkipFlag(uint256 _salt) external {
        uint128 amount = uint128(bound(_salt, 1, type(uint128).max));

        address user = _generateAuthorizedUser(_salt);

        river.sudoDeal(user, uint256(amount));

        vm.prank(user);
        river.approve(address(redeemManager), uint256(amount) * 2);

        vm.prank(user);
        redeemManager.requestRedeem(amount, user);

        vm.deal(address(this), amount);
        river.sudoReportWithdraw{value: amount}(address(redeemManager), amount);

        assertEq(redeemManager.getWithdrawalEventCount(), 1);
        assertEq(redeemManager.getRedeemRequestCount(), 1);

        uint32[] memory redeemRequestIds = new uint32[](2);
        uint32[] memory withdrawEventIds = new uint32[](2);

        redeemRequestIds[0] = 0;
        redeemRequestIds[1] = 0;
        withdrawEventIds[0] = 0;
        withdrawEventIds[1] = 0;

        assertEq(address(redeemManager).balance, amount);
        assertEq(user.balance, 0);

        vm.expectRevert(abi.encodeWithSignature("RedeemRequestAlreadyClaimed(uint256)", 0));
        redeemManager.claimRedeemRequests(redeemRequestIds, withdrawEventIds, false);
    }

    function testClaimRewardsRequestInside(uint256 _salt) external {
        uint128 amount = uint128(bound(_salt, 2, type(uint128).max));

        address user = _generateAuthorizedUser(_salt);

        river.sudoDeal(user, uint256(amount) / 2);

        vm.prank(user);
        river.approve(address(redeemManager), uint256(amount) / 2);

        vm.prank(user);
        redeemManager.requestRedeem(amount / 2, user);

        vm.deal(address(this), amount);
        river.sudoReportWithdraw{value: amount}(address(redeemManager), amount);

        assertEq(redeemManager.getWithdrawalEventCount(), 1);
        assertEq(redeemManager.getRedeemRequestCount(), 1);

        {
            RedeemRequests.RedeemRequest memory rr = redeemManager.getRedeemRequestDetails(0);

            assertEq(rr.height, 0);
            assertEq(rr.size, amount / 2);
            assertEq(rr.owner, user);
        }

        {
            WithdrawalEvents.WithdrawalEvent memory we = redeemManager.getWithdrawalEventDetails(0);

            assertEq(we.height, 0);
            assertEq(we.size, amount);
            assertEq(we.ethAmount, amount);
        }

        uint32[] memory redeemRequestIds = redeemManager.listRedeemRequests(user);
        uint32[] memory withdrawEventIds = new uint32[](1);

        withdrawEventIds[0] = 0;

        assertEq(redeemRequestIds.length, 1);
        assertEq(address(redeemManager).balance, amount);
        assertEq(user.balance, 0);

        redeemManager.claimRedeemRequests(redeemRequestIds, withdrawEventIds, true);

        redeemRequestIds = redeemManager.listRedeemRequests(user);

        assertEq(redeemRequestIds.length, 0);
        assertEq(address(redeemManager).balance, amount - (amount / 2));
        assertEq(user.balance, amount / 2);

        {
            RedeemRequests.RedeemRequest memory rr = redeemManager.getRedeemRequestDetails(0);

            assertEq(rr.height, amount / 2);
            assertEq(rr.size, 0);
            assertEq(rr.owner, user);
        }

        {
            WithdrawalEvents.WithdrawalEvent memory we = redeemManager.getWithdrawalEventDetails(0);

            assertEq(we.height, 0);
            assertEq(we.size, amount);
            assertEq(we.ethAmount, amount);
        }
    }

    function testClaimRewardsRequestTwiceBigger(uint256 _salt) external {
        uint128 amount = uint128(bound(_salt, 2, type(uint128).max));

        address user = _generateAuthorizedUser(_salt);

        river.sudoDeal(user, uint256(amount));

        vm.prank(user);
        river.approve(address(redeemManager), uint256(amount));

        vm.prank(user);
        redeemManager.requestRedeem(amount, user);

        vm.deal(address(this), amount / 2);
        river.sudoReportWithdraw{value: amount / 2}(address(redeemManager), amount / 2);

        assertEq(redeemManager.getWithdrawalEventCount(), 1);
        assertEq(redeemManager.getRedeemRequestCount(), 1);

        {
            RedeemRequests.RedeemRequest memory rr = redeemManager.getRedeemRequestDetails(0);

            assertEq(rr.height, 0);
            assertEq(rr.size, amount);
            assertEq(rr.owner, user);
        }

        {
            WithdrawalEvents.WithdrawalEvent memory we = redeemManager.getWithdrawalEventDetails(0);

            assertEq(we.height, 0);
            assertEq(we.size, amount / 2);
            assertEq(we.ethAmount, amount / 2);
        }

        uint32[] memory redeemRequestIds = redeemManager.listRedeemRequests(user);
        uint32[] memory withdrawEventIds = new uint32[](1);

        withdrawEventIds[0] = 0;

        assertEq(redeemRequestIds.length, 1);
        assertEq(address(redeemManager).balance, amount / 2);
        assertEq(user.balance, 0);

        redeemManager.claimRedeemRequests(redeemRequestIds, withdrawEventIds, true);

        redeemRequestIds = redeemManager.listRedeemRequests(user);

        assertEq(redeemRequestIds.length, 1);
        assertEq(address(redeemManager).balance, 0);
        assertEq(user.balance, amount / 2);

        {
            RedeemRequests.RedeemRequest memory rr = redeemManager.getRedeemRequestDetails(0);

            assertEq(rr.height, amount / 2);
            assertEq(rr.size, amount - (amount / 2));
            assertEq(rr.owner, user);
        }

        {
            WithdrawalEvents.WithdrawalEvent memory we = redeemManager.getWithdrawalEventDetails(0);

            assertEq(we.height, 0);
            assertEq(we.size, amount / 2);
            assertEq(we.ethAmount, amount / 2);
        }
    }

    function testClaimRewardsRequestOnTwoEvents(uint256 _salt) external {
        uint128 amount = uint128(bound(_salt, 2, type(uint128).max));

        address user = _generateAuthorizedUser(_salt);

        river.sudoDeal(user, uint256(amount));

        vm.prank(user);
        river.approve(address(redeemManager), uint256(amount));

        vm.prank(user);
        redeemManager.requestRedeem(amount, user);

        vm.deal(address(this), amount / 2);
        river.sudoReportWithdraw{value: amount / 2}(address(redeemManager), amount / 2);

        vm.deal(address(this), amount - (amount / 2));
        river.sudoReportWithdraw{value: amount - (amount / 2)}(address(redeemManager), amount - (amount / 2));

        assertEq(redeemManager.getWithdrawalEventCount(), 2);
        assertEq(redeemManager.getRedeemRequestCount(), 1);

        {
            RedeemRequests.RedeemRequest memory rr = redeemManager.getRedeemRequestDetails(0);

            assertEq(rr.height, 0);
            assertEq(rr.size, amount);
            assertEq(rr.owner, user);
        }

        {
            WithdrawalEvents.WithdrawalEvent memory we = redeemManager.getWithdrawalEventDetails(0);

            assertEq(we.height, 0);
            assertEq(we.size, amount / 2);
            assertEq(we.ethAmount, amount / 2);
        }

        {
            WithdrawalEvents.WithdrawalEvent memory we = redeemManager.getWithdrawalEventDetails(1);

            assertEq(we.height, amount / 2);
            assertEq(we.size, amount - (amount / 2));
            assertEq(we.ethAmount, amount - (amount / 2));
        }

        uint32[] memory redeemRequestIds = redeemManager.listRedeemRequests(user);
        uint32[] memory withdrawEventIds = new uint32[](1);

        withdrawEventIds[0] = 0;

        assertEq(redeemRequestIds.length, 1);
        assertEq(address(redeemManager).balance, amount);
        assertEq(user.balance, 0);

        vm.expectEmit(true, true, true, true);
        emit FilledRedeemRequest(0, 0, amount / 2, amount / 2);
        vm.expectEmit(true, true, true, true);
        emit FilledRedeemRequest(0, 1, amount - (amount / 2), amount - (amount / 2));
        vm.expectEmit(true, true, true, true);
        emit SentRewards(user, amount);
        redeemManager.claimRedeemRequests(redeemRequestIds, withdrawEventIds, true);

        redeemRequestIds = redeemManager.listRedeemRequests(user);

        assertEq(redeemRequestIds.length, 0);
        assertEq(address(redeemManager).balance, 0);
        assertEq(user.balance, amount);

        {
            RedeemRequests.RedeemRequest memory rr = redeemManager.getRedeemRequestDetails(0);

            assertEq(rr.height, amount);
            assertEq(rr.size, 0);
            assertEq(rr.owner, user);
        }

        {
            WithdrawalEvents.WithdrawalEvent memory we = redeemManager.getWithdrawalEventDetails(0);

            assertEq(we.height, 0);
            assertEq(we.size, amount / 2);
            assertEq(we.ethAmount, amount / 2);
        }

        {
            WithdrawalEvents.WithdrawalEvent memory we = redeemManager.getWithdrawalEventDetails(1);

            assertEq(we.height, amount / 2);
            assertEq(we.size, amount - (amount / 2));
            assertEq(we.ethAmount, amount - (amount / 2));
        }
    }

    function testClaimRewardsTwoRequestsOnOneEvent(uint256 _salt) external {
        uint256 amount = uint128(bound(_salt, 2, type(uint120).max));

        address user = _generateAuthorizedUser(_salt);
        address userB;
        unchecked {
            userB = uf._new(_salt + 1);
        }

        river.sudoDeal(user, uint256(amount) * 2);

        vm.prank(user);
        river.approve(address(redeemManager), uint256(amount) * 2);

        vm.prank(user);
        redeemManager.requestRedeem(amount, user);

        vm.prank(user);
        redeemManager.requestRedeem(amount, userB);

        vm.deal(address(this), amount * 2);
        river.sudoReportWithdraw{value: amount * 2}(address(redeemManager), amount * 2);

        assertEq(redeemManager.getWithdrawalEventCount(), 1);
        assertEq(redeemManager.getRedeemRequestCount(), 2);

        {
            RedeemRequests.RedeemRequest memory rr = redeemManager.getRedeemRequestDetails(0);

            assertEq(rr.height, 0);
            assertEq(rr.size, amount);
            assertEq(rr.owner, user);
        }

        {
            RedeemRequests.RedeemRequest memory rr = redeemManager.getRedeemRequestDetails(1);

            assertEq(rr.height, amount);
            assertEq(rr.size, amount);
            assertEq(rr.owner, userB);
        }

        {
            WithdrawalEvents.WithdrawalEvent memory we = redeemManager.getWithdrawalEventDetails(0);

            assertEq(we.height, 0);
            assertEq(we.size, amount * 2);
            assertEq(we.ethAmount, amount * 2);
        }

        uint32[] memory redeemRequestIds = new uint32[](2);
        uint32[] memory withdrawEventIds = new uint32[](2);

        redeemRequestIds[0] = 1;
        redeemRequestIds[1] = 0;

        withdrawEventIds[0] = 0;
        withdrawEventIds[1] = 0;

        assertEq(redeemManager.listRedeemRequests(user).length, 1);
        assertEq(redeemManager.listRedeemRequests(userB).length, 1);
        assertEq(address(redeemManager).balance, amount * 2);
        assertEq(user.balance, 0);
        assertEq(userB.balance, 0);

        vm.expectEmit(true, true, true, true);
        emit FilledRedeemRequest(1, 0, amount, amount);
        vm.expectEmit(true, true, true, true);
        emit SentRewards(userB, amount);
        vm.expectEmit(true, true, true, true);
        emit FilledRedeemRequest(0, 0, amount, amount);
        vm.expectEmit(true, true, true, true);
        emit SentRewards(user, amount);
        redeemManager.claimRedeemRequests(redeemRequestIds, withdrawEventIds, true);

        assertEq(redeemManager.listRedeemRequests(user).length, 0);
        assertEq(redeemManager.listRedeemRequests(userB).length, 0);
        assertEq(address(redeemManager).balance, 0);
        assertEq(user.balance, amount);
        assertEq(userB.balance, amount);

        {
            RedeemRequests.RedeemRequest memory rr = redeemManager.getRedeemRequestDetails(0);

            assertEq(rr.height, amount);
            assertEq(rr.size, 0);
            assertEq(rr.owner, user);
        }

        {
            RedeemRequests.RedeemRequest memory rr = redeemManager.getRedeemRequestDetails(1);

            assertEq(rr.height, amount * 2);
            assertEq(rr.size, 0);
            assertEq(rr.owner, userB);
        }

        {
            WithdrawalEvents.WithdrawalEvent memory we = redeemManager.getWithdrawalEventDetails(0);

            assertEq(we.height, 0);
            assertEq(we.size, amount * 2);
            assertEq(we.ethAmount, amount * 2);
        }
    }

    function testClaimRewardsIncompatibleArrayLengths(uint256 _salt) external {
        uint128 amount = uint128(bound(_salt, 1, type(uint128).max));

        address user = _generateAuthorizedUser(_salt);

        river.sudoDeal(user, uint256(amount));

        vm.prank(user);
        river.approve(address(redeemManager), uint256(amount) * 2);

        vm.prank(user);
        redeemManager.requestRedeem(amount, user);

        vm.deal(address(this), amount);
        river.sudoReportWithdraw{value: amount}(address(redeemManager), amount);

        uint32[] memory redeemRequestIds = redeemManager.listRedeemRequests(user);
        uint32[] memory withdrawEventIds = new uint32[](0);

        vm.expectRevert(abi.encodeWithSignature("IncompatibleArrayLengths()"));
        redeemManager.claimRedeemRequests(redeemRequestIds, withdrawEventIds, true);
    }

    function testClaimRewardsRequestOutOfBounds(uint256 _salt) external {
        uint128 amount = uint128(bound(_salt, 1, type(uint128).max));

        vm.deal(address(this), amount);
        river.sudoReportWithdraw{value: amount}(address(redeemManager), amount);

        uint32[] memory redeemRequestIds = new uint32[](1);
        uint32[] memory withdrawEventIds = new uint32[](1);

        redeemRequestIds[0] = 0;
        withdrawEventIds[0] = 0;

        vm.expectRevert(abi.encodeWithSignature("RedeemRequestOutOfBounds(uint256)", 0));
        redeemManager.claimRedeemRequests(redeemRequestIds, withdrawEventIds, true);
    }

    function testClaimRewardsWithdrawalEventOutOfBounds(uint256 _salt) external {
        uint128 amount = uint128(bound(_salt, 1, type(uint128).max));

        address user = _generateAuthorizedUser(_salt);

        river.sudoDeal(user, uint256(amount));

        vm.prank(user);
        river.approve(address(redeemManager), uint256(amount) * 2);

        vm.prank(user);
        redeemManager.requestRedeem(amount, user);

        uint32[] memory redeemRequestIds = new uint32[](1);
        uint32[] memory withdrawEventIds = new uint32[](1);

        redeemRequestIds[0] = 0;
        withdrawEventIds[0] = 0;

        vm.expectRevert(abi.encodeWithSignature("WithdrawalEventOutOfBounds(uint256)", 0));
        redeemManager.claimRedeemRequests(redeemRequestIds, withdrawEventIds, true);
    }

    function testClaimRewardsRequestNotMatching(uint256 _salt) external {
        uint128 amount = uint128(bound(_salt, 1, type(uint128).max));

        address user = _generateAuthorizedUser(_salt);

        river.sudoDeal(user, uint256(amount) * 2);

        vm.prank(user);
        river.approve(address(redeemManager), uint256(amount) * 2);

        vm.prank(user);
        redeemManager.requestRedeem(amount, user);

        vm.prank(user);
        redeemManager.requestRedeem(amount, user);

        vm.deal(address(this), amount);
        river.sudoReportWithdraw{value: amount}(address(redeemManager), amount);

        uint32[] memory redeemRequestIds = new uint32[](1);
        uint32[] memory withdrawEventIds = new uint32[](1);

        redeemRequestIds[0] = 1;
        withdrawEventIds[0] = 0;

        vm.expectRevert(abi.encodeWithSignature("DoesNotMatch(uint256,uint256)", 1, 0));
        redeemManager.claimRedeemRequests(redeemRequestIds, withdrawEventIds, true);
    }

    function rollNext(uint256 _salt) internal pure returns (uint256) {
        return uint256(keccak256(abi.encode(_salt)));
    }

    function testFillingBothQueues(uint256 _salt) external {
        address user = _generateAuthorizedUser(_salt);
        _salt = rollNext(_salt);
        uint256 totalAmount = bound(_salt, 1, type(uint64).max);
        uint256 filled = 0;
        uint256 salt = _salt;
        while (filled < totalAmount) {
            salt = rollNext(salt);
            uint256 eventSize = bound(salt, 1, type(uint64).max / 100);
            if (filled + eventSize > totalAmount) {
                eventSize = totalAmount - filled;
            }
            filled += eventSize;
            vm.deal(address(this), eventSize);
            river.sudoReportWithdraw{value: eventSize}(address(redeemManager), eventSize);
        }

        filled = 0;

        while (filled < totalAmount) {
            salt = rollNext(salt);
            uint256 requestSize = bound(salt, 1, type(uint64).max / 500);

            if (filled + requestSize > totalAmount) {
                requestSize = totalAmount - filled;
            }
            filled += requestSize;

            river.sudoDeal(user, requestSize);

            vm.prank(user);
            river.approve(address(redeemManager), requestSize);

            vm.prank(user);
            redeemManager.requestRedeem(requestSize, user);
        }

        uint32[] memory redeemRequestIds = redeemManager.listRedeemRequests(user);
        int64[] memory withdrawalEventIds = redeemManager.resolveRedeemRequests(redeemRequestIds);
        uint32[] memory withdrawalEventIdsUint = new uint32[](withdrawalEventIds.length);

        for (uint256 idx = 0; idx < withdrawalEventIds.length;) {
            assertTrue(withdrawalEventIds[idx] >= 0, "unresolved requests");
            withdrawalEventIdsUint[idx] = uint32(uint64(withdrawalEventIds[idx]));
            console.log(redeemRequestIds[idx], uint32(uint64(withdrawalEventIds[idx])));
            unchecked {
                ++idx;
            }
        }

        assertEq(address(redeemManager).balance, totalAmount);
        assertEq(user.balance, 0);
        assertEq(redeemManager.listRedeemRequests(user).length, redeemManager.getRedeemRequestCount());

        redeemManager.claimRedeemRequests(redeemRequestIds, withdrawalEventIdsUint, false);

        assertEq(address(redeemManager).balance, 0);
        assertEq(user.balance, totalAmount);
        assertEq(redeemManager.listRedeemRequests(user).length, 0);

        withdrawalEventIds = redeemManager.resolveRedeemRequests(redeemRequestIds);

        for (uint256 idx = 0; idx < withdrawalEventIds.length;) {
            assertTrue(withdrawalEventIds[idx] == -3);
            unchecked {
                ++idx;
            }
        }
    }

    function testResolveOutOfBounds() external {
        uint32[] memory redeemRequestIds = new uint32[](1);
        int64[] memory withdrawalEventIds = redeemManager.resolveRedeemRequests(redeemRequestIds);
        assertEq(withdrawalEventIds.length, 1);
        assertTrue(withdrawalEventIds[0] == -2);
    }

    function testResolveUnsatisfied(uint256 _salt) external {
        uint128 amount = uint128(bound(_salt, 1, type(uint128).max));
        address user = _generateAuthorizedUser(_salt);

        river.sudoDeal(user, uint256(amount) * 2);

        vm.prank(user);
        river.approve(address(redeemManager), uint256(amount) * 2);

        vm.prank(user);
        redeemManager.requestRedeem(amount, user);

        uint32[] memory redeemRequestIds = new uint32[](1);
        redeemRequestIds[0] = 0;

        int64[] memory withdrawalEventIds = redeemManager.resolveRedeemRequests(redeemRequestIds);
        assertEq(withdrawalEventIds.length, 1);
        assertTrue(withdrawalEventIds[0] == -1);
    }
}
