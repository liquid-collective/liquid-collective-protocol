//SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.34;

import "./RedeemManager.1.t.sol";

/// @title Repro for BS-4878
/// @notice Reproduces the state of the staging (hoodi/devHoodi) deployments: RedeemManager deployed
///         fresh from the v1.2.1 sources, so `initializeRedeemManagerV1` leaves Version at 1 and every
///         redeem request is written directly in the RedeemQueueV2 (5 word) layout. The BYOV v1.3.0
///         upgrade script then calls `initializeRedeemManagerV1_2`, whose `init(1)` guard still passes.
contract RedeemManagerDoubleMigrationRepro is RedeeManagerV1TestBase {
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

        // This is the only initializer the staging deploy script (03_deploy_...) calls.
        redeemManager.initializeRedeemManagerV1(address(river));
    }

    function _allowlistUser(address user) internal {
        address[] memory accounts = new address[](1);
        accounts[0] = user;
        uint256[] memory permissions = new uint256[](1);
        permissions[0] = LibAllowlistMasks.REDEEM_MASK | LibAllowlistMasks.DEPOSIT_MASK;

        vm.prank(allowlistAllower);
        allowlist.setAllowPermissions(accounts, permissions);
    }

    function _request(uint256 _salt, uint128 _amount) internal returns (address user) {
        user = uf._new(_salt);
        _allowlistUser(user);
        river.sudoDeal(user, _amount);
        vm.startPrank(user);
        river.approve(address(redeemManager), _amount);
        redeemManager.requestRedeem(_amount, user);
        vm.stopPrank();
    }

    function testDoubleMigrationCorruptsExistingRequests() external {
        address u0 = _request(1, 10 ether);
        address u1 = _request(2, 20 ether);
        address u2 = _request(3, 30 ether);

        RedeemQueueV2.RedeemRequest[3] memory before_;
        for (uint32 i = 0; i < 3; ++i) {
            before_[i] = redeemManager.getRedeemRequestDetails(i);
        }
        assertEq(before_[1].amount, 20 ether);
        assertEq(before_[1].recipient, u1);
        assertEq(before_[2].recipient, u2);
        assertEq(before_[0].recipient, u0);

        // The BYOV v1.3.0 upgrade script runs this against the already-V2 queue.
        redeemManager.initializeRedeemManagerV1_2();

        RedeemQueueV2.RedeemRequest[3] memory afterMigration;
        for (uint32 i = 0; i < 3; ++i) {
            afterMigration[i] = redeemManager.getRedeemRequestDetails(i);
            emit log_named_uint("id", i);
            emit log_named_uint("  amount", afterMigration[i].amount);
            emit log_named_uint("  maxRedeemableEth", afterMigration[i].maxRedeemableEth);
            emit log_named_address("  recipient", afterMigration[i].recipient);
            emit log_named_uint("  height", afterMigration[i].height);
            emit log_named_address("  initiator", afterMigration[i].initiator);
        }

        assertEq(redeemManager.getRedeemRequestCount(), 3);

        // Request 0 keeps its payload (stride 0 is identical in both layouts).
        assertEq(afterMigration[0].amount, before_[0].amount);
        assertEq(afterMigration[0].recipient, before_[0].recipient);

        // Requests 1 and 2 are read at the wrong stride and are destroyed.
        assertTrue(afterMigration[1].amount != before_[1].amount, "request 1 amount survived");
        assertTrue(afterMigration[1].recipient != before_[1].recipient, "request 1 recipient survived");
        assertTrue(afterMigration[2].amount != before_[2].amount, "request 2 amount survived");
        assertTrue(afterMigration[2].recipient != before_[2].recipient, "request 2 recipient survived");

        // Heights are no longer monotonic, which breaks the dichotomic resolve/claim search.
        assertTrue(
            !(afterMigration[0].height <= afterMigration[1].height
                    && afterMigration[1].height <= afterMigration[2].height),
            "heights still monotonic"
        );
    }

    /// @notice The stored initiator is lost even for request 0, which is the request that survives.
    function testDoubleMigrationOverwritesInitiatorWithRecipient() external {
        address initiator = uf._new(10);
        address recipient = uf._new(11);
        _allowlistUser(initiator);
        _allowlistUser(recipient);
        river.sudoDeal(initiator, 5 ether);
        vm.startPrank(initiator);
        river.approve(address(redeemManager), 5 ether);
        redeemManager.requestRedeem(5 ether, recipient);
        vm.stopPrank();

        assertEq(redeemManager.getRedeemRequestDetails(0).initiator, initiator);

        redeemManager.initializeRedeemManagerV1_2();

        assertEq(redeemManager.getRedeemRequestDetails(0).initiator, recipient);
    }
}
