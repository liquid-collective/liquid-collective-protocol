//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

/// @title VestingSchedules Storage
/// @notice Utility to manage VestingSchedules in storage
library VestingSchedules {
    /// @notice Storage slot of the Vesting Schedules
    bytes32 internal constant VESTING_SCHEDULES_SLOT = bytes32(uint256(keccak256("tlc.state.schedules")) - 1);

    struct VestingSchedule {
        // start time of the vesting period
        uint256 start;
        // cliff period in seconds
        uint256 cliff;
        // duration of the vesting period in seconds
        uint256 duration;
        // duration of a vesting period in seconds
        uint256 period;
        // date at which the vesting is ended
        // initially it is equal to start+duration then to revoke date in case of revoke
        uint256 end;
        // amount of tokens granted by the vesting schedule
        uint256 amount;
        // creator of the token vesting
        address creator;
        // beneficiary of tokens after they are releaseVestingScheduled
        address beneficiary;
        // whether or not the vesting is revocable
        bool revocable;
    }

    /// @notice The structure at the storage slot
    struct SlotVestingSchedule {
        /// @custom:attribute Array containing all the operators
        VestingSchedule[] value;
    }

    /// @notice The VestingSchedule was not found
    /// @param index vesting schedule index
    error VestingScheduleNotFound(uint256 index);

    /// @notice Retrieve the vesting schedule in storage
    /// @param _index index of the vesting schedule
    /// @return the vesting schedule
    function get(uint256 _index) internal view returns (VestingSchedule storage) {
        bytes32 slot = VESTING_SCHEDULES_SLOT;

        SlotVestingSchedule storage r;

        // solhint-disable-next-line no-inline-assembly
        assembly {
            r.slot := slot
        }

        if (r.value.length <= _index) {
            revert VestingScheduleNotFound(_index);
        }

        return r.value[_index];
    }

    /// @notice Get vesting schedule count in storage
    /// @return The count of vesting schedule in storage
    function getCount() internal view returns (uint256) {
        bytes32 slot = VESTING_SCHEDULES_SLOT;

        SlotVestingSchedule storage r;

        // solhint-disable-next-line no-inline-assembly
        assembly {
            r.slot := slot
        }

        return r.value.length;
    }

    /// @notice Add a new vesting schedule in storage
    /// @param _newSchedule new vesting schedule to create
    /// @return The size of the operator array after the operation
    function push(VestingSchedule memory _newSchedule) internal returns (uint256) {
        bytes32 slot = VESTING_SCHEDULES_SLOT;

        SlotVestingSchedule storage r;

        // solhint-disable-next-line no-inline-assembly
        assembly {
            r.slot := slot
        }

        r.value.push(_newSchedule);

        return r.value.length;
    }
}
