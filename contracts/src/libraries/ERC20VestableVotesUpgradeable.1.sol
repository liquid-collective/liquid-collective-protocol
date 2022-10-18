//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "openzeppelin-contracts-upgradeable/contracts/token/ERC20/extensions/ERC20VotesUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol";

import "../interfaces/IVestingSchedules.1.sol";

import "../state/tlc/VestingSchedules.sol";

import "./LibSanitize.sol";

abstract contract ERC20VestableVotesUpgradeableV1 is Initializable, IVestingSchedulesV1, ERC20VotesUpgradeable {
    function __ERC20VestableVotes_init() internal onlyInitializing {}

    function __ERC20VestableVotes_init_unchained() internal onlyInitializing {}

    /// @inheritdoc IVestingSchedulesV1
    function createVestingSchedule(
        address _beneficiary,
        uint256 _start,
        uint256 _lockDuration,
        uint256 _duration,
        uint256 _period,
        bool _revocable,
        uint256 _amount
    ) external returns (uint256) {
        return _createVestingSchedule(
            msg.sender, _beneficiary, _start, _lockDuration, _duration, _period, _revocable, _amount
        );
    }

    function _createVestingSchedule(
        address _creator,
        address _beneficiary,
        uint256 _start,
        uint256 _lockDuration,
        uint256 _duration,
        uint256 _period,
        bool _revocable,
        uint256 _amount
    ) internal returns (uint256) {
        if (balanceOf(_creator) < _amount) {
            revert UnsufficientVestingScheduleCreatorBalance();
        }

        if (_beneficiary == address(0)) {
            revert InvalidVestingScheduleParameter("Vesting schedule beneficiary must be non zero address");
        }

        if (_duration == 0) {
            revert InvalidVestingScheduleParameter("Vesting schedule duration must be > 0");
        }

        if (_lockDuration > _duration) {
            revert InvalidVestingScheduleParameter("Vesting schedule duration must be greater than lock duration");
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

        // if input start time is 0 then default to the current block time
        if (_start == 0) {
            _start = block.timestamp;
        }

        // Create new vesting schedule
        VestingSchedules.VestingSchedule memory vestingSchedule = VestingSchedules.VestingSchedule({
            start: _start,
            cliff: _start + _lockDuration,
            end: _start + _duration,
            duration: _duration,
            period: _period,
            amount: _amount,
            creator: _creator,
            beneficiary: _beneficiary,
            revocable: _revocable
        });
        uint256 index = VestingSchedules.push(vestingSchedule) - 1;

        // Create an escrow clone contract that will hold the token during the vesting
        address escrow = _cloneDeterministicEscrow(index);

        // transfer tokens to escrow contract and delegate escrow to beneficiary
        _transfer(_creator, escrow, _amount);
        _delegate(escrow, _beneficiary);

        emit CreatedVestingSchedule(index, _creator, _beneficiary, _amount);

        return index;
    }

    /// @inheritdoc IVestingSchedulesV1
    function getVestingSchedule(uint256 _index) external view returns (VestingSchedules.VestingSchedule memory) {
        return VestingSchedules.get(_index);
    }

    /// @inheritdoc IVestingSchedulesV1
    function getVestingScheduleCount() external view returns (uint256) {
        return VestingSchedules.getCount();
    }

    /// @inheritdoc IVestingSchedulesV1
    function revokeVestingSchedule(uint256 _index, uint256 _end) external returns (uint256) {
        return _revokeVestingSchedule(_index, _end);
    }

    function _revokeVestingSchedule(uint256 _index, uint256 _end) internal returns (uint256) {
        if (_end == 0) {
            // if end time is 0 then default to current block time
            _end = block.timestamp;
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

        // Only schedule creator can revoke vesting schedule
        if (vestingSchedule.creator != msg.sender) {
            revert LibErrors.Unauthorized(msg.sender);
        }

        // Return tokens that will never be vested to creator
        address escrow = _predictDeterministicEscrowClone(_index);
        uint256 releasableAmountAtEnd = _computeReleasableAmount(vestingSchedule, escrow, _end);
        uint256 returnedAmount = balanceOf(escrow) - releasableAmountAtEnd;
        if (returnedAmount > 0) {
            _transfer(escrow, vestingSchedule.creator, returnedAmount);
        }

        // Set schedule end
        vestingSchedule.end = _end;

        emit RevokedVestingSchedule(_index, returnedAmount);

        return returnedAmount;
    }

    /// @inheritdoc IVestingSchedulesV1
    function releaseVestingSchedule(uint256 _index) external returns (uint256) {
        return _releaseVestingSchedule(_index);
    }

    function _releaseVestingSchedule(uint256 _index) internal returns (uint256) {
        VestingSchedules.VestingSchedule memory vestingSchedule = VestingSchedules.get(_index);

        // Only schedule beneficiary can release
        if (msg.sender != vestingSchedule.beneficiary) {
            revert LibErrors.Unauthorized(msg.sender);
        }

        address escrow = _predictDeterministicEscrowClone(_index);
        uint256 releasableAmount = _computeReleasableAmount(vestingSchedule, escrow, _getCurrentTime());
        if (releasableAmount == 0) {
            revert ZeroReleasableAmount();
        }

        // transfer all releasable token to the beneficiary
        _transfer(escrow, vestingSchedule.beneficiary, releasableAmount);

        emit ReleasedVestingSchedule(_index, releasableAmount);

        return releasableAmount;
    }

    /// @inheritdoc IVestingSchedulesV1
    function delegateVestingEscrow(uint256 _index, address _delegatee) external returns (bool) {
        return _delegateVestingEscrow(_index, _delegatee);
    }

    function _delegateVestingEscrow(uint256 _index, address delegatee) internal returns (bool) {
        VestingSchedules.VestingSchedule storage vestingSchedule = VestingSchedules.get(_index);

        // Only schedule beneficiary can delegate
        if (msg.sender != vestingSchedule.beneficiary) {
            revert LibErrors.Unauthorized(msg.sender);
        }

        address escrow = _predictDeterministicEscrowClone(_index);
        address oldDelegatee = delegates(escrow);

        _delegate(escrow, delegatee);

        emit DelegatedVestingEscrow(_index, oldDelegatee, delegatee);

        return true;
    }

    /// @inheritdoc IVestingSchedulesV1
    function vestingEscrow(uint256 _index) external view returns (address) {
        return _predictDeterministicEscrowClone(_index);
    }

    /// @notice Internal utility to compute the escrow deterministic address
    /// @param _index index of the vesting schedule
    function _predictDeterministicEscrowClone(uint256 _index) internal view returns (address escrow) {
        bytes32 salt = sha256(abi.encodePacked(_index));
        bytes32 hash = keccak256(abi.encodePacked(bytes1(0xff), address(this), salt, keccak256("")));

        // NOTE: cast last 20 bytes of hash to address
        return address(uint160(uint256(hash)));
    }

    /// @notice Internal utility to deploy an escrow to hold the tokens while vesting
    /// @param _index index of the vesting schedule
    function _cloneDeterministicEscrow(uint256 _index) internal returns (address escrow) {
        bytes32 salt = sha256(abi.encodePacked(_index));
        assembly {
            // deploy a contract with empty code
            escrow := create2(0, 0, 0, salt)
        }
        LibSanitize._notZeroAddress(escrow);
    }

    /// @inheritdoc IVestingSchedulesV1
    function computeReleasableAmount(uint256 _index) external view returns (uint256) {
        address escrow = _predictDeterministicEscrowClone(_index);
        VestingSchedules.VestingSchedule storage vestingSchedule = VestingSchedules.get(_index);
        return _computeReleasableAmount(vestingSchedule, escrow, _getCurrentTime());
    }

    function _computeReleasableAmount(
        VestingSchedules.VestingSchedule memory vestingSchedule,
        address escrow,
        uint256 time
    ) internal view returns (uint256) {
        if (time < vestingSchedule.end) {
            // vesting has been revoked an we are before end time
            uint256 vestedAmount = _computeVestedAmount(vestingSchedule, time);
            uint256 releasedAmount = _computeVestedAmount(vestingSchedule, vestingSchedule.end) - balanceOf(escrow);
            if (vestedAmount > releasedAmount) {
                return vestedAmount - releasedAmount;
            }
        } else {
            // we are after vesting end date
            return balanceOf(escrow);
        }

        return 0;
    }

    function _computeVestedAmount(VestingSchedules.VestingSchedule memory vestingSchedule, uint256 time)
        internal
        pure
        returns (uint256)
    {
        if (time < vestingSchedule.cliff) {
            // pre cliff tokens are locked
            return 0;
        } else if (time >= vestingSchedule.start + vestingSchedule.duration) {
            // post vesting all tokens have been vested
            return vestingSchedule.amount;
        } else {
            uint256 timeFromStart = time - vestingSchedule.start;
            uint256 vestedDuration = timeFromStart - timeFromStart % vestingSchedule.period;
            return (vestedDuration * vestingSchedule.amount) / vestingSchedule.duration;
        }
    }

    function _getCurrentTime() internal view virtual returns (uint256) {
        return block.timestamp;
    }
}
