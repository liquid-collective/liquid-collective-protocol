//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "../../../src/state/tlc/VestingSchedules.1.sol";
import "../../../src/state/tlc/VestingSchedules.2.sol";
import "forge-std/Test.sol";

contract VestingSchedulesMigrationTest is Test {
    address internal alice;
    address internal bob;

    function setUp() public {
        alice = makeAddr("alice");
        bob = makeAddr("bob");
    }

    function _createV1VestingSchedule(
        VestingSchedulesV1.VestingSchedule memory vestingSchedule
    ) internal returns(uint256) {
        // Create a V1 schedule
       return VestingSchedulesV1.push(vestingSchedule) - 1;
    }

    function _updateV2VestingSchedule(
        uint256 index,
        VestingSchedulesV2.VestingSchedule memory newVestingSchedule
    ) internal returns(bool) {
        VestingSchedulesV2.VestingSchedule storage vestingScheduleV2 = VestingSchedulesV2.get(index);

        vestingScheduleV2.start = newVestingSchedule.start;
        vestingScheduleV2.end = newVestingSchedule.end;
        vestingScheduleV2.lockDuration = newVestingSchedule.lockDuration;
        vestingScheduleV2.cliffDuration = newVestingSchedule.cliffDuration;
        vestingScheduleV2.duration = newVestingSchedule.duration;
        vestingScheduleV2.period = newVestingSchedule.period;
        vestingScheduleV2.amount = newVestingSchedule.amount;
        vestingScheduleV2.creator = newVestingSchedule.creator;
        vestingScheduleV2.beneficiary = newVestingSchedule.beneficiary;
        vestingScheduleV2.revocable = newVestingSchedule.revocable;
        vestingScheduleV2.releasedAmount = newVestingSchedule.releasedAmount;

        // Create a V1 schedule
       return true;
    }

    function testVestingScheduleV1ToV2Compatibility(
        uint64 _start,
        uint64 _end,
        uint32 _duration,
        uint32 _period,
        uint32 _cliffDuration,
        uint32 _lockDuration,
        bool _revocable,
        uint256 _amount,
        uint256 _updateReleasedAmount
    ) public {
        // #1. Create V1 schedule
         VestingSchedulesV1.VestingSchedule memory vestingScheduleV1 = VestingSchedulesV1.VestingSchedule({
            start: _start,
            end: _end,
            lockDuration: _lockDuration,
            cliffDuration: _cliffDuration,
            duration: _duration,
            period: _period,
            amount: _amount,
            creator: bob,
            beneficiary: alice,
            revocable: _revocable
        });

        vm.startPrank(bob);
        uint256 index =  _createV1VestingSchedule(vestingScheduleV1);
        vm.stopPrank();

        // #2. Get it as a V2 schedule and verifies attributes
        VestingSchedulesV2.VestingSchedule memory vestingScheduleV2 = VestingSchedulesV2.get(index);
        assert(vestingScheduleV2.start == vestingScheduleV1.start);
        assert(vestingScheduleV2.end == vestingScheduleV1.end);
        assert(vestingScheduleV2.cliffDuration == vestingScheduleV1.cliffDuration);
        assert(vestingScheduleV2.lockDuration == vestingScheduleV1.lockDuration);
        assert(vestingScheduleV2.period == vestingScheduleV1.period);
        assert(vestingScheduleV2.amount == vestingScheduleV1.amount);
        assert(vestingScheduleV2.creator == vestingScheduleV1.creator);
        assert(vestingScheduleV2.beneficiary == vestingScheduleV1.beneficiary);
        assert(vestingScheduleV2.revocable == vestingScheduleV1.revocable);
        assert(vestingScheduleV2.releasedAmount == 0);

        // #3. Update it as a V2 schedule
        VestingSchedulesV2.VestingSchedule memory newVestingScheduleV2 = VestingSchedulesV2.VestingSchedule({
            start: _start/2,
            end: _end/2,
            lockDuration: _lockDuration/2,
            cliffDuration: _cliffDuration/2,
            duration: _duration/2,
            period: _period/2,
            amount: _amount/2,
            creator: bob,
            beneficiary: alice,
            revocable: _start % 2 == 0,
            releasedAmount: _updateReleasedAmount 
        });

        vm.startPrank(bob);
        assert(_updateV2VestingSchedule(index, newVestingScheduleV2));
        vm.stopPrank();

        // #4. Get it as a V2 schedule and verifies attributes have been updated properly
        vestingScheduleV2 = VestingSchedulesV2.get(index);
        assert(vestingScheduleV2.start == newVestingScheduleV2.start);
        assert(vestingScheduleV2.end == newVestingScheduleV2.end);
        assert(vestingScheduleV2.cliffDuration == newVestingScheduleV2.cliffDuration);
        assert(vestingScheduleV2.lockDuration == newVestingScheduleV2.lockDuration);
        assert(vestingScheduleV2.period == newVestingScheduleV2.period);
        assert(vestingScheduleV2.amount == newVestingScheduleV2.amount);
        assert(vestingScheduleV2.creator == newVestingScheduleV2.creator);
        assert(vestingScheduleV2.beneficiary == newVestingScheduleV2.beneficiary);
        assert(vestingScheduleV2.revocable == newVestingScheduleV2.revocable);
        assert(vestingScheduleV2.releasedAmount == newVestingScheduleV2.releasedAmount);
    }
}