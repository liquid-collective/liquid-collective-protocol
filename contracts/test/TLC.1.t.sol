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

    event CreatedVestingSchedule(uint256 index, address indexed creator, address indexed beneficiary, uint256 amount);

    function testCreateVesting() public {
        vm.startPrank(initAccount);
        vm.expectEmit(true, true, true, true);
        emit CreatedVestingSchedule(0, initAccount, joe, 10_000e18);
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

    function testCreateInvalidVestingZeroBeneficiary() public {
        vm.startPrank(initAccount);
        vm.expectRevert(
            abi.encodeWithSignature(
                "InvalidVestingScheduleParameter(string)", "Vesting schedule beneficiary must be non zero address"
            )
        );
        tlc.createVestingSchedule(
            address(0), block.timestamp, 365 * 24 * 3600, 4 * 365 * 24 * 3600, 365 * 2 * 3600, true, 10_000e18
        );
        vm.stopPrank();
    }

    function testCreateInvalidVestingZeroDuration() public {
        vm.startPrank(initAccount);
        vm.expectRevert(
            abi.encodeWithSignature("InvalidVestingScheduleParameter(string)", "Vesting schedule duration must be > 0")
        );
        tlc.createVestingSchedule(joe, block.timestamp, 365 * 24 * 3600, 0, 365 * 2 * 3600, true, 10_000e18);
        vm.stopPrank();
    }

    function testCreateInvalidVestingLockDurationOverDuration() public {
        vm.startPrank(initAccount);
        vm.expectRevert(
            abi.encodeWithSignature(
                "InvalidVestingScheduleParameter(string)",
                "Vesting schedule duration must be greater than lock duration"
            )
        );
        tlc.createVestingSchedule(
            joe, block.timestamp, 5 * 365 * 24 * 3600, 4 * 365 * 24 * 3600, 365 * 2 * 3600, true, 10_000e18
        );
        vm.stopPrank();
    }

    function testCreateInvalidVestingZeroAmount() public {
        vm.startPrank(initAccount);
        vm.expectRevert(
            abi.encodeWithSignature("InvalidVestingScheduleParameter(string)", "Vesting schedule amount must be > 0")
        );
        tlc.createVestingSchedule(joe, block.timestamp, 365 * 24 * 3600, 4 * 365 * 24 * 3600, 365 * 2 * 3600, true, 0);
        vm.stopPrank();
    }

    function testCreateInvalidVestingZeroPeriod() public {
        vm.startPrank(initAccount);
        vm.expectRevert(
            abi.encodeWithSignature("InvalidVestingScheduleParameter(string)", "Vesting schedule period must be > 0")
        );
        tlc.createVestingSchedule(joe, block.timestamp, 365 * 24 * 3600, 4 * 365 * 24 * 3600, 0, true, 10_000e18);
        vm.stopPrank();
    }

    function testCreateInvalidVestingPeriodDoesNotDivideDuration() public {
        vm.startPrank(initAccount);
        vm.expectRevert(
            abi.encodeWithSignature(
                "InvalidVestingScheduleParameter(string)", "Vesting schedule duration must split in exact periods"
            )
        );
        tlc.createVestingSchedule(
            joe, block.timestamp, 365 * 24 * 3600, 4 * 365 * 24 * 3600 + 1, 365 * 2 * 3600, true, 10_000e18
        );
        vm.stopPrank();
    }

    function testCreateInvalidVestingPeriodDoesNotDivideLockDuration() public {
        vm.startPrank(initAccount);
        vm.expectRevert(
            abi.encodeWithSignature(
                "InvalidVestingScheduleParameter(string)", "Vesting schedule cliff must split in exact periods"
            )
        );
        tlc.createVestingSchedule(
            joe, block.timestamp, 365 * 24 * 3600 + 1, 4 * 365 * 24 * 3600, 365 * 2 * 3600, true, 10_000e18
        );
        vm.stopPrank();
    }

    function testCreateMultipleVestings() public {
        vm.startPrank(initAccount);
        vm.expectEmit(true, true, true, true);
        emit CreatedVestingSchedule(0, initAccount, joe, 10_000e18);
        assert(
            tlc.createVestingSchedule(
                joe, block.timestamp, 365 * 24 * 3600, 4 * 365 * 24 * 3600, 365 * 2 * 3600, true, 10_000e18
            ) == 0
        );

        vm.expectEmit(true, true, true, true);
        emit CreatedVestingSchedule(1, initAccount, bob, 10_000e18);
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

    event ReleasedVestingSchedule(uint256 index, uint256 releasedAmount);

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
        vm.expectEmit(true, true, true, true);
        emit ReleasedVestingSchedule(0, 2_500e18);
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
        vm.expectEmit(true, true, true, true);
        emit ReleasedVestingSchedule(0, 5_000e18);
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

    event RevokedVestingSchedule(uint256 index, uint256 returnedAmount);

    function testRevokeBeforeCliff() public {
        vm.warp(0);

        vm.startPrank(initAccount);
        assert(
            tlc.createVestingSchedule(joe, 0, 365 * 24 * 3600, 4 * 365 * 24 * 3600, 365 * 2 * 3600, true, 10_000e18)
                == 0
        );
        vm.stopPrank();

        vm.startPrank(initAccount);
        vm.expectEmit(true, true, true, true);
        emit RevokedVestingSchedule(0, 10_000e18);
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
        vm.expectEmit(true, true, true, true);
        emit RevokedVestingSchedule(0, 7_500e18);
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
        vm.expectEmit(true, true, true, true);
        emit RevokedVestingSchedule(0, 0);
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
        vm.expectRevert(abi.encodeWithSignature("InvalidRevokedVestingScheduleEnd()"));
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

    event DelegatedVestingEscrow(uint256 index, address oldDelegatee, address newDelegatee);

    function testDelegateVestingEscrow() public {
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
        vm.expectEmit(true, true, true, true);
        emit DelegatedVestingEscrow(0, joe, bob);
        tlc.delegateVestingEscrow(0, bob);
        vm.stopPrank();

        // Verify escrow delegation has been updated
        assert(tlc.delegates(tlc.vestingEscrow(0)) == bob);
    }

    function testDelegateVestingEscrowFromInvalidAccount() public {
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

    function testVestingScheduleFuzzing(
        uint128 periodDuration,
        uint8 lockPeriodCount,
        uint8 vestingPeriodCount,
        uint256 amount,
        uint256 releaseAt
    ) public {
        vm.warp(0);
        if (periodDuration == 0) {
            periodDuration = 1;
        }

        if ((lockPeriodCount == 0) && (vestingPeriodCount == 0)) {
            vestingPeriodCount = 1;
        }

        // make sure that at least one token can be released for each period
        if (amount < (uint256(lockPeriodCount) + uint256(vestingPeriodCount) + 1)) {
            amount = uint256(lockPeriodCount) + uint256(vestingPeriodCount) + 1;
        }

        amount = amount % tlc.balanceOf(initAccount);

        uint256 totalDuration = (uint256(lockPeriodCount) + uint256(vestingPeriodCount)) * uint256(periodDuration);
        uint256 lockDuration = uint256(lockPeriodCount) * uint256(periodDuration);
        vm.startPrank(initAccount);
        assert(tlc.createVestingSchedule(joe, 0, lockDuration, totalDuration, periodDuration, true, amount) == 0);
        vm.stopPrank();
        assert(tlc.balanceOf(initAccount) == 1_000_000_000e18 - amount);
        assert(tlc.balanceOf(tlc.vestingEscrow(0)) == amount);

        releaseAt = releaseAt % totalDuration;

        vm.warp(releaseAt);

        if ((releaseAt < lockDuration) || (releaseAt < periodDuration)) {
            vm.startPrank(joe);
            vm.expectRevert(abi.encodeWithSignature("ZeroReleasableAmount()"));
            tlc.releaseVestingSchedule(0);
            vm.stopPrank();
        } else {
            vm.startPrank(joe);
            uint256 releasedAmount = tlc.releaseVestingSchedule(0);
            vm.stopPrank();
            assert(releasedAmount > 0);
            assert(tlc.balanceOf(joe) == releasedAmount);
            assert(tlc.balanceOf(tlc.vestingEscrow(0)) == amount - releasedAmount);
            assert(
                tlc.balanceOf(initAccount) + tlc.balanceOf(joe) + tlc.balanceOf(tlc.vestingEscrow(0))
                    == 1_000_000_000e18
            );
        }
    }
}
