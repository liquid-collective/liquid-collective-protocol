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

    function sharesFromUnderlyingBalance(uint256 balance) external view returns (uint256) {
        return (balance * 1e18) / rate;
    }

    /// @notice Reports a stopped-earning amount valued at the mock's current rate, the way River values
    ///         it from its pre-report snapshot
    function sudoReportStoppedEarning(address redeemManager, uint256 stoppedEarningEth) external {
        RedeemManagerV1(redeemManager).reportStoppedEarning(stoppedEarningEth, (stoppedEarningEth * 1e18) / rate);
    }

    /// @notice Reports a stopped-earning amount with an explicitly chosen LsETH leg, so tests can pin the
    ///         locked rate to something other than the mock's live rate
    function sudoReportStoppedEarningAt(address redeemManager, uint256 stoppedEarningEth, uint256 stoppedEarningLsETH)
        external
    {
        RedeemManagerV1(redeemManager).reportStoppedEarning(stoppedEarningEth, stoppedEarningLsETH);
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
    /// @dev Word count of RedeemRequestAnchor.Anchor
    uint256 internal constant ANCHOR_WORDS = 3;

    event RequestedRedeem(address indexed recipient, uint256 height, uint256 size, uint256 maxRedeemableEth, uint32 id);
    event ReportedWithdrawal(uint256 height, uint256 size, uint256 ethAmount, uint32 id);
    event CreditedStoppedEarning(uint32 indexed redeemRequestId, uint256 lsETHCredited, uint256 ethCredited);
    event ReportedStoppedEarning(uint256 reportedLsETH, uint256 creditedLsETH, uint256 droppedLsETH);
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

    /// @notice The request-time value is a one-sided CAP, never a floor: when the pool rate falls
    ///         between request and settlement the redeemer is paid the full, lower settlement rate.
    /// @dev testClaimMultiRate above only ever settles at rates >= the request rates, so it exercises
    ///      the cap branch exclusively. This is the complementary branch — the one that decides
    ///      whether redeemers bear slashing on the same terms as remaining holders — and it had no
    ///      coverage.
    function testClaimSettlementRateBelowRequestRateChargesFullLossToRedeemer() external {
        address user = _generateAllowlistedUser(0);

        uint256 requestRate = 1_200_000_000_000_000_000; // 1.2
        uint256 settlementRate = 900_000_000_000_000_000; // 0.9 — pool impaired after the request

        river.sudoSetRate(requestRate);
        river.sudoDeal(user, 30e18);
        vm.prank(user);
        river.approve(address(redeemManager), 30e18);
        vm.prank(user);
        redeemManager.requestRedeem(30e18, user);

        // the cap is recorded at the request-time rate
        assertEq(redeemManager.getRedeemRequestDetails(0).maxRedeemableEth, applyRate(30e18, requestRate));

        river.sudoSetRate(settlementRate);

        uint256 withdrawnEth = applyRate(30e18, settlementRate);
        vm.deal(address(this), withdrawnEth);
        river.sudoReportWithdraw{value: withdrawnEth}(address(redeemManager), 30e18);

        uint32[] memory ids = new uint32[](1);
        uint32[] memory withdrawalEventIds = new uint32[](1);

        uint256 balanceBefore = user.balance;
        redeemManager.claimRedeemRequests(ids, withdrawalEventIds);
        uint256 received = user.balance - balanceBefore;

        // the redeemer is paid at the depressed settlement rate — the request-time value is NOT a floor
        assertEq(received, withdrawnEth);
        assertEq((received * 1e18) / 30e18, settlementRate);
        assertTrue(received < applyRate(30e18, requestRate));

        // nothing is confiscated: the cap never bound
        assertEq(redeemManager.getBufferedExceedingEth(), 0);

        // the request is fully claimed, yet the unspent cap is stranded on it forever
        RedeemQueueV2.RedeemRequest memory request = redeemManager.getRedeemRequestDetails(0);
        assertEq(request.amount, 0);
    }

    /// @notice maxRedeemableEth is a decrementing ETH budget, not a rate: after a partial claim
    ///         settled BELOW the request rate, the implied per-LsETH cap (maxRedeemableEth / amount)
    ///         drifts far above the true request-time rate.
    /// @dev Pins the trap for any future change that reads maxRedeemableEth / amount as "the rate at
    ///      request time". Only sum(payouts) <= originalAmount * rate_at_request is invariant.
    function testPartialClaimBelowRequestRateDriftsImpliedCapRate() external {
        address user = _generateAllowlistedUser(0);

        uint256 requestRate = 1e18; // 1.0
        uint256 settlementRate = 500_000_000_000_000_000; // 0.5

        river.sudoSetRate(requestRate);
        river.sudoDeal(user, 100e18);
        vm.prank(user);
        river.approve(address(redeemManager), 100e18);
        vm.prank(user);
        redeemManager.requestRedeem(100e18, user);

        // implied cap rate at creation == the request rate
        RedeemQueueV2.RedeemRequest memory request = redeemManager.getRedeemRequestDetails(0);
        assertEq((request.maxRedeemableEth * 1e18) / request.amount, requestRate);

        river.sudoSetRate(settlementRate);

        // settle only 99 of the 100 LsETH, at half the request rate
        uint256 withdrawnEth = applyRate(99e18, settlementRate);
        vm.deal(address(this), withdrawnEth);
        river.sudoReportWithdraw{value: withdrawnEth}(address(redeemManager), 99e18);

        uint32[] memory ids = new uint32[](1);
        uint32[] memory withdrawalEventIds = new uint32[](1);
        redeemManager.claimRedeemRequests(ids, withdrawalEventIds);

        request = redeemManager.getRedeemRequestDetails(0);
        assertEq(request.amount, 1e18);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Stopped-earning rate marks
    //
    // Payout stays min(settlement value, cap). What changes is that the cap is raised from
    // rate_at_request to the pool rate of the report in which the backing principal crossed
    // exit_epoch, over exactly the marked slice. So: a fill involving no exit still pays
    // rate_at_request, accrual stops where a native staker's would, and the downside still
    // passes through because the clamp against the withdrawal event's real ETH is untouched.
    // ─────────────────────────────────────────────────────────────────────────

    /// @dev The LsETH width of `id` whose backing principal has been reported as stopped earning.
    ///      Replaces the rate mark stack's `amount`, which recorded the same width positionally.
    function _creditedLsETH(uint32 id) internal view returns (uint256) {
        return redeemManager.getRedeemRequestAnchor(id).creditedLsETH;
    }

    /// @dev The eth `id` has been credited and not yet released to a fill. Replaces the rate mark
    ///      stack's `markedEth`.
    function _creditedEth(uint32 id) internal view returns (uint256) {
        return redeemManager.getRedeemRequestCreditedEth(id);
    }

    /// @dev The cap `id` was offered by earlier fills and did not spend.
    function _unspentCap(uint32 id) internal view returns (uint256) {
        return redeemManager.getRedeemRequestUnspentCap(id);
    }

    /// @dev Opens a redeem request of `amount` LsETH for `user` at the current pool rate.
    function _openRequest(address user, uint256 amount) internal returns (uint32 id) {
        river.sudoDeal(user, amount);
        vm.prank(user);
        river.approve(address(redeemManager), amount);
        vm.prank(user);
        return redeemManager.requestRedeem(amount, user);
    }

    /// @dev Puts the contract in the state a live deployment is in just before the stopped-earning
    ///      upgrade, then applies it. setUp only runs initializeRedeemManagerV1, leaving the version at
    ///      1, whereas mainnet is already at 2.
    /// @dev The version is poked rather than reached by calling initializeRedeemManagerV1_2, because
    ///      RedeemQueueV1 and RedeemQueueV2 share the storage slot
    ///      keccak256("river.state.redeemQueue") - 1. Its migration re-interprets that array in place and
    ///      is only safe because init(1) runs it exactly once, before any V2 request exists. Running it
    ///      over a populated V2 queue silently corrupts every element.
    function _pokeVersionTo(uint256 version) internal {
        vm.store(address(redeemManager), bytes32(uint256(keccak256("river.state.version")) - 1), bytes32(version));
    }

    function _upgradeToV1_3() internal {
        _pokeVersionTo(2);
        redeemManager.initializeRedeemManagerV1_3();
    }

    /// @dev Makes a request look the way one created before the stopped-earning upgrade does. Two
    ///      things define that state. The anchor is absent, which is what selects the pre-upgrade code
    ///      path, and `maxRedeemableEth` holds the request-time eth budget the pre-upgrade path caps
    ///      against. Both are set explicitly, because an anchored request stops carrying a budget in
    ///      that field once the credited-eth counter moves into it.
    function _clearRequestAnchor(uint32 id) internal {
        uint256 requestTimeEth = redeemManager.getRedeemRequestAnchor(id).ethAtRequest;

        bytes32 anchorSlot =
            keccak256(abi.encode(uint256(id), bytes32(uint256(keccak256("river.state.redeemRequestAnchor")) - 1)));
        for (uint256 word = 0; word < ANCHOR_WORDS; ++word) {
            vm.store(address(redeemManager), bytes32(uint256(anchorSlot) + word), bytes32(0));
        }
        assertEq(redeemManager.getRedeemRequestAnchor(id).lsETHAtRequest, 0);

        uint256 base = uint256(keccak256(abi.encode(REDEEM_QUEUE_ID_SLOT)));
        vm.store(address(redeemManager), bytes32(base + uint256(id) * 5 + 1), bytes32(requestTimeEth));
        assertEq(redeemManager.getRedeemRequestDetails(id).maxRedeemableEth, requestTimeEth);
    }

    /// @dev Settles `lsETH` of demand at the current pool rate and claims request `id` in full.
    function _settleAndClaim(uint32 id, uint256 lsETH, uint256 settlementRate) internal returns (uint256 received) {
        uint256 withdrawnEth = applyRate(lsETH, settlementRate);
        vm.deal(address(this), withdrawnEth);
        river.sudoReportWithdraw{value: withdrawnEth}(address(redeemManager), lsETH);

        uint32[] memory ids = new uint32[](1);
        ids[0] = id;
        int64[] memory resolved = redeemManager.resolveRedeemRequests(ids);
        uint32[] memory eventIds = new uint32[](1);
        eventIds[0] = uint32(uint64(resolved[0]));

        address recipient = redeemManager.getRedeemRequestDetails(id).recipient;
        uint256 before = recipient.balance;
        redeemManager.claimRedeemRequests(ids, eventIds);
        return recipient.balance - before;
    }

    /// @dev Opens a 30 LsETH request at a rate of 1.0, then settles it in two withdrawal events and
    ///      claims after each: 20 LsETH priced at 0.5, then the remaining 10 LsETH priced at 1.5.
    ///      With `_clearAnchor` the request is made to look pre-upgrade, taking the legacy budget path.
    function _lowThenHighFill(uint256 _salt, bool _clearAnchor) internal returns (uint256 received) {
        address user = _generateAllowlistedUser(_salt);
        river.sudoSetRate(1e18);
        uint32 id = _openRequest(user, 30e18);
        assertEq(redeemManager.getRedeemRequestDetails(id).maxRedeemableEth, applyRate(30e18, 1e18));

        if (_clearAnchor) {
            _clearRequestAnchor(id);
        }

        // nothing is ever credited: the whole span is capped at the request rate
        received = _settleAndClaim(id, 20e18, 0.5e18) + _settleAndClaim(id, 10e18, 1.5e18);
        assertEq(_creditedLsETH(id), 0);
        assertEq(redeemManager.getRedeemRequestDetails(id).amount, 0);
    }

    /// A request settled by several withdrawal events is capped once per event, so a fill that settles
    /// BELOW its cap leaves headroom that the next fill must still be able to spend. The cheap fill uses
    /// 10 of its 20 ETH slice cap; the 10 ETH it did not spend is carried, so the expensive fill is worth
    /// 15 ETH and is paid all 15 rather than being clipped to its own 10 ETH slice value.
    /// @dev Pairs with testLegacyCapCarriesUnusedHeadroomAcrossEvents: the anchored path must pay exactly
    ///      what the pre-upgrade path pays here, because no rate mark is involved. How a settlement is
    ///      chunked across events is an oracle-reporting artifact and must not change the payout.
    function testAnchoredCapCarriesUnusedHeadroomAcrossEvents() external {
        assertEq(_lowThenHighFill(0, false), applyRate(20e18, 0.5e18) + applyRate(10e18, 1.5e18));
        assertEq(redeemManager.getBufferedExceedingEth(), 0);
    }

    /// Legacy path, same two fills. `maxRedeemableEth` is one decrementing ETH budget for the whole
    /// request, so the 10 ETH the cheap fill did not spend is still on it when the expensive fill lands:
    /// that fill is paid in full at 15 ETH and nothing is confiscated.
    function testLegacyCapCarriesUnusedHeadroomAcrossEvents() external {
        assertEq(_lowThenHighFill(0, true), applyRate(20e18, 0.5e18) + applyRate(10e18, 1.5e18));
        assertEq(redeemManager.getBufferedExceedingEth(), 0);
    }

    /// The unspent balance is never a budget the credited uplift is drawn from. A fill
    /// paid above the request rate because its span was marked must therefore leave the request-rate value
    /// of the UNMARKED remainder fully payable: 15 LsETH at the locked 2.0 plus 15 at the request 1.0.
    /// @dev This is the case a decrementing-budget fix gets wrong — there the 30 ETH uplift payout drains
    ///      the 30 ETH budget and the unmarked remainder is paid nothing.
    function testMarkUpliftDoesNotConsumeCapOfUnmarkedRemainder() external {
        address user = _generateAllowlistedUser(0);
        river.sudoSetRate(1e18);
        uint32 id = _openRequest(user, 30e18);

        // credit only the first 15 LsETH of the request, locking it at a rate of 2.0
        river.sudoReportStoppedEarningAt(address(redeemManager), applyRate(15e18, 2e18), 15e18);
        assertEq(_creditedLsETH(id), 15e18);
        assertEq(_creditedEth(id), applyRate(15e18, 2e18));

        uint256 received = _settleAndClaim(id, 15e18, 2e18) + _settleAndClaim(id, 15e18, 1e18);

        assertEq(received, applyRate(15e18, 2e18) + applyRate(15e18, 1e18));
        assertEq(redeemManager.getBufferedExceedingEth(), 0);
    }

    /// Splitting a marked request across two withdrawal events must not cap it at its request-time value.
    /// The carry only ever adds to a slice's cap, so the locked 1.05 rate survives the split and the total
    /// still exceeds `Anchor.ethAtRequest` — which is the entire point of a mark.
    function testMarkedSpanSplitAcrossEventsStillExceedsRequestValue() external {
        address user = _generateAllowlistedUser(0);
        river.sudoSetRate(1e18);
        uint32 id = _openRequest(user, 30e18);

        river.sudoSetRate(1.05e18);
        river.sudoReportStoppedEarning(address(redeemManager), applyRate(30e18, 1.05e18));
        assertEq(_creditedLsETH(id), 30e18);

        uint256 received = _settleAndClaim(id, 15e18, 1.05e18) + _settleAndClaim(id, 15e18, 1.05e18);

        assertEq(received, applyRate(30e18, 1.05e18));
        assertGt(received, redeemManager.getRedeemRequestAnchor(id).ethAtRequest);
    }

    /// A fully claimed request can never read its carry again, so the final fill clears the slot instead
    /// of stranding dust in storage forever.
    function testCarryIsClearedWhenRequestIsFullyClaimed() external {
        uint256 received = _lowThenHighFill(0, false);
        assertEq(received, applyRate(20e18, 0.5e18) + applyRate(10e18, 1.5e18));
        assertEq(redeemManager.getRedeemRequestCreditedEth(0), 0);
    }

    /// @dev Reports a withdrawal event for `lsETH` priced at `settlementRate` without claiming against it,
    ///      so a test can stack several events before a single claim walks them.
    function _settleOnly(uint256 lsETH, uint256 settlementRate) internal {
        uint256 withdrawnEth = applyRate(lsETH, settlementRate);
        vm.deal(address(this), withdrawnEth);
        river.sudoReportWithdraw{value: withdrawnEth}(address(redeemManager), lsETH);
    }

    /// The same two fills as testAnchoredCapCarriesUnusedHeadroomAcrossEvents, but both withdrawal events
    /// are reported before a single `claimRedeemRequests` call, so `_claimRedeemRequest` recurses across
    /// them rather than being entered twice. The carry rides that recursion in memory, so the payout must
    /// be identical: whether a redeemer claims eagerly or lazily cannot change what they are owed.
    function testAnchoredCapCarriesUnusedHeadroomAcrossOneRecursiveClaim() external {
        address user = _generateAllowlistedUser(0);
        river.sudoSetRate(1e18);
        uint32 id = _openRequest(user, 30e18);

        _settleOnly(20e18, 0.5e18);
        _settleOnly(10e18, 1.5e18);
        assertEq(redeemManager.getWithdrawalEventCount(), 2);

        uint32[] memory ids = new uint32[](1);
        ids[0] = id;
        int64[] memory resolved = redeemManager.resolveRedeemRequests(ids);
        uint32[] memory eventIds = new uint32[](1);
        eventIds[0] = uint32(uint64(resolved[0]));

        uint256 before = user.balance;
        redeemManager.claimRedeemRequests(ids, eventIds);
        uint256 received = user.balance - before;

        assertEq(received, applyRate(20e18, 0.5e18) + applyRate(10e18, 1.5e18));
        assertEq(redeemManager.getRedeemRequestDetails(id).amount, 0);
        assertEq(redeemManager.getBufferedExceedingEth(), 0);
        assertEq(_unspentCap(id), 0);
    }

    /// The claim loop reuses one `ClaimRedeemRequestParameters` across requests, so a request that leaves
    /// carry behind must not leak it into the next id in the same batch. Both requests are opened at the
    /// same rate and settled by one event below that rate, so neither may be paid above its own settlement.
    function testCarryDoesNotLeakBetweenRequestsInOneBatch() external {
        address userA = _generateAllowlistedUser(0);
        address userB = _generateAllowlistedUser(1);
        river.sudoSetRate(1e18);
        uint32 idA = _openRequest(userA, 30e18);
        uint32 idB = _openRequest(userB, 30e18);

        // one event covering both requests, settling everything at half the request rate
        _settleOnly(60e18, 0.5e18);

        uint32[] memory ids = new uint32[](2);
        ids[0] = idA;
        ids[1] = idB;
        uint32[] memory eventIds = new uint32[](2);

        uint256 beforeA = userA.balance;
        uint256 beforeB = userB.balance;
        redeemManager.claimRedeemRequests(ids, eventIds);

        assertEq(userA.balance - beforeA, applyRate(30e18, 0.5e18));
        assertEq(userB.balance - beforeB, applyRate(30e18, 0.5e18));
        assertEq(redeemManager.getRedeemRequestCreditedEth(idA), 0);
        assertEq(redeemManager.getRedeemRequestCreditedEth(idB), 0);
    }

    /// The carry is visible between fills, not only at the end: after the cheap fill it holds exactly the
    /// 10 ETH of slice cap that fill did not spend.
    function testCarryHoldsUnspentCapBetweenFills() external {
        address user = _generateAllowlistedUser(0);
        river.sudoSetRate(1e18);
        uint32 id = _openRequest(user, 30e18);
        assertEq(_unspentCap(id), 0);

        assertEq(_settleAndClaim(id, 20e18, 0.5e18), applyRate(20e18, 0.5e18));
        // slice cap was 20 ETH at the request rate, 10 ETH was paid
        assertEq(_unspentCap(id), applyRate(20e18, 1e18) - applyRate(20e18, 0.5e18));
    }

    /// FR1/AC2: a fill backed by no stopped-earning principal accrues nothing beyond
    /// rate_at_request, even though the pool rate rose. No mark is pushed, so the whole slice sits
    /// in a gap and is capped at the request rate; the appreciation is confiscated exactly as today.
    function testUnmarkedRequestPaysExactlyRequestRate() external {
        address user = _generateAllowlistedUser(0);
        river.sudoSetRate(1e18);
        uint32 id = _openRequest(user, 30e18);

        river.sudoSetRate(1.05e18);
        uint256 received = _settleAndClaim(id, 30e18, 1.05e18);

        assertEq(received, applyRate(30e18, 1e18));
        assertEq(_creditedLsETH(id), 0);
        assertEq(redeemManager.getBufferedExceedingEth(), applyRate(30e18, 1.05e18) - applyRate(30e18, 1e18));
    }

    /// FR1/AC1: once the backing principal is reported as having stopped earning, the cap rises to
    /// that report's rate and the redeemer keeps the exit-queue appreciation instead of the pool.
    function testMarkedRequestPaysMarkRate() external {
        address user = _generateAllowlistedUser(0);
        river.sudoSetRate(1e18);
        uint32 id = _openRequest(user, 30e18);

        // the principal backing this request crossed exit_epoch while the pool rate was 1.05
        river.sudoSetRate(1.05e18);
        river.sudoReportStoppedEarning(address(redeemManager), applyRate(30e18, 1.05e18));

        assertEq(_creditedLsETH(id), 30e18);
        assertEq(_creditedEth(id), applyRate(30e18, 1.05e18));

        uint256 received = _settleAndClaim(id, 30e18, 1.05e18);

        assertEq(received, applyRate(30e18, 1.05e18));
        assertEq(redeemManager.getBufferedExceedingEth(), 0);
    }

    /// Section 6 non-goals: accrual stops at exit_epoch. Pool appreciation between the mark and
    /// settlement — the withdrawability delay and the sweep tail — is NOT captured by the redeemer.
    function testMarkCapsAccrualAtStoppedEarningRate() external {
        address user = _generateAllowlistedUser(0);
        river.sudoSetRate(1e18);
        uint32 id = _openRequest(user, 30e18);

        river.sudoSetRate(1.05e18);
        river.sudoReportStoppedEarning(address(redeemManager), applyRate(30e18, 1.05e18));

        // pool keeps appreciating while the principal sits in withdrawability + sweep
        river.sudoSetRate(1.1e18);
        uint256 received = _settleAndClaim(id, 30e18, 1.1e18);

        assertEq(received, applyRate(30e18, 1.05e18));
        // the post-exit_epoch appreciation goes back to remaining holders, as before
        assertEq(redeemManager.getBufferedExceedingEth(), applyRate(30e18, 1.1e18) - applyRate(30e18, 1.05e18));
    }

    /// FR2/AC1+AC2: the downside passes through. The mark is a two-sided re-pricing with no floor on
    /// either side, so a redeemer whose pool loses value between the mark and settlement is paid the
    /// depressed settlement rate. This is NOT the same terms as a holder who stayed: a holder would
    /// receive a later recovery, whereas a marked redeemer's cap stays pinned at the marked rate.
    function testMarkIsNotAFloorOnSlashing() external {
        address user = _generateAllowlistedUser(0);
        river.sudoSetRate(1e18);
        uint32 id = _openRequest(user, 30e18);

        river.sudoSetRate(1.05e18);
        river.sudoReportStoppedEarning(address(redeemManager), applyRate(30e18, 1.05e18));

        // slashing after the mark
        river.sudoSetRate(0.95e18);
        uint256 received = _settleAndClaim(id, 30e18, 0.95e18);

        assertEq(received, applyRate(30e18, 0.95e18));
        assertEq((received * 1e18) / 30e18, 0.95e18);
        assertEq(redeemManager.getBufferedExceedingEth(), 0);
    }

    /// A request only partly backed by stopped-earning principal gets a blended cap: the credited
    /// width at the locked rate, the rest at the request rate. This is the pooled-exit case — one
    /// exit rarely lines up with one request.
    function testPartiallyCreditedRequestBlendsCreditedAndRequestRates() external {
        address user = _generateAllowlistedUser(0);
        river.sudoSetRate(1e18);
        uint32 id = _openRequest(user, 30e18);

        // only 10 of the 30 LsETH is backed by principal that stopped earning
        river.sudoSetRate(1.05e18);
        river.sudoReportStoppedEarning(address(redeemManager), applyRate(10e18, 1.05e18));
        assertEq(_creditedLsETH(id), 10e18);

        river.sudoSetRate(1.05e18);
        uint256 received = _settleAndClaim(id, 30e18, 1.05e18);

        uint256 expected = applyRate(10e18, 1.05e18) + applyRate(20e18, 1e18);
        assertEq(received, expected);
        assertEq(redeemManager.getBufferedExceedingEth(), applyRate(30e18, 1.05e18) - expected);
    }

    /// Credit accumulates across reports, so a request that waits longer earns more — the exit-queue
    /// duration shows up directly as the credited width.
    function testCreditAccumulatesAcrossReports() external {
        address user = _generateAllowlistedUser(0);
        river.sudoSetRate(1e18);
        uint32 id = _openRequest(user, 30e18);

        river.sudoSetRate(1.02e18);
        river.sudoReportStoppedEarning(address(redeemManager), applyRate(10e18, 1.02e18));
        river.sudoSetRate(1.04e18);
        river.sudoReportStoppedEarning(address(redeemManager), applyRate(20e18, 1.04e18));

        assertEq(_creditedLsETH(id), 30e18);
        assertEq(_creditedEth(id), applyRate(10e18, 1.02e18) + applyRate(20e18, 1.04e18));

        river.sudoSetRate(1.06e18);
        uint256 received = _settleAndClaim(id, 30e18, 1.06e18);

        assertEq(received, applyRate(10e18, 1.02e18) + applyRate(20e18, 1.04e18));
    }

    /// Reported stopped-earning principal is clamped to the creditable demand. Most exits do not back
    /// a redemption at all, so the reported figure routinely dwarfs the pending queue; the surplus
    /// must be dropped, not carried, and must be observable.
    function testReportStoppedEarningClampsToCreditableDemand() external {
        address user = _generateAllowlistedUser(0);
        river.sudoSetRate(1e18);
        uint32 id = _openRequest(user, 30e18);

        vm.expectEmit(true, true, true, true);
        emit ReportedStoppedEarning(100e18, 30e18, 0);
        river.sudoReportStoppedEarning(address(redeemManager), 100e18);

        assertEq(_creditedLsETH(id), 30e18);

        // a second report finds nothing creditable and must credit nothing
        vm.expectEmit(true, true, true, true);
        emit ReportedStoppedEarning(100e18, 0, 0);
        river.sudoReportStoppedEarning(address(redeemManager), 100e18);
        assertEq(_creditedLsETH(id), 30e18);
        assertEq(_creditedEth(id), 30e18);
    }

    /// The locked rate is the (eth, LsETH) pair River passes in, and nothing else. River values the
    /// delta from its pre-report snapshot; by the time this call lands River has already applied the
    /// report and minted the interval's fee, so reading the rate live here would credit the redeemer
    /// with the very interval during which their principal stopped earning.
    function testCreditUsesReportedPairNotLiveRate() external {
        address user = _generateAllowlistedUser(0);
        river.sudoSetRate(1e18);
        uint32 id = _openRequest(user, 30e18);

        // River reports 30 LsETH of principal valued at its pre-report rate of 1.02, while its live
        // rate has already rebased to 1.1
        river.sudoSetRate(1.1e18);
        river.sudoReportStoppedEarningAt(address(redeemManager), applyRate(30e18, 1.02e18), 30e18);

        assertEq(_creditedLsETH(id), 30e18);
        assertEq(_creditedEth(id), applyRate(30e18, 1.02e18));

        // and the cap follows the credit, not the rate the pool ended the interval on
        uint256 received = _settleAndClaim(id, 30e18, 1.1e18);
        assertEq(received, applyRate(30e18, 1.02e18));
        assertEq(redeemManager.getBufferedExceedingEth(), applyRate(30e18, 1.1e18) - applyRate(30e18, 1.02e18));
    }

    /// When the reported principal overshoots the creditable demand, the eth leg must be scaled down
    /// in the same proportion as the LsETH leg: the clamp shortens the credited width, it must not
    /// re-rate it. testReportStoppedEarningClampsToCreditableDemand runs at a 1:1 rate, where a
    /// mis-scaled eth leg is indistinguishable from a correct one.
    function testClampedCreditPreservesReportedRate() external {
        address user = _generateAllowlistedUser(0);
        river.sudoSetRate(1e18);
        uint32 id = _openRequest(user, 30e18);

        // 100 LsETH of principal stopped earning at a rate of 1.05, but only 30 LsETH is creditable
        uint256 reportedEth = applyRate(100e18, 1.05e18);
        vm.expectEmit(true, true, true, true);
        emit ReportedStoppedEarning(100e18, 30e18, 0);
        river.sudoReportStoppedEarningAt(address(redeemManager), reportedEth, 100e18);

        assertEq(_creditedLsETH(id), 30e18);
        assertEq(_creditedEth(id), applyRate(30e18, 1.05e18));
        // the locked rate survives the clamp exactly
        assertEq(_creditedEth(id) * 100e18, reportedEth * 30e18);

        river.sudoSetRate(1.05e18);
        assertEq(_settleAndClaim(id, 30e18, 1.05e18), applyRate(30e18, 1.05e18));
    }

    /// Credit never covers demand that a withdrawal event has already priced. Otherwise a redeemer
    /// would be credited pool appreciation earned after their principal stopped earning.
    function testCreditSkipsAlreadySettledDemand() external {
        address user = _generateAllowlistedUser(0);
        river.sudoSetRate(1e18);
        uint32 first = _openRequest(user, 30e18);
        uint32 second = _openRequest(user, 30e18);

        // settle the first request without ever marking it
        uint256 withdrawnEth = applyRate(30e18, 1e18);
        vm.deal(address(this), withdrawnEth);
        river.sudoReportWithdraw{value: withdrawnEth}(address(redeemManager), 30e18);

        river.sudoSetRate(1.05e18);
        river.sudoReportStoppedEarning(address(redeemManager), applyRate(30e18, 1.05e18));

        // the credit lands on the unsettled request, and the settled one is passed over for good
        assertEq(_creditedLsETH(first), 0);
        assertEq(_creditedLsETH(second), 30e18);
        assertEq(redeemManager.getLockPositionCursor(), 60e18);

        uint256 received = _settleAndClaim(second, 30e18, 1.05e18);
        assertEq(received, applyRate(30e18, 1.05e18));
    }

    /// A request settled before any report reaches it is never credited, which happens whenever
    /// settlement outruns reporting (a fill funded from the deposit buffer). It must be capped at the
    /// request rate.
    function testClaimOfUncreditedRequestPaysRequestRate() external {
        address user = _generateAllowlistedUser(0);
        river.sudoSetRate(1e18);
        uint32 first = _openRequest(user, 30e18);
        uint32 second = _openRequest(user, 30e18);

        // the first request is settled at an appreciated rate without ever being marked
        river.sudoSetRate(1.05e18);
        uint256 withdrawnEth = applyRate(30e18, 1.05e18);
        vm.deal(address(this), withdrawnEth);
        river.sudoReportWithdraw{value: withdrawnEth}(address(redeemManager), 30e18);

        // ...and only then does a report land, which skips straight past it
        river.sudoReportStoppedEarning(address(redeemManager), applyRate(30e18, 1.05e18));
        assertEq(_creditedLsETH(first), 0);
        assertEq(_creditedLsETH(second), 30e18);

        uint32[] memory ids = new uint32[](1);
        ids[0] = first;
        uint32[] memory eventIds = new uint32[](1);
        eventIds[0] = 0;
        uint256 before = user.balance;
        redeemManager.claimRedeemRequests(ids, eventIds);

        assertEq(user.balance - before, applyRate(30e18, 1e18));
        assertEq(redeemManager.getBufferedExceedingEth(), withdrawnEth - applyRate(30e18, 1e18));
    }

    /// A report skips any request a withdrawal event has already priced, so requests stranded between
    /// a credited one and the settled height are never credited at all. This is the gap the rate mark
    /// stack recorded positionally, and it must still pay the request rate. What distinguishes it from
    /// testClaimOfUncreditedRequestPaysRequestRate is that the stranded requests sit ABOVE an already
    /// credited request rather than below every credit.
    function testClaimOfRequestsStrandedBySettlementPaysRequestRate() external {
        address userA = _generateAllowlistedUser(0);
        address userB = _generateAllowlistedUser(1);
        address userC = _generateAllowlistedUser(2);
        address userD = _generateAllowlistedUser(3);
        river.sudoSetRate(1e18);

        uint32 idA = _openRequest(userA, 10e18); // [0, 10)
        uint32 idB = _openRequest(userB, 5e18); // [10, 15)
        uint32 idC = _openRequest(userC, 5e18); // [15, 20)
        _openRequest(userD, 10e18); // [20, 30)

        // the first 10 LsETH stopped earning at a locked rate of 1.02
        river.sudoReportStoppedEarningAt(address(redeemManager), applyRate(10e18, 1.02e18), 10e18);

        // settlement outruns reporting: one event prices [0, 20) at 1.10, so `settledHeight` is now 20
        _settleOnly(20e18, 1.1e18);

        // the next report is forced past everything the event priced, leaving B and C uncredited forever
        river.sudoReportStoppedEarningAt(address(redeemManager), applyRate(10e18, 1.05e18), 10e18);
        assertEq(_creditedLsETH(idA), 10e18);
        assertEq(_creditedLsETH(idB), 0);
        assertEq(_creditedLsETH(idC), 0);
        assertEq(_creditedLsETH(3), 10e18);

        uint32[] memory ids = new uint32[](3);
        ids[0] = idA;
        ids[1] = idB;
        ids[2] = idC;
        uint32[] memory eventIds = new uint32[](3);

        uint256 beforeA = userA.balance;
        uint256 beforeB = userB.balance;
        uint256 beforeC = userC.balance;
        redeemManager.claimRedeemRequests(ids, eventIds);

        // A is covered by mark 0 and is paid its locked rate
        assertEq(userA.balance - beforeA, applyRate(10e18, 1.02e18));
        // B starts exactly at mark 0's end, C strictly above it. Both sit in the gap below mark 1, so
        // the discarded mark's 1.02 never applies and neither does mark 1's 1.05: both pay 1.0.
        assertEq(userB.balance - beforeB, applyRate(5e18, 1e18));
        assertEq(userC.balance - beforeC, applyRate(5e18, 1e18));

        assertEq(redeemManager.getRedeemRequestCreditedEth(idB), 0);
        assertEq(redeemManager.getRedeemRequestCreditedEth(idC), 0);
        assertEq(
            redeemManager.getBufferedExceedingEth(),
            applyRate(20e18, 1.1e18) - applyRate(10e18, 1.02e18) - applyRate(10e18, 1e18)
        );
    }

    /// A request opened before the upgrade has no anchor and must behave exactly as it does today.
    /// This is the launch cutover: the PRD excludes retroactive application.
    function testRequestWithoutAnchorUsesLegacyCap() external {
        address user = _generateAllowlistedUser(0);
        river.sudoSetRate(1e18);
        uint32 id = _openRequest(user, 30e18);

        // simulate a pre-upgrade request by clearing its anchor
        _clearRequestAnchor(id);

        // even with a mark covering it, the legacy path caps at the request rate
        river.sudoSetRate(1.05e18);
        river.sudoReportStoppedEarning(address(redeemManager), applyRate(30e18, 1.05e18));

        uint256 received = _settleAndClaim(id, 30e18, 1.05e18);
        assertEq(received, applyRate(30e18, 1e18));
    }

    /// The initializer seeds nothing, and it does not need to. Every report resumes from
    /// `max(cursor, settledHeight)`, so demand a withdrawal event has already priced is skipped on the
    /// first report whether or not the cursor was ever pinned.
    function testReportSkipsDemandAlreadyPricedWithoutAnySeeding() external {
        address user = _generateAllowlistedUser(0);
        river.sudoSetRate(1e18);
        uint32 priced = _openRequest(user, 30e18);
        uint32 unpriced = _openRequest(user, 20e18);

        vm.deal(address(this), 30e18);
        river.sudoReportWithdraw{value: 30e18}(address(redeemManager), 30e18);

        _upgradeToV1_3();
        assertEq(redeemManager.getLockPositionCursor(), 0);

        river.sudoReportStoppedEarning(address(redeemManager), 20e18);
        assertEq(_creditedLsETH(priced), 0);
        assertEq(_creditedLsETH(unpriced), 20e18);
        assertEq(redeemManager.getLockPositionCursor(), 50e18);
    }

    /// A request only partly priced is still creditable over its unpriced part, and only over that
    /// part. The stretch below the settled height is skipped for good.
    function testReportCreditsOnlyTheUnpricedPartOfAPartlySettledRequest() external {
        address user = _generateAllowlistedUser(0);
        river.sudoSetRate(1e18);
        uint32 id = _openRequest(user, 30e18);

        vm.deal(address(this), 20e18);
        river.sudoReportWithdraw{value: 20e18}(address(redeemManager), 20e18);

        river.sudoReportStoppedEarning(address(redeemManager), 30e18);
        assertEq(_creditedLsETH(id), 10e18);
        assertEq(redeemManager.getLockPositionCursor(), 30e18);

        // and a later report cannot come back for the skipped stretch
        river.sudoReportStoppedEarning(address(redeemManager), 30e18);
        assertEq(_creditedLsETH(id), 10e18);
    }

    function testInitializeV1_3OnEmptyQueuePinsZero() external {
        _upgradeToV1_3();
        assertEq(redeemManager.getLockPositionCursor(), 0);
    }

    function testInitializeV1_3Twice() external {
        _upgradeToV1_3();
        vm.expectRevert(abi.encodeWithSignature("InvalidInitialization(uint256,uint256)", 2, 3));
        redeemManager.initializeRedeemManagerV1_3();
    }

    /// Credit that lands on a pre-upgrade request is consumed against it and dropped. Passing it on
    /// instead would lock the first post-upgrade cohort at the drain-era rate months before its own
    /// principal stops earning, which in a rising pool pays it less than letting it keep accruing.
    /// The post-upgrade request must instead receive its full credit at the rate its OWN principal
    /// stopped earning at, once the legacy demand ahead of it is out of the way.
    function testLegacyDemandConsumesCreditWithoutUsingIt() external {
        address user = _generateAllowlistedUser(0);
        river.sudoSetRate(1e18);

        // a pre-upgrade request, still pending at upgrade time
        uint32 legacy = _openRequest(user, 30e18);
        _clearRequestAnchor(legacy);

        _upgradeToV1_3();
        assertEq(redeemManager.getLockPositionCursor(), 0);

        // a post-upgrade request
        uint32 fresh = _openRequest(user, 30e18);

        // stopped-earning principal worth exactly one request, while the legacy request is still
        // unsettled: that principal is funding LEGACY demand, so it is consumed against the legacy
        // request and dropped rather than reaching the post-upgrade cohort
        river.sudoSetRate(1.05e18);
        vm.expectEmit(true, true, true, true);
        emit ReportedStoppedEarning(30e18, 0, 30e18);
        river.sudoReportStoppedEarning(address(redeemManager), applyRate(30e18, 1.05e18));
        assertEq(_creditedLsETH(fresh), 0);

        // legacy settles first and is unaffected: still capped at its request rate
        uint256 legacyWithdrawn = applyRate(30e18, 1.05e18);
        vm.deal(address(this), legacyWithdrawn);
        river.sudoReportWithdraw{value: legacyWithdrawn}(address(redeemManager), 30e18);
        uint32[] memory legacyIds = new uint32[](1);
        legacyIds[0] = legacy;
        uint32[] memory legacyEvents = new uint32[](1);
        legacyEvents[0] = 0;
        uint256 beforeLegacy = user.balance;
        redeemManager.claimRedeemRequests(legacyIds, legacyEvents);
        assertEq(user.balance - beforeLegacy, applyRate(30e18, 1e18));

        // the post-upgrade request's own principal now stops earning. The legacy request is behind the
        // cursor, so this credit reaches the cohort in full at its own rate.
        river.sudoReportStoppedEarning(address(redeemManager), applyRate(30e18, 1.05e18));
        assertEq(_creditedLsETH(fresh), 30e18);
        assertEq(_creditedEth(fresh), applyRate(30e18, 1.05e18));

        uint256 received = _settleAndClaim(fresh, 30e18, 1.05e18);
        assertEq(received, applyRate(30e18, 1.05e18));
    }

    /// Legacy demand absorbs credit once, not forever. Each unit of a pre-upgrade request consumes
    /// one unit of reported principal and is then behind the cursor, so the next report reaches the
    /// post-upgrade cohort even though the legacy request has not settled yet.
    /// @dev This is where the per-request rule is sharper than the positional floor it replaces. The
    ///      floor kept dropping every report until SETTLEMENT passed it, which over-charged the launch
    ///      cohort whenever a single large report had already covered the whole legacy queue. Credit is
    ///      attributed to demand, and demand is consumed when it is covered, not when it is paid.
    function testLegacyDemandAbsorbsCreditOnceNotForever() external {
        address user = _generateAllowlistedUser(0);
        river.sudoSetRate(1e18);
        uint32 legacy = _openRequest(user, 30e18);
        _clearRequestAnchor(legacy);
        _upgradeToV1_3();

        // the legacy request absorbs 30e18 of the report. The remaining 70e18 has no demand at all
        // behind it, so it belongs to no redeemer and is neither credited nor dropped.
        vm.expectEmit(true, true, true, true);
        emit ReportedStoppedEarning(100e18, 0, 30e18);
        river.sudoReportStoppedEarning(address(redeemManager), 100e18);

        // the legacy request is now fully covered and behind the cursor, so the next report reaches
        // the post-upgrade cohort without waiting for settlement
        uint32 fresh = _openRequest(user, 10e18);
        river.sudoSetRate(1.02e18);
        vm.expectEmit(true, true, true, true);
        emit ReportedStoppedEarning(10e18, 10e18, 0);
        river.sudoReportStoppedEarning(address(redeemManager), applyRate(10e18, 1.02e18));

        assertEq(redeemManager.getLockPositionCursor(), 40e18);
        assertEq(_creditedLsETH(fresh), 10e18);
        assertEq(_creditedEth(fresh), applyRate(10e18, 1.02e18));
        assertEq(redeemManager.getRedeemRequestAnchor(fresh).lsETHAtRequest, 10e18);
    }

    /// A report that lands entirely below the floor must be EXCLUDED FROM MARKING, not relocated onto
    /// the launch
    /// cohort. The floor branch fires only while the pre-upgrade queue is still draining, i.e. while
    /// `floor > max(markCursor, settledHeight)`. In that window the reported principal exited to serve
    /// LEGACY demand, whose payout is already priced by its request-time cap, so no mark is owed.
    ///
    /// Relocating it instead (`markStart = floor` with the full reported amount) would mint drain-era
    /// accrual onto the first post-upgrade span AND advance `_rateMarkCursor()` past it, so when that
    /// cohort's own principal later crosses exit_epoch at a higher rate `markable` would already be 0
    /// and the real credit would be clamped away — locking the launch cohort to whatever rate happened
    /// to prevail during the drain. Excluding it from marking keeps the cursor put so the later report
    /// can still land.
    function testFullyLegacyReportIsDroppedAndLeavesCursorForLaunchCohort() external {
        address user = _generateAllowlistedUser(0);
        river.sudoSetRate(1e18);

        // a pre-upgrade request, still pending at upgrade time
        uint32 legacy = _openRequest(user, 10e18);
        _clearRequestAnchor(legacy);

        _upgradeToV1_3();

        // the launch cohort: the first post-upgrade request, opened at 1.0
        uint32 fresh = _openRequest(user, 10e18);
        assertEq(redeemManager.getRedeemRequestAnchor(fresh).ethAtRequest, applyRate(10e18, 1e18));

        // REPORT 1, drain window. This principal exited to serve the LEGACY request: the rate is still
        // 1.0 and nothing has settled. The whole 10e18 is consumed against the legacy request, which
        // cannot use it, so nothing reaches the launch cohort.
        vm.expectEmit(true, true, true, true);
        emit ReportedStoppedEarning(10e18, 0, 10e18);
        river.sudoReportStoppedEarning(address(redeemManager), applyRate(10e18, 1e18));
        assertEq(_creditedLsETH(fresh), 0);

        // the legacy request settles and is paid at its request rate, which the floor does correctly
        uint256 legacyWithdrawn = applyRate(10e18, 1e18);
        vm.deal(address(this), legacyWithdrawn);
        river.sudoReportWithdraw{value: legacyWithdrawn}(address(redeemManager), 10e18);
        uint32[] memory legacyIds = new uint32[](1);
        legacyIds[0] = legacy;
        uint32[] memory legacyEvents = new uint32[](1);
        legacyEvents[0] = 0;
        redeemManager.claimRedeemRequests(legacyIds, legacyEvents);

        // the pool appreciates while the launch cohort waits for its OWN backing to reach exit_epoch
        river.sudoSetRate(1.5e18);

        // REPORT 2: the launch cohort's actual principal stops earning at 1.5. The legacy request is
        // behind the cursor, so this credit lands on the cohort's own request at 1.5.
        river.sudoReportStoppedEarning(address(redeemManager), applyRate(10e18, 1.5e18));
        assertEq(_creditedLsETH(fresh), 10e18);
        assertEq(_creditedEth(fresh), applyRate(10e18, 1.5e18));

        // settle the launch cohort at the rate its principal actually stopped earning at
        uint256 received = _settleAndClaim(fresh, 10e18, 1.5e18);

        // paid at the 1.5 its own principal stopped earning at, not the drain-era 1.0
        assertEq(received, applyRate(10e18, 1.5e18));
        assertEq(received, 15e18);

        // the full accrual reached the redeemer, so nothing is swept into the exceeding-eth buffer
        assertEq(redeemManager.getBufferedExceedingEth(), 0);
    }

    /// Same drain window, but the report straddles the cutover instead of sitting entirely inside it.
    /// The withdrawal stack has settled to 9e18 while the legacy request ends at 10e18, so only its
    /// LAST unit is still uncovered. A 4e18 report gives 1e18 to the legacy request and 3e18 to the
    /// launch cohort.
    ///
    /// The launch cohort must be credited 3e18, not 4e18. Handing it the full reported width would
    /// credit it for principal that exited to serve legacy demand. The locked rate must survive the
    /// split: the eth credited scales in the same proportion as the LsETH.
    function testReportStraddlingTheCutoverSplitsBetweenLegacyAndCohort() external {
        address user = _generateAllowlistedUser(0);
        river.sudoSetRate(1e18);

        // a pre-upgrade request, still pending at upgrade time
        uint32 legacy = _openRequest(user, 10e18);
        _clearRequestAnchor(legacy);

        _upgradeToV1_3();

        // the launch cohort: the first post-upgrade request, opened at 1.0, spans [10e18, 15e18)
        uint32 fresh = _openRequest(user, 5e18);
        assertEq(redeemManager.getRedeemRequestAnchor(fresh).ethAtRequest, applyRate(5e18, 1e18));

        // settle all but the last unit of the legacy request: settledHeight is now 9e18, one unit
        // short of the floor
        river.sudoReportWithdraw{value: 9e18}(address(redeemManager), 9e18);

        // the pool appreciates before the report, so a mispositioned mark is visible in the payout
        river.sudoSetRate(2e18);

        // REPORT: 4e18 LsETH stopped earning, locked at the 2.0 rate. The legacy request has 1e18 left
        // uncovered and absorbs that much; the surviving 3e18 credits the cohort. The eth scales
        // 8e18 -> 6e18, keeping the locked rate at 2.0.
        vm.expectEmit(true, true, true, true);
        emit ReportedStoppedEarning(4e18, 3e18, 1e18);
        river.sudoReportStoppedEarningAt(address(redeemManager), 8e18, 4e18);
        assertEq(_creditedLsETH(fresh), 3e18);
        assertEq(_creditedEth(fresh), 6e18);

        // settle the remaining legacy unit and the entire launch cohort request in one withdrawal event
        uint256 received = _settleAndClaim(fresh, 6e18, 2e18);

        // 3e18 of the request priced at the 2.0 locked rate (6e18) and 2e18 at the 1.0 request-time
        // rate (2e18), rather than 4e18 credited (8e18) + 1e18 uncredited (1e18)
        assertEq(received, 8e18);

        // the 2e18 of demand the credit does not reach stays capped at its request-time rate, so the
        // event's surplus over that cap returns to the pool
        assertEq(redeemManager.getBufferedExceedingEth(), 2e18);
    }

    /// Credit absorbed by a legacy request must shorten what the next request receives, not slide
    /// along the queue keeping its width. Sliding it would spill onto the request after that and price
    /// a second redeemer at a rate their own principal never stopped earning at.
    function testCreditAbsorbedByLegacyDoesNotSpillOntoTheNextRedeemer() external {
        address userLegacy = _generateAllowlistedUser(0);
        address userA = _generateAllowlistedUser(1);
        address userB = _generateAllowlistedUser(2);
        river.sudoSetRate(1e18);

        // Pre-upgrade queue has one 10e18 request, so floor is 10e18.
        uint32 legacy = _openRequest(userLegacy, 10e18);
        _clearRequestAnchor(legacy);

        _upgradeToV1_3();

        // Post-upgrade: requestA spans [10,13), requestB spans [13,15).
        uint32 requestA = _openRequest(userA, 3e18);
        uint32 requestB = _openRequest(userB, 2e18);

        // Withdrawal stack reaches 9e18, just below floor.
        vm.deal(address(this), 9e18);
        river.sudoReportWithdraw{value: 9e18}(address(redeemManager), 9e18);

        // Report 1 @2.0: of 4e18, the legacy request absorbs its last uncovered 1e18 and requestA is
        // credited the remaining 3e18, which is its whole width.
        river.sudoSetRate(2e18);
        vm.expectEmit(true, true, true, true);
        emit ReportedStoppedEarning(4e18, 3e18, 1e18);
        river.sudoReportStoppedEarningAt(address(redeemManager), 8e18, 4e18);
        assertEq(_creditedLsETH(requestA), 3e18);
        assertEq(_creditedEth(requestA), 6e18);
        assertEq(_creditedLsETH(requestB), 0);

        // Report 2 @3.0: the cursor stopped at requestB, so requestB is credited at its own rate and
        // requestA is not touched again.
        river.sudoSetRate(3e18);
        river.sudoReportStoppedEarningAt(address(redeemManager), 6e18, 2e18);
        assertEq(_creditedLsETH(requestB), 2e18);
        assertEq(_creditedEth(requestB), 6e18);
        assertEq(_creditedEth(requestA), 6e18);

        // Settle remaining demand in one @3.0 withdraw event; caps, not pro-rata, bound payouts.
        vm.deal(address(this), 18e18);
        river.sudoReportWithdraw{value: 18e18}(address(redeemManager), 6e18);

        // Legacy request is unmarked and paid at request-time value across two claim calls.
        assertEq(_reportWithdrawAndClaimAlreadySettled(legacy, 0), 9e18);
        assertEq(_reportWithdrawAndClaimAlreadySettled(legacy, 1), 1e18);

        // requestA: full 3e18 at 2.0 mark rate.
        assertEq(_reportWithdrawAndClaimAlreadySettled(requestA, 1), 6e18);

        // requestB: full 2e18 at 3.0 (its own stop-earning rate). Relocation bug would pay only 5e18.
        assertEq(_reportWithdrawAndClaimAlreadySettled(requestB, 1), 6e18);

        // Unspent cap returns to pool: 2e18 (legacy tail) + 3e18 (requestA).
        assertEq(redeemManager.getBufferedExceedingEth(), 5e18);
    }

    /// reportStoppedEarning is the one function that mints payout entitlement, yet had no negative
    /// test: onlyRiver is the sole gate standing between an arbitrary caller and forging a rate
    /// mark that raises another user's payout cap. Exercised from both a plain EOA and a
    /// highly-motivated allowlisted redeemer who already has an open request of their own to
    /// inflate.
    function testReportStoppedEarningRevertsForNonRiverCaller() external {
        address stranger = makeAddr("stranger");
        address redeemer = _generateAllowlistedUser(0);
        river.sudoSetRate(1e18);
        _openRequest(redeemer, 30e18);

        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSignature("Unauthorized(address)", stranger));
        redeemManager.reportStoppedEarning(30e18, 30e18);

        vm.prank(redeemer);
        vm.expectRevert(abi.encodeWithSignature("Unauthorized(address)", redeemer));
        redeemManager.reportStoppedEarning(30e18, 30e18);

        assertEq(_creditedLsETH(0), 0);

        // River itself can still credit the request after both attack attempts were rejected
        river.sudoReportStoppedEarning(address(redeemManager), 30e18);
        assertEq(_creditedLsETH(0), 30e18);
    }

    /// @dev Settles `lsETH` of demand at `settlementRate` and claims request `id` using whatever
    ///      withdrawal event currently resolves for it, without asserting the request is fully
    ///      resolved afterwards. Companion to _settleAndClaim for tests that need to observe state
    ///      BETWEEN two partial fills of the same request.
    function _reportWithdrawAndClaim(uint32 id, uint256 lsETH, uint256 settlementRate)
        internal
        returns (uint256 received)
    {
        uint256 withdrawnEth = applyRate(lsETH, settlementRate);
        vm.deal(address(this), withdrawnEth);
        river.sudoReportWithdraw{value: withdrawnEth}(address(redeemManager), lsETH);

        uint32[] memory ids = new uint32[](1);
        ids[0] = id;
        int64[] memory resolved = redeemManager.resolveRedeemRequests(ids);
        uint32[] memory eventIds = new uint32[](1);
        eventIds[0] = uint32(uint64(resolved[0]));

        address recipient = redeemManager.getRedeemRequestDetails(id).recipient;
        uint256 before = recipient.balance;
        redeemManager.claimRedeemRequests(ids, eventIds);
        return recipient.balance - before;
    }

    /// _claimRedeemRequest's maxRedeemableEth decrement is saturating, not checked, because a
    /// marked payout may legitimately exceed the request-time ETH budget: once the field floors at
    /// 0, a checked subtraction on a LATER fill of the same request would revert the entire
    /// claimRedeemRequests call with Panic(0x11). Every existing marked-request test claims in one
    /// shot, so this post-saturation state -- and the fact that the cap keeps paying the mark rate
    /// afterwards, recomputed from the anchor and the marks rather than from the exhausted budget
    /// -- was never observed. The second claim below succeeding at all is the regression guard: a
    /// reintroduced checked decrement would revert it with Panic(0x11).
    function testMultiFillOfCreditedRequestSaturatesCreditedEthWithoutReverting() external {
        address user = _generateAllowlistedUser(0);
        river.sudoSetRate(1e18);
        uint32 id = _openRequest(user, 30e18);
        assertEq(redeemManager.getRedeemRequestDetails(id).maxRedeemableEth, 30e18);

        // the whole request's backing principal stopped earning at an appreciated rate: the
        // entitled payout (48) now exceeds the request-time budget (30) recorded on
        // maxRedeemableEth
        river.sudoSetRate(1.6e18);
        river.sudoReportStoppedEarning(address(redeemManager), applyRate(30e18, 1.6e18));
        assertEq(_creditedEth(id), applyRate(30e18, 1.6e18));

        river.sudoSetRate(1.6e18);
        uint256 received1 = _reportWithdrawAndClaim(id, 20e18, 1.6e18);

        assertEq(received1, applyRate(20e18, 1.6e18));
        // 20 LsETH at the mark rate is already worth more than the entire 30 ETH budget: the
        // saturating subtraction floors at 0 instead of reverting
        assertEq(redeemManager.getRedeemRequestDetails(id).amount, 10e18);

        // the remaining 10 LsETH settles at the same mark rate; the decrement is now 0 - 16 ETH,
        // which would Panic(0x11) under checked arithmetic
        uint256 received2 = _reportWithdrawAndClaim(id, 10e18, 1.6e18);

        assertEq(received2, applyRate(10e18, 1.6e18));
        assertEq(received1 + received2, applyRate(30e18, 1.6e18));
        assertEq(redeemManager.getRedeemRequestDetails(id).amount, 0);
        assertEq(redeemManager.getBufferedExceedingEth(), 0);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // getRedeemRequestDetails projects maxRedeemableEth
    //
    // Nothing in the claim path writes `maxRedeemableEth` back for an anchored request, so the stored
    // field is frozen at its request-time value: it neither falls as the request is claimed nor rises
    // when a mark re-prices its span. The getter therefore recomputes the field in memory from the
    // same inputs a claim uses -- anchor, marks, carry, withdrawal events -- and returns the eth the
    // request can still be paid. Storage stays untouched, and pre-upgrade requests keep the stored
    // decrementing budget they are still governed by.
    // ─────────────────────────────────────────────────────────────────────────

    /// @dev Reads `maxRedeemableEth` straight out of the redeem queue, bypassing the getter's
    ///      projection. The queue is a dynamic array at a raw keccak slot with a stride of 5 words and
    ///      `maxRedeemableEth` as its second field.
    function _storedMaxRedeemableEth(uint32 id) internal view returns (uint256) {
        uint256 base = uint256(keccak256(abi.encode(bytes32(uint256(keccak256("river.state.redeemQueue")) - 1))));
        return uint256(vm.load(address(redeemManager), bytes32(base + uint256(id) * 5 + 1)));
    }

    /// @dev Claims request `id` in full against the withdrawal events that already exist, without
    ///      reporting a new one. Pairs with `_settleOnly` when a test needs to read the projection
    ///      between settlement and claim.
    function _claimOnly(uint32 id) internal returns (uint256 received) {
        uint32[] memory ids = new uint32[](1);
        ids[0] = id;
        int64[] memory resolved = redeemManager.resolveRedeemRequests(ids);
        uint32[] memory eventIds = new uint32[](1);
        eventIds[0] = uint32(uint64(resolved[0]));

        address recipient = redeemManager.getRedeemRequestDetails(id).recipient;
        uint256 before = recipient.balance;
        redeemManager.claimRedeemRequests(ids, eventIds);
        return recipient.balance - before;
    }

    /// With no mark and no withdrawal event, the projection is the request-time value: the whole span
    /// sits in a mark gap, so it is worth exactly what it was quoted at. This is the case every
    /// pre-existing assertion of `maxRedeemableEth` right after `requestRedeem` relies on.
    function testDetailsMaxRedeemableEthUnsettledAnchoredEqualsRequestValue() external {
        address user = _generateAllowlistedUser(0);
        river.sudoSetRate(1.2e18);
        uint32 id = _openRequest(user, 30e18);

        assertEq(redeemManager.getRedeemRequestDetails(id).maxRedeemableEth, applyRate(30e18, 1.2e18));
    }

    /// A report raises what the request can be paid, and the getter must show it. Here the stored
    /// balance happens to equal the projection, because the whole request is credited and nothing has
    /// settled; testDetailsMaxRedeemableEthClampsToSettlementBelowCap is where the two part company.
    function testDetailsMaxRedeemableEthRisesWithCredit() external {
        address user = _generateAllowlistedUser(0);
        river.sudoSetRate(1e18);
        uint32 id = _openRequest(user, 30e18);

        river.sudoSetRate(1.6e18);
        river.sudoReportStoppedEarning(address(redeemManager), applyRate(30e18, 1.6e18));

        assertEq(redeemManager.getRedeemRequestDetails(id).maxRedeemableEth, applyRate(30e18, 1.6e18));
        assertEq(_storedMaxRedeemableEth(id), applyRate(30e18, 1.6e18));
    }

    /// The projection is view-only. Reading it cannot move the stored credited-eth balance, whatever
    /// that balance happens to be.
    /// @dev The request is first filled below its cap, so the balance under test is non-zero and the
    ///      assertion has teeth. Asserting against a slot that is zero either way proves nothing.
    function testDetailsProjectionNeverWritesStoredCreditedEth() external {
        address user = _generateAllowlistedUser(0);
        river.sudoSetRate(1e18);
        uint32 id = _openRequest(user, 30e18);

        // a cheap fill leaves the unspent half of its cap on the request
        assertEq(_settleAndClaim(id, 20e18, 0.5e18), applyRate(20e18, 0.5e18));
        uint256 unspentAfterFill = _unspentCap(id);
        assertEq(unspentAfterFill, applyRate(20e18, 1e18) - applyRate(20e18, 0.5e18));

        redeemManager.getRedeemRequestDetails(id);
        assertEq(_unspentCap(id), unspentAfterFill);

        // the last fill spends it, and a fully claimed request is left carrying nothing
        assertEq(_settleAndClaim(id, 10e18, 1.5e18), applyRate(10e18, 1.5e18));
        assertEq(_unspentCap(id), 0);
        assertEq(_storedMaxRedeemableEth(id), 0);
        assertEq(redeemManager.getRedeemRequestDetails(id).maxRedeemableEth, 0);
    }

    /// A withdrawal event that settles the span below its cap bounds the projection: the request can
    /// only ever be paid the eth that event actually supplied, so that is what the getter reports.
    function testDetailsMaxRedeemableEthClampsToSettlementBelowCap() external {
        address user = _generateAllowlistedUser(0);
        river.sudoSetRate(1e18);
        uint32 id = _openRequest(user, 30e18);

        _settleOnly(30e18, 0.5e18);

        assertEq(redeemManager.getRedeemRequestDetails(id).maxRedeemableEth, applyRate(30e18, 0.5e18));
        assertEq(_claimOnly(id), applyRate(30e18, 0.5e18));
    }

    /// The mirror case: a settlement above the cap does not raise the projection, because the excess
    /// is swept to the exceeding-eth buffer rather than paid to the request.
    function testDetailsMaxRedeemableEthStaysAtCapWhenSettlementExceedsIt() external {
        address user = _generateAllowlistedUser(0);
        river.sudoSetRate(1e18);
        uint32 id = _openRequest(user, 30e18);

        _settleOnly(30e18, 1.5e18);

        assertEq(redeemManager.getRedeemRequestDetails(id).maxRedeemableEth, 30e18);
        assertEq(_claimOnly(id), 30e18);
        assertEq(redeemManager.getBufferedExceedingEth(), applyRate(30e18, 1.5e18) - 30e18);
    }

    /// After a partial claim the projection covers the LsETH that is LEFT, and it must include the cap
    /// the first fill was credited with but did not spend. Dropping the carry here would under-report
    /// by exactly the 10 ETH the cheap fill left on the table.
    function testDetailsMaxRedeemableEthAfterPartialClaimCountsCarry() external {
        address user = _generateAllowlistedUser(0);
        river.sudoSetRate(1e18);
        uint32 id = _openRequest(user, 30e18);

        assertEq(_settleAndClaim(id, 20e18, 0.5e18), applyRate(20e18, 0.5e18));
        uint256 carry = _unspentCap(id);
        assertEq(carry, applyRate(20e18, 1e18) - applyRate(20e18, 0.5e18));

        // 10 LsETH left at the request rate, plus the unspent 10 ETH of cap
        uint256 projected = redeemManager.getRedeemRequestDetails(id).maxRedeemableEth;
        assertEq(projected, applyRate(10e18, 1e18) + carry);

        // the next fill is worth less than the projection, which is a ceiling and not a quote
        assertEq(_settleAndClaim(id, 10e18, 1.5e18), applyRate(10e18, 1.5e18));
        assertLe(applyRate(10e18, 1.5e18), projected);
    }

    /// A fully claimed request can receive nothing more, whatever the marks say.
    function testDetailsMaxRedeemableEthIsZeroWhenFullyClaimed() external {
        _lowThenHighFill(0, false);

        assertEq(redeemManager.getRedeemRequestDetails(0).amount, 0);
        assertEq(redeemManager.getRedeemRequestDetails(0).maxRedeemableEth, 0);
    }

    /// A pre-upgrade request is returned verbatim: there `maxRedeemableEth` is the authoritative
    /// decrementing budget the claim path still maintains, so projecting over it would be wrong.
    function testDetailsMaxRedeemableEthUnchangedForLegacyRequest() external {
        address user = _generateAllowlistedUser(0);
        river.sudoSetRate(1e18);
        uint32 id = _openRequest(user, 30e18);
        _clearRequestAnchor(id);

        assertEq(redeemManager.getRedeemRequestDetails(id).maxRedeemableEth, 30e18);

        assertEq(_settleAndClaim(id, 20e18, 0.5e18), applyRate(20e18, 0.5e18));

        uint256 stored = _storedMaxRedeemableEth(id);
        assertEq(stored, 30e18 - applyRate(20e18, 0.5e18));
        assertEq(redeemManager.getRedeemRequestDetails(id).maxRedeemableEth, stored);
    }

    /// The strong form: with the whole request covered by withdrawal events, the projection is not an
    /// estimate but the exact eth the next claim pays -- across an event boundary, a marked span and
    /// an unmarked one. This is what makes the getter safe for a UI to quote.
    function testDetailsMaxRedeemableEthMatchesPayoutWhenFullySettled() external {
        address user = _generateAllowlistedUser(0);
        river.sudoSetRate(1e18);
        uint32 id = _openRequest(user, 30e18);

        // the first half of the span stopped earning at 2.0; the rest never did
        river.sudoReportStoppedEarningAt(address(redeemManager), applyRate(15e18, 2e18), 15e18);

        _settleOnly(15e18, 2e18);
        _settleOnly(15e18, 1e18);

        uint256 projected = redeemManager.getRedeemRequestDetails(id).maxRedeemableEth;
        assertEq(projected, applyRate(15e18, 2e18) + applyRate(15e18, 1e18));
        assertEq(_claimOnly(id), projected);
        assertEq(redeemManager.getRedeemRequestDetails(id).maxRedeemableEth, 0);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Fuzz / property coverage for the slice-cap math
    // ─────────────────────────────────────────────────────────────────────────

    /// Property: the projection is never less than what the following claim pays, and is exactly it
    /// once every LsETH of the request is covered by a withdrawal event. Fuzzes the request size, the
    /// request rate, the marked fraction, the locked rate, the settlement rate and how much of the
    /// request is settled, so no hand-picked scenario can hide a carry or rounding divergence between
    /// the projection and `_claimRedeemRequest`.
    function testFuzz_DetailsMaxRedeemableEthBoundsPayout(
        uint256 _amount,
        uint256 _requestRate,
        uint256 _markedFraction,
        uint256 _markRate,
        uint256 _settlementRate,
        uint256 _settledAmount
    ) external {
        uint256 amount = bound(_amount, 1, 1_000_000 ether);
        uint256 requestRate = bound(_requestRate, 0.5e18, 2e18);
        uint256 markedFraction = bound(_markedFraction, 0, 1e18);
        uint256 markRate = bound(_markRate, 0.5e18, 2e18);
        uint256 settlementRate = bound(_settlementRate, 0.5e18, 2e18);
        uint256 settledAmount = bound(_settledAmount, 1, amount);

        address user = _generateAllowlistedUser(0);
        river.sudoSetRate(requestRate);
        uint32 id = _openRequest(user, amount);

        // mirrors reportStoppedEarning's own dual-nonzero guard: a tiny marked amount at a sub-1.0
        // rate floors the eth leg to 0 and no mark is pushed
        uint256 markedAmount = (amount * markedFraction) / 1e18;
        uint256 markedEth = applyRate(markedAmount, markRate);
        if (markedAmount > 0 && markedEth > 0) {
            river.sudoReportStoppedEarningAt(address(redeemManager), markedEth, markedAmount);
        }

        river.sudoSetRate(settlementRate);
        _settleOnly(settledAmount, settlementRate);

        uint256 projected = redeemManager.getRedeemRequestDetails(id).maxRedeemableEth;
        uint256 received = _claimOnly(id);

        assertLe(received, projected);
        if (settledAmount == amount) {
            assertEq(received, projected);
        }
    }

    /// Property: splitting the same settlement across two withdrawal events cannot make the
    /// projection disagree with the payout. The projection walks events exactly as the claim
    /// recursion does, carry included, so the equality must survive any split point.
    function testFuzz_DetailsMaxRedeemableEthMatchesPayoutAcrossSplitEvents(
        uint256 _amount,
        uint256 _requestRate,
        uint256 _markRate,
        uint256 _firstRate,
        uint256 _secondRate,
        uint256 _splitPoint
    ) external {
        uint256 amount = bound(_amount, 2, 1_000_000 ether);
        uint256 requestRate = bound(_requestRate, 0.5e18, 2e18);
        uint256 markRate = bound(_markRate, 0.5e18, 2e18);
        uint256 firstRate = bound(_firstRate, 0.5e18, 2e18);
        uint256 secondRate = bound(_secondRate, 0.5e18, 2e18);
        uint256 splitPoint = bound(_splitPoint, 1, amount - 1);

        address user = _generateAllowlistedUser(0);
        river.sudoSetRate(requestRate);
        uint32 id = _openRequest(user, amount);

        // mark only the first part of the span, so the request straddles a mark edge as well as an
        // event edge and the two boundaries do not line up
        uint256 markedEth = applyRate(splitPoint, markRate);
        if (markedEth > 0) {
            river.sudoReportStoppedEarningAt(address(redeemManager), markedEth, splitPoint);
        }

        _settleOnly(splitPoint, firstRate);
        _settleOnly(amount - splitPoint, secondRate);

        uint256 projected = redeemManager.getRedeemRequestDetails(id).maxRedeemableEth;
        assertEq(_claimOnly(id), projected);
        assertEq(redeemManager.getRedeemRequestDetails(id).maxRedeemableEth, 0);
    }

    /// @dev Deploys a fresh, independent RiverMock + RedeemManagerV1 pair sharing this test's
    ///      allowlist, so a scenario can be replayed from a clean slate without disturbing the
    ///      contract-level `redeemManager`/`river` used by every other test.
    function _deployFreshManager() internal returns (RiverMock riverInstance, RedeemManagerV1 managerInstance) {
        managerInstance = new RedeemManagerV1();
        LibImplementationUnbricker.unbrick(vm, address(managerInstance));
        riverInstance = new RiverMock(address(allowlist));
        managerInstance.initializeRedeemManagerV1(address(riverInstance));
    }

    /// Property: the payout for a (possibly partially marked) request can never exceed the
    /// request's cap -- request-time rate over any unmarked remainder, the mark's locked rate over
    /// the marked span -- and can never exceed the ETH the matching withdrawal event actually
    /// supplied. Whichever of the two binds, the shortfall is exactly what lands in the
    /// exceeding-eth buffer. Fuzzes the request size, the request-time rate, how much of the
    /// request is marked, the mark's locked rate and the settlement rate independently, so no
    /// single hand-picked scenario can mask a rounding or ordering bug in the cap arithmetic.
    function testFuzz_MarkedRequestPayoutRespectsCapAndConservesEth(
        uint256 _amount,
        uint256 _requestRate,
        uint256 _markedFraction,
        uint256 _markRate,
        uint256 _settlementRate
    ) external {
        uint256 amount = bound(_amount, 1, 1_000_000 ether);
        uint256 requestRate = bound(_requestRate, 0.5e18, 2e18);
        uint256 markedFraction = bound(_markedFraction, 0, 1e18);
        uint256 markRate = bound(_markRate, 0.5e18, 2e18);
        uint256 settlementRate = bound(_settlementRate, 0.5e18, 2e18);

        address user = _generateAllowlistedUser(0);
        river.sudoSetRate(requestRate);
        uint32 id = _openRequest(user, amount);

        uint256 markedAmount = (amount * markedFraction) / 1e18;
        // reportStoppedEarning no-ops when EITHER leg of the reported pair is zero (see its own
        // guard comment): a tiny markedAmount combined with a sub-1.0 markRate can floor the eth
        // leg to 0 even though markedAmount itself is nonzero, so mirror that exact condition here
        // rather than assuming markedAmount > 0 alone means the request was credited.
        uint256 markedEthForReport = applyRate(markedAmount, markRate);
        bool marked = markedAmount > 0 && markedEthForReport > 0;
        if (marked) {
            river.sudoReportStoppedEarningAt(address(redeemManager), markedEthForReport, markedAmount);
            assertEq(_creditedLsETH(id), markedAmount);
        } else {
            assertEq(_creditedLsETH(id), 0);
        }

        RedeemRequestAnchor.Anchor memory anchor = redeemManager.getRedeemRequestAnchor(id);

        uint256 expectedCap;
        if (!marked) {
            expectedCap = (amount * anchor.ethAtRequest) / anchor.lsETHAtRequest;
        } else {
            uint256 markedEth = _creditedEth(id);
            uint256 unmarkedAmount = amount - markedAmount;
            uint256 gapEth = unmarkedAmount == 0 ? 0 : (unmarkedAmount * anchor.ethAtRequest) / anchor.lsETHAtRequest;
            expectedCap = markedEth + gapEth;
        }

        uint256 received = _settleAndClaim(id, amount, settlementRate);
        uint256 withdrawnEth = applyRate(amount, settlementRate);

        // solvency: never paid more than the withdrawal event actually supplied
        assertLe(received, withdrawnEth);
        // cap ceiling: never paid more than the request's cap allows
        assertLe(received, expectedCap);
        // exact: the payout is precisely whichever of the two binds
        assertEq(received, withdrawnEth < expectedCap ? withdrawnEth : expectedCap);
        // conservation: nothing is created or destroyed, only redirected to the exceeding buffer
        assertEq(redeemManager.getBufferedExceedingEth(), withdrawnEth - received);
    }

    /// Property: across a cohort of requests -- some marked, some not -- every wei a withdrawal
    /// event supplies is accounted for exactly once: either paid to a recipient or redirected to
    /// the exceeding-eth buffer. testFuzz_MarkedRequestPayoutRespectsCapAndConservesEth only checks
    /// this in isolation for a single request; this is the multi-request cohort form.
    function testFuzz_ConservationAcrossMixedMarkedAndUnmarkedCohort(
        uint256 _amountA,
        uint256 _amountB,
        uint256 _requestRateA,
        uint256 _requestRateB,
        uint256 _markRate,
        uint256 _settlementRate
    ) external {
        uint256 amountA = bound(_amountA, 1, 500_000 ether);
        uint256 amountB = bound(_amountB, 1, 500_000 ether);
        uint256 requestRateA = bound(_requestRateA, 0.5e18, 2e18);
        uint256 requestRateB = bound(_requestRateB, 0.5e18, 2e18);
        uint256 markRate = bound(_markRate, 0.5e18, 2e18);
        uint256 settlementRate = bound(_settlementRate, 0.5e18, 2e18);

        address userA = _generateAllowlistedUser(0);
        address userB = _generateAllowlistedUser(1);

        river.sudoSetRate(requestRateA);
        uint32 idA = _openRequest(userA, amountA);
        river.sudoSetRate(requestRateB);
        uint32 idB = _openRequest(userB, amountB);

        // only the first request's principal is ever reported as having stopped earning (a no-op
        // if amountA is too small for the reported pair to clear reportStoppedEarning's own
        // dual-nonzero guard, which the conservation property must hold under regardless)
        river.sudoReportStoppedEarningAt(address(redeemManager), applyRate(amountA, markRate), amountA);

        river.sudoSetRate(settlementRate);

        // each request settles against its own dedicated withdrawal event -- a shared event would
        // additionally introduce a few wei of pro-rata rounding dust that is orthogonal to the
        // property under test here (see _claimRedeemRequest's ethAmount computation)
        uint256 receivedA = _settleAndClaim(idA, amountA, settlementRate);
        uint256 receivedB = _settleAndClaim(idB, amountB, settlementRate);

        uint256 totalWithdrawn = applyRate(amountA, settlementRate) + applyRate(amountB, settlementRate);
        assertEq(totalWithdrawn, receivedA + receivedB + redeemManager.getBufferedExceedingEth());
    }

    /// Property: splitting a marked request's settlement into two separate withdrawal events and
    /// claiming each with its own claimRedeemRequests call never pays MORE, in total, than settling
    /// and claiming the identical request whole in a single event. Guards the
    /// report-time division that values a credited width: a rounding
    /// bug there would show up as the split path leaking extra wei across additional claims.
    function testFuzz_SplitClaimNeverPaysMoreThanWholeClaim(
        uint256 _amount,
        uint256 _requestRate,
        uint256 _markRate,
        uint256 _settlementRate,
        uint256 _splitPoint
    ) external {
        uint256 amount = bound(_amount, 2, 1_000_000 ether);
        uint256 requestRate = bound(_requestRate, 0.5e18, 2e18);
        uint256 markRate = bound(_markRate, 0.5e18, 2e18);
        uint256 settlementRate = bound(_settlementRate, 0.5e18, 2e18);
        uint256 splitPoint = bound(_splitPoint, 1, amount - 1);

        address user = _generateAllowlistedUser(0);

        (RiverMock riverWhole, RedeemManagerV1 rmWhole) = _deployFreshManager();
        riverWhole.sudoSetRate(requestRate);
        riverWhole.sudoDeal(user, amount);
        vm.prank(user);
        riverWhole.approve(address(rmWhole), amount);
        vm.prank(user);
        uint32 idWhole = rmWhole.requestRedeem(amount, user);
        riverWhole.sudoReportStoppedEarningAt(address(rmWhole), applyRate(amount, markRate), amount);
        riverWhole.sudoSetRate(settlementRate);
        uint256 wholeEth = applyRate(amount, settlementRate);
        vm.deal(address(this), wholeEth);
        riverWhole.sudoReportWithdraw{value: wholeEth}(address(rmWhole), amount);

        uint32[] memory idsW = new uint32[](1);
        idsW[0] = idWhole;
        uint32[] memory eventsW = new uint32[](1);
        eventsW[0] = 0;
        uint256 beforeWhole = user.balance;
        rmWhole.claimRedeemRequests(idsW, eventsW);
        uint256 receivedWhole = user.balance - beforeWhole;

        (RiverMock riverSplit, RedeemManagerV1 rmSplit) = _deployFreshManager();
        riverSplit.sudoSetRate(requestRate);
        riverSplit.sudoDeal(user, amount);
        vm.prank(user);
        riverSplit.approve(address(rmSplit), amount);
        vm.prank(user);
        uint32 idSplit = rmSplit.requestRedeem(amount, user);
        riverSplit.sudoReportStoppedEarningAt(address(rmSplit), applyRate(amount, markRate), amount);
        riverSplit.sudoSetRate(settlementRate);

        // the identical total settlement, delivered as two withdrawal events instead of one, each
        // claimed with its own top-level claimRedeemRequests call
        uint256 firstEth = applyRate(splitPoint, settlementRate);
        vm.deal(address(this), firstEth);
        riverSplit.sudoReportWithdraw{value: firstEth}(address(rmSplit), splitPoint);

        uint32[] memory idsS = new uint32[](1);
        idsS[0] = idSplit;
        int64[] memory resolved1 = rmSplit.resolveRedeemRequests(idsS);
        uint32[] memory events1 = new uint32[](1);
        events1[0] = uint32(uint64(resolved1[0]));
        uint256 beforeSplit = user.balance;
        rmSplit.claimRedeemRequests(idsS, events1);

        uint256 secondEth = applyRate(amount - splitPoint, settlementRate);
        vm.deal(address(this), secondEth);
        riverSplit.sudoReportWithdraw{value: secondEth}(address(rmSplit), amount - splitPoint);
        int64[] memory resolved2 = rmSplit.resolveRedeemRequests(idsS);
        uint32[] memory events2 = new uint32[](1);
        events2[0] = uint32(uint64(resolved2[0]));
        rmSplit.claimRedeemRequests(idsS, events2);

        uint256 receivedSplit = user.balance - beforeSplit;

        assertLe(receivedSplit, receivedWhole);
    }

    // -----------------------------------------------------------------------
    // Gap-analysis HIGH items: the credited-balance cap and the claim path
    // -----------------------------------------------------------------------

    /// Historically this exercised the rate mark predecessor search. It survives as a scenario: a request
    /// whose span is credited by two reports with a settlement in between. The original note read: only
    /// answers "which mark STARTS at or before this
    /// position" -- it is a plain predecessor search over a non-contiguous stack, so the mark it
    /// returns can end well below the slice's start. Every existing test starts a slice either
    /// inside a mark, below every mark, or past the last mark, so the "candidate mark is stale and
    /// must be discarded" branch (`sliceCursor >= markEnd`) has never fired. Here mark A ends at
    /// 40e18 and mark B starts at 50e18; the claim's first sub-slice starts at 45e18, so the
    /// predecessor search hands back stale mark A and case 2 must discard it before the walk can
    /// reach the real gap-then-B pricing.
    function testRequestCreditedAcrossTwoReportsWithSettlementInBetween() external {
        address userPre = _generateAllowlistedUser(0);
        address userTest = _generateAllowlistedUser(1);
        river.sudoSetRate(1e18);

        // soaks up positions [0, 45e18) so the test request starts exactly at 45e18
        _openRequest(userPre, 45e18);
        uint32 idTest = _openRequest(userTest, 20e18);

        // settle [0, 30e18) without marking it
        vm.deal(address(this), 30e18);
        river.sudoReportWithdraw{value: 30e18}(address(redeemManager), 30e18);

        // report A credits the tail of the filler request at 1.02, not the test request
        river.sudoReportStoppedEarningAt(address(redeemManager), applyRate(10e18, 1.02e18), 10e18);
        assertEq(_creditedLsETH(0), 10e18);
        assertEq(_creditedLsETH(idTest), 0);

        // settle [30e18, 50e18), skipping [40e18, 50e18) so it becomes a permanent gap
        vm.deal(address(this), applyRate(20e18, 1.02e18));
        river.sudoReportWithdraw{value: applyRate(20e18, 1.02e18)}(address(redeemManager), 20e18);

        // report B skips the filler, now fully priced, and credits 10e18 of the test request at 1.05
        river.sudoReportStoppedEarningAt(address(redeemManager), applyRate(10e18, 1.05e18), 10e18);
        assertEq(_creditedLsETH(idTest), 10e18);
        assertEq(_creditedEth(idTest), applyRate(10e18, 1.05e18));

        // settle the remainder, [50e18, 65e18), which fully covers mark B plus a trailing gap
        vm.deal(address(this), applyRate(15e18, 1.05e18));
        river.sudoReportWithdraw{value: applyRate(15e18, 1.05e18)}(address(redeemManager), 15e18);

        uint32[] memory ids = new uint32[](1);
        ids[0] = idTest;
        int64[] memory resolved = redeemManager.resolveRedeemRequests(ids);
        uint32[] memory eventIds = new uint32[](1);
        eventIds[0] = uint32(uint64(resolved[0]));

        uint256 before = userTest.balance;
        redeemManager.claimRedeemRequests(ids, eventIds);
        uint256 received = userTest.balance - before;

        // 10e18 of the request is credited at 1.05 and the other 10e18 is worth its request rate
        uint256 expected = applyRate(5e18, 1e18) + applyRate(10e18, 1.05e18) + applyRate(5e18, 1e18);
        assertEq(received, expected);
        assertEq(received, 20.5e18);
        assertEq(redeemManager.getBufferedExceedingEth(), 0.35e18);
    }

    /// A single request can be backed by exits that only cover part of it, with an uncovered stretch
    /// in between, because settlement outrunning reporting strands whatever it passes over. One
    /// `claimRedeemRequests` call auto-recursing across both events must pay exactly the credited
    /// value plus the request-rate value of the stranded stretch, with the two reports at
    /// deliberately different rates so a mis-attribution between them cannot hide.
    function testCreditThenStrandedThenCreditWithinSingleClaimSumsExactly() external {
        address user = _generateAllowlistedUser(0);
        river.sudoSetRate(1e18);
        uint32 id = _openRequest(user, 30e18);

        // report A: 10e18 at 1.02
        river.sudoReportStoppedEarningAt(address(redeemManager), applyRate(10e18, 1.02e18), 10e18);
        assertEq(_creditedLsETH(id), 10e18);

        // settle [0, 20e18): the credited 10e18, plus 10e18 no report will now ever reach
        vm.deal(address(this), applyRate(20e18, 1.2e18));
        river.sudoReportWithdraw{value: applyRate(20e18, 1.2e18)}(address(redeemManager), 20e18);

        // report B: 10e18 at 1.08, a different rate from report A
        river.sudoReportStoppedEarningAt(address(redeemManager), applyRate(10e18, 1.08e18), 10e18);
        assertEq(_creditedLsETH(id), 20e18);
        assertEq(_creditedEth(id), applyRate(10e18, 1.02e18) + applyRate(10e18, 1.08e18));

        // settle the rest, [20e18, 30e18)
        vm.deal(address(this), applyRate(10e18, 1.2e18));
        river.sudoReportWithdraw{value: applyRate(10e18, 1.2e18)}(address(redeemManager), 10e18);

        uint32[] memory ids = new uint32[](1);
        ids[0] = id;
        int64[] memory resolved = redeemManager.resolveRedeemRequests(ids);
        uint32[] memory eventIds = new uint32[](1);
        eventIds[0] = uint32(uint64(resolved[0]));

        uint256 before = user.balance;
        redeemManager.claimRedeemRequests(ids, eventIds);
        uint256 received = user.balance - before;

        uint256 reportAEth = applyRate(10e18, 1.02e18);
        uint256 strandedEth = applyRate(10e18, 1e18);
        uint256 reportBEth = applyRate(10e18, 1.08e18);
        assertEq(received, reportAEth + strandedEth + reportBEth);
        assertEq(received, 31e18);

        uint256 totalWithdrawn = applyRate(20e18, 1.2e18) + applyRate(10e18, 1.2e18);
        assertEq(redeemManager.getBufferedExceedingEth(), totalWithdrawn - received);
        assertEq(redeemManager.getBufferedExceedingEth(), 5e18);
    }

    /// Six reports at six distinct rates against one request, settled over five events, is the
    /// sharpest statement of what changed when per-position rate marks became a per-request balance.
    ///
    /// The total is identical to the wei: 102.32 ETH either way, because every unit of LsETH is still
    /// valued exactly once, at its locked rate or at the request rate. What moves is the split. A
    /// mark stack priced each fill against the marks its own span touched, so step 1 paid 15.1 (mark
    /// 0 at 1.01 plus a 5 ETH gap at 1.0). One balance pools all six credits, so step 1 draws on the
    /// blend and is paid 18, and the later fills are correspondingly smaller. Nothing is created or
    /// lost, and the exceeding buffer ends in the same place; redeemers are simply paid earlier.
    ///
    /// The steps are asserted one at a time so a wrong split is attributable to its own boundary.
    function testCreditBalanceBlendsSixRatesAndPreservesTheTotal() external {
        address user = _generateAllowlistedUser(0);
        river.sudoSetRate(1e18);
        uint32 id = _openRequest(user, 100e18);

        // report 0: 10e18 @ 1.01
        river.sudoReportStoppedEarningAt(address(redeemManager), applyRate(10e18, 1.01e18), 10e18);
        // settle [0, 15e18): the credited 10e18 plus 5e18 that no report reached
        vm.deal(address(this), applyRate(15e18, 1.2e18));
        river.sudoReportWithdraw{value: applyRate(15e18, 1.2e18)}(address(redeemManager), 15e18);

        // report 1: 10e18 @ 1.02
        river.sudoReportStoppedEarningAt(address(redeemManager), applyRate(10e18, 1.02e18), 10e18);
        // settle [15e18, 30e18)
        vm.deal(address(this), applyRate(15e18, 1.2e18));
        river.sudoReportWithdraw{value: applyRate(15e18, 1.2e18)}(address(redeemManager), 15e18);

        // report 2: 10e18 @ 1.03
        river.sudoReportStoppedEarningAt(address(redeemManager), applyRate(10e18, 1.03e18), 10e18);
        // settle [30e18, 42e18)
        vm.deal(address(this), applyRate(12e18, 1.2e18));
        river.sudoReportWithdraw{value: applyRate(12e18, 1.2e18)}(address(redeemManager), 12e18);

        // report 3: 8e18 @ 1.04
        river.sudoReportStoppedEarningAt(address(redeemManager), applyRate(8e18, 1.04e18), 8e18);
        // report 4: 10e18 @ 1.05, landing with no withdrawal in between
        river.sudoReportStoppedEarningAt(address(redeemManager), applyRate(10e18, 1.05e18), 10e18);
        // settle [42e18, 65e18)
        vm.deal(address(this), applyRate(23e18, 1.2e18));
        river.sudoReportWithdraw{value: applyRate(23e18, 1.2e18)}(address(redeemManager), 23e18);

        // report 5: 15e18 @ 1.06, the last one, leaving a 20e18 tail no report ever reaches
        river.sudoReportStoppedEarningAt(address(redeemManager), applyRate(15e18, 1.06e18), 15e18);
        // settle [65e18, 100e18)
        vm.deal(address(this), applyRate(35e18, 1.2e18));
        river.sudoReportWithdraw{value: applyRate(35e18, 1.2e18)}(address(redeemManager), 35e18);

        // 63e18 of the request is credited, worth 65.32 ETH at the six locked rates; the other 37e18
        // is worth the request rate as each fill reaches it
        assertEq(_creditedLsETH(id), 63e18);
        assertEq(_creditedEth(id), 65.32e18);
        assertEq(redeemManager.getRedeemRequestDetails(id).amount, 100e18);

        // A rate mark stack pays 15.10, 15.20, 12.30, 23.82 and 35.90 here, because it prices every
        // fill against the individual marks its own span touches. One credited balance holds a single
        // blended rate over the whole band, so each step lands a little differently. The band position
        // is what keeps them close; without it the first step alone was 18.
        uint256 received1 = _reportWithdrawAndClaimAlreadySettled(id, 0);
        assertEq(received1, 15.55238095238095238e18);

        uint256 received2 = _reportWithdrawAndClaimAlreadySettled(id, 1);
        assertEq(received2, 15.552380952380952381e18);

        uint256 received3 = _reportWithdrawAndClaimAlreadySettled(id, 2);
        assertEq(received3, 12.441904761904761905e18);

        uint256 received4 = _reportWithdrawAndClaimAlreadySettled(id, 3);
        assertEq(received4, 23.773333333333333334e18);

        // the tail no report ever reached, paid at exactly the request rate
        uint256 received5 = _reportWithdrawAndClaimAlreadySettled(id, 4);
        assertEq(received5, applyRate(35e18, 1e18));

        assertEq(redeemManager.getRedeemRequestDetails(id).amount, 0);

        // the figure a mark stack produces, to the wei
        assertEq(received1 + received2 + received3 + received4 + received5, 102.32e18);
    }

    /// @dev Resolves and claims request `id` against the withdrawal event at `eventId`, which
    ///      must already exist (this test pre-reports every withdrawal event up front so the
    ///      credits land exactly where the scenario needs them, then claims step by step).
    function _reportWithdrawAndClaimAlreadySettled(uint32 id, uint32 eventId) internal returns (uint256 received) {
        uint32[] memory ids = new uint32[](1);
        ids[0] = id;
        uint32[] memory eventIds = new uint32[](1);
        eventIds[0] = eventId;
        address recipient = redeemManager.getRedeemRequestDetails(id).recipient;
        uint256 before = recipient.balance;
        redeemManager.claimRedeemRequests(ids, eventIds, true, 0);
        return recipient.balance - before;
    }

    /// One exit backs whatever happens to be at the front of the queue when it lands, which routinely
    /// straddles two different recipients' requests. Request A and request B are opened at different
    /// request-time rates, so their uncredited legs are distinguishable from each other and from the
    /// locked rate, and one report covers A's tail and B's head. Each must be credited over only its
    /// own covered portion, at the same locked rate.
    function testSingleReportStraddlesTwoRequestsFromDifferentRecipients() external {
        address userA = _generateAllowlistedUser(0);
        address userB = _generateAllowlistedUser(1);

        river.sudoSetRate(1e18);
        uint32 idA = _openRequest(userA, 20e18); // [0, 20e18) @ request rate 1.0

        river.sudoSetRate(1.1e18);
        uint32 idB = _openRequest(userB, 20e18); // [20e18, 40e18) @ request rate 1.1

        // settle A's first 15e18 without marking it
        vm.deal(address(this), 15e18);
        river.sudoReportWithdraw{value: 15e18}(address(redeemManager), 15e18);

        // report 15e18 @ 1.05, covering A's last 5e18 and B's first 10e18
        river.sudoReportStoppedEarningAt(address(redeemManager), applyRate(15e18, 1.05e18), 15e18);
        assertEq(_creditedLsETH(idA), 5e18);
        assertEq(_creditedEth(idA), applyRate(5e18, 1.05e18));
        assertEq(_creditedLsETH(idB), 10e18);
        assertEq(_creditedEth(idB), applyRate(10e18, 1.05e18));

        // settle the remainder, [15e18, 40e18): A's credited tail, all of B, at a generous rate so
        // the cap binds throughout
        vm.deal(address(this), applyRate(25e18, 1.2e18));
        river.sudoReportWithdraw{value: applyRate(25e18, 1.2e18)}(address(redeemManager), 25e18);

        // claim A: 15e18 @ request rate 1.0, then 5e18 @ the locked 1.05
        uint32[] memory idsA = new uint32[](1);
        idsA[0] = idA;
        int64[] memory resolvedA = redeemManager.resolveRedeemRequests(idsA);
        uint32[] memory eventIdsA = new uint32[](1);
        eventIdsA[0] = uint32(uint64(resolvedA[0]));
        uint256 beforeA = userA.balance;
        redeemManager.claimRedeemRequests(idsA, eventIdsA);
        uint256 receivedA = userA.balance - beforeA;

        uint256 expectedA = applyRate(15e18, 1e18) + applyRate(5e18, 1.05e18);
        assertEq(receivedA, expectedA);
        assertEq(receivedA, 20.25e18);

        // claim B: 10e18 @ the same report's 1.05, then 10e18 @ B's own request rate 1.1
        uint32[] memory idsB = new uint32[](1);
        idsB[0] = idB;
        int64[] memory resolvedB = redeemManager.resolveRedeemRequests(idsB);
        uint32[] memory eventIdsB = new uint32[](1);
        eventIdsB[0] = uint32(uint64(resolvedB[0]));
        uint256 beforeB = userB.balance;
        redeemManager.claimRedeemRequests(idsB, eventIdsB);
        uint256 receivedB = userB.balance - beforeB;

        uint256 expectedB = applyRate(10e18, 1.05e18) + applyRate(10e18, 1.1e18);
        assertEq(receivedB, expectedB);
        assertEq(receivedB, 21.5e18);

        uint256 totalWithdrawn = 15e18 + applyRate(25e18, 1.2e18);
        assertEq(redeemManager.getBufferedExceedingEth(), totalWithdrawn - receivedA - receivedB);
        assertEq(redeemManager.getBufferedExceedingEth(), 3.25e18);
    }

    /// A zero-value cap must resolve to a zero-value, successful transfer rather than a revert. It is
    /// reachable whenever an uncredited sub-slice is small enough that its request-rate value floors
    /// to nothing: here the request was opened at 0.5, so one wei of LsETH is worth zero wei of ETH.
    function testZeroValueUncreditedSliceDoesNotRevert() external {
        address user = _generateAllowlistedUser(0);
        river.sudoSetRate(0.5e18);
        uint32 id = _openRequest(user, 10e18);
        assertEq(redeemManager.getRedeemRequestAnchor(id).ethAtRequest, 5e18);

        // no report reaches the request, so the fill is valued at its request rate alone
        vm.deal(address(this), 1 ether);
        river.sudoReportWithdraw{value: 1 ether}(address(redeemManager), 1);

        uint32[] memory ids = new uint32[](1);
        ids[0] = id;
        uint32[] memory eventIds = new uint32[](1);
        eventIds[0] = 0;
        uint256 before = user.balance;
        redeemManager.claimRedeemRequests(ids, eventIds);

        assertEq(user.balance - before, 0);
        assertEq(redeemManager.getRedeemRequestDetails(id).amount, 10e18 - 1);
        assertEq(redeemManager.getBufferedExceedingEth(), 1 ether);
    }

    /// Credited eth is divided once, at report time, and is then paid out to the wei. This is a
    /// behaviour change worth pinning: pricing every fill against a rate, as the rate mark stack did,
    /// floored once per fill, so drawing a 22 wei credit down in seven 1-wei fills paid only 21 and
    /// withheld the difference. A balance is drawn down by subtraction, so all 22 reach the redeemer.
    function testCreditedEthIsPaidWithoutPerFillRoundingDust() external {
        address user = _generateAllowlistedUser(0);
        river.sudoSetRate(1e18);
        uint32 id = _openRequest(user, 7);

        // 22 wei of eth against 7 wei of LsETH: a coprime pair, so any per-fill division would floor
        river.sudoReportStoppedEarningAt(address(redeemManager), 22, 7);
        assertEq(_creditedLsETH(id), 7);
        assertEq(_creditedEth(id), 22);

        uint256 totalReceived = 0;
        uint256 totalWithdrawn = 0;
        for (uint256 i = 0; i < 7; ++i) {
            vm.deal(address(this), 100);
            river.sudoReportWithdraw{value: 100}(address(redeemManager), 1);
            totalWithdrawn += 100;

            uint32[] memory ids = new uint32[](1);
            ids[0] = id;
            uint32[] memory eventIds = new uint32[](1);
            eventIds[0] = uint32(i);
            uint256 before = user.balance;
            redeemManager.claimRedeemRequests(ids, eventIds);
            totalReceived += user.balance - before;
        }

        assertEq(redeemManager.getRedeemRequestDetails(id).amount, 0);
        assertEq(totalReceived, 22);
        assertEq(_creditedEth(id), 0);
        assertEq(redeemManager.getBufferedExceedingEth(), totalWithdrawn - totalReceived);
        assertEq(redeemManager.getBufferedExceedingEth(), 678);
    }

    /// Report-time division floors per request, so the credits a report hands out can never add up to
    /// more than the eth it reported. The dust stays with the protocol, never invented for a redeemer.
    function testReportTimeRoundingNeverCreditsMoreThanReported() external {
        address userA = _generateAllowlistedUser(0);
        address userB = _generateAllowlistedUser(1);
        river.sudoSetRate(1e18);
        uint32 idA = _openRequest(userA, 1);
        uint32 idB = _openRequest(userB, 1);

        // 3 wei of eth across 2 wei of LsETH: each request floors to 1, so 1 wei is never credited
        river.sudoReportStoppedEarningAt(address(redeemManager), 3, 2);

        assertEq(_creditedEth(idA), 1);
        assertEq(_creditedEth(idB), 1);
        assertLt(_creditedEth(idA) + _creditedEth(idB), 3);
    }

    /// @dev Builds one 30e18 request on `rmX`/`riverX` spanning two marks with a gap between
    ///      them, settled across exactly three withdrawal events (mark 0, the gap, mark 1, then an
    ///      unmarked tail), all at a settlement rate generous enough that the cap binds throughout.
    ///      Shared by the HIGH-10 depth tests so both the unrestricted and the depth-limited claim
    ///      path start from an identical, independently-deployed queue.
    function _buildDepthTestScenario(RiverMock riverX, RedeemManagerV1 rmX, address user) internal returns (uint32 id) {
        riverX.sudoSetRate(1e18);
        riverX.sudoDeal(user, 30e18);
        vm.prank(user);
        riverX.approve(address(rmX), 30e18);
        vm.prank(user);
        id = rmX.requestRedeem(30e18, user);

        // mark 0: [0, 10e18) @ 1.05
        riverX.sudoReportStoppedEarningAt(address(rmX), applyRate(10e18, 1.05e18), 10e18);
        vm.deal(address(this), applyRate(15e18, 1.2e18));
        riverX.sudoReportWithdraw{value: applyRate(15e18, 1.2e18)}(address(rmX), 15e18); // event 0: [0,15)

        // mark 1: [15e18, 25e18) @ 1.1
        riverX.sudoReportStoppedEarningAt(address(rmX), applyRate(10e18, 1.1e18), 10e18);
        vm.deal(address(this), applyRate(10e18, 1.2e18));
        riverX.sudoReportWithdraw{value: applyRate(10e18, 1.2e18)}(address(rmX), 10e18); // event 1: [15,25)

        vm.deal(address(this), applyRate(5e18, 1.2e18));
        riverX.sudoReportWithdraw{value: applyRate(5e18, 1.2e18)}(address(rmX), 5e18); // event 2: [25,30)
    }

    /// HIGH-10: `_depth` exists so a request spanning many marks/withdrawal events can be claimed
    /// in bounded steps instead of one unbounded recursive call. The pre-existing depth tests are
    /// all on anchorless (legacy) requests. The property that matters is that splitting a MARKED
    /// request's claim by depth must not change the total paid, nor how it is attributed to each
    /// mark: `depth = 0` three times in a row (one withdrawal event settled per call) must sum to
    /// exactly the same total as one unrestricted call over the identical scenario, and the
    /// request's residual `height`/`amount` must stay consistent in between.
    function testDepthLimitedClaimOfMarkedRequestSumsToUnrestrictedTotal() external {
        address user = _generateAllowlistedUser(0);

        // baseline: the same scenario, claimed in one unrestricted call
        (RiverMock riverBaseline, RedeemManagerV1 rmBaseline) = _deployFreshManager();
        uint32 idBaseline = _buildDepthTestScenario(riverBaseline, rmBaseline, user);

        uint32[] memory idsBaseline = new uint32[](1);
        idsBaseline[0] = idBaseline;
        uint32[] memory eventIdsBaseline = new uint32[](1);
        eventIdsBaseline[0] = 0;
        uint256 beforeBaseline = user.balance;
        rmBaseline.claimRedeemRequests(idsBaseline, eventIdsBaseline);
        uint256 totalBaseline = user.balance - beforeBaseline;

        uint256 expectedTotal =
            applyRate(10e18, 1.05e18) + applyRate(5e18, 1e18) + applyRate(10e18, 1.1e18) + applyRate(5e18, 1e18);
        assertEq(totalBaseline, expectedTotal);
        assertEq(totalBaseline, 31.5e18);
        assertEq(rmBaseline.getRedeemRequestDetails(idBaseline).amount, 0);

        // depth-limited: the identical scenario, claimed with depth = 0 three times in a row, so
        // each call settles against exactly one withdrawal event
        (RiverMock riverStepped, RedeemManagerV1 rmStepped) = _deployFreshManager();
        uint32 idStepped = _buildDepthTestScenario(riverStepped, rmStepped, user);

        uint32[] memory idsStepped = new uint32[](1);
        idsStepped[0] = idStepped;

        // step 1 (depth 0): 10e18 credited plus a 5e18 tail at the request rate. A mark stack pays
        // 15.5 here, the difference being that the two credits are blended into one rate.
        uint32[] memory events0 = new uint32[](1);
        events0[0] = 0;
        uint256 before1 = user.balance;
        rmStepped.claimRedeemRequests(idsStepped, events0, true, 0);
        uint256 received1 = user.balance - before1;
        assertEq(received1, 16.125e18);
        assertEq(rmStepped.getRedeemRequestDetails(idStepped).height, 15e18);
        assertEq(rmStepped.getRedeemRequestDetails(idStepped).amount, 15e18);

        // step 2 (depth 0): the rest of the credited band. Ends at height 25e18.
        uint32[] memory events1 = new uint32[](1);
        events1[0] = 1;
        uint256 before2 = user.balance;
        rmStepped.claimRedeemRequests(idsStepped, events1, true, 0);
        uint256 received2 = user.balance - before2;
        assertEq(received2, 10.375e18);
        assertEq(rmStepped.getRedeemRequestDetails(idStepped).height, 25e18);
        assertEq(rmStepped.getRedeemRequestDetails(idStepped).amount, 5e18);

        // step 3 (depth 0): the uncredited tail, at exactly the request rate -- fully claimed
        uint32[] memory events2 = new uint32[](1);
        events2[0] = 2;
        uint256 before3 = user.balance;
        rmStepped.claimRedeemRequests(idsStepped, events2, true, 0);
        uint256 received3 = user.balance - before3;
        assertEq(received3, applyRate(5e18, 1e18));
        assertEq(rmStepped.getRedeemRequestDetails(idStepped).amount, 0);

        uint256 totalStepped = received1 + received2 + received3;
        assertEq(totalStepped, totalBaseline);

        // depth = 1: a single call settling exactly two events (one recursion), then finished off
        // unrestricted -- the total must still match
        (RiverMock riverMid, RedeemManagerV1 rmMid) = _deployFreshManager();
        uint32 idMid = _buildDepthTestScenario(riverMid, rmMid, user);

        uint32[] memory idsMid = new uint32[](1);
        idsMid[0] = idMid;
        uint32[] memory midEvents = new uint32[](1);
        midEvents[0] = 0;
        uint256 beforeMid1 = user.balance;
        rmMid.claimRedeemRequests(idsMid, midEvents, true, 1);
        uint256 receivedMid1 = user.balance - beforeMid1;
        assertEq(receivedMid1, received1 + received2);
        assertEq(rmMid.getRedeemRequestDetails(idMid).height, 25e18);
        assertEq(rmMid.getRedeemRequestDetails(idMid).amount, 5e18);

        uint32[] memory midEvents2 = new uint32[](1);
        midEvents2[0] = 2;
        uint256 beforeMid2 = user.balance;
        rmMid.claimRedeemRequests(idsMid, midEvents2);
        uint256 receivedMid2 = user.balance - beforeMid2;

        assertEq(receivedMid1 + receivedMid2, totalBaseline);
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
        assertEq(redeemManager.version(), "1.3.0");
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
