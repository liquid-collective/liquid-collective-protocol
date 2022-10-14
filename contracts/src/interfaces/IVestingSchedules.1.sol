//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "../state/tlc/VestingSchedules.sol";

/// @title Vesting Schedules Interface (v1)
/// @author Alluvial
/// @notice This interface exposes methods to manage vestings
interface IVestingSchedulesV1 {
    /// @notice A new vesting schedule has been created
    /// @param index Vesting schedule index
    /// @param creator Creator of the vesting schedule
    /// @param beneficiary Vesting beneficiary address
    /// @param amount Vesting schedule amount
    event CreatedVestingSchedule(uint256 index, address indexed creator, address indexed beneficiary, uint256 amount);

    /// @notice Vesting schedule has been released
    /// @param index Vesting schedule index
    /// @param releasedAmount Amount of tokens released to the beneficiary
    event ReleasedVestingSchedule(uint256 index, uint256 releasedAmount);

    /// @notice Vesting schedule has been revoked
    /// @param index Vesting schedule index
    /// @param releasedAmount Amount of tokens released to the beneficiary
    /// @param returnedAmount Amount of tokens returned to the creator
    event RevokedVestingSchedule(uint256 index, uint256 releasedAmount, uint256 returnedAmount);

    /// @notice Vesting escrow has been delegated
    /// @param index Vesting schedule index
    /// @param oldDelegatee old delegatee
    /// @param newDelegatee new delegatee
    event DelegatedVestingEscrow(uint256 index, address oldDelegatee, address newDelegatee);

    /// @notice Vesting schedule creator has unsufficient balance to create vesting schedule
    error UnsufficientVestingScheduleCreatorBalance();

    /// @notice Invalid parameter for a vesting schedule
    error InvalidVestingScheduleParameter(string msg);

    /// @notice The vesting schedule is not revocable
    error VestingScheduleNotRevocable();

    /// @notice The vesting schedule has been revoked
    error VestingScheduleRevoked();

    /// @notice No token to release
    error ZeroReleasableAmount();

    /// @notice Initializes the TLC Token
    /// @param _account The initial account to grant all the minted tokens
    function initTLCV1(address _account) external;

    /// @notice Creates a new vesting schedule
    /// @param _beneficiary address of the beneficiary of the tokens
    /// @param _start start time of the vesting
    /// @param _cliff cliff duration during which tokens are locked (in seconds)
    /// @param _duration total vesting duration after which all tokens are vested (in seconds)
    /// @param _period duration of a period after which new tokens unlock (in seconds)
    /// @param _revocable whether the vesting schedule is revocable or not
    /// @param _amount amount of token attributed by the vesting schedule
    /// @return index of the created vesting schedule
    function createVestingSchedule(
        address _beneficiary,
        uint256 _start,
        uint256 _cliff,
        uint256 _duration,
        uint256 _period,
        bool _revocable,
        uint256 _amount
    ) external returns (uint256);

    /// @notice Get vesting schedule
    /// @param _index Index of the vesting schedule
    function getVestingSchedule(uint256 _index) external view returns (VestingSchedules.VestingSchedule memory);

    /// @notice Get count of vesting schedules
    /// @return count of vesting schedules
    function getVestingScheduleCount() external view returns (uint256);

    /// @notice Revoke vesting schedule
    /// @param _index Index of the vesting schedule to revoke
    /// @return releasedAmount released amount
    /// @return returnedAmount amount returned to the vesting schedule creator
    function revokeVestingSchedule(uint256 _index) external returns (uint256 releasedAmount, uint256 returnedAmount);

    /// @notice Release vesting schedule
    /// @param _index Index of the vesting schedule to release
    /// @return released amount
    function releaseVestingSchedule(uint256 _index) external returns (uint256);

    /// @notice Get the address of the escrow for a vesting schedule
    /// @param _index Index of the vesting schedule
    /// @return address of the escrow
    function vestingEscrow(uint256 _index) external view returns (address);

    /// @notice Delegate vesting escrowed tokens
    /// @param _index index of the vesting schedule
    /// @param _delegatee address to delegate the token to
    function delegateVestingEscrow(uint256 _index, address _delegatee) external returns (bool);

    /// @notice Computes the releasable amount of tokens for a vesting schedule.
    /// @param _index index of the vesting schedule
    /// @return amount of release tokens
    function computeReleasableAmount(uint256 _index) external view returns (uint256);
}