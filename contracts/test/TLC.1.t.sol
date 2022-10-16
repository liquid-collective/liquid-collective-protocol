//SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import "../src/TLC.1.sol";
import "forge-std/Test.sol";

contract TLCTests is Test {
    TLCV1 internal tlc;

    address internal escrowImplem;
    address internal initAccount;
    address internal bob;
    address internal joe;

    function setUp() public {
        initAccount = makeAddr("init");
        bob = makeAddr("bob");
        joe = makeAddr("joe");

        tlc = new TLCV1();
        tlc.initTLCV1(initAccount);
    }

    function testName() public view {
        assert(keccak256(bytes(tlc.name())) == keccak256("Liquid Collective"));
    }

    function testSymbol() public view {
        assert(keccak256(bytes(tlc.symbol())) == keccak256("TLC"));
    }

    function testInitialSupplyAndBalance() public view {
        assert(tlc.totalSupply() == 1_000_000_000e18);
        assert(tlc.balanceOf(initAccount) == tlc.totalSupply());
    }

    function testTransfer() public {
        vm.startPrank(initAccount);
        tlc.transfer(joe, 5_000e18);
        vm.stopPrank();

        assert(tlc.balanceOf(joe) == 5_000e18);
        assert(tlc.balanceOf(initAccount) == 999_995_000e18);
    }

    function testDelegate() public {
        vm.startPrank(initAccount);
        tlc.transfer(joe, 5_000e18);
        vm.stopPrank();
        assert(tlc.balanceOf(joe) == 5_000e18);

        // before self delegating voting power is zero (this is an implementation choice from
        // open zeppelin to optimize gas)
        assert(tlc.getVotes(joe) == 0);

        vm.startPrank(joe);
        tlc.delegate(joe);
        vm.stopPrank();

        assert(tlc.balanceOf(joe) == 5_000e18);
        assert(tlc.getVotes(joe) == 5_000e18);
    }

    function testCheckpoints() public {
        vm.roll(1000);

        vm.startPrank(initAccount);
        tlc.transfer(joe, 5_000e18);
        vm.stopPrank();

        vm.startPrank(joe);
        tlc.delegate(joe);
        vm.stopPrank();

        assert(tlc.balanceOf(joe) == 5_000e18);
        assert(tlc.getVotes(joe) == 5_000e18);

        vm.roll(1010);
        assert(tlc.getPastVotes(joe, 999) == 0);
        assert(tlc.getPastVotes(joe, 1005) == 5_000e18);

        vm.startPrank(joe);
        tlc.transfer(bob, 2_500e18);
        vm.stopPrank();

        vm.startPrank(bob);
        tlc.delegate(bob);
        vm.stopPrank();

        vm.roll(1020);
        assert(tlc.getPastVotes(joe, 999) == 0);
        assert(tlc.getPastVotes(joe, 1005) == 5_000e18);
        assert(tlc.getPastVotes(joe, 1010) == 2_500e18);
        assert(tlc.getPastVotes(bob, 1005) == 0);
        assert(tlc.getPastVotes(bob, 1010) == 2_500e18);
    }

    function testDelegateAndTransfer() public {
        vm.startPrank(initAccount);
        tlc.transfer(joe, 5_000e18);
        vm.stopPrank();
        assert(tlc.balanceOf(joe) == 5_000e18);

        // before self delegating voting power is zero
        // (this is an implementation choice from open zeppelin to optimize gas)
        assert(tlc.getVotes(joe) == 0);

        vm.startPrank(joe);
        tlc.delegate(joe);
        vm.stopPrank();

        assert(tlc.balanceOf(joe) == 5_000e18);
        assert(tlc.getVotes(joe) == 5_000e18);

        vm.startPrank(joe);
        tlc.transfer(bob, 2_500e18);
        vm.stopPrank();

        assert(tlc.balanceOf(joe) == 2_500e18);
        assert(tlc.balanceOf(bob) == 2_500e18);
        assert(tlc.getVotes(joe) == 2_500e18);

        // before self delegating voting power is zero
        assert(tlc.getVotes(bob) == 0);

        vm.startPrank(bob);
        tlc.delegate(bob);
        vm.stopPrank();

        assert(tlc.balanceOf(joe) == 2_500e18);
        assert(tlc.balanceOf(bob) == 2_500e18);
        assert(tlc.getVotes(joe) == 2_500e18);
        assert(tlc.getVotes(bob) == 2_500e18);

        vm.startPrank(joe);
        tlc.transfer(bob, 1_000e18);
        vm.stopPrank();

        assert(tlc.balanceOf(joe) == 1_500e18);
        assert(tlc.balanceOf(bob) == 3_500e18);
        assert(tlc.getVotes(joe) == 1_500e18);
        assert(tlc.getVotes(bob) == 3_500e18);
    }

    function testCreateVesting() public {
        vm.startPrank(initAccount);
        assert(
            tlc.createVestingSchedule(
                joe, block.timestamp, 365 * 24 * 3600, 4 * 365 * 24 * 3600, 365 * 2 * 3600, true, 10_000e18
            ) == 0
        );
        vm.stopPrank();

        assert(tlc.getVestingScheduleCount() == 1);

        // Verify balances
        assert(tlc.balanceOf(initAccount) == 999_990_000e18);
        assert(tlc.balanceOf(tlc.vestingEscrow(0)) == 10_000e18);
        assert(tlc.balanceOf(joe) == 0);

        // Verify vesting schedule object has been properly created
        VestingSchedules.VestingSchedule memory vestingSchedule = tlc.getVestingSchedule(0);

        assert(vestingSchedule.start == block.timestamp);
        assert(vestingSchedule.cliff == block.timestamp + 365 * 24 * 3600);
        assert(vestingSchedule.duration == 4 * 365 * 24 * 3600);
        assert(vestingSchedule.period == 365 * 2 * 3600);
        assert(vestingSchedule.amount == 10_000e18);
        assert(vestingSchedule.creator == initAccount);
        assert(vestingSchedule.beneficiary == joe);
        assert(vestingSchedule.revocable == true);
        assert(vestingSchedule.end == block.timestamp + 4 * 365 * 24 * 3600);

        // Verify escrow delegated to beneficiary
        assert(tlc.delegates(tlc.vestingEscrow(0)) == joe);
    }

    function testCreateMultipleVestings() public {
        vm.startPrank(initAccount);
        assert(
            tlc.createVestingSchedule(
                joe, block.timestamp, 365 * 24 * 3600, 4 * 365 * 24 * 3600, 365 * 2 * 3600, true, 10_000e18
            ) == 0
        );
        assert(
            tlc.createVestingSchedule(
                bob, block.timestamp, 365 * 24 * 3600, 4 * 365 * 24 * 3600, 365 * 2 * 3600, true, 10_000e18
            ) == 1
        );
        vm.stopPrank();

        assert(tlc.getVestingScheduleCount() == 2);
        assert(tlc.balanceOf(initAccount) == 999_980_000e18);
        assert(tlc.balanceOf(tlc.vestingEscrow(0)) == 10_000e18);
        assert(tlc.balanceOf(tlc.vestingEscrow(1)) == 10_000e18);
    }

    function testReleaseVestingScheduleBeforeCliff() public {
        vm.warp(0);

        vm.startPrank(initAccount);
        assert(
            tlc.createVestingSchedule(joe, 0, 365 * 24 * 3600, 4 * 365 * 24 * 3600, 365 * 2 * 3600, true, 10_000e18)
                == 0
        );
        vm.stopPrank();

        // Move time right before cliff
        vm.warp(365 * 24 * 3600 - 1);

        vm.startPrank(joe);
        vm.expectRevert(abi.encodeWithSignature("ZeroReleasableAmount()"));
        // Attempts to releaseVestingSchedule
        tlc.releaseVestingSchedule(0);
        vm.stopPrank();
    }

    function testReleaseVestingScheduleAtCliff() public {
        vm.warp(0);

        vm.startPrank(initAccount);
        assert(
            tlc.createVestingSchedule(joe, 0, 365 * 24 * 3600, 4 * 365 * 24 * 3600, 365 * 2 * 3600, true, 10_000e18)
                == 0
        );
        vm.stopPrank();

        // Move to cliff
        vm.warp(365 * 24 * 3600);

        vm.startPrank(joe);
        // Attempts to releaseVestingSchedule all vested tokens
        tlc.releaseVestingSchedule(0);
        vm.stopPrank();

        // Verify balances
        assert(tlc.balanceOf(tlc.vestingEscrow(0)) == 7_500e18);
        assert(tlc.balanceOf(joe) == 2_500e18);
    }

    function testReleaseVestingScheduleAfterCliff() public {
        vm.warp(0);

        vm.startPrank(initAccount);
        assert(
            tlc.createVestingSchedule(joe, 0, 365 * 24 * 3600, 4 * 365 * 24 * 3600, 365 * 2 * 3600, true, 10_000e18)
                == 0
        );
        vm.stopPrank();

        // Move to end half way vesting
        vm.warp(2 * 365 * 24 * 3600);

        vm.startPrank(joe);
        // Attempts to releaseVestingSchedule all vested tokens
        tlc.releaseVestingSchedule(0);
        vm.stopPrank();

        // Verify balances
        assert(tlc.balanceOf(tlc.vestingEscrow(0)) == 5_000e18);
        assert(tlc.balanceOf(joe) == 5_000e18);
    }

    function testComputeReleasableAmount() public {
        vm.warp(0);

        vm.startPrank(initAccount);
        assert(
            tlc.createVestingSchedule(joe, 0, 365 * 24 * 3600, 4 * 365 * 24 * 3600, 365 * 2 * 3600, true, 10_000e18)
                == 0
        );
        vm.stopPrank();

        // At beginning of schedule
        assert(tlc.computeReleasableAmount(0) == 0);

        // Move right after beginning of schedule
        vm.warp(1);
        assert(tlc.computeReleasableAmount(0) == 0);

        // Move to half way cliff
        vm.warp(365 * 12 * 3600);
        assert(tlc.computeReleasableAmount(0) == 0);

        // Move right before cliff
        vm.warp(365 * 24 * 3600 - 1);
        assert(tlc.computeReleasableAmount(0) == 0);

        // Move at cliff
        vm.warp(365 * 24 * 3600);
        assert(tlc.computeReleasableAmount(0) == 2_500e18);

        // Move right after cliff
        vm.warp(365 * 24 * 3600 + 1);
        assert(tlc.computeReleasableAmount(0) == 2_500e18);

        // Move right before slice period
        vm.warp(365 * 24 * 3600 + 365 * 2 * 3600 - 1);
        assert(tlc.computeReleasableAmount(0) == 2_500e18);

        // Move at slice period
        vm.warp(365 * 24 * 3600 + 365 * 2 * 3600);
        assert(tlc.computeReleasableAmount(0) == 2708333333333333333333);

        // Move right after slice period
        vm.warp(365 * 24 * 3600 + 365 * 2 * 3600 + 1);
        assert(tlc.computeReleasableAmount(0) == 2708333333333333333333);

        // Move half way vesting
        vm.warp(365 * 24 * 3600 + 365 * 24 * 3600);
        assert(tlc.computeReleasableAmount(0) == 5_000e18);

        // Move right before vesting end
        vm.warp(4 * 365 * 24 * 3600 - 1);
        assert(tlc.computeReleasableAmount(0) == 9791666666666666666666);

        // Move at vesting end
        vm.warp(4 * 365 * 24 * 3600);
        assert(tlc.computeReleasableAmount(0) == 10_000e18);

        // Move right after vesting end
        vm.warp(4 * 365 * 24 * 3600 + 1);
        assert(tlc.computeReleasableAmount(0) == 10_000e18);

        // Move 1 year after vesting end
        vm.warp(5 * 365 * 24 * 3600 + 1);
        assert(tlc.computeReleasableAmount(0) == 10_000e18);
    }

    function testReleaseVestingScheduleFromInvalidAccount() public {
        vm.warp(0);

        vm.startPrank(initAccount);
        assert(
            tlc.createVestingSchedule(joe, 0, 365 * 24 * 3600, 4 * 365 * 24 * 3600, 365 * 2 * 3600, true, 10_000e18)
                == 0
        );
        vm.stopPrank();

        // Move to end half way vesting
        vm.warp(2 * 365 * 24 * 3600);

        vm.startPrank(bob);
        vm.expectRevert(abi.encodeWithSignature("Unauthorized(address)", bob));
        tlc.releaseVestingSchedule(0);
        vm.stopPrank();
    }

    function testRevokeBeforeCliff() public {
        vm.warp(0);

        vm.startPrank(initAccount);
        assert(
            tlc.createVestingSchedule(joe, 0, 365 * 24 * 3600, 4 * 365 * 24 * 3600, 365 * 2 * 3600, true, 10_000e18)
                == 0
        );
        vm.stopPrank();

        vm.startPrank(initAccount);
        tlc.revokeVestingSchedule(0, 365 * 24 * 3600 - 1);
        vm.stopPrank();

        assert(tlc.balanceOf(initAccount) == 1_000_000_000e18);
        assert(tlc.balanceOf(tlc.vestingEscrow(0)) == 0);
        assert(tlc.balanceOf(joe) == 0);

        // Verify vesting schedule object has been properly updated
        VestingSchedules.VestingSchedule memory vestingSchedule = tlc.getVestingSchedule(0);
        assert(vestingSchedule.end == 365 * 24 * 3600 - 1);
    }

    function testRevokeAtCliff() public {
        vm.warp(0);

        vm.startPrank(initAccount);
        assert(
            tlc.createVestingSchedule(joe, 0, 365 * 24 * 3600, 4 * 365 * 24 * 3600, 365 * 2 * 3600, true, 10_000e18)
                == 0
        );
        vm.stopPrank();

        vm.startPrank(initAccount);
        tlc.revokeVestingSchedule(0, 365 * 24 * 3600);
        vm.stopPrank();

        assert(tlc.balanceOf(initAccount) == 999_997_500e18);
        assert(tlc.balanceOf(tlc.vestingEscrow(0)) == 2_500e18);
        assert(tlc.balanceOf(joe) == 0);

        // Verify vesting schedule object has been properly updated
        VestingSchedules.VestingSchedule memory vestingSchedule = tlc.getVestingSchedule(0);
        assert(vestingSchedule.end == 365 * 24 * 3600);
    }

    function testRevokeAtDuration() public {
        vm.warp(0);

        vm.startPrank(initAccount);
        assert(
            tlc.createVestingSchedule(joe, 0, 365 * 24 * 3600, 4 * 365 * 24 * 3600, 365 * 2 * 3600, true, 10_000e18)
                == 0
        );
        vm.stopPrank();

        vm.startPrank(initAccount);
        tlc.revokeVestingSchedule(0, 4 * 365 * 24 * 3600);
        vm.stopPrank();

        assert(tlc.balanceOf(initAccount) == 999_990_000e18);
        assert(tlc.balanceOf(tlc.vestingEscrow(0)) == 10_000e18);

        // Verify vesting schedule object has been properly updated
        VestingSchedules.VestingSchedule memory vestingSchedule = tlc.getVestingSchedule(0);
        assert(vestingSchedule.end == 4 * 365 * 24 * 3600);
    }

    function testRevokeNotRevokable() public {
        vm.warp(0);

        vm.startPrank(initAccount);
        assert(
            tlc.createVestingSchedule(joe, 0, 365 * 24 * 3600, 4 * 365 * 24 * 3600, 365 * 2 * 3600, false, 10_000e18)
                == 0
        );
        vm.stopPrank();

        vm.startPrank(initAccount);
        vm.expectRevert(abi.encodeWithSignature("VestingScheduleNotRevocable()"));
        tlc.revokeVestingSchedule(0, 4 * 365 * 24 * 3600);
        vm.stopPrank();
    }

    function testRevokeFromInvalidAccount() public {
        vm.warp(0);

        vm.startPrank(initAccount);
        assert(
            tlc.createVestingSchedule(joe, 0, 365 * 24 * 3600, 4 * 365 * 24 * 3600, 365 * 2 * 3600, true, 10_000e18)
                == 0
        );
        vm.stopPrank();

        vm.startPrank(joe);
        vm.expectRevert(abi.encodeWithSignature("Unauthorized(address)", joe));
        tlc.revokeVestingSchedule(0, 4 * 365 * 24 * 3600);
        vm.stopPrank();
    }

    function testRevokeTwice() public {
        vm.warp(0);

        vm.startPrank(initAccount);
        assert(
            tlc.createVestingSchedule(joe, 0, 365 * 24 * 3600, 4 * 365 * 24 * 3600, 365 * 2 * 3600, true, 10_000e18)
                == 0
        );
        vm.stopPrank();

        vm.startPrank(initAccount);
        tlc.revokeVestingSchedule(0, 2 * 365 * 24 * 3600);
        vm.stopPrank();

        assert(tlc.balanceOf(initAccount) == 999_995_000e18);
        assert(tlc.balanceOf(tlc.vestingEscrow(0)) == 5_000e18);

        vm.startPrank(initAccount);
        tlc.revokeVestingSchedule(0, 1 * 365 * 24 * 3600);
        vm.stopPrank();

        assert(tlc.balanceOf(initAccount) == 999_997_500e18);
        assert(tlc.balanceOf(tlc.vestingEscrow(0)) == 2_500e18);
    }

    function testRevokeTwiceAfterEnd() public {
        vm.warp(0);

        vm.startPrank(initAccount);
        assert(
            tlc.createVestingSchedule(joe, 0, 365 * 24 * 3600, 4 * 365 * 24 * 3600, 365 * 2 * 3600, true, 10_000e18)
                == 0
        );
        vm.stopPrank();

        vm.startPrank(initAccount);
        tlc.revokeVestingSchedule(0, 1 * 365 * 24 * 3600);
        vm.stopPrank();

        vm.startPrank(initAccount);
        vm.expectRevert(abi.encodeWithSignature("VestingScheduleNotRevocableAfterEnd(uint256)", 365 * 24 * 3600));
        tlc.revokeVestingSchedule(0, 2 * 365 * 24 * 3600);
        vm.stopPrank();
    }

    function testReleaseVestingScheduleAfterRevoke() public {
        vm.warp(0);

        vm.startPrank(initAccount);
        assert(
            tlc.createVestingSchedule(joe, 0, 365 * 24 * 3600, 4 * 365 * 24 * 3600, 365 * 2 * 3600, true, 10_000e18)
                == 0
        );
        vm.stopPrank();

        vm.startPrank(initAccount);
        // revoke at mid vesting duration
        tlc.revokeVestingSchedule(0, 2 * 365 * 24 * 3600);
        vm.stopPrank();

        assert(tlc.balanceOf(initAccount) == 999_995_000e18);
        assert(tlc.balanceOf(tlc.vestingEscrow(0)) == 5_000e18);

        // move to cliff
        vm.warp(365 * 24 * 3600);

        vm.startPrank(joe);
        tlc.releaseVestingSchedule(0);
        vm.stopPrank();

        assert(tlc.balanceOf(initAccount) == 999_995_000e18);
        assert(tlc.balanceOf(tlc.vestingEscrow(0)) == 2_500e18);
        assert(tlc.balanceOf(joe) == 2_500e18);

        // move to vesting schedule end
        vm.warp(2 * 365 * 24 * 3600);

        vm.startPrank(joe);
        tlc.releaseVestingSchedule(0);
        vm.stopPrank();

        assert(tlc.balanceOf(initAccount) == 999_995_000e18);
        assert(tlc.balanceOf(tlc.vestingEscrow(0)) == 0);
        assert(tlc.balanceOf(joe) == 5_000e18);
    }

    function testdelegateVestingEscrow() public {
        vm.startPrank(initAccount);
        assert(
            tlc.createVestingSchedule(
                joe, block.timestamp, 365 * 24 * 3600, 4 * 365 * 24 * 3600, 365 * 2 * 3600, true, 10_000e18
            ) == 0
        );
        vm.stopPrank();

        // Verify escrow delegated to beneficiary
        assert(tlc.delegates(tlc.vestingEscrow(0)) == joe);

        vm.startPrank(joe);
        tlc.delegateVestingEscrow(0, bob);
        vm.stopPrank();

        // Verify escrow delegation has been updated
        assert(tlc.delegates(tlc.vestingEscrow(0)) == bob);
    }

    function testdelegateVestingEscrowFromInvalidAccount() public {
        vm.startPrank(initAccount);
        assert(
            tlc.createVestingSchedule(
                joe, block.timestamp, 365 * 24 * 3600, 4 * 365 * 24 * 3600, 365 * 2 * 3600, true, 10_000e18
            ) == 0
        );
        vm.stopPrank();

        // Verify escrow delegated to beneficiary
        assert(tlc.delegates(tlc.vestingEscrow(0)) == joe);

        vm.startPrank(bob);
        vm.expectRevert(abi.encodeWithSignature("Unauthorized(address)", bob));
        tlc.delegateVestingEscrow(0, bob);
        vm.stopPrank();
    }
}
