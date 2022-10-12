//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "openzeppelin-contracts-upgradeable/contracts/token/ERC20/extensions/ERC20VotesUpgradeable.sol";
import "openzeppelin-contracts/contracts/proxy/Clones.sol";

import "./interfaces/IVestingSchedules.1.sol";

import "./state/tlc/VestingSchedules.sol";

contract TLCV1 is IVestingSchedulesV1, ERC20VotesUpgradeable {
    // Token information
    string internal constant NAME = "Liquid Collective";
    string internal constant SYMBOL = "TLC";

    // Initial supply of token minted
    uint256 internal constant INITIAL_SUPPLY = 1_000_000_000e18; // 1 billion TLC

    // Implementation for token escrow clones
    address private escrowImplementation;

    /// @inheritdoc IVestingSchedulesV1
    function initTLCV1(address _account, address _escrowImplementation) external initializer {
        __ERC20Permit_init(NAME);
        __ERC20_init(NAME, SYMBOL);
        _mint(_account, INITIAL_SUPPLY);
        escrowImplementation = _escrowImplementation;
    }

    /// @inheritdoc IVestingSchedulesV1
    function createVestingSchedule(
        address _beneficiary,
        uint256 _start,
        uint256 _cliff,
        uint256 _duration,
        uint256 _period,
        bool _revocable,
        uint256 _amount
    )
        external
        returns (uint256)
    {   
        return _createVestingSchedule(
            _beneficiary, 
            _start,
            _cliff,
            _duration,
            _period,
            _revocable,
            _amount
        );
    }

    function _createVestingSchedule(
        address _beneficiary,
        uint256 _start,
        uint256 _cliff,
        uint256 _duration,
        uint256 _period,
        bool _revocable,
        uint256 _amount
    )
        internal
        returns  (uint256)
    {           
        address creator = msg.sender;
        if (balanceOf(creator) < _amount) {
            revert UnsufficientVestingScheduleCreatorBalance();
        }

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
        
        // Create new vesting schedule
        VestingSchedules.VestingSchedule memory vestingSchedule = VestingSchedules.VestingSchedule({
            start: _start,
            cliff: _start + _cliff,
            duration: _duration,
            period: _period,
            amount: _amount,
            creator: creator,
            beneficiary: _beneficiary,
            revocable: _revocable,
            revoked: false
        });
        uint256 index = VestingSchedules.push(vestingSchedule) - 1;

        // Create an escrow clone contract that will hold the token during the vesting
        address escrow = _cloneDeterministicEscrow(index);

        // transfer tokens to escrow contract and delegate escrow to beneficiary
        _transfer(creator, escrow, _amount);
        _delegate(escrow, _beneficiary);

        emit CreatedVestingSchedule(index, creator, _beneficiary, _amount);

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
    function revokeVestingSchedule(uint256 _index) external returns (uint256 releasedAmount, uint256 returnedAmount) {
        return _revokeVestingSchedule(_index);
    }

    function _revokeVestingSchedule(uint256 _index) internal returns (uint256 releasedAmount, uint256 returnedAmount) {
        VestingSchedules.VestingSchedule storage vestingSchedule = VestingSchedules.get(_index);
        
        if (!vestingSchedule.revocable) {
            revert VestingScheduleNotRevocable();
        }

        if (vestingSchedule.revoked) {
            revert VestingScheduleRevoked();
        }

        if (vestingSchedule.creator != msg.sender) {
            revert LibErrors.Unauthorized(msg.sender); 
        }
        
        address escrow = _predictDeterministicEscrowClone(_index);

        // transfer all releasable token to the beneficiary
        uint256 releasableAmount = _computeReleasableAmount(vestingSchedule, escrow);
        if(releasableAmount > 0){
            _transfer(escrow, vestingSchedule.beneficiary, releasableAmount);
        }
        
        // transfer remaining token back to the creator
        uint256 remainingAmount = balanceOf(escrow);
        if (remainingAmount > 0) {
            _transfer(escrow, vestingSchedule.creator, remainingAmount);
        }

        vestingSchedule.revoked = true;

        emit RevokedVestingSchedule(_index, releasableAmount, remainingAmount);

        return (releasableAmount, remainingAmount);
    }

    /// @inheritdoc IVestingSchedulesV1
    function releaseVestingSchedule(uint256 _index) external returns (uint256) {
        return _releaseVestingSchedule(_index);
    }

    function _releaseVestingSchedule(uint256 _index) internal returns (uint256) {
        VestingSchedules.VestingSchedule storage vestingSchedule = VestingSchedules.get(_index);
        
        if (vestingSchedule.revoked) {
            revert VestingScheduleRevoked();
        }

        if (msg.sender != vestingSchedule.beneficiary) {
            revert LibErrors.Unauthorized(msg.sender); 
        }

        address escrow = _predictDeterministicEscrowClone(_index);
        uint256 releasableAmount = _computeReleasableAmount(vestingSchedule, escrow);
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
        if (vestingSchedule.revoked) {
            revert VestingScheduleRevoked();
        }

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
    function _predictDeterministicEscrowClone(uint256 _index) internal view returns (address) {
        bytes32 salt = sha256(abi.encodePacked(_index));
        return Clones.predictDeterministicAddress(escrowImplementation, salt);
    }

    /// @notice Internal utility to deploy an escrow to hold the tokens while vesting
    /// @param _index index of the vesting schedule
    function _cloneDeterministicEscrow(uint256 _index) internal returns (address) {
        bytes32 salt = sha256(abi.encodePacked(_index));
        return Clones.cloneDeterministic(escrowImplementation, salt);
    }

    /// @inheritdoc IVestingSchedulesV1
    function computeReleasableAmount(uint256 _index) external view returns (uint256) {
        address escrow = _predictDeterministicEscrowClone(_index);
        VestingSchedules.VestingSchedule storage vestingSchedule = VestingSchedules.get(_index);
        return _computeReleasableAmount(vestingSchedule, escrow);
    }

    function _computeReleasableAmount(VestingSchedules.VestingSchedule memory vestingSchedule, address escrow)
        internal
        view
        returns(uint256)
    {
        uint256 vestedAmount = _computeVestedAmount(vestingSchedule);
        uint256 releasedAmount = vestingSchedule.amount - balanceOf(escrow);
        if (vestedAmount > releasedAmount) {
            return vestedAmount - releasedAmount;
        } else {
            return 0;
        }
    }

    function _computeVestedAmount(VestingSchedules.VestingSchedule memory vestingSchedule)
        internal
        view
        returns(uint256)
    {
        uint256 currentTime = _getCurrentTime();
        if ((currentTime < vestingSchedule.cliff) || vestingSchedule.revoked == true) {
            // pre cliff tokens are locked
            return 0;
        } else if (currentTime >= vestingSchedule.start + vestingSchedule.duration) {
            // post vesting all tokens have been vested
            return vestingSchedule.amount;
        } else {
            uint256 timeFromStart = currentTime - vestingSchedule.start;
            uint secondsPerSlice = vestingSchedule.period;
            uint256 vestedSlicePeriods = timeFromStart / secondsPerSlice;
            uint256 vestedSeconds = vestedSlicePeriods * secondsPerSlice;
            return (vestingSchedule.amount * vestedSeconds) /vestingSchedule.duration;
        }
    }

    function _getCurrentTime() internal  virtual view returns(uint256) {
        return block.timestamp;
    }

    receive() external payable {}

    fallback() external payable {}
}

contract Escrow {
    /// @notice Empty calldata fallback
    receive() external payable {}

    /// @notice Non-empty calldata fallback
    fallback() external payable {}
}