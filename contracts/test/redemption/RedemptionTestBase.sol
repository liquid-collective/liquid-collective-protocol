//SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.34;

import "forge-std/Test.sol";

import "../RedeemManager.1.t.sol";

import "../utils/LibImplementationUnbricker.sol";

import "../../src/RedeemManager.1.sol";
import "../../src/Allowlist.1.sol";
import "../../src/libraries/LibAllowlistMasks.sol";
import "../../src/state/redeemManager/RateMarkStack.sol";
import "../../src/state/redeemManager/RedeemRequestAnchor.sol";

/// @title Redemption fulfillment test base
/// @notice Shared fixture for the redemption-fulfillment suites under contracts/test/redemption.
/// @dev Deliberately a standalone base rather than an inheritance of `RedeemManagerV1Tests`: that
///      contract is concrete and carries the entire legacy suite, so extending it would re-run every
///      one of its tests inside each new suite. The helpers below mirror the ones that live there so
///      the two suites stay idiomatically identical; `RiverMock` and the event declarations are
///      reused verbatim from `RedeemManager.1.t.sol`.
abstract contract RedemptionTestBase is RedeeManagerV1TestBase {
    RedeemManagerV1 internal redeemManager;

    function setUp() public virtual {
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
        mockRiverAddress = address(river);

        redeemManager.initializeRedeemManagerV1(address(river));
    }

    /// @dev Grants the redeem and deposit permissions to `user`.
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

    function applyRate(uint256 amount, uint256 rate) internal pure returns (uint256) {
        return (amount * rate) / 1e18;
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
    ///      upgrade. `setUp` only runs initializeRedeemManagerV1, leaving the version at 1, whereas
    ///      mainnet is already at 2.
    /// @dev The version is poked rather than reached by calling initializeRedeemManagerV1_2, because
    ///      RedeemQueueV1 and RedeemQueueV2 share the storage slot
    ///      keccak256("river.state.redeemQueue") - 1. Its migration re-interprets that array in place
    ///      and is only safe because init(1) runs it exactly once, before any V2 request exists.
    function _pokeVersionTo(uint256 version) internal {
        vm.store(address(redeemManager), bytes32(uint256(keccak256("river.state.version")) - 1), bytes32(version));
    }

    function _upgradeToV1_3() internal {
        _pokeVersionTo(2);
        redeemManager.initializeRedeemManagerV1_3();
    }

    /// @dev Erases the request-time anchor of `id`, which is how a request that predates the
    ///      stopped-earning upgrade looks on a live deployment: no anchor, so the legacy pro-rata cap
    ///      applies and rate marks are ignored for it.
    function _stripAnchor(uint32 id) internal {
        bytes32 anchorSlot =
            keccak256(abi.encode(uint256(id), bytes32(uint256(keccak256("river.state.redeemRequestAnchor")) - 1)));
        vm.store(address(redeemManager), anchorSlot, bytes32(0));
        vm.store(address(redeemManager), bytes32(uint256(anchorSlot) + 1), bytes32(0));
    }

    /// @dev Pushes a withdrawal event settling `lsETH` of demand, funded at `settlementRate`.
    function _reportWithdraw(uint256 lsETH, uint256 settlementRate) internal returns (uint256 withdrawnEth) {
        withdrawnEth = applyRate(lsETH, settlementRate);
        vm.deal(address(this), withdrawnEth);
        river.sudoReportWithdraw{value: withdrawnEth}(address(redeemManager), lsETH);
    }

    /// @dev Claims request `id` against the withdrawal event that currently satisfies it and returns
    ///      the ETH the recipient received.
    function _claim(uint32 id) internal returns (uint256 received) {
        uint32[] memory ids = new uint32[](1);
        ids[0] = id;
        int64[] memory resolved = redeemManager.resolveRedeemRequests(ids);
        uint32[] memory eventIds = new uint32[](1);
        eventIds[0] = uint32(uint64(resolved[0]));

        address recipient = redeemManager.getRedeemRequestDetails(id).recipient;
        uint256 balanceBefore = recipient.balance;
        redeemManager.claimRedeemRequests(ids, eventIds);
        return recipient.balance - balanceBefore;
    }

    /// @dev Claims request `id` with an explicit starting withdrawal event and recursion depth, for
    ///      the cases that need the walk truncated part-way.
    function _claimWithDepth(uint32 id, uint32 withdrawalEventId, uint16 depth) internal returns (uint256 received) {
        uint32[] memory ids = new uint32[](1);
        ids[0] = id;
        uint32[] memory eventIds = new uint32[](1);
        eventIds[0] = withdrawalEventId;

        address recipient = redeemManager.getRedeemRequestDetails(id).recipient;
        uint256 balanceBefore = recipient.balance;
        redeemManager.claimRedeemRequests(ids, eventIds, true, depth);
        return recipient.balance - balanceBefore;
    }

    /// @dev Settles `lsETH` of demand at `settlementRate` and claims request `id` in full.
    function _settleAndClaim(uint32 id, uint256 lsETH, uint256 settlementRate) internal returns (uint256 received) {
        _reportWithdraw(lsETH, settlementRate);
        return _claim(id);
    }

    /// @dev The first LsETH position not yet covered by any rate mark.
    function _markCursor() internal view returns (uint256) {
        uint256 count = redeemManager.getRateMarkCount();
        if (count == 0) {
            return 0;
        }
        RateMarkStack.RateMark memory last = redeemManager.getRateMarkDetails(uint32(count - 1));
        return last.height + last.amount;
    }

    /// @dev The amount of LsETH demand settled by withdrawal events so far.
    function _settledHeight() internal view returns (uint256) {
        uint256 count = redeemManager.getWithdrawalEventCount();
        if (count == 0) {
            return 0;
        }
        WithdrawalStack.WithdrawalEvent memory last = redeemManager.getWithdrawalEventDetails(uint32(count - 1));
        return last.height + last.amount;
    }

    receive() external payable {}
}
