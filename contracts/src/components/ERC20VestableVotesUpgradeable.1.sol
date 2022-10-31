//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "openzeppelin-contracts-upgradeable/contracts/token/ERC20/extensions/ERC20VotesUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol";

import "../interfaces/components/IVestingScheduleManager.1.sol";

import "../state/tlc/VestingSchedules.sol";

import "../libraries/LibSanitize.sol";

/// @title ERC20VestableVotesUpgradeableV1
/// @author Alluvial
/// @notice This is an ERC20 extension that
/// @notice   - can be used as source of voting power (inherited from OpenZeppelin ERC20VotesUpgradeable)
/// @notice   - can delegate voting power from an account to another account (inherited from OpenZeppelin ERC20Votes)
/// @notice   - can manage token vestings (token that are progressively transfered to a beneficiary according to a vesting schedule)
/// @notice This extension keeps a history (checkpoints) of each account's vote power. Vote power can be delegated either
/// @notice
/// @notice Notes from OpenZeppelin ERC20VotesUpgradeable (https://github.com/OpenZeppelin/openzeppelin-contracts-upgradeable/blob/master/contracts/token/ERC20/extensions/ERC20VotesUpgradeable.sol)
/// @notice   - Vote power can be delegated either by calling the {delegate} function directly, or by providing a signature to be used with {delegateBySig}
/// @notice   - keeps a history (checkpoints) of each account's vote power
/// @notice   - power can be queried through the public accessors {getVotes} and {getPastVotes}.
/// @notice   - By default, token balance does not account for voting power. This makes transfers cheaper. The downside is that it
/// @notice requires users to delegate to themselves in order to activate checkpoints and have their voting power tracked.
/// @notice
/// @notice Notes about vesting
/// @notice   - any token holder can call the method {createVestingSchedule} in order to transfer tokens to a beneficiary according to a vesting schedule. When
/// @notice     creating a vesting schedule, tokens are transferred to a temporary escrow and the voting power is delegated to the beneficiary or a delegatee account
/// @notice     set by the vesting schedule creator
/// @notice   - beneficiary gets tokens transferred from escrow by calling {releaseVestingSchedule}
/// @notice   - the schedule creator can revoke a revocable schedule by calling {revokeVestingSchedule} in which case the non-vested tokens are transfered from the escrow back to the creator
/// @notice   - a beneficiary can delegate escrow voting power to any account by calling {releaseVestingEscrow}
/// @notice
/// @notice Vesting attributes are
/// @notice   - start date: date at which tokens start to be vested)
/// @notice   - cliff duration: duration before reaching vesting cliff when first tokens are vested (example this may be 1 year)
/// @notice   - total duration: total duration after which all tokens are vested (example this may be 4 year)
/// @notice   - period duration: slice the vesting into periods. New tokens get vested an the end of each period (example this may be 1 month)
/// @notice   - lock duration: duration before which no tokens can be released to beneficiary even if some tokens have been vested already (the lock supersedes the cliff)
/// @notice   - amount: the total amount of tokens to be vested
/// @notice   - beneficiary: the beneficiary of the vested tokens
/// @notice   - revocable: is a boolean indicating whether a the vesting can be revoked by the creator
/// @notice
/// @notice Vesting release rules
/// @notice   - before cliff no token are vested and no token can be released
/// @notice   - at cliff first chunk of token get vested and can be released as long as the locked period is over
/// @notice   - at the end of every period new tokens get vested and can be released as long as the locked period is over
/// @notice
/// @notice Lock period prevents beneficiary from releasing vested tokens before the lock end. Vested tokens
/// @notice will eventually be releasable once the lock duration is over.
/// @notice
/// @notice Example: Joe gets a vesting starting on Jan 1st 2022 with duration of 1 year and a lock period of 2 years.
/// @notice On Jan 1st 2023, Joe will have all tokens vested but can not yet release it due to the lock period.
/// @notice On Jan 1st 2024, lock period is over and Joe can release all tokens.
abstract contract ERC20VestableVotesUpgradeableV1 is Initializable, IVestingScheduleManagerV1, ERC20VotesUpgradeable {
    // internal used to compute the address of the escrow
    bytes32 internal constant ESCROW = bytes32(uint256(keccak256("escrow")) - 1);

    function __ERC20VestableVotes_init() internal onlyInitializing {}

    function __ERC20VestableVotes_init_unchained() internal onlyInitializing {}

    /// @inheritdoc IVestingScheduleManagerV1
    function getVestingSchedule(uint256 _index) external view returns (VestingSchedules.VestingSchedule memory) {
        return VestingSchedules.get(_index);
    }

    /// @inheritdoc IVestingScheduleManagerV1
    function getVestingScheduleCount() external view returns (uint256) {
        return VestingSchedules.getCount();
    }

    /// @inheritdoc IVestingScheduleManagerV1
    function vestingEscrow(uint256 _index) external view returns (address) {
        return _deterministicVestingEscrow(_index);
    }

    /// @inheritdoc IVestingScheduleManagerV1
    function computeVestingReleasableAmount(uint256 _index) external view returns (uint256) {
        VestingSchedules.VestingSchedule memory vestingSchedule = VestingSchedules.get(_index);

        uint256 time = _getCurrentTime();
        if (time < (vestingSchedule.start + vestingSchedule.lockDuration)) {
            return 0;
        }

        address escrow = _deterministicVestingEscrow(_index);

        return _computeVestingReleasableAmount(vestingSchedule, escrow, time);
    }

    /// @inheritdoc IVestingScheduleManagerV1
    function computeVestingVestedAmount(uint256 _index) external view returns (uint256) {
        VestingSchedules.VestingSchedule memory vestingSchedule = VestingSchedules.get(_index);
        return _computeVestedAmount(vestingSchedule, _getCurrentTime());
    }

    /// @inheritdoc IVestingScheduleManagerV1
    function createVestingSchedule(
        uint64 _start,
        uint32 _cliffDuration,
        uint32 _duration,
        uint32 _period,
        uint32 _lockDuration,
        bool _revocable,
        uint256 _amount,
        address _beneficiary,
        address _delegatee
    ) external returns (uint256) {
        return _createVestingSchedule(
            msg.sender,
            _beneficiary,
            _delegatee,
            _start,
            _cliffDuration,
            _duration,
            _period,
            _lockDuration,
            _revocable,
            _amount
        );
    }

    /// @inheritdoc IVestingScheduleManagerV1
    function revokeVestingSchedule(uint256 _index, uint64 _end) external returns (uint256) {
        return _revokeVestingSchedule(_index, _end);
    }

    /// @inheritdoc IVestingScheduleManagerV1
    function releaseVestingSchedule(uint256 _index) external returns (uint256) {
        return _releaseVestingSchedule(_index);
    }

    /// @inheritdoc IVestingScheduleManagerV1
    function delegateVestingEscrow(uint256 _index, address _delegatee) external returns (bool) {
        return _delegateVestingEscrow(_index, _delegatee);
    }

    /// @notice Creates a new vesting schedule
    /// @param _creator address of the creator that transfer the tokens
    /// @param _beneficiary address of the beneficiary of the tokens
    /// @param _delegatee address of the delegate escrowed tokens votes to (if address(0) then it defaults to the beneficiary)
    /// @param _start start time of the vesting
    /// @param _cliffDuration duration to vesting cliff (in seconds)
    /// @param _duration total vesting schedule duration after which all tokens are vested (in seconds)
    /// @param _period duration of a period after which new tokens unlock (in seconds)
    /// @param _lockDuration duration during which tokens are locked (in seconds)
    /// @param _revocable whether the vesting schedule is revocable or not
    /// @param _amount amount of token attributed by the vesting schedule
    /// @return index of the created vesting schedule
    function _createVestingSchedule(
        address _creator,
        address _beneficiary,
        address _delegatee,
        uint64 _start,
        uint32 _cliffDuration,
        uint32 _duration,
        uint32 _period,
        uint32 _lockDuration,
        bool _revocable,
        uint256 _amount
    ) internal returns (uint256) {
        if (balanceOf(_creator) < _amount) {
            revert UnsufficientVestingScheduleCreatorBalance();
        }

        // validate schedule parameters are valid
        if (_beneficiary == address(0)) {
            revert InvalidVestingScheduleParameter("Vesting schedule beneficiary must be non zero address");
        }

        if (_duration == 0) {
            revert InvalidVestingScheduleParameter("Vesting schedule duration must be > 0");
        }

        if (_amount == 0) {
            revert InvalidVestingScheduleParameter("Vesting schedule amount must be > 0");
        }

        if (_period == 0) {
            revert InvalidVestingScheduleParameter("Vesting schedule period must be > 0");
        }

        if (_duration % _period > 0) {
            revert InvalidVestingScheduleParameter("Vesting schedule duration must split in exact periods");
        }

        if (_cliffDuration > _duration) {
            revert InvalidVestingScheduleParameter("Vesting schedule duration must be greater than the cliff duration");
        }

        // if input start time is 0 then default to the current block time
        if (_start == 0) {
            _start = uint64(block.timestamp);
        }

        // Create new vesting schedule
        VestingSchedules.VestingSchedule memory vestingSchedule = VestingSchedules.VestingSchedule({
            start: _start,
            end: _start + _duration,
            lockDuration: _lockDuration,
            cliffDuration: _cliffDuration,
            duration: _duration,
            period: _period,
            amount: _amount,
            creator: _creator,
            beneficiary: _beneficiary,
            revocable: _revocable
        });
        uint256 index = VestingSchedules.push(vestingSchedule) - 1;

        // compute escrow address that will hold the token during the vesting
        address escrow = _deterministicVestingEscrow(index);

        // transfer tokens to the escrow and delegate escrow to beneficiary
        _transfer(_creator, escrow, _amount);

        // delegate escrow tokens
        if (_delegatee == address(0)) {
            // default to beneficiary address
            _delegate(escrow, _beneficiary);
        } else {
            _delegate(escrow, _delegatee);
        }

        emit CreatedVestingSchedule(index, _creator, _beneficiary, _amount);

        return index;
    }

    /// @notice Revoke vesting schedule
    /// @param _index Index of the vesting schedule to revoke
    /// @param _end End date for the schedule
    /// @return returnedAmount amount returned to the vesting schedule creator
    function _revokeVestingSchedule(uint256 _index, uint64 _end) internal returns (uint256) {
        if (_end == 0) {
            // if end time is 0 then default to current block time
            _end = uint64(block.timestamp);
        } else if (_end < block.timestamp) {
            revert VestingScheduleNotRevocableInPast();
        }

        VestingSchedules.VestingSchedule storage vestingSchedule = VestingSchedules.get(_index);
        if (!vestingSchedule.revocable) {
            revert VestingScheduleNotRevocable();
        }

        // revoked end date MUST be after vesting schedule start and before current end
        if ((_end < vestingSchedule.start) || (vestingSchedule.end < _end)) {
            revert InvalidRevokedVestingScheduleEnd();
        }

        // only creator can revoke vesting schedule
        if (vestingSchedule.creator != msg.sender) {
            revert LibErrors.Unauthorized(msg.sender);
        }

        // return tokens that will never be vested to creator
        address escrow = _deterministicVestingEscrow(_index);
        uint256 releasableAmountAtEnd = _computeVestingReleasableAmount(vestingSchedule, escrow, _end);
        uint256 returnedAmount = balanceOf(escrow) - releasableAmountAtEnd;
        if (returnedAmount > 0) {
            _transfer(escrow, vestingSchedule.creator, returnedAmount);
        }

        // set schedule end
        vestingSchedule.end = uint64(_end);

        emit RevokedVestingSchedule(_index, returnedAmount);

        return returnedAmount;
    }

    /// @notice Release vesting schedule
    /// @param _index Index of the vesting schedule to release
    /// @return released amount
    function _releaseVestingSchedule(uint256 _index) internal returns (uint256) {
        VestingSchedules.VestingSchedule memory vestingSchedule = VestingSchedules.get(_index);

        // only beneficiary can release
        if (msg.sender != vestingSchedule.beneficiary) {
            revert LibErrors.Unauthorized(msg.sender);
        }

        // compute releasable amount
        uint256 time = _getCurrentTime();
        if (time < (vestingSchedule.start + vestingSchedule.lockDuration)) {
            revert VestingScheduleIsLocked();
        }

        address escrow = _deterministicVestingEscrow(_index);
        uint256 releasableAmount = _computeVestingReleasableAmount(vestingSchedule, escrow, time);
        if (releasableAmount == 0) {
            revert ZeroReleasableAmount();
        }

        // transfer all releasable token to the beneficiary
        _transfer(escrow, vestingSchedule.beneficiary, releasableAmount);

        emit ReleasedVestingSchedule(_index, releasableAmount);

        return releasableAmount;
    }

    /// @notice Delegate vesting escrowed tokens
    /// @param _index index of the vesting schedule
    /// @param _delegatee address to delegate the token to
    function _delegateVestingEscrow(uint256 _index, address _delegatee) internal returns (bool) {
        VestingSchedules.VestingSchedule storage vestingSchedule = VestingSchedules.get(_index);

        // only beneficiary can delegate
        if (msg.sender != vestingSchedule.beneficiary) {
            revert LibErrors.Unauthorized(msg.sender);
        }

        // update delegate
        address escrow = _deterministicVestingEscrow(_index);
        address oldDelegatee = delegates(escrow);
        _delegate(escrow, _delegatee);

        emit DelegatedVestingEscrow(_index, oldDelegatee, _delegatee);

        return true;
    }

    /// @notice Internal utility to compute the unique escrow deterministic address
    /// @param _index index of the vesting schedule
    function _deterministicVestingEscrow(uint256 _index) internal view returns (address escrow) {
        bytes32 hash = keccak256(abi.encodePacked(address(this), ESCROW, _index));
        return address(uint160(uint256(hash)));
    }

    /// @notice Computes the releasable amount of tokens for a vesting schedule.
    /// @param _vestingSchedule vesting schedule to compute releasable tokens for
    /// @param _escrow address of the escrow of the vesting schedule
    /// @param _time time to compute the releasable amount at
    /// @return amount of release tokens
    function _computeVestingReleasableAmount(
        VestingSchedules.VestingSchedule memory _vestingSchedule,
        address _escrow,
        uint256 _time
    ) internal view returns (uint256) {
        if (_time < _vestingSchedule.end) {
            // vesting has been revoked an we are before end time
            uint256 vestedAmount = _computeVestedAmount(_vestingSchedule, _time);
            uint256 releasedAmount = _computeVestedAmount(_vestingSchedule, _vestingSchedule.end) - balanceOf(_escrow);
            if (vestedAmount > releasedAmount) {
                return vestedAmount - releasedAmount;
            }
            return 0;
        }

        // we are after vesting end date so all remaining tokens can be released
        return balanceOf(_escrow);
    }

    /// @notice Computes the vested amount of tokens for a vesting schedule.
    /// @param _vestingSchedule vesting schedule to compute vested tokens for
    /// @param _time time to compute the vested amount at
    /// @return amount of release tokens
    function _computeVestedAmount(VestingSchedules.VestingSchedule memory _vestingSchedule, uint256 _time)
        internal
        pure
        returns (uint256)
    {
        if (_time < _vestingSchedule.start + _vestingSchedule.cliffDuration) {
            // pre-fliff no tokens have been vested
            return 0;
        } else if (_time >= _vestingSchedule.start + _vestingSchedule.duration) {
            // post vesting all tokens have been vested
            return _vestingSchedule.amount;
        } else {
            uint256 timeFromStart = _time - _vestingSchedule.start;

            // compute tokens vested for completly elapsed periods
            uint256 vestedDuration = timeFromStart - timeFromStart % _vestingSchedule.period;

            return (vestedDuration * _vestingSchedule.amount) / _vestingSchedule.duration;
        }
    }

    /// @notice Returns current time
    function _getCurrentTime() internal view virtual returns (uint256) {
        return block.timestamp;
    }
}
