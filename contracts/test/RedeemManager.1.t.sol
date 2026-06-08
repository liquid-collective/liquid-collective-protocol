//SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.34;

import "forge-std/Test.sol";

import "./utils/UserFactory.sol";
import "./utils/LibImplementationUnbricker.sol";

import "../src/state/shared/RiverAddress.sol";
import "../src/state/redeemManager/RedeemDemand.sol";
import "../src/state/redeemManager/RedeemQueue.1.sol";
import "../src/state/redeemManager/RedeemQueue.2.sol";

import "../src/state/redeemManager/WithdrawalStack.sol";
import "../src/state/redeemManager/MaxRedeemableETHLockedStack.sol";
import "../src/state/redeemManager/NextLockHeight.sol";
import "../src/RedeemManager.1.sol";
import "../src/TUPProxy.sol";
import "../src/Initializable.sol";
import "../src/Allowlist.1.sol";
import "./mocks/RejectEtherMock.sol";
import "./mocks/ReentrancyClaimAttackMock.sol";

contract RiverMock {
    mapping(address => uint256) internal balances;
    mapping(address => mapping(address => uint256)) internal approvals;
    address internal allowlist;
    uint256 internal rate = 1e18;
    uint256 internal _totalSupply;

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

    function balanceOf(address account) external view returns (uint256) {
        return balances[account];
    }

    /// @notice Sets the balance of the given account and updates totalSupply
    /// @param account The account to set the balance of
    /// @param amount Amount to set as balance
    function sudoDeal(address account, uint256 amount) external {
        if (amount > balances[account]) {
            _totalSupply += amount - balances[account];
        } else {
            _totalSupply -= balances[account] - amount;
        }
        balances[account] = amount;
    }

    function sudoSetRate(uint256 newRate) external {
        rate = newRate;
    }

    function getAllowlist() external view returns (address) {
        return allowlist;
    }

    function sudoReportWithdraw(address redeemManager, uint256 lsETHAmount) external payable {
        RedeemManagerV1(redeemManager).reportWithdraw{value: msg.value}(lsETHAmount);
    }

    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    function totalUnderlyingSupply() external view returns (uint256) {
        return (_totalSupply * rate) / 1e18;
    }

    function underlyingBalanceFromShares(uint256 shares) external view returns (uint256) {
        return (shares * rate) / 1e18;
    }

    function pullExceedingEth(address redeemManager, uint256 amount) external {
        RedeemManagerV1(redeemManager).pullExceedingEth(amount);
    }

    bool internal _slashingContainmentMode;

    function getSlashingContainmentMode() external view returns (bool) {
        return _slashingContainmentMode;
    }

    function sudoSetSlashingContainmentMode(bool _enabled) external {
        _slashingContainmentMode = _enabled;
    }

    fallback() external payable {}
}

contract RedeeManagerV1TestBase is Test {
    AllowlistV1 internal allowlist;
    RiverMock internal river;
    UserFactory internal uf = new UserFactory();
    address internal allowlistAdmin;
    address internal allowlistAllower;
    address internal allowlistDenier;
    address public mockRiverAddress;
    bytes32 internal constant REDEEM_QUEUE_ID_SLOT = bytes32(uint256(keccak256("river.state.redeemQueue")) - 1);

    event RequestedRedeem(address indexed recipient, uint256 height, uint256 size, uint256 maxRedeemableEth, uint32 id);
    event ReportedWithdrawal(uint256 height, uint256 size, uint256 ethAmount, uint32 id);
    event SatisfiedRedeemRequest(
        uint32 indexed redeemRequestId,
        uint32 indexed withdrawalEventId,
        uint256 lsEthAmountSatisfied,
        uint256 ethAmountSatisfied,
        uint256 lsEthAmountRemaining,
        uint256 ethAmountExceeding
    );

    event ClaimedRedeemRequest(
        uint32 indexed redeemRequestId,
        address indexed recipient,
        uint256 ethAmount,
        uint256 lsEthAmount,
        uint256 remainingLsEthAmount
    );
}

contract RedeemManagerV1Tests is RedeeManagerV1TestBase {
    RedeemManagerV1 internal redeemManager;

    function setUp() external {
        allowlistAdmin = makeAddr("allowlistAdmin");
        allowlistAllower = makeAddr("allowlistAllower");
        allowlistDenier = makeAddr("allowlistDenier");
        redeemManager = new RedeemManagerV1();
        LibImplementationUnbricker.unbrick(vm, address(redeemManager));
        allowlist = new AllowlistV1();
        LibImplementationUnbricker.unbrick(vm, address(allowlist));
        allowlist.initAllowlistV1(allowlistAdmin, allowlistAllower);
        allowlist.initAllowlistV1_1(allowlistDenier);
        river = new RiverMock(address(allowlist));

        redeemManager.initializeRedeemManagerV1(address(river));
    }

    // allowlist a user
    function _allowlistUser(address user) internal {
        address[] memory accounts = new address[](1);
        accounts[0] = user;
        uint256[] memory permissions = new uint256[](1);
        permissions[0] = LibAllowlistMasks.REDEEM_MASK | LibAllowlistMasks.DEPOSIT_MASK;

        vm.prank(allowlistAllower);
        allowlist.setAllowPermissions(accounts, permissions);
    }

    function _generateAllowlistedUser(uint256 _salt) internal returns (address) {
        address user = uf._new(_salt);
        _allowlistUser(user);
        return user;
    }

    function _denyUser(address user) internal {
        address[] memory accounts = new address[](1);
        accounts[0] = user;
        uint256[] memory permissions = new uint256[](1);
        permissions[0] = LibAllowlistMasks.DENY_MASK;

        vm.prank(allowlistDenier);
        allowlist.setDenyPermissions(accounts, permissions);
    }

    function _unDenyUser(address user) internal {
        address[] memory accounts = new address[](1);
        accounts[0] = user;
        uint256[] memory permissions = new uint256[](1);
        permissions[0] = 0;

        vm.prank(allowlistDenier);
        allowlist.setDenyPermissions(accounts, permissions);
    }

    function testGetRiver() public view {
        assert(redeemManager.getRiver() == address(river));
    }

    function testRequestRedeem(uint256 _salt) external {
        address user = _generateAllowlistedUser(_salt);

        uint128 amount = uint128(bound(_salt, 1, type(uint128).max));

        river.sudoDeal(user, amount);

        vm.prank(user);
        river.approve(address(redeemManager), amount);

        assertEq(river.balanceOf(user), amount);

        vm.prank(user);
        vm.expectEmit(true, true, true, true);
        emit RequestedRedeem(user, 0, amount, amount, 0);
        redeemManager.requestRedeem(amount, user);

        uint32[] memory requests = new uint32[](1);
        requests[0] = 0;

        assertEq(requests[0], 0);

        {
            RedeemQueueV2.RedeemRequest memory rr = redeemManager.getRedeemRequestDetails(0);

            assertEq(rr.height, 0);
            assertEq(rr.amount, amount);
            assertEq(rr.recipient, user);
            assertEq(rr.maxRedeemableEth, amount);
        }

        assertEq(river.balanceOf(user), 0);
        assertEq(redeemManager.getRedeemRequestCount(), 1);
    }

    function testRequestRedeemImplicitRecipient(uint256 _salt) external {
        address user = _generateAllowlistedUser(_salt);

        uint128 amount = uint128(bound(_salt, 1, type(uint128).max));

        river.sudoDeal(user, amount);

        vm.prank(user);
        river.approve(address(redeemManager), amount);

        assertEq(river.balanceOf(user), amount);

        vm.prank(user);
        vm.expectEmit(true, true, true, true);
        emit RequestedRedeem(user, 0, amount, amount, 0);
        redeemManager.requestRedeem(amount);

        uint32[] memory requests = new uint32[](1);
        requests[0] = 0;

        assertEq(requests[0], 0);

        {
            RedeemQueueV2.RedeemRequest memory rr = redeemManager.getRedeemRequestDetails(0);

            assertEq(rr.height, 0);
            assertEq(rr.amount, amount);
            assertEq(rr.recipient, user);
            assertEq(rr.maxRedeemableEth, amount);
        }

        assertEq(river.balanceOf(user), 0);
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

    function testRequestRedeemWithAuthorizedRecipient(uint256 _salt, uint256 _salt2) external {
        vm.assume(_salt != _salt2);
        address user = _generateAllowlistedUser(_salt);
        address recipient = uf._new(_salt2);

        uint128 amount = uint128(bound(_salt, 1, type(uint128).max));

        river.sudoDeal(user, amount);

        vm.prank(user);
        river.approve(address(redeemManager), amount);

        assertEq(river.balanceOf(user), amount);

        vm.prank(user);
        vm.expectEmit(true, true, true, true);
        emit RequestedRedeem(recipient, 0, amount, amount, 0);
        redeemManager.requestRedeem(amount, recipient);

        uint32[] memory requests = new uint32[](1);
        requests[0] = 0;

        assertEq(requests[0], 0);

        {
            RedeemQueueV2.RedeemRequest memory rr = redeemManager.getRedeemRequestDetails(0);

            assertEq(rr.height, 0);
            assertEq(rr.amount, amount);
            assertEq(rr.recipient, recipient);
            assertEq(rr.maxRedeemableEth, amount);
        }

        assertEq(river.balanceOf(user), 0);
        assertEq(redeemManager.getRedeemRequestCount(), 1);
    }

    function testRequestRedeemUnauthorizedRecipient(uint256 _salt, uint256 _salt2) external {
        vm.assume(_salt != _salt2);
        address user = _generateAllowlistedUser(_salt);
        address recipient = uf._new(_salt2);
        uint128 amount = uint128(bound(_salt, 1, type(uint128).max));

        _denyUser(recipient);

        vm.prank(user);
        vm.expectRevert(abi.encodeWithSignature("RecipientIsDenied()"));
        redeemManager.requestRedeem(amount, recipient);
    }

    function testRequestRedeemMultiple(uint256 _salt) external {
        address user0 = _generateAllowlistedUser(_salt);
        address user1 = _generateAllowlistedUser(uint256(keccak256(abi.encode(_salt))));

        uint64 amount0 = uint64(bound(_salt, 1, type(uint64).max));
        uint64 amount1 = uint64(bound(uint256(keccak256(abi.encode(_salt))), 1, type(uint64).max));

        river.sudoDeal(user0, uint256(amount0));
        river.sudoDeal(user1, uint256(amount1));

        vm.prank(user0);
        river.approve(address(redeemManager), uint256(amount0));

        vm.prank(user1);
        river.approve(address(redeemManager), uint256(amount1));

        assertEq(river.balanceOf(user0), amount0);
        assertEq(river.balanceOf(user1), amount1);

        vm.prank(user0);
        redeemManager.requestRedeem(amount0, user0);

        vm.prank(user1);
        redeemManager.requestRedeem(amount1, user1);

        assertEq(river.balanceOf(user0), 0);
        assertEq(river.balanceOf(user1), 0);

        uint32[] memory requests = new uint32[](2);
        requests[0] = 0;
        requests[1] = 1;

        assertEq(requests[0], 0);
        assertEq(requests[1], 1);

        {
            RedeemQueueV2.RedeemRequest memory rr = redeemManager.getRedeemRequestDetails(0);

            assertEq(rr.height, 0);
            assertEq(rr.amount, amount0);
            assertEq(rr.recipient, user0);
        }

        {
            RedeemQueueV2.RedeemRequest memory rr = redeemManager.getRedeemRequestDetails(1);

            assertEq(rr.height, amount0);
            assertEq(rr.amount, amount1);
            assertEq(rr.recipient, user1);
        }

        assertEq(redeemManager.getRedeemRequestCount(), 2);
    }

    function testRequestRedeemAmountZero(uint256 _salt) external {
        address user = _generateAllowlistedUser(_salt);

        vm.prank(user);
        vm.expectRevert(abi.encodeWithSignature("InvalidZeroAmount()"));
        redeemManager.requestRedeem(0, user);

        assertEq(redeemManager.getRedeemRequestCount(), 0);
    }

    function testRequestRedeemApproveTooLow(uint256 _salt) external {
        address user = _generateAllowlistedUser(_salt);

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
        address user = _generateAllowlistedUser(_salt);

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
        address user = _generateAllowlistedUser(_salt);

        river.sudoDeal(user, amount);

        vm.prank(user);
        river.approve(address(redeemManager), amount);

        vm.prank(user);
        redeemManager.requestRedeem(amount, user);

        vm.deal(address(this), amount);

        vm.expectEmit(true, true, true, true);
        emit ReportedWithdrawal(0, amount, amount, 0);
        river.sudoReportWithdraw{value: amount}(address(redeemManager), amount);

        assertEq(address(redeemManager).balance, amount);
        assertEq(redeemManager.getWithdrawalEventCount(), 1);

        {
            WithdrawalStack.WithdrawalEvent memory we = redeemManager.getWithdrawalEventDetails(0);

            assertEq(we.height, 0);
            assertEq(we.amount, amount);
            assertEq(we.withdrawnEth, amount);
        }
    }

    function testReportWithdrawFail(uint256 _salt) external {
        uint128 amount = uint128(bound(_salt, 1, type(uint128).max));
        address user = _generateAllowlistedUser(_salt);

        river.sudoDeal(user, amount);

        vm.prank(user);
        river.approve(address(redeemManager), amount);

        vm.prank(user);
        redeemManager.requestRedeem(amount, user);

        vm.deal(address(this), amount);

        vm.expectRevert(
            abi.encodeWithSignature(
                "WithdrawalExceedsRedeemDemand(uint256,uint256)", uint256(amount) + 1e18, uint256(amount)
            )
        );
        river.sudoReportWithdraw{value: amount}(address(redeemManager), uint256(amount) + 1e18);
    }

    function testRequestRedeemFailNotRiver(uint256 _salt) external {
        uint128 amount = uint128(bound(_salt, 1, type(uint128).max));
        address user = _generateAllowlistedUser(_salt);

        vm.prank(user);
        river.approve(address(redeemManager), amount);

        vm.prank(user);
        vm.expectRevert(abi.encodeWithSignature("Unauthorized(address)", user));
        redeemManager.requestRedeem(amount, user, user);
    }

    function testReportWithdrawMultiple(uint256 _salt) external {
        uint128 amount = uint128(bound(_salt, 1, type(uint128).max));
        address user = _generateAllowlistedUser(_salt);

        river.sudoDeal(user, uint256(amount) * 2);

        vm.prank(user);
        river.approve(address(redeemManager), uint256(amount) * 2);

        vm.prank(user);
        redeemManager.requestRedeem(uint256(amount) * 2, user);

        vm.deal(address(this), amount);

        vm.expectEmit(true, true, true, true);
        emit ReportedWithdrawal(0, amount, amount, 0);
        river.sudoReportWithdraw{value: amount}(address(redeemManager), amount);

        vm.deal(address(this), amount);

        vm.expectEmit(true, true, true, true);
        emit ReportedWithdrawal(amount, amount, amount, 1);
        river.sudoReportWithdraw{value: amount}(address(redeemManager), amount);

        assertEq(redeemManager.getWithdrawalEventCount(), 2);
        assertEq(address(redeemManager).balance, uint256(amount) * 2);

        {
            WithdrawalStack.WithdrawalEvent memory we = redeemManager.getWithdrawalEventDetails(0);

            assertEq(we.height, 0);
            assertEq(we.amount, amount);
            assertEq(we.withdrawnEth, amount);
        }

        {
            WithdrawalStack.WithdrawalEvent memory we = redeemManager.getWithdrawalEventDetails(1);

            assertEq(we.height, amount);
            assertEq(we.amount, amount);
            assertEq(we.withdrawnEth, amount);
        }
    }

    function testClaimRedeemRequest(uint256 _salt) external {
        uint128 amount = uint128(bound(_salt, 1, type(uint128).max));

        address user = _generateAllowlistedUser(_salt);

        river.sudoDeal(user, uint256(amount));

        vm.prank(user);
        river.approve(address(redeemManager), uint256(amount));

        vm.prank(user);
        redeemManager.requestRedeem(amount, user);

        vm.deal(address(this), amount);
        river.sudoReportWithdraw{value: amount}(address(redeemManager), amount);

        assertEq(redeemManager.getWithdrawalEventCount(), 1);
        assertEq(redeemManager.getRedeemRequestCount(), 1);

        {
            RedeemQueueV2.RedeemRequest memory rr = redeemManager.getRedeemRequestDetails(0);

            assertEq(rr.height, 0);
            assertEq(rr.amount, amount);
            assertEq(rr.recipient, user);
        }

        {
            WithdrawalStack.WithdrawalEvent memory we = redeemManager.getWithdrawalEventDetails(0);

            assertEq(we.height, 0);
            assertEq(we.amount, amount);
            assertEq(we.withdrawnEth, amount);
        }

        uint32[] memory redeemRequestIds = new uint32[](1);
        uint32[] memory withdrawEventIds = new uint32[](1);

        redeemRequestIds[0] = 0;
        withdrawEventIds[0] = 0;

        assertEq(address(redeemManager).balance, amount);
        assertEq(user.balance, 0);

        int64[] memory resolvedRedeemRequests = redeemManager.resolveRedeemRequests(redeemRequestIds);

        assertEq(resolvedRedeemRequests.length, 1);
        assertEq(resolvedRedeemRequests[0], 0);

        vm.expectEmit(true, true, true, true);
        emit SatisfiedRedeemRequest(0, 0, amount, amount, 0, 0);
        vm.expectEmit(true, true, true, true);
        emit ClaimedRedeemRequest(0, user, amount, amount, 0);
        redeemManager.claimRedeemRequests(redeemRequestIds, withdrawEventIds, true, type(uint16).max);

        assertEq(redeemManager.getBufferedExceedingEth(), 0);
        assertEq(address(redeemManager).balance, 0);
        assertEq(user.balance, amount);

        resolvedRedeemRequests = redeemManager.resolveRedeemRequests(redeemRequestIds);

        assertEq(resolvedRedeemRequests.length, 1);
        assertEq(resolvedRedeemRequests[0], -3);

        {
            RedeemQueueV2.RedeemRequest memory rr = redeemManager.getRedeemRequestDetails(0);

            assertEq(rr.height, amount);
            assertEq(rr.amount, 0);
            assertEq(rr.recipient, user);
        }

        {
            WithdrawalStack.WithdrawalEvent memory we = redeemManager.getWithdrawalEventDetails(0);

            assertEq(we.height, 0);
            assertEq(we.amount, amount);
            assertEq(we.withdrawnEth, amount);
        }
    }

    function testClaimRedeemRequestWithImplicitSkipFlag(uint256 _salt) external {
        uint128 amount = uint128(bound(_salt, 1, type(uint128).max));

        address user = _generateAllowlistedUser(_salt);

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
            RedeemQueueV2.RedeemRequest memory rr = redeemManager.getRedeemRequestDetails(0);

            assertEq(rr.height, 0);
            assertEq(rr.amount, amount);
            assertEq(rr.recipient, user);
        }

        {
            WithdrawalStack.WithdrawalEvent memory we = redeemManager.getWithdrawalEventDetails(0);

            assertEq(we.height, 0);
            assertEq(we.amount, amount);
            assertEq(we.withdrawnEth, amount);
        }

        uint32[] memory redeemRequestIds = new uint32[](1);
        uint32[] memory withdrawEventIds = new uint32[](1);

        redeemRequestIds[0] = 0;
        withdrawEventIds[0] = 0;

        int64[] memory resolvedRedeemRequests = redeemManager.resolveRedeemRequests(redeemRequestIds);

        assertEq(resolvedRedeemRequests.length, 1);
        assertEq(resolvedRedeemRequests[0], 0);

        assertEq(address(redeemManager).balance, amount);
        assertEq(user.balance, 0);

        vm.expectEmit(true, true, true, true);
        emit SatisfiedRedeemRequest(0, 0, amount, amount, 0, 0);
        vm.expectEmit(true, true, true, true);
        emit ClaimedRedeemRequest(0, user, amount, amount, 0);
        redeemManager.claimRedeemRequests(redeemRequestIds, withdrawEventIds);

        assertEq(address(redeemManager).balance, 0);
        assertEq(user.balance, amount);

        resolvedRedeemRequests = redeemManager.resolveRedeemRequests(redeemRequestIds);

        assertEq(resolvedRedeemRequests.length, 1);
        assertEq(resolvedRedeemRequests[0], -3);

        {
            RedeemQueueV2.RedeemRequest memory rr = redeemManager.getRedeemRequestDetails(0);

            assertEq(rr.height, amount);
            assertEq(rr.amount, 0);
            assertEq(rr.recipient, user);
        }

        {
            WithdrawalStack.WithdrawalEvent memory we = redeemManager.getWithdrawalEventDetails(0);

            assertEq(we.height, 0);
            assertEq(we.amount, amount);
            assertEq(we.withdrawnEth, amount);
        }
    }

    function testClaimRedeemRequestTwiceWithSkipFlag(uint256 _salt) external {
        uint128 amount = uint128(bound(_salt, 1, type(uint128).max));

        address user = _generateAllowlistedUser(_salt);

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
            RedeemQueueV2.RedeemRequest memory rr = redeemManager.getRedeemRequestDetails(0);

            assertEq(rr.height, 0);
            assertEq(rr.amount, amount);
            assertEq(rr.recipient, user);
        }

        {
            WithdrawalStack.WithdrawalEvent memory we = redeemManager.getWithdrawalEventDetails(0);

            assertEq(we.height, 0);
            assertEq(we.amount, amount);
            assertEq(we.withdrawnEth, amount);
        }

        uint32[] memory redeemRequestIds = new uint32[](1);
        uint32[] memory withdrawEventIds = new uint32[](1);

        redeemRequestIds[0] = 0;
        withdrawEventIds[0] = 0;

        int64[] memory resolvedRedeemRequests = redeemManager.resolveRedeemRequests(redeemRequestIds);

        assertEq(resolvedRedeemRequests.length, 1);
        assertEq(resolvedRedeemRequests[0], 0);

        assertEq(address(redeemManager).balance, amount);
        assertEq(user.balance, 0);

        vm.expectEmit(true, true, true, true);
        emit SatisfiedRedeemRequest(0, 0, amount, amount, 0, 0);
        vm.expectEmit(true, true, true, true);
        emit ClaimedRedeemRequest(0, user, amount, amount, 0);
        uint8[] memory claimStatus =
            redeemManager.claimRedeemRequests(redeemRequestIds, withdrawEventIds, true, type(uint16).max);

        assertEq(address(redeemManager).balance, 0);
        assertEq(user.balance, amount);

        assertEq(claimStatus.length, 1);
        assertEq(claimStatus[0], 0);

        resolvedRedeemRequests = redeemManager.resolveRedeemRequests(redeemRequestIds);

        assertEq(resolvedRedeemRequests.length, 1);
        assertEq(resolvedRedeemRequests[0], -3);

        claimStatus = redeemManager.claimRedeemRequests(redeemRequestIds, withdrawEventIds, true, type(uint16).max);

        assertEq(claimStatus.length, 1);
        assertEq(claimStatus[0], 2);

        resolvedRedeemRequests = redeemManager.resolveRedeemRequests(redeemRequestIds);

        assertEq(resolvedRedeemRequests.length, 1);
        assertEq(resolvedRedeemRequests[0], -3);

        {
            RedeemQueueV2.RedeemRequest memory rr = redeemManager.getRedeemRequestDetails(0);

            assertEq(rr.height, amount);
            assertEq(rr.amount, 0);
            assertEq(rr.recipient, user);
        }

        {
            WithdrawalStack.WithdrawalEvent memory we = redeemManager.getWithdrawalEventDetails(0);

            assertEq(we.height, 0);
            assertEq(we.amount, amount);
            assertEq(we.withdrawnEth, amount);
        }
    }

    function testClaimRedeemRequestTwiceWithoutSkipFlag(uint256 _salt) external {
        uint128 amount = uint128(bound(_salt, 1, type(uint128).max));

        address user = _generateAllowlistedUser(_salt);

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
        redeemManager.claimRedeemRequests(redeemRequestIds, withdrawEventIds, false, type(uint16).max);
    }

    // Tests that when the first item in claimRedeemRequests is already claimed and triggers
    // the continue statement, subsequent items are still processed correctly.
    // This verifies the loop advances properly after continue in a for(;;++idx) loop.
    function testClaimRedeemRequestsSkipDoesNotBreakSubsequentClaims(uint256 _salt) external {
        // Bound salt to avoid overflow when adding 1
        _salt = bound(_salt, 0, type(uint256).max - 1);
        uint128 amount = uint128(bound(_salt, 1, type(uint128).max / 2));

        // Create two users with redeem requests
        address user0 = _generateAllowlistedUser(_salt);
        address user1 = _generateAllowlistedUser(_salt + 1);

        // Give both users tokens and create redeem requests
        river.sudoDeal(user0, uint256(amount));
        river.sudoDeal(user1, uint256(amount));

        vm.prank(user0);
        river.approve(address(redeemManager), uint256(amount));
        vm.prank(user1);
        river.approve(address(redeemManager), uint256(amount));

        vm.prank(user0);
        redeemManager.requestRedeem(amount, user0); // request 0
        vm.prank(user1);
        redeemManager.requestRedeem(amount, user1); // request 1

        // Report enough withdrawal to cover both requests
        vm.deal(address(this), uint256(amount) * 2);
        river.sudoReportWithdraw{value: uint256(amount) * 2}(address(redeemManager), uint256(amount) * 2);

        assertEq(redeemManager.getWithdrawalEventCount(), 1);
        assertEq(redeemManager.getRedeemRequestCount(), 2);

        // First: claim only request 0
        {
            uint32[] memory ids = new uint32[](1);
            uint32[] memory events = new uint32[](1);
            ids[0] = 0;
            events[0] = 0;

            uint8[] memory statuses = redeemManager.claimRedeemRequests(ids, events, true, type(uint16).max);
            assertEq(statuses.length, 1);
            assertEq(statuses[0], 0); // CLAIM_FULLY_CLAIMED
        }

        // Verify request 0 is now claimed (amount == 0)
        {
            RedeemQueueV2.RedeemRequest memory rr = redeemManager.getRedeemRequestDetails(0);
            assertEq(rr.amount, 0, "Request 0 should be fully claimed");
        }

        // Now claim [0, 1] with skipAlreadyClaimed=true
        // Request 0 triggers continue (already claimed), request 1 should still be processed
        uint32[] memory redeemRequestIds = new uint32[](2);
        uint32[] memory withdrawEventIds = new uint32[](2);
        redeemRequestIds[0] = 0; // already claimed - will trigger continue
        redeemRequestIds[1] = 1; // fresh - should still be processed
        withdrawEventIds[0] = 0;
        withdrawEventIds[1] = 0;

        uint256 user0BalanceBefore = user0.balance;
        uint256 user1BalanceBefore = user1.balance;

        uint8[] memory claimStatuses =
            redeemManager.claimRedeemRequests(redeemRequestIds, withdrawEventIds, true, type(uint16).max);

        // Verify the return values
        assertEq(claimStatuses.length, 2, "Should return 2 statuses");
        assertEq(claimStatuses[0], 2, "Request 0 should be CLAIM_SKIPPED (2)");
        assertEq(claimStatuses[1], 0, "Request 1 should be CLAIM_FULLY_CLAIMED (0)");

        // Verify user1 received their funds (proves loop continued after the skip)
        assertEq(user0.balance, user0BalanceBefore, "User0 balance should not change (already claimed before)");
        assertEq(user1.balance, user1BalanceBefore + amount, "User1 should receive their redemption");

        // Verify request 1 is now claimed
        {
            RedeemQueueV2.RedeemRequest memory rr = redeemManager.getRedeemRequestDetails(1);
            assertEq(rr.amount, 0, "Request 1 should be fully claimed");
        }
    }

    function testClaimRedeemRequestTwiceBigger(uint256 _salt) external {
        uint128 amount = uint128(bound(_salt, 2, type(uint128).max));

        address user = _generateAllowlistedUser(_salt);

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
            RedeemQueueV2.RedeemRequest memory rr = redeemManager.getRedeemRequestDetails(0);

            assertEq(rr.height, 0);
            assertEq(rr.amount, amount);
            assertEq(rr.recipient, user);
        }

        {
            WithdrawalStack.WithdrawalEvent memory we = redeemManager.getWithdrawalEventDetails(0);

            assertEq(we.height, 0);
            assertEq(we.amount, amount / 2);
            assertEq(we.withdrawnEth, amount / 2);
        }

        uint32[] memory redeemRequestIds = new uint32[](1);
        uint32[] memory withdrawEventIds = new uint32[](1);

        redeemRequestIds[0] = 0;
        withdrawEventIds[0] = 0;

        int64[] memory resolvedRedeemRequests = redeemManager.resolveRedeemRequests(redeemRequestIds);

        assertEq(resolvedRedeemRequests.length, 1);
        assertEq(resolvedRedeemRequests[0], 0);

        assertEq(address(redeemManager).balance, amount / 2);
        assertEq(user.balance, 0);

        vm.expectEmit(true, true, true, true);
        emit SatisfiedRedeemRequest(0, 0, amount / 2, amount / 2, amount - (amount / 2), 0);
        vm.expectEmit(true, true, true, true);
        emit ClaimedRedeemRequest(0, user, amount / 2, amount / 2, amount - (amount / 2));
        uint8[] memory claimStatuses =
            redeemManager.claimRedeemRequests(redeemRequestIds, withdrawEventIds, true, type(uint16).max);

        assertEq(address(redeemManager).balance, 0);
        assertEq(user.balance, amount / 2);
        assertEq(claimStatuses.length, 1);
        assertEq(claimStatuses[0], 1);

        resolvedRedeemRequests = redeemManager.resolveRedeemRequests(redeemRequestIds);

        assertEq(resolvedRedeemRequests.length, 1);
        assertEq(resolvedRedeemRequests[0], -1);

        {
            RedeemQueueV2.RedeemRequest memory rr = redeemManager.getRedeemRequestDetails(0);

            assertEq(rr.height, amount / 2);
            assertEq(rr.amount, amount - (amount / 2));
            assertEq(rr.recipient, user);
        }

        {
            WithdrawalStack.WithdrawalEvent memory we = redeemManager.getWithdrawalEventDetails(0);

            assertEq(we.height, 0);
            assertEq(we.amount, amount / 2);
            assertEq(we.withdrawnEth, amount / 2);
        }
    }

    function testClaimRedeemRequestOnMultipleEventsCustomDepths(uint256 _salt) external {
        uint128 amount = uint128(bound(_salt, 10, type(uint128).max / 10));
        amount *= 10;

        address user = _generateAllowlistedUser(_salt);

        river.sudoDeal(user, uint256(amount));

        vm.prank(user);
        river.approve(address(redeemManager), uint256(amount));

        vm.prank(user);
        redeemManager.requestRedeem(amount, user);

        vm.deal(address(this), amount);
        river.sudoReportWithdraw{value: amount / 10}(address(redeemManager), amount / 10);
        river.sudoReportWithdraw{value: amount / 10}(address(redeemManager), amount / 10);
        river.sudoReportWithdraw{value: amount / 10}(address(redeemManager), amount / 10);
        river.sudoReportWithdraw{value: amount / 10}(address(redeemManager), amount / 10);
        river.sudoReportWithdraw{value: amount / 10}(address(redeemManager), amount / 10);
        river.sudoReportWithdraw{value: amount / 10}(address(redeemManager), amount / 10);
        river.sudoReportWithdraw{value: amount / 10}(address(redeemManager), amount / 10);
        river.sudoReportWithdraw{value: amount / 10}(address(redeemManager), amount / 10);
        river.sudoReportWithdraw{value: amount / 10}(address(redeemManager), amount / 10);
        river.sudoReportWithdraw{value: amount / 10}(address(redeemManager), amount / 10);

        assertEq(redeemManager.getWithdrawalEventCount(), 10);
        assertEq(redeemManager.getRedeemRequestCount(), 1);

        uint32[] memory redeemRequestIds = new uint32[](1);
        uint32[] memory withdrawEventIds = new uint32[](1);

        withdrawEventIds[0] = 0;
        redeemRequestIds[0] = 0;

        assertEq(address(redeemManager).balance, amount);
        assertEq(user.balance, 0);

        uint256 remaining = amount - (amount / 10);

        vm.expectEmit(true, true, true, true);
        emit SatisfiedRedeemRequest(0, 0, amount / 10, amount / 10, remaining, 0);
        vm.expectEmit(true, true, true, true);
        emit ClaimedRedeemRequest(0, user, amount / 10, amount / 10, remaining);
        redeemManager.claimRedeemRequests(redeemRequestIds, withdrawEventIds, true, 0);

        RedeemQueueV2.RedeemRequest memory redeemRequest = redeemManager.getRedeemRequestDetails(0);
        assertEq(redeemRequest.height, amount - remaining);
        assertEq(redeemRequest.amount, remaining);

        withdrawEventIds[0] = 1;

        remaining -= (amount / 10);
        vm.expectEmit(true, true, true, true);
        emit SatisfiedRedeemRequest(0, 1, amount / 10, amount / 10, remaining, 0);
        remaining -= (amount / 10);
        vm.expectEmit(true, true, true, true);
        emit SatisfiedRedeemRequest(0, 2, amount / 10, amount / 10, remaining, 0);
        vm.expectEmit(true, true, true, true);
        emit ClaimedRedeemRequest(0, user, 2 * (amount / 10), 2 * (amount / 10), remaining);
        redeemManager.claimRedeemRequests(redeemRequestIds, withdrawEventIds, true, 1);

        redeemRequest = redeemManager.getRedeemRequestDetails(0);
        assertEq(redeemRequest.height, amount - remaining);
        assertEq(redeemRequest.amount, remaining);

        withdrawEventIds[0] = 3;

        remaining -= (amount / 10);
        vm.expectEmit(true, true, true, true);
        emit SatisfiedRedeemRequest(0, 3, amount / 10, amount / 10, remaining, 0);
        remaining -= (amount / 10);
        vm.expectEmit(true, true, true, true);
        emit SatisfiedRedeemRequest(0, 4, amount / 10, amount / 10, remaining, 0);
        remaining -= (amount / 10);
        vm.expectEmit(true, true, true, true);
        emit SatisfiedRedeemRequest(0, 5, amount / 10, amount / 10, remaining, 0);
        vm.expectEmit(true, true, true, true);
        emit ClaimedRedeemRequest(0, user, 3 * (amount / 10), 3 * (amount / 10), remaining);
        redeemManager.claimRedeemRequests(redeemRequestIds, withdrawEventIds, true, 2);

        redeemRequest = redeemManager.getRedeemRequestDetails(0);
        assertEq(redeemRequest.height, amount - remaining);
        assertEq(redeemRequest.amount, remaining);

        withdrawEventIds[0] = 6;

        remaining -= (amount / 10);
        vm.expectEmit(true, true, true, true);
        emit SatisfiedRedeemRequest(0, 6, amount / 10, amount / 10, remaining, 0);
        remaining -= (amount / 10);
        vm.expectEmit(true, true, true, true);
        emit SatisfiedRedeemRequest(0, 7, amount / 10, amount / 10, remaining, 0);
        remaining -= (amount / 10);
        vm.expectEmit(true, true, true, true);
        emit SatisfiedRedeemRequest(0, 8, amount / 10, amount / 10, remaining, 0);
        remaining -= (amount / 10);
        vm.expectEmit(true, true, true, true);
        emit SatisfiedRedeemRequest(0, 9, amount / 10, amount / 10, remaining, 0);
        vm.expectEmit(true, true, true, true);
        emit ClaimedRedeemRequest(0, user, 4 * (amount / 10), 4 * (amount / 10), remaining);
        redeemManager.claimRedeemRequests(redeemRequestIds, withdrawEventIds, true, 3);

        redeemRequest = redeemManager.getRedeemRequestDetails(0);
        assertEq(redeemRequest.height, amount - remaining);
        assertEq(redeemRequest.amount, remaining);

        assertEq(address(redeemManager).balance, 0);
        assertEq(user.balance, amount);
    }

    function testClaimRedeemRequestOnTwoEvents(uint256 _salt) external {
        uint128 amount = uint128(bound(_salt, 2, type(uint128).max));

        address user = _generateAllowlistedUser(_salt);

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
            RedeemQueueV2.RedeemRequest memory rr = redeemManager.getRedeemRequestDetails(0);

            assertEq(rr.height, 0);
            assertEq(rr.amount, amount);
            assertEq(rr.recipient, user);
        }

        {
            WithdrawalStack.WithdrawalEvent memory we = redeemManager.getWithdrawalEventDetails(0);

            assertEq(we.height, 0);
            assertEq(we.amount, amount / 2);
            assertEq(we.withdrawnEth, amount / 2);
        }

        {
            WithdrawalStack.WithdrawalEvent memory we = redeemManager.getWithdrawalEventDetails(1);

            assertEq(we.height, amount / 2);
            assertEq(we.amount, amount - (amount / 2));
            assertEq(we.withdrawnEth, amount - (amount / 2));
        }

        uint32[] memory redeemRequestIds = new uint32[](1);
        uint32[] memory withdrawEventIds = new uint32[](1);

        withdrawEventIds[0] = 0;
        redeemRequestIds[0] = 0;

        int64[] memory resolvedRedeemRequests = redeemManager.resolveRedeemRequests(redeemRequestIds);

        assertEq(resolvedRedeemRequests.length, 1);
        assertEq(resolvedRedeemRequests[0], 0);

        assertEq(address(redeemManager).balance, amount);
        assertEq(user.balance, 0);

        vm.expectEmit(true, true, true, true);
        emit SatisfiedRedeemRequest(0, 0, amount / 2, amount / 2, amount - (amount / 2), 0);
        vm.expectEmit(true, true, true, true);
        emit SatisfiedRedeemRequest(0, 1, amount - (amount / 2), amount - (amount / 2), 0, 0);
        vm.expectEmit(true, true, true, true);
        emit ClaimedRedeemRequest(0, user, amount, amount, 0);
        redeemManager.claimRedeemRequests(redeemRequestIds, withdrawEventIds, true, type(uint16).max);

        assertEq(address(redeemManager).balance, 0);
        assertEq(user.balance, amount);

        resolvedRedeemRequests = redeemManager.resolveRedeemRequests(redeemRequestIds);

        assertEq(resolvedRedeemRequests.length, 1);
        assertEq(resolvedRedeemRequests[0], -3);

        {
            RedeemQueueV2.RedeemRequest memory rr = redeemManager.getRedeemRequestDetails(0);

            assertEq(rr.height, amount);
            assertEq(rr.amount, 0);
            assertEq(rr.recipient, user);
        }

        {
            WithdrawalStack.WithdrawalEvent memory we = redeemManager.getWithdrawalEventDetails(0);

            assertEq(we.height, 0);
            assertEq(we.amount, amount / 2);
            assertEq(we.withdrawnEth, amount / 2);
        }

        {
            WithdrawalStack.WithdrawalEvent memory we = redeemManager.getWithdrawalEventDetails(1);

            assertEq(we.height, amount / 2);
            assertEq(we.amount, amount - (amount / 2));
            assertEq(we.withdrawnEth, amount - (amount / 2));
        }
    }

    function testClaimRedeemRequestTwoRequestsOnOneEvent(uint256 _salt) external {
        uint256 amount = uint128(bound(_salt, 2, type(uint120).max));

        address user = _generateAllowlistedUser(_salt);
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
            RedeemQueueV2.RedeemRequest memory rr = redeemManager.getRedeemRequestDetails(0);

            assertEq(rr.height, 0);
            assertEq(rr.amount, amount);
            assertEq(rr.recipient, user);
        }

        {
            RedeemQueueV2.RedeemRequest memory rr = redeemManager.getRedeemRequestDetails(1);

            assertEq(rr.height, amount);
            assertEq(rr.amount, amount);
            assertEq(rr.recipient, userB);
        }

        {
            WithdrawalStack.WithdrawalEvent memory we = redeemManager.getWithdrawalEventDetails(0);

            assertEq(we.height, 0);
            assertEq(we.amount, amount * 2);
            assertEq(we.withdrawnEth, amount * 2);
        }

        uint32[] memory redeemRequestIds = new uint32[](2);
        uint32[] memory withdrawEventIds = new uint32[](2);

        redeemRequestIds[0] = 1;
        redeemRequestIds[1] = 0;

        withdrawEventIds[0] = 0;
        withdrawEventIds[1] = 0;

        assertEq(address(redeemManager).balance, amount * 2);
        assertEq(user.balance, 0);
        assertEq(userB.balance, 0);

        vm.expectEmit(true, true, true, true);
        emit SatisfiedRedeemRequest(1, 0, amount, amount, 0, 0);
        vm.expectEmit(true, true, true, true);
        emit ClaimedRedeemRequest(1, userB, amount, amount, 0);
        vm.expectEmit(true, true, true, true);
        emit SatisfiedRedeemRequest(0, 0, amount, amount, 0, 0);
        vm.expectEmit(true, true, true, true);
        emit ClaimedRedeemRequest(0, user, amount, amount, 0);
        redeemManager.claimRedeemRequests(redeemRequestIds, withdrawEventIds, true, type(uint16).max);

        assertEq(address(redeemManager).balance, 0);
        assertEq(user.balance, amount);
        assertEq(userB.balance, amount);

        {
            RedeemQueueV2.RedeemRequest memory rr = redeemManager.getRedeemRequestDetails(0);

            assertEq(rr.height, amount);
            assertEq(rr.amount, 0);
            assertEq(rr.recipient, user);
        }

        {
            RedeemQueueV2.RedeemRequest memory rr = redeemManager.getRedeemRequestDetails(1);

            assertEq(rr.height, amount * 2);
            assertEq(rr.amount, 0);
            assertEq(rr.recipient, userB);
        }

        {
            WithdrawalStack.WithdrawalEvent memory we = redeemManager.getWithdrawalEventDetails(0);

            assertEq(we.height, 0);
            assertEq(we.amount, amount * 2);
            assertEq(we.withdrawnEth, amount * 2);
        }
    }

    function testClaimRedeemRequestIncompatibleArrayLengths(uint256 _salt) external {
        uint128 amount = uint128(bound(_salt, 1, type(uint128).max));

        address user = _generateAllowlistedUser(_salt);

        river.sudoDeal(user, uint256(amount));

        vm.prank(user);
        river.approve(address(redeemManager), uint256(amount) * 2);

        vm.prank(user);
        redeemManager.requestRedeem(amount, user);

        vm.deal(address(this), amount);
        river.sudoReportWithdraw{value: amount}(address(redeemManager), amount);

        uint32[] memory redeemRequestIds = new uint32[](1);
        uint32[] memory withdrawEventIds = new uint32[](0);

        redeemRequestIds[0] = 0;

        vm.expectRevert(abi.encodeWithSignature("IncompatibleArrayLengths()"));
        redeemManager.claimRedeemRequests(redeemRequestIds, withdrawEventIds, true, type(uint16).max);
    }

    function testClaimRedeemRequestOutOfBounds() external {
        uint32[] memory redeemRequestIds = new uint32[](1);
        uint32[] memory withdrawEventIds = new uint32[](1);

        redeemRequestIds[0] = 0;
        withdrawEventIds[0] = 0;

        vm.expectRevert(abi.encodeWithSignature("RedeemRequestOutOfBounds(uint256)", 0));
        redeemManager.claimRedeemRequests(redeemRequestIds, withdrawEventIds, true, type(uint16).max);
    }

    function testClaimRedeemRequestWithdrawalEventOutOfBounds(uint256 _salt) external {
        uint128 amount = uint128(bound(_salt, 1, type(uint128).max));

        address user = _generateAllowlistedUser(_salt);

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
        redeemManager.claimRedeemRequests(redeemRequestIds, withdrawEventIds, true, type(uint16).max);
    }

    function testClaimRedeemRequestNotMatching(uint256 _salt) external {
        uint128 amount = uint128(bound(_salt, 1, type(uint120).max));

        address user = _generateAllowlistedUser(_salt);

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
        redeemManager.claimRedeemRequests(redeemRequestIds, withdrawEventIds, true, type(uint16).max);
    }

    function rollNext(uint256 _salt) internal pure returns (uint256) {
        return uint256(keccak256(abi.encode(_salt)));
    }

    function testFillingBothQueues(uint256 _salt) external {
        address user = _generateAllowlistedUser(_salt);
        river.sudoDeal(address(this), 1e18);
        _salt = rollNext(_salt);
        uint256 totalAmount = bound(_salt, 1, type(uint64).max);

        uint256 filled = 0;
        uint256 count = 0;
        uint256 salt = _salt;

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
            ++count;
        }

        assertEq(redeemManager.getRedeemDemand(), totalAmount);

        filled = 0;
        while (filled < totalAmount) {
            salt = rollNext(salt);
            uint256 eventSize = bound(salt, 1, type(uint64).max / 100);
            if (filled + eventSize > totalAmount) {
                eventSize = totalAmount - filled;
            }
            filled += eventSize;
            vm.deal(address(this), eventSize * 2);
            river.sudoReportWithdraw{value: eventSize * 2}(address(redeemManager), eventSize);
        }

        assertEq(redeemManager.getRedeemDemand(), 0);

        uint32[] memory redeemRequestIds = new uint32[](count);
        for (uint256 idx = 0; idx < count; ++idx) {
            redeemRequestIds[idx] = uint32(idx);
        }
        int64[] memory withdrawalEventIds = redeemManager.resolveRedeemRequests(redeemRequestIds);
        uint32[] memory withdrawalEventIdsUint = new uint32[](withdrawalEventIds.length);

        for (uint256 idx = 0; idx < withdrawalEventIds.length; ++idx) {
            assertTrue(withdrawalEventIds[idx] >= 0, "unresolved requests");
            withdrawalEventIdsUint[idx] = uint32(uint64(withdrawalEventIds[idx]));
        }

        assertEq(address(redeemManager).balance, totalAmount * 2);
        assertEq(user.balance, 0);

        uint8[] memory claimStatus =
            redeemManager.claimRedeemRequests(redeemRequestIds, withdrawalEventIdsUint, false, type(uint16).max);

        assertEq(address(redeemManager).balance, totalAmount);
        assertEq(user.balance, totalAmount);
        assertEq(redeemManager.getRedeemDemand(), 0);

        withdrawalEventIds = redeemManager.resolveRedeemRequests(redeemRequestIds);

        for (uint256 idx = 0; idx < withdrawalEventIds.length; ++idx) {
            assertTrue(withdrawalEventIds[idx] == -3);
            assertTrue(claimStatus[idx] == 0);
        }

        assertEq(redeemManager.getBufferedExceedingEth(), totalAmount);
    }

    function applyRate(uint256 amount, uint256 rate) internal pure returns (uint256) {
        return (amount * rate) / 1e18;
    }

    function testClaimMultiRate() external {
        address user = _generateAllowlistedUser(0);

        uint256[] memory rates = new uint256[](10);
        rates[0] = 1_000_000_000_000_000_000;
        rates[1] = 1_000_000_000_000_000_000;
        rates[2] = 1_000_000_000_000_000_000;
        rates[3] = 1_000_000_000_000_000_000;

        rates[4] = 1_025_000_000_000_000_000;
        rates[5] = 1_050_000_000_000_000_000;
        rates[6] = 1_075_000_000_000_000_000;

        rates[7] = 1_200_000_000_000_000_000;
        rates[8] = 1_300_000_000_000_000_000;
        rates[9] = 1_400_000_000_000_000_000;

        for (uint256 idx = 0; idx < rates.length; ++idx) {
            river.sudoSetRate(rates[idx]);
            river.sudoDeal(user, 30e18);

            vm.prank(user);
            river.approve(address(redeemManager), 30e18);

            vm.prank(user);
            redeemManager.requestRedeem(30e18, user);

            RedeemQueueV2.RedeemRequest memory redeemRequest = redeemManager.getRedeemRequestDetails(uint32(idx));

            assertEq(redeemRequest.height, idx * 30e18);
            assertEq(redeemRequest.amount, 30e18);
            assertEq(redeemRequest.recipient, user);
            assertEq(redeemRequest.maxRedeemableEth, applyRate(30e18, rates[idx]));
        }

        uint256[] memory redeemRates = new uint256[](3);
        redeemRates[0] = 1_000_000_000_000_000_000;
        redeemRates[1] = 1_100_000_000_000_000_000;
        redeemRates[2] = 1_500_000_000_000_000_000;

        for (uint256 idx = 0; idx < redeemRates.length; ++idx) {
            uint256 amount = applyRate(100e18, redeemRates[idx]);
            vm.deal(address(this), amount);
            river.sudoReportWithdraw{value: amount}(address(redeemManager), 100e18);

            WithdrawalStack.WithdrawalEvent memory withdrawalEvent =
                redeemManager.getWithdrawalEventDetails(uint32(idx));

            assertEq(withdrawalEvent.height, idx * 100e18);
            assertEq(withdrawalEvent.amount, 100e18);
            assertEq(withdrawalEvent.withdrawnEth, applyRate(100e18, redeemRates[idx]));
        }

        uint256 exceedingAmount = 0;

        exceedingAmount += applyRate(30e18, redeemRates[0]) - applyRate(30e18, rates[0]);
        exceedingAmount += applyRate(30e18, redeemRates[0]) - applyRate(30e18, rates[1]);
        exceedingAmount += applyRate(30e18, redeemRates[0]) - applyRate(30e18, rates[2]);
        exceedingAmount += applyRate(10e18, redeemRates[0]) - applyRate(10e18, rates[3]);

        exceedingAmount += applyRate(20e18, redeemRates[1]) - applyRate(20e18, rates[3]);
        exceedingAmount += applyRate(30e18, redeemRates[1]) - applyRate(30e18, rates[4]);
        exceedingAmount += applyRate(30e18, redeemRates[1]) - applyRate(30e18, rates[5]);
        exceedingAmount += applyRate(20e18, redeemRates[1]) - applyRate(20e18, rates[6]);

        exceedingAmount += applyRate(10e18, redeemRates[2]) - applyRate(10e18, rates[6]);
        exceedingAmount += applyRate(30e18, redeemRates[2]) - applyRate(30e18, rates[7]);
        exceedingAmount += applyRate(30e18, redeemRates[2]) - applyRate(30e18, rates[8]);
        exceedingAmount += applyRate(30e18, redeemRates[2]) - applyRate(30e18, rates[9]);

        uint32[] memory ids = new uint32[](10);

        for (uint256 idx = 0; idx < ids.length; ++idx) {
            ids[idx] = uint32(idx);
        }

        int64[] memory withdrawalEventIds = redeemManager.resolveRedeemRequests(ids);

        uint32[] memory withdrawalEventIdsU32 = new uint32[](withdrawalEventIds.length);
        for (uint256 idx = 0; idx < withdrawalEventIds.length; ++idx) {
            withdrawalEventIdsU32[idx] = uint32(uint64(withdrawalEventIds[idx]));
        }

        redeemManager.claimRedeemRequests(ids, withdrawalEventIdsU32);

        assertEq(redeemManager.getBufferedExceedingEth(), exceedingAmount);
    }

    function testResolveOutOfBounds() external {
        uint32[] memory redeemRequestIds = new uint32[](1);
        int64[] memory withdrawalEventIds = redeemManager.resolveRedeemRequests(redeemRequestIds);
        assertEq(withdrawalEventIds.length, 1);
        assertTrue(withdrawalEventIds[0] == -2);
    }

    function testResolveUnsatisfied(uint256 _salt) external {
        uint128 amount = uint128(bound(_salt, 1, type(uint120).max));
        address user = _generateAllowlistedUser(_salt);

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

    function testResolveRedeemRequestForZeroIds() external {
        uint32[] memory redeemRequestIds = new uint32[](0);
        int64[] memory withdrawalEventIds = redeemManager.resolveRedeemRequests(redeemRequestIds);
        assert(withdrawalEventIds.length == 0);
    }

    function testPullExceedingEth() external {
        vm.deal(address(redeemManager), 1 ether);
        vm.store(
            address(redeemManager),
            bytes32(uint256(keccak256("river.state.bufferedExceedingEth")) - 1),
            bytes32(uint256(1 ether))
        );
        river.pullExceedingEth(address(redeemManager), 1 ether);
    }

    function testClaimRedeemRequestFailsWithDeniedUser(uint256 _salt) external {
        uint128 amount = uint128(bound(_salt, 1, type(uint128).max));

        address user = _generateAllowlistedUser(_salt);

        river.sudoDeal(user, uint256(amount));

        vm.prank(user);
        river.approve(address(redeemManager), uint256(amount));

        vm.prank(user);
        redeemManager.requestRedeem(amount, user);

        vm.deal(address(this), amount);
        river.sudoReportWithdraw{value: amount}(address(redeemManager), amount);

        assertEq(redeemManager.getWithdrawalEventCount(), 1);
        assertEq(redeemManager.getRedeemRequestCount(), 1);

        {
            RedeemQueueV2.RedeemRequest memory rr = redeemManager.getRedeemRequestDetails(0);

            assertEq(rr.height, 0);
            assertEq(rr.amount, amount);
            assertEq(rr.recipient, user);
        }

        {
            WithdrawalStack.WithdrawalEvent memory we = redeemManager.getWithdrawalEventDetails(0);

            assertEq(we.height, 0);
            assertEq(we.amount, amount);
            assertEq(we.withdrawnEth, amount);
        }

        uint32[] memory redeemRequestIds = new uint32[](1);
        uint32[] memory withdrawEventIds = new uint32[](1);

        redeemRequestIds[0] = 0;
        withdrawEventIds[0] = 0;

        assertEq(address(redeemManager).balance, amount);
        assertEq(user.balance, 0);

        int64[] memory resolvedRedeemRequests = redeemManager.resolveRedeemRequests(redeemRequestIds);

        assertEq(resolvedRedeemRequests.length, 1);
        assertEq(resolvedRedeemRequests[0], 0);

        _denyUser(user);

        // A user can't claim if the recipient is denied
        vm.expectRevert(abi.encodeWithSignature("ClaimRecipientIsDenied()"));
        redeemManager.claimRedeemRequests(redeemRequestIds, withdrawEventIds, true, type(uint16).max);

        // The denied user can't claim
        vm.expectRevert(abi.encodeWithSignature("ClaimRecipientIsDenied()"));
        vm.prank(user);
        redeemManager.claimRedeemRequests(redeemRequestIds, withdrawEventIds, true, type(uint16).max);
    }

    // A claimRedeemRequest for a redeemRequest whose initiator is denied should fail
    function testClaimRedeemRequestFailsWithDeniedInitiator(uint256 _salt, uint256 _salt2) external {
        uint128 amount = uint128(bound(_salt, 1, type(uint128).max));

        address user = _generateAllowlistedUser(_salt);
        address initiator = _generateAllowlistedUser(_salt2); // Generate a different initiator

        river.sudoDeal(initiator, uint256(amount));

        vm.prank(initiator);
        river.approve(address(redeemManager), uint256(amount));

        vm.prank(initiator);
        redeemManager.requestRedeem(amount, user);

        vm.deal(address(this), amount);
        river.sudoReportWithdraw{value: amount}(address(redeemManager), amount);

        assertEq(redeemManager.getWithdrawalEventCount(), 1);
        assertEq(redeemManager.getRedeemRequestCount(), 1);

        {
            RedeemQueueV2.RedeemRequest memory rr = redeemManager.getRedeemRequestDetails(0);

            assertEq(rr.height, 0);
            assertEq(rr.amount, amount);
            assertEq(rr.recipient, user);
            assertEq(rr.initiator, initiator); // Check the initiator
        }

        {
            WithdrawalStack.WithdrawalEvent memory we = redeemManager.getWithdrawalEventDetails(0);

            assertEq(we.height, 0);
            assertEq(we.amount, amount);
            assertEq(we.withdrawnEth, amount);
        }

        uint32[] memory redeemRequestIds = new uint32[](1);
        uint32[] memory withdrawEventIds = new uint32[](1);

        redeemRequestIds[0] = 0;
        withdrawEventIds[0] = 0;

        assertEq(address(redeemManager).balance, amount);
        assertEq(user.balance, 0);

        int64[] memory resolvedRedeemRequests = redeemManager.resolveRedeemRequests(redeemRequestIds);

        assertEq(resolvedRedeemRequests.length, 1);
        assertEq(resolvedRedeemRequests[0], 0);

        _denyUser(initiator);

        // A user can't claim if the initiator is denied
        vm.expectRevert(abi.encodeWithSignature("ClaimInitiatorIsDenied()"));
        redeemManager.claimRedeemRequests(redeemRequestIds, withdrawEventIds, true, type(uint16).max);

        // The allowed recipient can't claim, if the initiator is denied
        vm.expectRevert(abi.encodeWithSignature("ClaimInitiatorIsDenied()"));
        vm.prank(user);
        redeemManager.claimRedeemRequests(redeemRequestIds, withdrawEventIds, true, type(uint16).max);
    }

    // A denied user when undenied would be able to claim the ETH
    function testClaimRedeemRequestClaimsWithDeniedUserUndenied(uint256 _salt) external {
        uint128 amount = uint128(bound(_salt, 1, type(uint128).max));

        address user = _generateAllowlistedUser(_salt);

        river.sudoDeal(user, uint256(amount));

        vm.prank(user);
        river.approve(address(redeemManager), uint256(amount));

        vm.prank(user);
        redeemManager.requestRedeem(amount, user);

        vm.deal(address(this), amount);
        river.sudoReportWithdraw{value: amount}(address(redeemManager), amount);

        assertEq(redeemManager.getWithdrawalEventCount(), 1);
        assertEq(redeemManager.getRedeemRequestCount(), 1);

        {
            RedeemQueueV2.RedeemRequest memory rr = redeemManager.getRedeemRequestDetails(0);

            assertEq(rr.height, 0);
            assertEq(rr.amount, amount);
            assertEq(rr.recipient, user);
        }

        {
            WithdrawalStack.WithdrawalEvent memory we = redeemManager.getWithdrawalEventDetails(0);

            assertEq(we.height, 0);
            assertEq(we.amount, amount);
            assertEq(we.withdrawnEth, amount);
        }

        uint32[] memory redeemRequestIds = new uint32[](1);
        uint32[] memory withdrawEventIds = new uint32[](1);

        redeemRequestIds[0] = 0;
        withdrawEventIds[0] = 0;

        assertEq(address(redeemManager).balance, amount);
        assertEq(user.balance, 0);

        int64[] memory resolvedRedeemRequests = redeemManager.resolveRedeemRequests(redeemRequestIds);

        assertEq(resolvedRedeemRequests.length, 1);
        assertEq(resolvedRedeemRequests[0], 0);

        _denyUser(user);

        // A user can't claim if the recipient is denied
        vm.expectRevert(abi.encodeWithSignature("ClaimRecipientIsDenied()"));
        redeemManager.claimRedeemRequests(redeemRequestIds, withdrawEventIds, true, type(uint16).max);

        // The denied user can't claim
        vm.expectRevert(abi.encodeWithSignature("ClaimRecipientIsDenied()"));
        vm.prank(user);
        redeemManager.claimRedeemRequests(redeemRequestIds, withdrawEventIds, true, type(uint16).max);

        _unDenyUser(user);

        vm.expectEmit(true, true, true, true);
        emit SatisfiedRedeemRequest(0, 0, amount, amount, 0, 0);
        vm.expectEmit(true, true, true, true);
        emit ClaimedRedeemRequest(0, user, amount, amount, 0);
        redeemManager.claimRedeemRequests(redeemRequestIds, withdrawEventIds, true, type(uint16).max);

        assertEq(redeemManager.getBufferedExceedingEth(), 0);
        assertEq(address(redeemManager).balance, 0);
        assertEq(user.balance, amount);

        resolvedRedeemRequests = redeemManager.resolveRedeemRequests(redeemRequestIds);

        assertEq(resolvedRedeemRequests.length, 1);
        assertEq(resolvedRedeemRequests[0], -3);

        {
            RedeemQueueV2.RedeemRequest memory rr = redeemManager.getRedeemRequestDetails(0);

            assertEq(rr.height, amount);
            assertEq(rr.amount, 0);
            assertEq(rr.recipient, user);
        }

        {
            WithdrawalStack.WithdrawalEvent memory we = redeemManager.getWithdrawalEventDetails(0);

            assertEq(we.height, 0);
            assertEq(we.amount, amount);
            assertEq(we.withdrawnEth, amount);
        }
    }

    // The ETH remains behind in the protocol
    // Submit 2 different redeem requests from different users
    // One user gets denied
    // Other user claims
    // The balance of redeem manager shows the unclaimable ETH
    function testUnclaimableDeniedETHRemainsInProtocol(uint256 _salt, uint256 _salt2) external {
        vm.assume(_salt != _salt2);

        uint128 amount = uint128(bound(_salt, 1, type(uint64).max));

        address user = _generateAllowlistedUser(_salt);
        address user2 = _generateAllowlistedUser(_salt2);

        {
            river.sudoDeal(user, uint256(amount));
            river.sudoDeal(user2, uint256(amount));

            vm.prank(user);
            river.approve(address(redeemManager), uint256(amount));

            vm.prank(user);
            redeemManager.requestRedeem(amount, user);

            vm.prank(user2);
            river.approve(address(redeemManager), uint256(amount));

            vm.prank(user2);
            redeemManager.requestRedeem(amount, user2);

            vm.deal(address(this), amount);
            river.sudoReportWithdraw{value: amount}(address(redeemManager), amount);

            vm.deal(address(this), amount);
            river.sudoReportWithdraw{value: amount}(address(redeemManager), amount);
        }

        assertEq(redeemManager.getWithdrawalEventCount(), 2);
        assertEq(redeemManager.getRedeemRequestCount(), 2);

        uint32[] memory redeemRequestIds = new uint32[](1);
        uint32[] memory withdrawEventIds = new uint32[](1);

        redeemRequestIds[0] = 0;
        withdrawEventIds[0] = 0;

        assertEq(address(redeemManager).balance, amount * 2);
        assertEq(user.balance, 0);

        int64[] memory resolvedRedeemRequests = redeemManager.resolveRedeemRequests(redeemRequestIds);

        assertEq(resolvedRedeemRequests.length, 1);
        assertEq(resolvedRedeemRequests[0], 0);

        _denyUser(user2);

        vm.prank(user);
        redeemManager.claimRedeemRequests(redeemRequestIds, withdrawEventIds, true, type(uint16).max);

        assertEq(redeemManager.getBufferedExceedingEth(), 0);
        assertEq(address(redeemManager).balance, amount);
        assertEq(user.balance, amount);

        redeemRequestIds[0] = 1;
        withdrawEventIds[0] = 1;

        vm.expectRevert(abi.encodeWithSignature("ClaimRecipientIsDenied()"));
        vm.prank(user2);
        redeemManager.claimRedeemRequests(redeemRequestIds, withdrawEventIds, true, type(uint16).max);
    }

    // ClaimedRedeemRequest event should be emitted when a redeem request is claimed
    function testClaimRedeemRequestEmitsClaimedEvent(uint256 _salt) external {
        uint128 amount = uint128(bound(_salt, 1, type(uint64).max));
        address initiator = _generateAllowlistedUser(_salt);

        river.sudoDeal(initiator, uint256(amount));

        vm.prank(initiator);
        river.approve(address(redeemManager), uint256(amount));

        vm.prank(initiator);
        redeemManager.requestRedeem(amount, initiator);

        vm.deal(address(this), amount);
        river.sudoReportWithdraw{value: amount}(address(redeemManager), amount);

        assertEq(redeemManager.getWithdrawalEventCount(), 1);
        assertEq(redeemManager.getRedeemRequestCount(), 1);

        {
            RedeemQueueV2.RedeemRequest memory rr = redeemManager.getRedeemRequestDetails(0);

            assertEq(rr.height, 0);
            assertEq(rr.amount, amount);
            assertEq(rr.recipient, initiator);
        }

        {
            WithdrawalStack.WithdrawalEvent memory we = redeemManager.getWithdrawalEventDetails(0);

            assertEq(we.height, 0);
            assertEq(we.amount, amount);
            assertEq(we.withdrawnEth, amount);
        }

        uint32[] memory redeemRequestIds = new uint32[](1);
        uint32[] memory withdrawEventIds = new uint32[](1);

        redeemRequestIds[0] = 0;
        withdrawEventIds[0] = 0;

        assertEq(address(redeemManager).balance, amount);
        assertEq(initiator.balance, 0);

        int64[] memory resolvedRedeemRequests = redeemManager.resolveRedeemRequests(redeemRequestIds);

        assertEq(resolvedRedeemRequests.length, 1);
        assertEq(resolvedRedeemRequests[0], 0);

        // Assume the initiator and recipient to be same
        vm.expectEmit(true, true, true, true);
        emit ClaimedRedeemRequest(0, initiator, amount, amount, 0);
        redeemManager.claimRedeemRequests(redeemRequestIds, withdrawEventIds, true, type(uint16).max);
    }

    function testClaimRedeemRequestRevertsOnFailedEtherTransferToRecipient(uint256 _salt) external {
        uint128 amount = uint128(bound(_salt, 1, type(uint128).max));

        address initiator = _generateAllowlistedUser(_salt);

        // Deploy the RejectEtherMock contract for recipient
        address recipient = address(new RejectEtherMock());
        _allowlistUser(recipient);

        // Fund the initiator
        river.sudoDeal(initiator, uint256(amount));

        // Approve and request redeem with the initiator
        vm.prank(initiator);
        river.approve(address(redeemManager), uint256(amount));

        vm.prank(initiator);
        redeemManager.requestRedeem(amount, recipient);

        vm.deal(address(this), amount);
        river.sudoReportWithdraw{value: amount}(address(redeemManager), amount);

        assertEq(redeemManager.getWithdrawalEventCount(), 1);
        assertEq(redeemManager.getRedeemRequestCount(), 1);

        {
            RedeemQueueV2.RedeemRequest memory rr = redeemManager.getRedeemRequestDetails(0);

            assertEq(rr.height, 0);
            assertEq(rr.amount, amount);
            assertEq(rr.recipient, recipient);
        }

        {
            WithdrawalStack.WithdrawalEvent memory we = redeemManager.getWithdrawalEventDetails(0);

            assertEq(we.height, 0);
            assertEq(we.amount, amount);
            assertEq(we.withdrawnEth, amount);
        }

        uint32[] memory redeemRequestIds = new uint32[](1);
        uint32[] memory withdrawEventIds = new uint32[](1);

        redeemRequestIds[0] = 0;
        withdrawEventIds[0] = 0;

        assertEq(address(redeemManager).balance, amount);
        assertEq(initiator.balance, 0);

        int64[] memory resolvedRedeemRequests = redeemManager.resolveRedeemRequests(redeemRequestIds);

        assertEq(resolvedRedeemRequests.length, 1);
        assertEq(resolvedRedeemRequests[0], 0);

        // Attempt to claim the redeem request and expect it to fail
        vm.expectRevert(abi.encodeWithSignature("ClaimRedeemFailed(address,bytes)", recipient, new bytes(0)));
        redeemManager.claimRedeemRequests(redeemRequestIds, withdrawEventIds, true, type(uint16).max);
    }

    function testRequestRedeemTwoArgBlockedInSlashingMode(uint256 _salt) external {
        address user = _generateAllowlistedUser(_salt);
        uint64 amount = uint64(bound(_salt, 1, type(uint64).max));
        river.sudoDeal(user, amount);
        vm.prank(user);
        river.approve(address(redeemManager), amount);

        river.sudoSetSlashingContainmentMode(true);

        vm.prank(user);
        vm.expectRevert(abi.encodeWithSignature("SlashingContainmentModeEnabled()"));
        redeemManager.requestRedeem(amount, user);
    }

    function testRequestRedeemOneArgBlockedInSlashingMode(uint256 _salt) external {
        address user = _generateAllowlistedUser(_salt);
        uint64 amount = uint64(bound(_salt, 1, type(uint64).max));
        river.sudoDeal(user, amount);
        vm.prank(user);
        river.approve(address(redeemManager), amount);

        river.sudoSetSlashingContainmentMode(true);

        vm.prank(user);
        vm.expectRevert(abi.encodeWithSignature("SlashingContainmentModeEnabled()"));
        redeemManager.requestRedeem(amount);
    }

    function testClaimRedeemRequestsFourArgAllowedInSlashingMode(uint256 _salt) external {
        uint128 amount = uint128(bound(_salt, 1, type(uint128).max));
        address user = _generateAllowlistedUser(_salt);

        river.sudoDeal(user, uint256(amount));
        vm.prank(user);
        river.approve(address(redeemManager), uint256(amount));
        vm.prank(user);
        redeemManager.requestRedeem(amount, user);

        vm.deal(address(this), amount);
        river.sudoReportWithdraw{value: amount}(address(redeemManager), amount);

        river.sudoSetSlashingContainmentMode(true);

        uint32[] memory redeemRequestIds = new uint32[](1);
        uint32[] memory withdrawalEventIds = new uint32[](1);
        redeemRequestIds[0] = 0;
        withdrawalEventIds[0] = 0;

        uint256 userBalanceBefore = user.balance;

        uint8[] memory claimStatuses =
            redeemManager.claimRedeemRequests(redeemRequestIds, withdrawalEventIds, true, type(uint16).max);

        assertEq(claimStatuses.length, 1);
        assertEq(claimStatuses[0], 0); // CLAIM_FULLY_CLAIMED
        assertEq(user.balance - userBalanceBefore, amount);
        assertEq(address(redeemManager).balance, 0);
    }

    function testClaimRedeemRequestsTwoArgAllowedInSlashingMode(uint256 _salt) external {
        uint128 amount = uint128(bound(_salt, 1, type(uint128).max));
        address user = _generateAllowlistedUser(_salt);

        river.sudoDeal(user, uint256(amount));
        vm.prank(user);
        river.approve(address(redeemManager), uint256(amount));
        vm.prank(user);
        redeemManager.requestRedeem(amount, user);

        vm.deal(address(this), amount);
        river.sudoReportWithdraw{value: amount}(address(redeemManager), amount);

        river.sudoSetSlashingContainmentMode(true);

        uint32[] memory redeemRequestIds = new uint32[](1);
        uint32[] memory withdrawalEventIds = new uint32[](1);
        redeemRequestIds[0] = 0;
        withdrawalEventIds[0] = 0;

        uint256 userBalanceBefore = user.balance;

        uint8[] memory claimStatuses = redeemManager.claimRedeemRequests(redeemRequestIds, withdrawalEventIds);

        assertEq(claimStatuses.length, 1);
        assertEq(claimStatuses[0], 0); // CLAIM_FULLY_CLAIMED
        assertEq(user.balance - userBalanceBefore, amount);
        assertEq(address(redeemManager).balance, 0);
    }

    function testRequestRedeemTwoArgAllowedWhenSlashingModeOff(uint256 _salt) external {
        address user = _generateAllowlistedUser(_salt);
        uint64 amount = uint64(bound(_salt, 1, type(uint64).max));
        river.sudoDeal(user, amount);
        vm.prank(user);
        river.approve(address(redeemManager), amount);

        river.sudoSetSlashingContainmentMode(false);

        vm.prank(user);
        uint32 id = redeemManager.requestRedeem(amount, user);
        assertEq(redeemManager.getRedeemRequestCount(), 1);
        assertEq(redeemManager.getRedeemRequestDetails(id).recipient, user);
    }

    function testClaimRedeemRequestsBlocksReentrancy() external {
        uint256 amount = 32 ether;

        // Deploy attacker whose receive() re-enters claimRedeemRequests
        ReentrancyClaimAttackMock attacker = new ReentrancyClaimAttackMock(address(redeemManager));

        // Allowlisted EOA requests a redeem with the attacker contract as recipient
        address requester = _generateAllowlistedUser(999);
        river.sudoDeal(requester, amount);
        vm.prank(requester);
        river.approve(address(redeemManager), amount);
        vm.prank(requester);
        redeemManager.requestRedeem(amount, address(attacker));

        // Fund the withdrawal
        vm.deal(address(this), amount);
        river.sudoReportWithdraw{value: amount}(address(redeemManager), amount);

        // Prime the attacker with the request/event IDs it will use during re-entry
        uint32[] memory reqIds = new uint32[](1);
        uint32[] memory eventIds = new uint32[](1);
        reqIds[0] = 0;
        eventIds[0] = 0;
        attacker.setAttackIds(reqIds, eventIds);

        // Trigger claim: attacker's receive() attempts a re-entrant call.
        // Without nonReentrant: the re-entrant call succeeds (reentrancySucceeded = true).
        // With nonReentrant:    the re-entrant call is blocked  (reentrancySucceeded = false).
        redeemManager.claimRedeemRequests(reqIds, eventIds, true, type(uint16).max);

        assertFalse(attacker.reentrancySucceeded(), "re-entrant call to claimRedeemRequests must be blocked");
    }

    function testVersion() external {
        assertEq(redeemManager.version(), "1.4.0");
    }
}

interface IRedeemManagerV1Mock {
    event RequestedRedeem(
        address indexed recipient, uint256 height, uint256 amount, uint256 maxRedeemableEth, uint32 id
    );

    event SetRedeemDemand(uint256 oldRedeemDemand, uint256 newRedeemDemand);

    event SetRiver(address river);

    /// @notice Thrown When a zero value is provided
    error InvalidZeroAmount();

    /// @notice Thrown when a transfer error occured with LsETH
    error TransferError();

    /// @notice Thrown when the provided arrays don't have matching lengths
    error IncompatibleArrayLengths();

    error RedeemRequestOutOfBounds(uint256 id);

    error DoesNotMatch(uint256 redeemRequestId, uint256 withdrawalEventId);

    /// @notice Thrown when the recipient of redeemRequest is denied
    error RecipientIsDenied();
}

contract MockRedeemManagerV1Base is Initializable, IRedeemManagerV1Mock {
    modifier onlyRedeemerOrRiver() {
        {
            IRiverV1 river = _castedRiver();
            if (msg.sender != address(river)) {
                IAllowlistV1(river.getAllowlist()).onlyAllowed(msg.sender, LibAllowlistMasks.REDEEM_MASK);
            }
        }
        _;
    }

    function initializeRedeemManagerV1(address _river) external init(0) {
        RiverAddress.set(_river);
        emit SetRiver(_river);
    }

    function _setRedeemDemand(uint256 _newValue) internal {
        emit SetRedeemDemand(RedeemDemand.get(), _newValue);
        RedeemDemand.set(_newValue);
    }

    function _castedRiver() internal view returns (IRiverV1) {
        return IRiverV1(payable(RiverAddress.get()));
    }
}

contract MockRedeemManagerV1 is MockRedeemManagerV1Base {
    function getRedeemRequestDetails(uint32 _redeemRequestId)
        external
        view
        returns (RedeemQueueV1.RedeemRequest memory)
    {
        return RedeemQueueV1.get()[_redeemRequestId];
    }

    function requestRedeem(uint256 _lsETHAmount, address _recipient)
        external
        onlyRedeemerOrRiver
        returns (uint32 redeemRequestId)
    {
        IRiverV1 river = _castedRiver();
        if (IAllowlistV1(river.getAllowlist()).isDenied(_recipient)) {
            revert RecipientIsDenied();
        }
        return _requestRedeem(_lsETHAmount, _recipient);
    }

    function _requestRedeem(uint256 _lsETHAmount, address _recipient) internal returns (uint32 redeemRequestId) {
        LibSanitize._notZeroAddress(_recipient);
        if (_lsETHAmount == 0) {
            revert InvalidZeroAmount();
        }
        if (!_castedRiver().transferFrom(msg.sender, address(this), _lsETHAmount)) {
            revert TransferError();
        }
        RedeemQueueV1.RedeemRequest[] storage redeemRequests = RedeemQueueV1.get();
        redeemRequestId = uint32(redeemRequests.length);
        uint256 height = 0;
        if (redeemRequestId != 0) {
            RedeemQueueV1.RedeemRequest memory previousRedeemRequest = redeemRequests[redeemRequestId - 1];
            height = previousRedeemRequest.height + previousRedeemRequest.amount;
        }

        uint256 maxRedeemableEth = _castedRiver().underlyingBalanceFromShares(_lsETHAmount);

        redeemRequests.push(
            RedeemQueueV1.RedeemRequest({
                height: height, amount: _lsETHAmount, recipient: _recipient, maxRedeemableEth: maxRedeemableEth
            })
        );

        _setRedeemDemand(RedeemDemand.get() + _lsETHAmount);

        emit RequestedRedeem(_recipient, height, _lsETHAmount, maxRedeemableEth, redeemRequestId);
    }
}

contract InitializeRedeemManagerV1_2Test is RedeeManagerV1TestBase {
    address public admin = address(0x123);
    address redeemManager;

    bytes32 constant REDEEM_QUEUE_V1_SLOT = bytes32(uint256(keccak256("river.state.redeemQueue")) - 1);
    bytes32 constant INITIALIZABLE_STORAGE_SLOT = bytes32(uint256(keccak256("openzeppelin.storage.Initializable")) - 1);
    bytes32 internal constant IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    // allowlist a user
    function _allowlistUser(address user) internal {
        address[] memory accounts = new address[](1);
        accounts[0] = user;
        uint256[] memory permissions = new uint256[](1);
        permissions[0] = LibAllowlistMasks.REDEEM_MASK | LibAllowlistMasks.DEPOSIT_MASK;

        vm.prank(allowlistAllower);
        allowlist.setAllowPermissions(accounts, permissions);
    }

    function setUp() public {
        allowlistAdmin = makeAddr("allowlistAdmin");
        allowlistAllower = makeAddr("allowlistAllower");
        allowlistDenier = makeAddr("allowlistDenier");
        allowlist = new AllowlistV1();
        LibImplementationUnbricker.unbrick(vm, address(allowlist));
        allowlist.initAllowlistV1(allowlistAdmin, allowlistAllower);
        allowlist.initAllowlistV1_1(allowlistDenier);
        river = new RiverMock(address(allowlist));

        MockRedeemManagerV1 redeemQueueImplV1 = new MockRedeemManagerV1();
        TUPProxy proxy = new TUPProxy(
            address(redeemQueueImplV1), admin, abi.encodeWithSignature("initializeRedeemManagerV1(address)", river)
        );
        redeemManager = address(proxy);

        // Setup initial queue (RedeemQueueV1) -> Create 30 random redeem requests to populate the queue before the upgrade/migration
        for (uint256 i = 0; i < 30; i++) {
            address user = address(uint160(i + 100));
            _allowlistUser(user);
            uint128 amount = uint128((i + 1) * 1e18);
            river.sudoDeal(user, amount);

            vm.prank(user);
            river.approve(address(redeemManager), amount);
            assertEq(river.balanceOf(user), amount);
            vm.prank(user);
            MockRedeemManagerV1(redeemManager).requestRedeem(amount, user);
        }
    }

    function testInitializeTwice() public {
        RedeemManagerV1 redeemQueueImplV2 = new RedeemManagerV1();
        vm.store(redeemManager, IMPLEMENTATION_SLOT, bytes32(uint256(uint160(address(redeemQueueImplV2)))));
        RedeemManagerV1(redeemManager).initializeRedeemManagerV1_2();

        vm.expectRevert(abi.encodeWithSignature("InvalidInitialization(uint256,uint256)", 1, 2));
        RedeemManagerV1(redeemManager).initializeRedeemManagerV1_2();
    }

    function testRedeemQueueMigrationV1_2() public {
        // Call the migration function
        RedeemManagerV1 redeemQueueImplV2 = new RedeemManagerV1();
        vm.store(redeemManager, IMPLEMENTATION_SLOT, bytes32(uint256(uint160(address(redeemQueueImplV2)))));
        RedeemManagerV1(redeemManager).initializeRedeemManagerV1_2();

        // Check all existing redeemRequests are intact after the migration (from oldQueue)
        for (uint256 i = 0; i < 30; i++) {
            RedeemQueueV2.RedeemRequest memory current =
                RedeemManagerV1(redeemManager).getRedeemRequestDetails(uint32(i));
            assertEq(current.amount, (i + 1) * 1e18);
            assertEq(current.recipient, address(uint160(i + 100)));
            if (i == 0) {
                assertEq(current.height, 0);
            } else {
                uint256 prevHeight = RedeemManagerV1(redeemManager).getRedeemRequestDetails(uint32(i - 1)).height;
                uint256 prevAmount = RedeemManagerV1(redeemManager).getRedeemRequestDetails(uint32(i - 1)).amount;
                assertEq(current.height, prevHeight + prevAmount);
            }
            assertEq(current.initiator, current.recipient);
        }

        // Check total length
        assertEq(RedeemManagerV1(redeemManager).getRedeemRequestCount(), 30);
    }

    function testRedeemQueueV1_2PostMigrationWithNewRequests() public {
        // Call the migration function
        RedeemManagerV1 redeemQueueImplV2 = new RedeemManagerV1();
        vm.store(redeemManager, IMPLEMENTATION_SLOT, bytes32(uint256(uint160(address(redeemQueueImplV2)))));
        RedeemManagerV1(redeemManager).initializeRedeemManagerV1_2();

        // Add new 30 random redeem requests after upgrade / migration. Note: 30 is just a random number
        for (uint256 i = 30; i < 60; i++) {
            address user = address(uint160(i + 100));
            _allowlistUser(user);
            uint128 amount = uint128((i + 1) * 1e18);
            river.sudoDeal(user, amount);

            vm.prank(user);
            river.approve(address(redeemManager), amount);
            assertEq(river.balanceOf(user), amount);
            vm.prank(user);
            RedeemManagerV1(redeemManager).requestRedeem(amount, user);
        }

        // Check all existing and new redeemRequests are intact after the migration
        for (uint256 i = 0; i < 60; i++) {
            RedeemQueueV2.RedeemRequest memory current =
                RedeemManagerV1(redeemManager).getRedeemRequestDetails(uint32(i));
            assertEq(current.amount, (i + 1) * 1e18);
            assertEq(current.recipient, address(uint160(i + 100)));
            if (i == 0) {
                assertEq(current.height, 0);
            } else {
                uint256 prevHeight = RedeemManagerV1(redeemManager).getRedeemRequestDetails(uint32(i - 1)).height;
                uint256 prevAmount = RedeemManagerV1(redeemManager).getRedeemRequestDetails(uint32(i - 1)).amount;
                assertEq(current.height, prevHeight + prevAmount);
            }
            assertEq(current.initiator, current.recipient);
        }

        // Check total length
        assertEq(RedeemManagerV1(redeemManager).getRedeemRequestCount(), 60);
    }
}

/// @title Rewards-on-Redemption tests
/// @notice Coverage for the MaxRedeemableETH lock mechanism added in V1_3:
///         - lockMaxRedeemableETH state mutation and revert paths
///         - getEffectiveCapForDemand aggregation across lock events and pre-upgrade fallback
///         - _claimRedeemRequest override-not-min cap semantics
///         - _claimRedeemRequest recursion across mixed withdrawal/lock-event boundaries
///         - reportWithdraw's MaxRedeemableETHLockedDemand decrement
contract RedeemManagerV1RewardsOnRedemptionTests is RedeeManagerV1TestBase {
    RedeemManagerV1 internal redeemManager;
    address internal initiatorAdmin;

    event MaxRedeemableETHLocked(
        uint32 indexed id,
        uint256 height,
        uint256 amount,
        uint256 lockedEth,
        uint256 fromFullExits,
        uint256 fromPartialWithdrawals,
        uint256 fromRebalancing
    );

    /// @dev Initializes all the way through V1_3 so post-upgrade behavior is the default.
    ///      Tests that need to model a pre-upgrade slice submit requests BEFORE this setUp's V1_3 call
    ///      via the helper `_simulatePreUpgradeQueueState` (see below).
    function setUp() external {
        allowlistAdmin = makeAddr("allowlistAdmin");
        allowlistAllower = makeAddr("allowlistAllower");
        allowlistDenier = makeAddr("allowlistDenier");
        redeemManager = new RedeemManagerV1();
        LibImplementationUnbricker.unbrick(vm, address(redeemManager));
        allowlist = new AllowlistV1();
        LibImplementationUnbricker.unbrick(vm, address(allowlist));
        allowlist.initAllowlistV1(allowlistAdmin, allowlistAllower);
        allowlist.initAllowlistV1_1(allowlistDenier);
        river = new RiverMock(address(allowlist));

        redeemManager.initializeRedeemManagerV1(address(river));
        redeemManager.initializeRedeemManagerV1_2();
        redeemManager.initializeRedeemManagerV1_3();
    }

    // ---- helpers ------------------------------------------------------------

    function _allowlistUser(address user) internal {
        address[] memory accounts = new address[](1);
        accounts[0] = user;
        uint256[] memory permissions = new uint256[](1);
        permissions[0] = LibAllowlistMasks.REDEEM_MASK | LibAllowlistMasks.DEPOSIT_MASK;
        vm.prank(allowlistAllower);
        allowlist.setAllowPermissions(accounts, permissions);
    }

    /// @dev Mints LsETH on the river mock, allowlists the user, approves the redeem manager,
    ///      and submits a request. Returns the assigned request id.
    function _submitRequest(address user, uint256 amount) internal returns (uint32 id) {
        _allowlistUser(user);
        river.sudoDeal(user, amount);
        vm.prank(user);
        river.approve(address(redeemManager), amount);
        vm.prank(user);
        id = redeemManager.requestRedeem(amount, user);
    }

    /// @dev Issues a lock event from the river (the only authorized caller) with all amount going
    ///      to `fromFullExits` for simplicity. Other source-attribution slots default to 0.
    function _lock(uint256 lsETHToLock, uint256 lockedEth) internal {
        vm.prank(address(river));
        redeemManager.lockMaxRedeemableETH(lsETHToLock, lockedEth, lockedEth, 0, 0);
    }

    function _lockFromRebalance(uint256 lsETHToLock, uint256 lockedEth) internal {
        vm.prank(address(river));
        redeemManager.lockMaxRedeemableETH(lsETHToLock, lockedEth, 0, 0, lockedEth);
    }

    /// @dev Reports a withdrawal event via the river mock. ETH is dealt to river first so it can
    ///      forward msg.value.
    function _reportWithdraw(uint256 lsETHWithdrawable, uint256 ethAmount) internal {
        vm.deal(address(river), address(river).balance + ethAmount);
        river.sudoReportWithdraw{value: ethAmount}(address(redeemManager), lsETHWithdrawable);
    }

    /// @dev Simulates a pre-upgrade queue state by submitting a request while temporarily resetting
    ///      NextLockHeight to 0, then restoring it after. Used by tests that need to verify pre-upgrade
    ///      requests are NOT covered by future lock events.
    function _submitAsPreUpgrade(address user, uint256 amount) internal returns (uint32 id) {
        // Stash NextLockHeight, set to 0 to simulate the pre-V1_3 state, submit, then restore.
        // We also have to re-bootstrap NextLockHeight to the new RedeemDemand after the submission
        // to mirror what V1_3 init would have done at upgrade time.
        bytes32 nextLockHeightSlot = bytes32(uint256(keccak256("river.state.nextLockHeight")) - 1);
        uint256 saved = uint256(vm.load(address(redeemManager), nextLockHeightSlot));
        vm.store(address(redeemManager), nextLockHeightSlot, bytes32(uint256(0)));
        id = _submitRequest(user, amount);
        // After the "pre-upgrade" request lands, set NextLockHeight to current RedeemDemand
        // (this is what initializeRedeemManagerV1_3 would have set at upgrade).
        vm.store(address(redeemManager), nextLockHeightSlot, bytes32(redeemManager.getRedeemDemand()));
        // suppress unused-var warning
        saved;
    }

    // ---- tests --------------------------------------------------------------

    /// @notice lockMaxRedeemableETH only mutates the lock state — no shares burned, no ETH moved.
    function testLockMaxRedeemableETHAppendsEventNoSwap() external {
        address user = makeAddr("user_a");
        _submitRequest(user, 10 ether);

        // Snapshot pre-lock state
        uint256 preRedeemDemand = redeemManager.getRedeemDemand();
        uint256 preLockedDemand = redeemManager.getMaxRedeemableETHLockedDemand();
        uint256 preLockEventCount = redeemManager.getMaxRedeemableETHLockedEventCount();
        uint256 preWithdrawalEventCount = redeemManager.getWithdrawalEventCount();
        uint256 preRMBalance = address(redeemManager).balance;
        uint256 preTotalSupply = river.totalSupply();

        vm.expectEmit(true, true, true, true);
        emit MaxRedeemableETHLocked(0, redeemManager.getNextLockHeight(), 10 ether, 10 ether, 10 ether, 0, 0);
        _lock(10 ether, 10 ether);

        // Lock state advanced
        assertEq(redeemManager.getMaxRedeemableETHLockedEventCount(), preLockEventCount + 1);
        assertEq(redeemManager.getMaxRedeemableETHLockedDemand(), preLockedDemand + 10 ether);
        assertEq(redeemManager.getNextLockHeight(), 10 ether + uint256(_initialNextLockHeight()));

        // Untouched: RedeemDemand, WithdrawalStack, RedeemManager ETH balance, LsETH totalSupply
        assertEq(redeemManager.getRedeemDemand(), preRedeemDemand);
        assertEq(redeemManager.getWithdrawalEventCount(), preWithdrawalEventCount);
        assertEq(address(redeemManager).balance, preRMBalance);
        assertEq(river.totalSupply(), preTotalSupply);

        MaxRedeemableETHLockedStack.MaxRedeemableETHLockedEvent memory ev =
            redeemManager.getMaxRedeemableETHLockedEventDetails(0);
        assertEq(ev.amount, 10 ether);
        assertEq(ev.lockedEth, 10 ether);
    }

    /// @notice The lock event's `lockedEth` overrides the per-request `maxRedeemableEth` at claim
    ///         when the lock covers the slice — this is the heart of the rewards-on-redemption feature.
    function testLockMaxRedeemableETHOverridesPerRequestCap() external {
        address user = makeAddr("user_override");
        // Submit at rate 1.0
        uint32 reqId = _submitRequest(user, 10 ether);

        // Rate appreciates to 1.1 (pool earned 10% — driven by other validators)
        river.sudoSetRate(1.1e18);

        // Validator becomes inactive; lock at the new rate (10 LsETH × 1.1 = 11 ETH)
        _lock(10 ether, 11 ether);

        // Fund the redeem with 11 ETH at the current rate (one WithdrawalEvent)
        _reportWithdraw(10 ether, 11 ether);

        // Claim — user should receive the LOCK cap (11 ETH), not the original request cap (10 ETH)
        uint32[] memory reqIds = new uint32[](1);
        reqIds[0] = reqId;
        uint32[] memory weIds = new uint32[](1);
        weIds[0] = 0;
        uint256 preUserBalance = user.balance;
        redeemManager.claimRedeemRequests(reqIds, weIds);
        assertEq(user.balance - preUserBalance, 11 ether);

        // No excess routed to the buffer (lock cap == withdrawnEth pro-rata)
        assertEq(redeemManager.getBufferedExceedingEth(), 0);
    }

    /// @notice Without the lock-event override, the user would only ever see the request-time cap.
    ///         This is the failure mode the override prevents — assert it actually overrides.
    function testLockMaxRedeemableETHCoversRateAppreciationAfterRequest() external {
        address user = makeAddr("user_apprec");
        _submitRequest(user, 10 ether);
        // request-time maxRedeemableEth was 10 ETH (rate 1.0). After lock at 1.2:
        river.sudoSetRate(1.2e18);
        _lock(10 ether, 12 ether);
        _reportWithdraw(10 ether, 12 ether);

        uint32[] memory reqIds = new uint32[](1);
        reqIds[0] = 0;
        uint32[] memory weIds = new uint32[](1);
        weIds[0] = 0;
        uint256 preBalance = user.balance;
        redeemManager.claimRedeemRequests(reqIds, weIds);
        // User sees the appreciation (12 ETH, NOT capped at the request-time 10 ETH).
        assertEq(user.balance - preBalance, 12 ether);
        assertEq(redeemManager.getBufferedExceedingEth(), 0);
    }

    /// @notice Pre-upgrade requests must NOT be covered by any post-upgrade lock event — they retain
    ///         the request-time maxRedeemableEth cap and behavior is unchanged from V1_2.
    function testLockMaxRedeemableETHRespectsOldMaxRedeemableForPreUpgrade() external {
        address oldUser = makeAddr("user_old");
        address newUser = makeAddr("user_new");
        // Pre-upgrade request at rate 1.0
        _submitAsPreUpgrade(oldUser, 10 ether);
        // Post-upgrade request at rate 1.0
        _submitRequest(newUser, 10 ether);

        // Rate appreciates; lock fires for the post-upgrade portion only
        river.sudoSetRate(1.2e18);
        _lock(10 ether, 12 ether);

        // Single WithdrawalEvent funds both (20 LsETH at current rate = 24 ETH)
        _reportWithdraw(20 ether, 24 ether);

        // Pre-upgrade claim: capped at request-time 10 ETH; rate excess to buffer
        uint32[] memory reqIds = new uint32[](1);
        uint32[] memory weIds = new uint32[](1);
        reqIds[0] = 0;
        weIds[0] = 0;
        uint256 preOld = oldUser.balance;
        redeemManager.claimRedeemRequests(reqIds, weIds);
        assertEq(oldUser.balance - preOld, 10 ether);
        // Pro-rata of withdrawnEth for old's 10 LsETH = (10*24)/20 = 12 ETH; capped to 10 → 2 ETH to buffer
        assertEq(redeemManager.getBufferedExceedingEth(), 2 ether);

        // Post-upgrade claim: lock cap = 12 ETH; should receive full 12 ETH
        reqIds[0] = 1;
        weIds[0] = 0;
        uint256 preNew = newUser.balance;
        redeemManager.claimRedeemRequests(reqIds, weIds);
        assertEq(newUser.balance - preNew, 12 ether);
    }

    /// @notice A request covered by multiple lock events at different rates is paid piecewise.
    ///         Critical multi-event test (per plan).
    function testClaimSpansMultipleLockEvents() external {
        address user = makeAddr("user_multi");
        // 100 LsETH request at rate 1.0 → request-time cap is 100 ETH (won't bind in this test)
        uint32 reqId = _submitRequest(user, 100 ether);

        // Three locks at appreciating rates (R1 < R2 < R3):
        // [0, 30) at 1.05 → 31.5 ETH locked
        // [30, 70) at 1.10 → 44 ETH locked
        // [70, 100) at 1.15 → 34.5 ETH locked
        river.sudoSetRate(1.05e18);
        _lock(30 ether, 31.5 ether);
        river.sudoSetRate(1.10e18);
        _lock(40 ether, 44 ether);
        river.sudoSetRate(1.15e18);
        _lock(30 ether, 34.5 ether);

        // Fund all 100 LsETH with a single WithdrawalEvent at the final rate (1.15 → 115 ETH)
        _reportWithdraw(100 ether, 115 ether);

        uint32[] memory reqIds = new uint32[](1);
        reqIds[0] = reqId;
        uint32[] memory weIds = new uint32[](1);
        weIds[0] = 0;
        uint256 preBalance = user.balance;
        redeemManager.claimRedeemRequests(reqIds, weIds);

        // Expected payout = sum of lockedEth per slice = 31.5 + 44 + 34.5 = 110 ETH
        assertEq(user.balance - preBalance, 110 ether);

        // The 5 ETH delta (115 sent - 110 paid) overflowed each lock-cap pro-rata and routed to buffer
        assertEq(redeemManager.getBufferedExceedingEth(), 5 ether);
    }

    /// @notice A request spanning multiple lock events AND multiple withdrawal events with non-aligned
    ///         boundaries is correctly resolved piecewise.
    function testClaimSpansInterleavedLockAndWithdrawalEvents() external {
        address user = makeAddr("user_inter");
        uint32 reqId = _submitRequest(user, 100 ether);

        // Two locks: [0, 60) at 1.1 (66 ETH), [60, 100) at 1.2 (48 ETH)
        river.sudoSetRate(1.1e18);
        _lock(60 ether, 66 ether);
        river.sudoSetRate(1.2e18);
        _lock(40 ether, 48 ether);

        // Two withdrawal events with non-aligned boundaries: [0, 40), [40, 100)
        // Funded at the current rate of 1.2 — same rate as the second lock, higher than the first
        _reportWithdraw(40 ether, 48 ether); // [0, 40) — 1.2 ETH/LsETH supplied
        _reportWithdraw(60 ether, 72 ether); // [40, 100) — 1.2 ETH/LsETH supplied

        uint32[] memory reqIds = new uint32[](2);
        uint32[] memory weIds = new uint32[](2);
        reqIds[0] = reqId;
        weIds[0] = 0; // start in withdrawal event 0
        reqIds[1] = reqId;
        weIds[1] = 1; // continuation in withdrawal event 1 (after recursion advances)

        // Need only one claim entry — recursion handles event progression internally
        uint32[] memory singleReqIds = new uint32[](1);
        uint32[] memory singleWeIds = new uint32[](1);
        singleReqIds[0] = reqId;
        singleWeIds[0] = 0;
        uint256 preBalance = user.balance;
        redeemManager.claimRedeemRequests(singleReqIds, singleWeIds);

        // Expected piecewise payout:
        //   [0, 40) covered by lock1 (1.1 cap) and wd1 (1.2 supply) → capped at 40*1.1 = 44 ETH (4 ETH to buffer)
        //   [40, 60) covered by lock1 (1.1 cap) and wd2 (1.2 supply) → capped at 20*1.1 = 22 ETH (2 ETH to buffer)
        //   [60, 100) covered by lock2 (1.2 cap) and wd2 (1.2 supply) → 40*1.2 = 48 ETH (no excess)
        // Total to user: 44 + 22 + 48 = 114 ETH
        assertEq(user.balance - preBalance, 114 ether);
        assertEq(redeemManager.getBufferedExceedingEth(), 6 ether);
    }

    /// @notice The over-lock guard reverts when an attempt would push MaxRedeemableETHLockedDemand
    ///         above RedeemDemand.
    function testOverLockReverts() external {
        address user = makeAddr("user_over");
        _submitRequest(user, 10 ether);

        vm.prank(address(river));
        vm.expectRevert(
            abi.encodeWithSelector(IRedeemManagerV1.LockExceedsRedeemDemand.selector, 11 ether, 10 ether)
        );
        redeemManager.lockMaxRedeemableETH(11 ether, 11 ether, 11 ether, 0, 0);
    }

    /// @notice reportWithdraw decrements MaxRedeemableETHLockedDemand by min(_lsETHWithdrawable, locked).
    function testReportWithdrawDecrementsMaxRedeemableETHLockedDemand() external {
        address user = makeAddr("user_decr");
        _submitRequest(user, 10 ether);
        _lock(10 ether, 10 ether);
        assertEq(redeemManager.getMaxRedeemableETHLockedDemand(), 10 ether);

        // Partial reportWithdraw: 3 LsETH → locked demand drops by 3
        _reportWithdraw(3 ether, 3 ether);
        assertEq(redeemManager.getMaxRedeemableETHLockedDemand(), 7 ether);

        // Remaining reportWithdraw: 7 LsETH → locked demand drops to 0
        _reportWithdraw(7 ether, 7 ether);
        assertEq(redeemManager.getMaxRedeemableETHLockedDemand(), 0);
    }

    /// @notice When a reportWithdraw arrives before any lock event covers the demand (pre-upgrade
    ///         tail case), the locked demand decrement is bounded by current value (no underflow).
    function testReportWithdrawDoesNotUnderflowLockedDemand() external {
        address user = makeAddr("user_underflow");
        _submitAsPreUpgrade(user, 10 ether);
        assertEq(redeemManager.getMaxRedeemableETHLockedDemand(), 0);
        _reportWithdraw(10 ether, 10 ether);
        assertEq(redeemManager.getMaxRedeemableETHLockedDemand(), 0);
    }

    /// @notice getEffectiveCapForDemand sums lockedEth across the lock-covered portion and falls back
    ///         to per-request maxRedeemableEth for any uncovered tail.
    function testGetEffectiveCapForDemandMixed() external {
        address oldUser = makeAddr("user_mix_old");
        address newUser = makeAddr("user_mix_new");
        _submitAsPreUpgrade(oldUser, 10 ether); // request 0: pre-upgrade, [0, 10), cap=10 ETH
        _submitRequest(newUser, 10 ether); // request 1: post-upgrade, [10, 20), cap=10 ETH (request-time)

        // Rate appreciates; lock fires for the post-upgrade slice only
        river.sudoSetRate(1.3e18);
        _lock(10 ether, 13 ether); // covers [10, 20), cap=13 ETH

        // Cap for the full 20 LsETH demand = 10 (pre-upgrade, fallback) + 13 (lock) = 23 ETH
        assertEq(redeemManager.getEffectiveCapForDemand(20 ether), 23 ether);

        // Cap for the first 10 (pre-upgrade portion only)
        assertEq(redeemManager.getEffectiveCapForDemand(10 ether), 10 ether);

        // Cap for 15 LsETH straddles: 10 (pre) + 5 (lock pro-rata = 5*13/10 = 6.5) = 16.5 ETH
        assertEq(redeemManager.getEffectiveCapForDemand(15 ether), 16.5 ether);
    }

    /// @notice getEffectiveCapForDemand aggregates across multiple lock events.
    function testGetEffectiveCapForDemandAcrossMultipleLockEvents() external {
        address user = makeAddr("user_acc");
        _submitRequest(user, 100 ether);

        river.sudoSetRate(1.05e18);
        _lock(30 ether, 31.5 ether);
        river.sudoSetRate(1.10e18);
        _lock(40 ether, 44 ether);
        river.sudoSetRate(1.15e18);
        _lock(30 ether, 34.5 ether);

        // Aggregate for full 100 = 31.5 + 44 + 34.5 = 110 ETH
        assertEq(redeemManager.getEffectiveCapForDemand(100 ether), 110 ether);
        // Aggregate for first 70 LsETH (across two lock events) = 31.5 + 44 = 75.5 ETH
        assertEq(redeemManager.getEffectiveCapForDemand(70 ether), 75.5 ether);
        // Aggregate for 50 LsETH (first lock event fully + 20/40 of second) = 31.5 + (20*44)/40 = 53.5 ETH
        assertEq(redeemManager.getEffectiveCapForDemand(50 ether), 53.5 ether);
    }

    /// @notice A lock event with `fromRebalancing > 0` advances the same stack as inactivity locks
    ///         and follows the same override semantics at claim. This test exercises the rebalance
    ///         attribution path through RedeemManager (River-level integration covered elsewhere).
    function testRebalanceLockFiresOnDepositToRedeem() external {
        address user = makeAddr("user_rebal");
        _submitRequest(user, 10 ether);

        river.sudoSetRate(1.1e18);
        // Simulate the rebalance lock the way River would fire it from
        // _requestExitsBasedOnRedeemDemandAfterRebalancings
        vm.expectEmit(true, true, true, true);
        emit MaxRedeemableETHLocked(0, redeemManager.getNextLockHeight(), 10 ether, 11 ether, 0, 0, 11 ether);
        _lockFromRebalance(10 ether, 11 ether);

        // Claim at rebalance-time rate
        _reportWithdraw(10 ether, 11 ether);
        uint32[] memory reqIds = new uint32[](1);
        uint32[] memory weIds = new uint32[](1);
        reqIds[0] = 0;
        weIds[0] = 0;
        uint256 preBalance = user.balance;
        redeemManager.claimRedeemRequests(reqIds, weIds);
        assertEq(user.balance - preBalance, 11 ether);
    }

    /// @notice Two lock events fire in the same flow (one inactivity, one rebalance) and cover
    ///         disjoint slices; claim resolves piecewise.
    function testTwoLockEventsInOneReport() external {
        address user = makeAddr("user_two");
        _submitRequest(user, 20 ether);

        river.sudoSetRate(1.1e18);
        // Inactivity lock for first 10 LsETH at 1.1 (11 ETH)
        _lock(10 ether, 11 ether);
        // Rebalance lock for next 10 LsETH at 1.1 (11 ETH)
        _lockFromRebalance(10 ether, 11 ether);

        // Stack now has 2 events covering [0, 20) disjointly
        assertEq(redeemManager.getMaxRedeemableETHLockedEventCount(), 2);
        assertEq(redeemManager.getMaxRedeemableETHLockedDemand(), 20 ether);

        _reportWithdraw(20 ether, 22 ether);
        uint32[] memory reqIds = new uint32[](1);
        uint32[] memory weIds = new uint32[](1);
        reqIds[0] = 0;
        weIds[0] = 0;
        uint256 preBalance = user.balance;
        redeemManager.claimRedeemRequests(reqIds, weIds);
        assertEq(user.balance - preBalance, 22 ether);
    }

    /// @notice Over-locking via rebalance is also gated by the unlocked-head guard.
    function testRebalanceLockRespectsUnlockedHead() external {
        address user = makeAddr("user_head");
        _submitRequest(user, 10 ether);
        _lock(5 ether, 5 ether); // first 5 LsETH locked → only 5 LsETH unlocked head remains

        vm.prank(address(river));
        vm.expectRevert(
            abi.encodeWithSelector(IRedeemManagerV1.LockExceedsRedeemDemand.selector, 6 ether, 5 ether)
        );
        redeemManager.lockMaxRedeemableETH(6 ether, 6 ether, 0, 0, 6 ether);
    }

    /// @notice Pre-upgrade-style request claimed after a post-upgrade reportWithdraw still pays at the
    ///         request-time cap (no retroactive value transfer). The Pre-upgrade tail case from the plan.
    function testPreUpgradeTailAtReportWithdraw() external {
        address oldUser = makeAddr("user_tail_old");
        _submitAsPreUpgrade(oldUser, 10 ether);

        river.sudoSetRate(2e18);
        // No lock fires for the pre-upgrade slice. reportWithdraw at rate 2.0 supplies 20 ETH.
        _reportWithdraw(10 ether, 20 ether);

        uint32[] memory reqIds = new uint32[](1);
        uint32[] memory weIds = new uint32[](1);
        reqIds[0] = 0;
        weIds[0] = 0;
        uint256 preBalance = oldUser.balance;
        redeemManager.claimRedeemRequests(reqIds, weIds);
        // Pre-upgrade cap = 10 ETH; user gets 10 ETH; 10 ETH excess to buffer
        assertEq(oldUser.balance - preBalance, 10 ether);
        assertEq(redeemManager.getBufferedExceedingEth(), 10 ether);
    }

    // The initial NextLockHeight after V1_3 init (RedeemDemand at init time = 0 because nothing
    // was submitted in the base setUp).
    function _initialNextLockHeight() internal pure returns (uint256) {
        return 0;
    }
}
