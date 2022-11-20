//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "../../src/components/ERC20VestableVotesUpgradeable.1.sol";
import "forge-std/Test.sol";

contract TestToken is ERC20VestableVotesUpgradeableV1 {
    // Token information
    string internal constant NAME = "Test Token";
    string internal constant SYMBOL = "TT";

    // Initial supply of token minted
    uint256 internal constant INITIAL_SUPPLY = 1_000_000_000e18; // 1 billion TLC

    function initTestTokenV1(address _account) external initializer {
        LibSanitize._notZeroAddress(_account);
        __ERC20Permit_init(NAME);
        __ERC20_init(NAME, SYMBOL);
        _mint(_account, INITIAL_SUPPLY);
    }
}

contract ERC20VestableVotesUpgradeableV1Tests is Test {
    TestToken internal tt;

    address internal escrowImplem;
    address internal initAccount;
    address internal bob;
    address internal joe;

    function setUp() public {
        initAccount = makeAddr("init");
        bob = makeAddr("bob");
        joe = makeAddr("joe");

        tt = new TestToken();
        tt.initTestTokenV1(initAccount);
    }

    function testTransfer() public {
        vm.startPrank(initAccount);
        tt.transfer(joe, 5_000e18);
        vm.stopPrank();

        assert(tt.balanceOf(joe) == 5_000e18);
        assert(tt.balanceOf(initAccount) == 999_995_000e18);
    }

    function testDelegate() public {
        vm.startPrank(initAccount);
        tt.transfer(joe, 5_000e18);
        vm.stopPrank();
        assert(tt.balanceOf(joe) == 5_000e18);

        // before self delegating voting power is zero (this is an implementation choice from
        // open zeppelin to optimize gas)
        assert(tt.getVotes(joe) == 0);

        vm.startPrank(joe);
        tt.delegate(joe);
        vm.stopPrank();

        assert(tt.balanceOf(joe) == 5_000e18);
        assert(tt.getVotes(joe) == 5_000e18);
    }

    function testCheckpoints() public {
        vm.roll(1000);

        vm.startPrank(initAccount);
        tt.transfer(joe, 5_000e18);
        vm.stopPrank();

        vm.startPrank(joe);
        tt.delegate(joe);
        vm.stopPrank();

        assert(tt.balanceOf(joe) == 5_000e18);
        assert(tt.getVotes(joe) == 5_000e18);

        vm.roll(1010);
        assert(tt.getPastVotes(joe, 999) == 0);
        assert(tt.getPastVotes(joe, 1005) == 5_000e18);

        vm.startPrank(joe);
        tt.transfer(bob, 2_500e18);
        vm.stopPrank();

        vm.startPrank(bob);
        tt.delegate(bob);
        vm.stopPrank();

        vm.roll(1020);
        assert(tt.getPastVotes(joe, 999) == 0);
        assert(tt.getPastVotes(joe, 1005) == 5_000e18);
        assert(tt.getPastVotes(joe, 1010) == 2_500e18);
        assert(tt.getPastVotes(bob, 1005) == 0);
        assert(tt.getPastVotes(bob, 1010) == 2_500e18);
    }

    function testDelegateAndTransfer() public {
        vm.startPrank(initAccount);
        tt.transfer(joe, 5_000e18);
        vm.stopPrank();
        assert(tt.balanceOf(joe) == 5_000e18);

        // before self delegating voting power is zero
        // (this is an implementation choice from open zeppelin to optimize gas)
        assert(tt.getVotes(joe) == 0);

        vm.startPrank(joe);
        tt.delegate(joe);
        vm.stopPrank();

        assert(tt.balanceOf(joe) == 5_000e18);
        assert(tt.getVotes(joe) == 5_000e18);

        vm.startPrank(joe);
        tt.transfer(bob, 2_500e18);
        vm.stopPrank();

        assert(tt.balanceOf(joe) == 2_500e18);
        assert(tt.balanceOf(bob) == 2_500e18);
        assert(tt.getVotes(joe) == 2_500e18);

        // before self delegating voting power is zero
        assert(tt.getVotes(bob) == 0);

        vm.startPrank(bob);
        tt.delegate(bob);
        vm.stopPrank();

        assert(tt.balanceOf(joe) == 2_500e18);
        assert(tt.balanceOf(bob) == 2_500e18);
        assert(tt.getVotes(joe) == 2_500e18);
        assert(tt.getVotes(bob) == 2_500e18);

        vm.startPrank(joe);
        tt.transfer(bob, 1_000e18);
        vm.stopPrank();

        assert(tt.balanceOf(joe) == 1_500e18);
        assert(tt.balanceOf(bob) == 3_500e18);
        assert(tt.getVotes(joe) == 1_500e18);
        assert(tt.getVotes(bob) == 3_500e18);
    }

    event CreatedVestingSchedule(uint256 index, address indexed creator, address indexed beneficiary, uint256 amount);

    function createVestingSchedule(
        address beneficiary,
        uint256 start,
        uint256 cliffDuration,
        uint256 duration,
        uint256 period,
        uint256 lockDuration,
        bool revocable,
        uint256 amount
    ) internal returns (uint256) {
        return createVestingScheduleStackOptimized(
            uint64(start),
            uint32(cliffDuration),
            uint32(duration),
            uint32(period),
            uint32(lockDuration),
            amount,
            beneficiary,
            revocable
        );
    }

    function createVestingScheduleStackOptimized(
        uint64 start,
        uint32 cliffDuration,
        uint32 duration,
        uint32 period,
        uint32 lockDuration,
        uint256 amount,
        address beneficiary,
        bool revocable
    ) internal returns (uint256) {
        return tt.createVestingSchedule(
            start, cliffDuration, duration, period, lockDuration, revocable, amount, beneficiary, address(0)
        );
    }

    function testCreateVesting() public {
        vm.startPrank(initAccount);
        vm.expectEmit(true, true, true, true);
        emit CreatedVestingSchedule(0, initAccount, joe, 10_000e18);
        assert(
            createVestingSchedule(
                joe,
                block.timestamp,
                365 * 24 * 3600,
                4 * 365 * 24 * 3600,
                365 * 2 * 3600,
                365 * 24 * 3600,
                true,
                10_000e18
            ) == 0
        );
        vm.stopPrank();

        assert(tt.getVestingScheduleCount() == 1);

        // Verify balances
        assert(tt.balanceOf(initAccount) == 999_990_000e18);
        assert(tt.balanceOf(tt.vestingEscrow(0)) == 10_000e18);
        assert(tt.balanceOf(joe) == 0);

        // Verify vesting schedule object has been properly created
        VestingSchedules.VestingSchedule memory vestingSchedule = tt.getVestingSchedule(0);

        assert(vestingSchedule.start == block.timestamp);
        assert(vestingSchedule.cliffDuration == 365 * 24 * 3600);
        assert(vestingSchedule.lockDuration == 365 * 24 * 3600);
        assert(vestingSchedule.duration == 4 * 365 * 24 * 3600);
        assert(vestingSchedule.periodDuration == 365 * 2 * 3600);
        assert(vestingSchedule.amount == 10_000e18);
        assert(vestingSchedule.creator == initAccount);
        assert(vestingSchedule.beneficiary == joe);
        assert(vestingSchedule.revocable == true);
        assert(vestingSchedule.end == block.timestamp + 4 * 365 * 24 * 3600);

        // Verify escrow delegated to beneficiary
        assert(tt.delegates(tt.vestingEscrow(0)) == joe);
    }

    function testCreateVestingWithDelegatee() public {
        vm.startPrank(initAccount);
        vm.expectEmit(true, true, true, true);
        emit CreatedVestingSchedule(0, initAccount, joe, 10_000e18);
        assert(
            tt.createVestingSchedule(
                0, 365 * 24 * 3600, 4 * 365 * 24 * 3600, 365 * 2 * 3600, 365 * 24 * 3600, true, 10_000e18, joe, bob
            ) == 0
        );
        vm.stopPrank();

        assert(tt.getVestingScheduleCount() == 1);

        // Verify balances
        assert(tt.balanceOf(initAccount) == 999_990_000e18);
        assert(tt.balanceOf(tt.vestingEscrow(0)) == 10_000e18);
        assert(tt.balanceOf(joe) == 0);

        // Verify vesting schedule object has been properly created
        VestingSchedules.VestingSchedule memory vestingSchedule = tt.getVestingSchedule(0);

        assert(vestingSchedule.start == block.timestamp);
        assert(vestingSchedule.lockDuration == 365 * 24 * 3600);
        assert(vestingSchedule.duration == 4 * 365 * 24 * 3600);
        assert(vestingSchedule.periodDuration == 365 * 2 * 3600);
        assert(vestingSchedule.amount == 10_000e18);
        assert(vestingSchedule.creator == initAccount);
        assert(vestingSchedule.beneficiary == joe);
        assert(vestingSchedule.revocable == true);
        assert(vestingSchedule.end == block.timestamp + 4 * 365 * 24 * 3600);

        // Verify escrow delegated to beneficiary
        assert(tt.delegates(tt.vestingEscrow(0)) == bob);
    }

    function testCreateInvalidVestingZeroBeneficiary() public {
        vm.startPrank(initAccount);
        vm.expectRevert(
            abi.encodeWithSignature(
                "InvalidVestingScheduleParameter(string)", "Vesting schedule beneficiary must be non zero address"
            )
        );
        createVestingSchedule(
            address(0),
            block.timestamp,
            365 * 24 * 3600,
            4 * 365 * 24 * 3600,
            365 * 2 * 3600,
            365 * 24 * 3600,
            true,
            10_000e18
        );
        vm.stopPrank();
    }

    function testCreateInvalidVestingAmountTooLowForPeriodAndDuration() public {
        vm.startPrank(initAccount);
        vm.expectRevert(
            abi.encodeWithSignature(
                "InvalidVestingScheduleParameter(string)", "Vesting schedule amount too low for duration and period"
            )
        );
        createVestingSchedule(joe, block.timestamp, 0, 365, 1, 0, true, 364);
        vm.stopPrank();
    }

    function testCreateInvalidVestingZeroDuration() public {
        vm.startPrank(initAccount);
        vm.expectRevert(
            abi.encodeWithSignature("InvalidVestingScheduleParameter(string)", "Vesting schedule duration must be > 0")
        );
        createVestingSchedule(
            joe, block.timestamp, 365 * 24 * 3600, 0, 365 * 2 * 3600, 365 * 24 * 3600, true, 10_000e18
        );
        vm.stopPrank();
    }

    function testCreateInvalidVestingZeroAmount() public {
        vm.startPrank(initAccount);
        vm.expectRevert(
            abi.encodeWithSignature("InvalidVestingScheduleParameter(string)", "Vesting schedule amount must be > 0")
        );
        createVestingSchedule(
            joe, block.timestamp, 365 * 24 * 3600, 4 * 365 * 24 * 3600, 365 * 2 * 3600, 365 * 24 * 3600, true, 0
        );
        vm.stopPrank();
    }

    function testCreateInvalidVestingZeroPeriod() public {
        vm.startPrank(initAccount);
        vm.expectRevert(
            abi.encodeWithSignature("InvalidVestingScheduleParameter(string)", "Vesting schedule period must be > 0")
        );
        createVestingSchedule(
            joe, block.timestamp, 365 * 24 * 3600, 4 * 365 * 24 * 3600, 0, 365 * 24 * 3600, true, 10_000e18
        );
        vm.stopPrank();
    }

    function testCreateInvalidVestingPeriodDoesNotDivideDuration() public {
        vm.startPrank(initAccount);
        vm.expectRevert(
            abi.encodeWithSignature(
                "InvalidVestingScheduleParameter(string)", "Vesting schedule duration must split in exact periods"
            )
        );
        createVestingSchedule(
            joe,
            block.timestamp,
            365 * 24 * 3600,
            4 * 365 * 24 * 3600 + 1,
            365 * 2 * 3600,
            365 * 24 * 3600,
            true,
            10_000e18
        );
        vm.stopPrank();
    }

    function testCreateInvalidVestingPeriodDoesNotDivideCliffDuration() public {
        vm.startPrank(initAccount);
        vm.expectRevert(
            abi.encodeWithSignature(
                "InvalidVestingScheduleParameter(string)", "Vesting schedule cliff duration must split in exact periods"
            )
        );
        createVestingSchedule(
            joe,
            block.timestamp,
            365 * 24 * 3600 + 1,
            4 * 365 * 24 * 3600,
            365 * 2 * 3600,
            365 * 24 * 3600,
            true,
            10_000e18
        );
        vm.stopPrank();
    }

    function testCreateMultipleVestings() public {
        vm.startPrank(initAccount);
        vm.expectEmit(true, true, true, true);
        emit CreatedVestingSchedule(0, initAccount, joe, 10_000e18);
        assert(
            createVestingSchedule(
                joe,
                block.timestamp,
                365 * 24 * 3600,
                4 * 365 * 24 * 3600,
                365 * 2 * 3600,
                365 * 24 * 3600,
                true,
                10_000e18
            ) == 0
        );

        vm.expectEmit(true, true, true, true);
        emit CreatedVestingSchedule(1, initAccount, bob, 10_000e18);
        assert(
            createVestingSchedule(
                bob,
                block.timestamp,
                365 * 24 * 3600,
                4 * 365 * 24 * 3600,
                365 * 2 * 3600,
                365 * 24 * 3600,
                true,
                10_000e18
            ) == 1
        );
        vm.stopPrank();

        assert(tt.getVestingScheduleCount() == 2);
        assert(tt.balanceOf(initAccount) == 999_980_000e18);
        assert(tt.balanceOf(tt.vestingEscrow(0)) == 10_000e18);
        assert(tt.balanceOf(tt.vestingEscrow(1)) == 10_000e18);
    }

    function testCreateVestingDefaultStart(uint40 start) public {
        vm.warp(start);
        vm.startPrank(initAccount);
        assert(
            createVestingSchedule(
                joe, 0, 365 * 24 * 3600, 4 * 365 * 24 * 3600, 365 * 2 * 3600, 365 * 24 * 3600, true, 10_000e18
            ) == 0
        );
        vm.stopPrank();

        // Verify vesting schedule object has been properly created
        VestingSchedules.VestingSchedule memory vestingSchedule = tt.getVestingSchedule(0);

        assert(vestingSchedule.start == start);
    }

    function testReleaseVestingScheduleBeforeCliff() public {
        vm.warp(0);

        vm.startPrank(initAccount);
        assert(
            createVestingSchedule(joe, 0, 365 * 24 * 3600, 4 * 365 * 24 * 3600, 365 * 2 * 3600, 0, true, 10_000e18) == 0
        );
        vm.stopPrank();

        // Move time right before cliff
        vm.warp(365 * 24 * 3600 - 1);

        vm.startPrank(joe);
        vm.expectRevert(abi.encodeWithSignature("ZeroReleasableAmount()"));
        // Attempts to releaseVestingSchedule
        tt.releaseVestingSchedule(0);
        vm.stopPrank();
    }

    function testReleaseVestingScheduleAfterCliffButBeforeLock() public {
        vm.warp(0);

        vm.startPrank(initAccount);
        assert(
            createVestingSchedule(
                joe, 0, 365 * 24 * 3600, 4 * 365 * 24 * 3600, 365 * 2 * 3600, 365 * 24 * 3600 + 1, true, 10_000e18
            ) == 0
        );
        vm.stopPrank();

        // Move time right before cliff
        vm.warp(365 * 24 * 3600);

        vm.startPrank(joe);
        vm.expectRevert(abi.encodeWithSignature("VestingScheduleIsLocked()"));
        // Attempts to releaseVestingSchedule
        tt.releaseVestingSchedule(0);
        vm.stopPrank();
    }

    event ReleasedVestingSchedule(uint256 index, uint256 releasedAmount);

    function testReleaseVestingScheduleAtLockDuration() public {
        vm.warp(0);

        vm.startPrank(initAccount);
        assert(
            createVestingSchedule(
                joe, 0, 365 * 24 * 3600, 4 * 365 * 24 * 3600, 365 * 2 * 3600, 365 * 24 * 3600, true, 10_000e18
            ) == 0
        );
        vm.stopPrank();

        // Move to cliff
        vm.warp(365 * 24 * 3600);

        vm.startPrank(joe);
        vm.expectEmit(true, true, true, true);
        emit ReleasedVestingSchedule(0, 2_500e18);
        // Attempts to releaseVestingSchedule all vested tokens
        tt.releaseVestingSchedule(0);
        vm.stopPrank();

        // Verify balances
        assert(tt.balanceOf(tt.vestingEscrow(0)) == 7_500e18);
        assert(tt.balanceOf(joe) == 2_500e18);
    }

    function testReleaseVestingScheduleAfterLockDuration() public {
        vm.warp(0);

        vm.startPrank(initAccount);
        assert(
            createVestingSchedule(
                joe, 0, 365 * 24 * 3600, 4 * 365 * 24 * 3600, 365 * 2 * 3600, 365 * 24 * 3600, true, 10_000e18
            ) == 0
        );
        vm.stopPrank();

        // Move to end half way vesting
        vm.warp(2 * 365 * 24 * 3600);

        vm.startPrank(joe);
        vm.expectEmit(true, true, true, true);
        emit ReleasedVestingSchedule(0, 5_000e18);
        // Attempts to releaseVestingSchedule all vested tokens
        tt.releaseVestingSchedule(0);
        vm.stopPrank();

        // Verify balances
        assert(tt.balanceOf(tt.vestingEscrow(0)) == 5_000e18);
        assert(tt.balanceOf(joe) == 5_000e18);
    }

    function testcomputeVestingAmounts() public {
        vm.warp(0);

        // Create a schedule such as
        // - cliff 1 year
        // - total duration 4 years
        // - lock duration 2 years
        vm.startPrank(initAccount);
        assert(
            createVestingSchedule(
                joe, 0, 365 * 24 * 3600, 4 * 365 * 24 * 3600, 365 * 2 * 3600, 2 * 365 * 24 * 3600, true, 10_000e18
            ) == 0
        );
        vm.stopPrank();

        // At beginning of schedule
        assert(tt.computeVestingReleasableAmount(0) == 0);
        assert(tt.computeVestingVestedAmount(0) == 0);

        // Move right after beginning of schedule
        vm.warp(1);
        assert(tt.computeVestingReleasableAmount(0) == 0);
        assert(tt.computeVestingVestedAmount(0) == 0);

        // Move to half way cliff
        vm.warp(365 * 12 * 3600);
        assert(tt.computeVestingReleasableAmount(0) == 0);
        assert(tt.computeVestingVestedAmount(0) == 0);

        // Move right before cliff
        vm.warp(365 * 24 * 3600 - 1);
        assert(tt.computeVestingReleasableAmount(0) == 0);
        assert(tt.computeVestingVestedAmount(0) == 0);

        // Move at cliff
        vm.warp(365 * 24 * 3600);
        assert(tt.computeVestingReleasableAmount(0) == 0);
        assert(tt.computeVestingVestedAmount(0) == 2_500e18);

        // Move right after cliff
        vm.warp(365 * 24 * 3600 + 1);
        assert(tt.computeVestingReleasableAmount(0) == 0);
        assert(tt.computeVestingVestedAmount(0) == 2_500e18);

        // Move right before slice period
        vm.warp(365 * 24 * 3600 + 365 * 2 * 3600 - 1);
        assert(tt.computeVestingReleasableAmount(0) == 0);
        assert(tt.computeVestingVestedAmount(0) == 2_500e18);

        // Move at slice period
        vm.warp(365 * 24 * 3600 + 365 * 2 * 3600);
        assert(tt.computeVestingReleasableAmount(0) == 0);
        assert(tt.computeVestingVestedAmount(0) == 2708333333333333333333);

        // Move right after slice period
        vm.warp(365 * 24 * 3600 + 365 * 2 * 3600 + 1);
        assert(tt.computeVestingReleasableAmount(0) == 0);
        assert(tt.computeVestingVestedAmount(0) == 2708333333333333333333);

        // Move right before lock
        vm.warp(2 * 365 * 24 * 3600 - 1);
        assert(tt.computeVestingReleasableAmount(0) == 0);
        assert(tt.computeVestingVestedAmount(0) == 4791666666666666666666);

        // Move at lock
        vm.warp(2 * 365 * 24 * 3600);
        assert(tt.computeVestingReleasableAmount(0) == 5_000e18);
        assert(tt.computeVestingVestedAmount(0) == 5_000e18);

        // Move right after lock
        vm.warp(2 * 365 * 24 * 3600);
        assert(tt.computeVestingReleasableAmount(0) == 5_000e18);
        assert(tt.computeVestingVestedAmount(0) == 5_000e18);

        // Move right before vesting end
        vm.warp(4 * 365 * 24 * 3600 - 1);
        assert(tt.computeVestingReleasableAmount(0) == 9791666666666666666666);
        assert(tt.computeVestingVestedAmount(0) == 9791666666666666666666);

        // Move at vesting end
        vm.warp(4 * 365 * 24 * 3600);
        assert(tt.computeVestingReleasableAmount(0) == 10_000e18);
        assert(tt.computeVestingVestedAmount(0) == 10_000e18);

        // Move right after vesting end
        vm.warp(4 * 365 * 24 * 3600 + 1);
        assert(tt.computeVestingReleasableAmount(0) == 10_000e18);
        assert(tt.computeVestingVestedAmount(0) == 10_000e18);

        // Move 1 year after vesting end
        vm.warp(5 * 365 * 24 * 3600 + 1);
        assert(tt.computeVestingReleasableAmount(0) == 10_000e18);
        assert(tt.computeVestingVestedAmount(0) == 10_000e18);
    }

    function testReleaseVestingScheduleFromInvalidAccount() public {
        vm.warp(0);

        vm.startPrank(initAccount);
        assert(
            createVestingSchedule(
                joe, 0, 365 * 24 * 3600, 4 * 365 * 24 * 3600, 365 * 2 * 3600, 365 * 24 * 3600, true, 10_000e18
            ) == 0
        );
        vm.stopPrank();

        // Move to end half way vesting
        vm.warp(2 * 365 * 24 * 3600);

        vm.startPrank(bob);
        vm.expectRevert(abi.encodeWithSignature("Unauthorized(address)", bob));
        tt.releaseVestingSchedule(0);
        vm.stopPrank();
    }

    event RevokedVestingSchedule(uint256 index, uint256 returnedAmount);

    function testRevokeBeforeCliff() public {
        vm.warp(0);

        vm.startPrank(initAccount);
        assert(
            createVestingSchedule(
                joe, 0, 365 * 24 * 3600, 4 * 365 * 24 * 3600, 365 * 2 * 3600, 365 * 24 * 3600, true, 10_000e18
            ) == 0
        );
        vm.stopPrank();

        vm.startPrank(initAccount);
        vm.expectEmit(true, true, true, true);
        emit RevokedVestingSchedule(0, 10_000e18);
        tt.revokeVestingSchedule(0, 365 * 24 * 3600 - 1);
        vm.stopPrank();

        assert(tt.balanceOf(initAccount) == 1_000_000_000e18);
        assert(tt.balanceOf(tt.vestingEscrow(0)) == 0);
        assert(tt.balanceOf(joe) == 0);

        // Verify vesting schedule object has been properly updated
        VestingSchedules.VestingSchedule memory vestingSchedule = tt.getVestingSchedule(0);
        assert(vestingSchedule.end == 365 * 24 * 3600 - 1);
    }

    function testRevokeAtCliff() public {
        vm.warp(0);

        vm.startPrank(initAccount);
        assert(
            createVestingSchedule(
                joe, 0, 365 * 24 * 3600, 4 * 365 * 24 * 3600, 365 * 2 * 3600, 365 * 24 * 3600, true, 10_000e18
            ) == 0
        );
        vm.stopPrank();

        vm.startPrank(initAccount);
        vm.expectEmit(true, true, true, true);
        emit RevokedVestingSchedule(0, 7_500e18);
        tt.revokeVestingSchedule(0, 365 * 24 * 3600);
        vm.stopPrank();

        assert(tt.balanceOf(initAccount) == 999_997_500e18);
        assert(tt.balanceOf(tt.vestingEscrow(0)) == 2_500e18);
        assert(tt.balanceOf(joe) == 0);

        // Verify vesting schedule object has been properly updated
        VestingSchedules.VestingSchedule memory vestingSchedule = tt.getVestingSchedule(0);
        assert(vestingSchedule.end == 365 * 24 * 3600);
    }

    function testRevokeAtDuration() public {
        vm.warp(0);

        vm.startPrank(initAccount);
        assert(
            createVestingSchedule(
                joe, 0, 365 * 24 * 3600, 4 * 365 * 24 * 3600, 365 * 2 * 3600, 365 * 24 * 3600, true, 10_000e18
            ) == 0
        );
        vm.stopPrank();

        vm.startPrank(initAccount);
        vm.expectEmit(true, true, true, true);
        emit RevokedVestingSchedule(0, 0);
        tt.revokeVestingSchedule(0, 4 * 365 * 24 * 3600);
        vm.stopPrank();

        assert(tt.balanceOf(initAccount) == 999_990_000e18);
        assert(tt.balanceOf(tt.vestingEscrow(0)) == 10_000e18);

        // Verify vesting schedule object has been properly updated
        VestingSchedules.VestingSchedule memory vestingSchedule = tt.getVestingSchedule(0);
        assert(vestingSchedule.end == 4 * 365 * 24 * 3600);
    }

    function testRevokeDefault() public {
        vm.warp(0);

        vm.startPrank(initAccount);
        assert(
            createVestingSchedule(
                joe, 0, 365 * 24 * 3600, 4 * 365 * 24 * 3600, 365 * 2 * 3600, 365 * 24 * 3600, true, 10_000e18
            ) == 0
        );
        vm.stopPrank();

        vm.warp(2 * 365 * 24 * 3600);

        vm.startPrank(initAccount);
        vm.expectEmit(true, true, true, true);
        emit RevokedVestingSchedule(0, 5_000e18);
        tt.revokeVestingSchedule(0, 0);
        vm.stopPrank();

        assert(tt.balanceOf(initAccount) == 999_995_000e18);
        assert(tt.balanceOf(tt.vestingEscrow(0)) == 5_000e18);

        // Verify vesting schedule object has been properly updated
        VestingSchedules.VestingSchedule memory vestingSchedule = tt.getVestingSchedule(0);
        assert(vestingSchedule.end == 2 * 365 * 24 * 3600);
    }

    function testRevokeNotRevokable() public {
        vm.warp(0);

        vm.startPrank(initAccount);
        assert(
            createVestingSchedule(
                joe, 0, 365 * 24 * 3600, 4 * 365 * 24 * 3600, 365 * 2 * 3600, 365 * 24 * 3600, false, 10_000e18
            ) == 0
        );
        vm.stopPrank();

        vm.startPrank(initAccount);
        vm.expectRevert(abi.encodeWithSignature("VestingScheduleNotRevocable()"));
        tt.revokeVestingSchedule(0, 4 * 365 * 24 * 3600);
        vm.stopPrank();
    }

    function testRevokeFromInvalidAccount() public {
        vm.warp(0);

        vm.startPrank(initAccount);
        assert(
            createVestingSchedule(
                joe, 0, 365 * 24 * 3600, 4 * 365 * 24 * 3600, 365 * 2 * 3600, 365 * 24 * 3600, true, 10_000e18
            ) == 0
        );
        vm.stopPrank();

        vm.startPrank(joe);
        vm.expectRevert(abi.encodeWithSignature("Unauthorized(address)", joe));
        tt.revokeVestingSchedule(0, 4 * 365 * 24 * 3600);
        vm.stopPrank();
    }

    function testRevokeTwice() public {
        vm.warp(0);

        vm.startPrank(initAccount);
        assert(
            createVestingSchedule(
                joe, 0, 365 * 24 * 3600, 4 * 365 * 24 * 3600, 365 * 2 * 3600, 365 * 24 * 3600, true, 10_000e18
            ) == 0
        );
        vm.stopPrank();

        vm.startPrank(initAccount);
        tt.revokeVestingSchedule(0, 2 * 365 * 24 * 3600);
        vm.stopPrank();

        assert(tt.balanceOf(initAccount) == 999_995_000e18);
        assert(tt.balanceOf(tt.vestingEscrow(0)) == 5_000e18);

        vm.startPrank(initAccount);
        tt.revokeVestingSchedule(0, 1 * 365 * 24 * 3600);
        vm.stopPrank();

        assert(tt.balanceOf(initAccount) == 999_997_500e18);
        assert(tt.balanceOf(tt.vestingEscrow(0)) == 2_500e18);
    }

    function testRevokeTwiceAfterEnd() public {
        vm.warp(0);

        vm.startPrank(initAccount);
        assert(
            createVestingSchedule(
                joe, 0, 365 * 24 * 3600, 4 * 365 * 24 * 3600, 365 * 2 * 3600, 365 * 24 * 3600, true, 10_000e18
            ) == 0
        );
        vm.stopPrank();

        vm.startPrank(initAccount);
        tt.revokeVestingSchedule(0, 1 * 365 * 24 * 3600);
        vm.stopPrank();

        vm.startPrank(initAccount);
        vm.expectRevert(abi.encodeWithSignature("InvalidRevokedVestingScheduleEnd()"));
        tt.revokeVestingSchedule(0, 2 * 365 * 24 * 3600);
        vm.stopPrank();
    }

    function testReleaseVestingScheduleAfterRevoke() public {
        vm.warp(0);

        vm.startPrank(initAccount);
        assert(
            createVestingSchedule(
                joe, 0, 365 * 24 * 3600, 4 * 365 * 24 * 3600, 365 * 2 * 3600, 365 * 24 * 3600, true, 10_000e18
            ) == 0
        );
        vm.stopPrank();

        vm.startPrank(initAccount);
        // revoke at mid vesting duration
        tt.revokeVestingSchedule(0, 2 * 365 * 24 * 3600);
        vm.stopPrank();

        assert(tt.balanceOf(initAccount) == 999_995_000e18);
        assert(tt.balanceOf(tt.vestingEscrow(0)) == 5_000e18);

        // move to cliff
        vm.warp(365 * 24 * 3600);

        vm.startPrank(joe);
        tt.releaseVestingSchedule(0);
        vm.stopPrank();

        assert(tt.balanceOf(initAccount) == 999_995_000e18);
        assert(tt.balanceOf(tt.vestingEscrow(0)) == 2_500e18);
        assert(tt.balanceOf(joe) == 2_500e18);

        // move to vesting schedule end
        vm.warp(2 * 365 * 24 * 3600);

        vm.startPrank(joe);
        tt.releaseVestingSchedule(0);
        vm.stopPrank();

        assert(tt.balanceOf(initAccount) == 999_995_000e18);
        assert(tt.balanceOf(tt.vestingEscrow(0)) == 0);
        assert(tt.balanceOf(joe) == 5_000e18);
    }

    event DelegatedVestingEscrow(uint256 index, address indexed oldDelegatee, address indexed newDelegatee);

    function testDelegateVestingEscrow() public {
        vm.startPrank(initAccount);
        assert(
            createVestingSchedule(
                joe,
                block.timestamp,
                365 * 24 * 3600,
                4 * 365 * 24 * 3600,
                365 * 2 * 3600,
                365 * 24 * 3600,
                true,
                10_000e18
            ) == 0
        );
        vm.stopPrank();

        // Verify escrow delegated to beneficiary
        assert(tt.delegates(tt.vestingEscrow(0)) == joe);

        vm.startPrank(joe);
        vm.expectEmit(true, true, true, true);
        emit DelegatedVestingEscrow(0, joe, bob);
        tt.delegateVestingEscrow(0, bob);
        vm.stopPrank();

        // Verify escrow delegation has been updated
        assert(tt.delegates(tt.vestingEscrow(0)) == bob);
    }

    function testDelegateVestingEscrowFromInvalidAccount() public {
        vm.startPrank(initAccount);
        assert(
            createVestingSchedule(
                joe,
                block.timestamp,
                365 * 24 * 3600,
                4 * 365 * 24 * 3600,
                365 * 2 * 3600,
                365 * 24 * 3600,
                true,
                10_000e18
            ) == 0
        );
        vm.stopPrank();

        // Verify escrow delegated to beneficiary
        assert(tt.delegates(tt.vestingEscrow(0)) == joe);

        vm.startPrank(bob);
        vm.expectRevert(abi.encodeWithSignature("Unauthorized(address)", bob));
        tt.delegateVestingEscrow(0, bob);
        vm.stopPrank();
    }

    function testVestingScheduleFuzzing(
        uint24 periodDuration,
        uint32 lockDuration,
        uint8 cliffPeriodCount,
        uint8 vestingPeriodCount,
        uint256 amount,
        uint256 releaseAt,
        uint256 revokeAt
    ) public {
        vm.warp(0);
        if (periodDuration == 0) {
            // period duration should be a list one
            periodDuration = 1;
        }

        if (vestingPeriodCount == 0) {
            // we should have at list one period for the vesting
            vestingPeriodCount = 1;
        }

        // make sure that at least one token can be released for each period
        if (amount < vestingPeriodCount) {
            amount = uint256(vestingPeriodCount);
        }

        // make sure that initAccount has enough funds to create the schedule
        amount = amount % tt.balanceOf(initAccount);

        uint32 totalDuration = uint32(vestingPeriodCount) * uint32(periodDuration);

        uint32 cliffDuration = (cliffPeriodCount % vestingPeriodCount) * uint32(periodDuration);
        lockDuration = lockDuration % (totalDuration + periodDuration);

        vm.startPrank(initAccount);
        assert(
            createVestingSchedule(joe, 0, cliffDuration, totalDuration, periodDuration, lockDuration, true, amount) == 0
        );
        vm.stopPrank();

        assert(tt.balanceOf(initAccount) == 1_000_000_000e18 - amount);
        assert(tt.balanceOf(tt.vestingEscrow(0)) == amount);

        revokeAt = revokeAt % totalDuration;
        if (revokeAt > 0) {
            vm.startPrank(initAccount);
            assert(tt.revokeVestingSchedule(0, uint64(revokeAt)) > 0);
            vm.stopPrank();

            if (revokeAt < cliffDuration) {
                assert(tt.balanceOf(tt.vestingEscrow(0)) == 0);
            } else if (revokeAt >= periodDuration) {
                assert(tt.balanceOf(tt.vestingEscrow(0)) > 0);
            }
        }

        releaseAt = releaseAt % periodDuration;
        while (true) {
            vm.warp(releaseAt);
            if (releaseAt < lockDuration) {
                vm.startPrank(joe);
                vm.expectRevert(abi.encodeWithSignature("VestingScheduleIsLocked()"));
                tt.releaseVestingSchedule(0);
                vm.stopPrank();
            } else if (
                (releaseAt < periodDuration) || (releaseAt < cliffDuration)
                    || (revokeAt > 0) && ((revokeAt < cliffDuration) || (revokeAt < periodDuration))
            ) {
                // we are in either of this situation
                // - before end of lock duration
                // - lock duration is 0 and we are before end of first period
                // - vesting has been revoked and end is before end of lock duration
                // - vesting has been revoked and end is before end of first period
                vm.startPrank(joe);
                vm.expectRevert(abi.encodeWithSignature("ZeroReleasableAmount()"));
                tt.releaseVestingSchedule(0);
                vm.stopPrank();
            } else {
                uint256 oldJoeBalance = tt.balanceOf(joe);
                uint256 oldEscrowBalance = tt.balanceOf(tt.vestingEscrow(0));

                vm.startPrank(joe);
                uint256 releasedAmount = tt.releaseVestingSchedule(0);
                vm.stopPrank();

                // make sure funds are properly transferred from escrow to beneficiary
                assert(releasedAmount > 0);
                assert(tt.balanceOf(joe) == oldJoeBalance + releasedAmount);
                assert(tt.balanceOf(tt.vestingEscrow(0)) == oldEscrowBalance - releasedAmount);

                // make sure invariant is respected
                assert(
                    tt.balanceOf(initAccount) + tt.balanceOf(joe) + tt.balanceOf(tt.vestingEscrow(0))
                        == 1_000_000_000e18
                );
            }

            if (
                releaseAt >= ((tt.getVestingSchedule(0).end / periodDuration) * periodDuration)
                    && (releaseAt >= lockDuration)
            ) {
                // we got into the end period and passed the lock duration so all tokens should have been released
                assert(tt.balanceOf(tt.vestingEscrow(0)) == 0);
                break;
            }

            // Release at next period
            releaseAt += periodDuration;
        }
    }
}
