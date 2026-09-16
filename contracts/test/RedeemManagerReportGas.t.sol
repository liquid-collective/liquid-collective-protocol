//SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.34;

import "forge-std/Test.sol";

import {RiverMock} from "./RedeemManager.1.t.sol";
import "./utils/UserFactory.sol";
import "./utils/LibImplementationUnbricker.sol";
import "../src/Allowlist.1.sol";
import "../src/RedeemManager.1.sol";
import "../src/libraries/LibAllowlistMasks.sol";

/// @title Stopped-earning report gas ceiling
/// @notice Measures what one `reportStoppedEarning` costs per redeem request it credits, and asserts
///         how many requests a report can cover inside a block.
/// @dev `reportStoppedEarning` walks the redeem queue, so its cost grows with the number of pending
///      requests the reported principal covers. It runs inside River's oracle report, after the
///      cumulative stopped-earning balance has already been persisted, so a revert takes the whole
///      report down and the next report faces the same queue and reverts identically. Recovery needs
///      a governance implementation upgrade.
///
///      That makes the request count a report can cover an operating limit, not an implementation
///      detail. This test measures it so the limit is a number in CI rather than a guess, and fails
///      if the per-request cost regresses. `requestRedeem` is gated on REDEEM_MASK, so reaching the
///      limit takes either an allowlisted adversary or an organically long queue.
contract RedeemManagerReportGas_HEAVY_FUZZING is Test {
    /// @dev Measured at 63,711 gas for a request's FIRST credit. Almost all of it is three
    ///      zero-to-non-zero SSTOREs at 22,100 each, for the credited eth, the credited width and the
    ///      band's start position. A later credit to the same request skips the band write and costs
    ///      about 43,600. Packing the width and the band start into one slot, both fit in uint128
    ///      against a total LsETH supply far below 2^128, would take roughly 17,000 off the first
    ///      credit.
    uint256 internal constant MAX_GAS_PER_CREDITED_REQUEST = 66_000;

    /// @dev The operating limit this implies, and the number that actually matters. Below it, a report
    ///      covering that many pending requests no longer fits in a block and the oracle report reverts.
    uint256 internal constant MIN_REQUESTS_PER_BLOCK = 900;
    uint256 internal constant BLOCK_GAS_LIMIT = 60_000_000;

    /// @dev Requests credited in the measured report
    uint256 internal constant REQUESTS = 512;

    AllowlistV1 internal allowlist;
    UserFactory internal uf = new UserFactory();
    RedeemManagerV1 internal redeemManager;
    RiverMock internal river;

    function setUp() external {
        address allowlistAdmin = makeAddr("allowlistAdmin");
        address allowlistAllower = makeAddr("allowlistAllower");
        allowlist = new AllowlistV1();
        LibImplementationUnbricker.unbrick(vm, address(allowlist));
        allowlist.initAllowlistV1(allowlistAdmin, allowlistAllower);
        allowlist.initAllowlistV1_1(makeAddr("allowlistDenier"));

        redeemManager = new RedeemManagerV1();
        LibImplementationUnbricker.unbrick(vm, address(redeemManager));
        river = new RiverMock(address(allowlist));
        redeemManager.initializeRedeemManagerV1(address(river));
    }

    function testReportStoppedEarningGasPerCreditedRequest() external {
        river.sudoSetRate(1e18);

        address user = uf._new(1);
        address[] memory accounts = new address[](1);
        accounts[0] = user;
        uint256[] memory permissions = new uint256[](1);
        permissions[0] = LibAllowlistMasks.REDEEM_MASK | LibAllowlistMasks.DEPOSIT_MASK;
        vm.prank(allowlist.getAllower());
        allowlist.setAllowPermissions(accounts, permissions);

        river.sudoDeal(user, REQUESTS * 1e18);
        vm.prank(user);
        river.approve(address(redeemManager), type(uint256).max);
        for (uint256 i = 0; i < REQUESTS; ++i) {
            vm.prank(user);
            redeemManager.requestRedeem(1e18, user);
        }

        // one report covering every pending request
        uint256 before = gasleft();
        river.sudoReportStoppedEarning(address(redeemManager), REQUESTS * 1e18);
        uint256 used = before - gasleft();

        assertEq(redeemManager.getLockPositionCursor(), REQUESTS * 1e18);

        uint256 perRequest = used / REQUESTS;
        emit log_named_uint("gas for the whole report", used);
        emit log_named_uint("gas per credited request", perRequest);
        emit log_named_uint("requests coverable in a 60M gas block", BLOCK_GAS_LIMIT / perRequest);

        assertLt(perRequest, MAX_GAS_PER_CREDITED_REQUEST);
        assertGt(BLOCK_GAS_LIMIT / perRequest, MIN_REQUESTS_PER_BLOCK);
    }
}
