//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "./interfaces/IRiver.1.sol";
import "./interfaces/IOracle.1.sol";

import "./Administrable.sol";
import "./Initializable.sol";

import "./state/shared/RiverAddress.sol";
import "./state/oracle/OracleMembers.sol";
import "./state/oracle/Quorum.sol";
import "./state/oracle/ExpectedEpochId.sol";
import "./state/oracle/LastEpochId.sol";
import "./state/oracle/ReportsPositions.sol";
import "./state/oracle/ReportsVariants.sol";

/// @title Oracle (v1)
/// @author Kiln
/// @notice This contract handles the input from the allowed oracle members. Highly inspired by Lido's implementation.
contract OracleV1 is IOracleV1, Initializable, Administrable {
    uint256 internal constant ONE_YEAR = 365 days;

    /// @notice Received ETH input has only 9 decimals
    uint128 internal constant DENOMINATION_OFFSET = 1e9;

    /// @notice Initializes the oracle
    /// @param _river Address of the River contract, able to receive oracle input data after quorum is met
    /// @param _administratorAddress Address able to call administrative methods
    /// @param _epochsPerFrame CL spec parameter. Number of epochs in a frame.
    /// @param _slotsPerEpoch CL spec parameter. Number of slots in one epoch.
    /// @param _secondsPerSlot CL spec parameter. Number of seconds between slots.
    /// @param _genesisTime CL spec parameter. Timestamp of the genesis slot.
    /// @param _annualAprUpperBound CL bound parameter. Maximum apr allowed for balance increase. Delta between updates is extrapolated on a year time frame.
    /// @param _relativeLowerBound CL bound parameter. Maximum relative balance decrease.
    function initOracleV1(
        address _river,
        address _administratorAddress,
        uint64 _epochsPerFrame,
        uint64 _slotsPerEpoch,
        uint64 _secondsPerSlot,
        uint64 _genesisTime,
        uint256 _annualAprUpperBound,
        uint256 _relativeLowerBound
    ) external init(0) {
        _setAdmin(_administratorAddress);
        RiverAddress.set(_river);
        emit SetRiver(_river);
        CLSpec.set(
            CLSpec.CLSpecStruct({
                epochsPerFrame: _epochsPerFrame,
                slotsPerEpoch: _slotsPerEpoch,
                secondsPerSlot: _secondsPerSlot,
                genesisTime: _genesisTime
            })
        );
        emit SetSpec(_epochsPerFrame, _slotsPerEpoch, _secondsPerSlot, _genesisTime);
        ReportBounds.set(
            ReportBounds.ReportBoundsStruct({
                annualAprUpperBound: _annualAprUpperBound,
                relativeLowerBound: _relativeLowerBound
            })
        );
        emit SetBounds(_annualAprUpperBound, _relativeLowerBound);
        Quorum.set(1);
        emit SetQuorum(1);
    }

    /// @notice Retrieve River address
    function getRiver() external view returns (address) {
        return RiverAddress.get();
    }
    /// @notice Retrieve the block timestamp

    function getTime() external view returns (uint256) {
        return _getTime();
    }

    /// @notice Retrieve expected epoch id
    function getExpectedEpochId() external view returns (uint256) {
        return ExpectedEpochId.get();
    }

    /// @notice Retrieve member report status
    /// @param _oracleMember Address of member to check
    function getMemberReportStatus(address _oracleMember) external view returns (bool) {
        int256 memberIndex = OracleMembers.indexOf(_oracleMember);
        return memberIndex != -1 && ReportsPositions.get(uint256(memberIndex));
    }

    /// @notice Retrieve member report status
    function getGlobalReportStatus() external view returns (uint256) {
        return ReportsPositions.getRaw();
    }

    /// @notice Retrieve report variants count
    function getReportVariantsCount() external view returns (uint256) {
        return ReportsVariants.get().length;
    }

    /// @notice Retrieve decoded report at provided index
    /// @param _idx Index of report
    function getReportVariant(uint256 _idx)
        external
        view
        returns (uint64 _clBalance, uint32 _clValidators, uint16 _reportCount)
    {
        uint256 report = ReportsVariants.get()[_idx];
        (_clBalance, _clValidators) = _decodeReport(report);
        _reportCount = _getReportCount(report);
    }

    /// @notice Retrieve the last completed epoch id
    function getLastCompletedEpochId() external view returns (uint256) {
        return LastEpochId.get();
    }

    /// @notice Retrieve the current epoch id based on block timestamp
    function getCurrentEpochId() external view returns (uint256) {
        CLSpec.CLSpecStruct memory clSpec = CLSpec.get();
        return _getCurrentEpochId(clSpec);
    }

    /// @notice Retrieve the current quorum
    function getQuorum() external view returns (uint256) {
        return Quorum.get();
    }

    /// @notice Retrieve the current cl spec
    function getCLSpec() external view returns (CLSpec.CLSpecStruct memory) {
        return CLSpec.get();
    }

    /// @notice Retrieve the current frame details
    function getCurrentFrame() external view returns (uint256 _startEpochId, uint256 _startTime, uint256 _endTime) {
        CLSpec.CLSpecStruct memory clSpec = CLSpec.get();
        _startEpochId = _getFrameFirstEpochId(_getCurrentEpochId(clSpec), clSpec);
        uint256 secondsPerEpoch = clSpec.secondsPerSlot * clSpec.slotsPerEpoch;
        _startTime = clSpec.genesisTime + _startEpochId * secondsPerEpoch;
        _endTime = _startTime + secondsPerEpoch * clSpec.epochsPerFrame - 1;
    }

    /// @notice Retrieve the first epoch id of the frame of the provided epoch id
    /// @param _epochId Epoch id used to get the frame
    function getFrameFirstEpochId(uint256 _epochId) external view returns (uint256) {
        CLSpec.CLSpecStruct memory clSpec = CLSpec.get();
        return _getFrameFirstEpochId(_epochId, clSpec);
    }

    function getReportBounds() external view returns (ReportBounds.ReportBoundsStruct memory) {
        return ReportBounds.get();
    }

    function getOracleMembers() external view returns (address[] memory) {
        return OracleMembers.get();
    }

    /// @notice Returns true if address is member
    /// @dev Performs a naive search, do not call this on-chain, used as an off-chain helper
    /// @param _memberAddress Address of the member
    function isMember(address _memberAddress) external view returns (bool) {
        return OracleMembers.indexOf(_memberAddress) >= 0;
    }

    /// @notice Adds new address as oracle member, giving the ability to push cl reports.
    /// @dev Only callable by the adminstrator
    /// @param _newOracleMember Address of the new member
    /// @param _newQuorum New quorum value
    function addMember(address _newOracleMember, uint256 _newQuorum) external onlyAdmin {
        int256 memberIdx = OracleMembers.indexOf(_newOracleMember);
        if (memberIdx >= 0) {
            revert LibErrors.InvalidCall();
        }
        OracleMembers.push(_newOracleMember);
        uint256 previousQuorum = Quorum.get();
        _setQuorum(_newQuorum, previousQuorum);
        emit AddMember(_newOracleMember);
    }

    /// @notice Removes an address from the oracle members.
    /// @dev Only callable by the adminstrator
    /// @param _oracleMember Address to remove
    /// @param _newQuorum New quorum value
    function removeMember(address _oracleMember, uint256 _newQuorum) external onlyAdmin {
        int256 memberIdx = OracleMembers.indexOf(_oracleMember);
        if (memberIdx < 0) {
            revert LibErrors.InvalidCall();
        }
        OracleMembers.deleteItem(uint256(memberIdx));
        ReportsPositions.clear();
        ReportsVariants.clear();
        uint256 previousQuorum = Quorum.get();
        _setQuorum(_newQuorum, previousQuorum);
        emit RemoveMember(_oracleMember);
    }

    function setMember(address _oracleMember, address _newAddress) external {
        LibSanitize._notZeroAddress(_newAddress);
        if (msg.sender != _getAdmin()) {
            revert LibErrors.Unauthorized(msg.sender);
        }
        if (OracleMembers.indexOf(_newAddress) >= 0) {
            revert AddressAlreadyInUse(_newAddress);
        }
        int256 memberIdx = OracleMembers.indexOf(_oracleMember);
        if (memberIdx < 0) {
            revert LibErrors.InvalidCall();
        }
        OracleMembers.set(uint256(memberIdx), _newAddress);
        emit SetMember(_oracleMember, _newAddress);
    }

    /// @notice Edits the cl spec parameters
    /// @dev Only callable by the adminstrator
    /// @param _epochsPerFrame Number of epochs in a frame.
    /// @param _slotsPerEpoch Number of slots in one epoch.
    /// @param _secondsPerSlot Number of seconds between slots.
    /// @param _genesisTime Timestamp of the genesis slot.
    function setCLSpec(uint64 _epochsPerFrame, uint64 _slotsPerEpoch, uint64 _secondsPerSlot, uint64 _genesisTime)
        external
        onlyAdmin
    {
        CLSpec.set(
            CLSpec.CLSpecStruct({
                epochsPerFrame: _epochsPerFrame,
                slotsPerEpoch: _slotsPerEpoch,
                secondsPerSlot: _secondsPerSlot,
                genesisTime: _genesisTime
            })
        );
        emit SetSpec(_epochsPerFrame, _slotsPerEpoch, _secondsPerSlot, _genesisTime);
    }

    /// @notice Edits the cl bounds parameters
    /// @dev Only callable by the adminstrator
    /// @param _annualAprUpperBound Maximum apr allowed for balance increase. Delta between updates is extrapolated on a year time frame.
    /// @param _relativeLowerBound Maximum relative balance decrease.
    function setReportBounds(uint256 _annualAprUpperBound, uint256 _relativeLowerBound) external onlyAdmin {
        ReportBounds.set(
            ReportBounds.ReportBoundsStruct({
                annualAprUpperBound: _annualAprUpperBound,
                relativeLowerBound: _relativeLowerBound
            })
        );
        emit SetBounds(_annualAprUpperBound, _relativeLowerBound);
    }

    /// @notice Edits the quorum required to forward cl data to River
    /// @dev Only callable by the adminstrator
    /// @param _newQuorum New quorum parameter
    function setQuorum(uint256 _newQuorum) external onlyAdmin {
        uint256 previousQuorum = Quorum.get();
        if (previousQuorum == _newQuorum) {
            revert LibErrors.InvalidArgument();
        }
        _setQuorum(_newQuorum, previousQuorum);
    }

    // TODO write natspec
    function _setQuorum(uint256 _newQuorum, uint256 _previousQuorum) internal {
        uint256 memberCount = OracleMembers.get().length;
        if ((_newQuorum == 0 && memberCount > 0) || _newQuorum > memberCount) {
            revert LibErrors.InvalidArgument();
        }
        if (_previousQuorum > _newQuorum) {
            (bool isQuorum, uint256 report) = _getQuorumReport(_newQuorum);
            if (isQuorum) {
                (uint64 clBalance, uint32 clValidators) = _decodeReport(report);
                _pushToRiver(
                    ExpectedEpochId.get(), DENOMINATION_OFFSET * uint128(clBalance), clValidators, CLSpec.get()
                );
            }
        }
        Quorum.set(_newQuorum);
        emit SetQuorum(_newQuorum);
    }

    /// @notice Report cl chain data
    /// @dev Only callable by an oracle member
    /// @param _epochId Epoch where the balance and validator count has been computed
    /// @param _clValidatorsBalance Total balance of River validators
    /// @param _clValidatorCount Total River validator count
    function reportConsensusLayerData(uint256 _epochId, uint64 _clValidatorsBalance, uint32 _clValidatorCount)
        external
    {
        int256 memberIndex = OracleMembers.indexOf(msg.sender);
        if (memberIndex == -1) {
            revert LibErrors.Unauthorized(msg.sender);
        }

        CLSpec.CLSpecStruct memory clSpec = CLSpec.get();
        uint256 expectedEpochId = ExpectedEpochId.get();
        if (_epochId < expectedEpochId) {
            revert EpochTooOld(_epochId, expectedEpochId);
        }

        if (_epochId > expectedEpochId) {
            uint256 frameFirstEpochId = _getFrameFirstEpochId(_getCurrentEpochId(clSpec), clSpec);
            if (_epochId != frameFirstEpochId) {
                revert NotFrameFirstEpochId(_epochId, frameFirstEpochId);
            }
            _clearReporting(_epochId);
        }

        if (ReportsPositions.get(uint256(memberIndex))) {
            revert AlreadyReported(_epochId, msg.sender);
        }
        ReportsPositions.register(uint256(memberIndex));

        uint128 clBalanceEth1 = DENOMINATION_OFFSET * uint128(_clValidatorsBalance);
        emit CLReported(_epochId, clBalanceEth1, _clValidatorCount, msg.sender);

        uint256 report = _encodeReport(_clValidatorsBalance, _clValidatorCount);
        int256 reportIndex = ReportsVariants.indexOfReport(report);
        uint256 quorum = Quorum.get();

        if (reportIndex >= 0) {
            uint256 registeredReport = ReportsVariants.get()[uint256(reportIndex)];
            if (_getReportCount(registeredReport) + 1 >= quorum) {
                _pushToRiver(_epochId, clBalanceEth1, _clValidatorCount, clSpec);
            } else {
                ReportsVariants.set(uint256(reportIndex), registeredReport + 1);
            }
        } else {
            if (quorum == 1) {
                _pushToRiver(_epochId, clBalanceEth1, _clValidatorCount, clSpec);
            } else {
                ReportsVariants.push(report + 1);
            }
        }
    }

    /// @notice Retrieve the report that has the highest number of "votes"
    /// @param _quorum The quorum used for the query
    function _getQuorumReport(uint256 _quorum) internal view returns (bool isQuorum, uint256 report) {
        // check most frequent cases first: all reports are the same or no reports yet
        uint256[] memory variants = ReportsVariants.get();
        if (variants.length == 1) {
            return (_getReportCount(variants[0]) >= _quorum, variants[0]);
        } else if (variants.length == 0) {
            return (false, 0);
        }

        // if more than 2 kind of reports exist, choose the most frequent
        uint256 maxind = 0;
        uint256 repeat = 0;
        uint16 maxval = 0;
        uint16 cur = 0;
        for (uint256 i = 0; i < variants.length;) {
            cur = _getReportCount(variants[i]);
            if (cur >= maxval) {
                if (cur == maxval) {
                    unchecked {
                        ++repeat;
                    }
                } else {
                    maxind = i;
                    maxval = cur;
                    repeat = 0;
                }
            }
            unchecked {
                ++i;
            }
        }
        return (maxval >= _quorum && repeat == 0, variants[maxind]);
    }

    /// @notice Retrieve the block timestamp
    function _getTime() internal view returns (uint256) {
        return block.timestamp; // solhint-disable-line not-rely-on-time
    }

    /// @notice Retrieve the current epoch id based on block timestamp
    /// @param _clSpec CL spec parameters
    function _getCurrentEpochId(CLSpec.CLSpecStruct memory _clSpec) internal view returns (uint256) {
        return (_getTime() - _clSpec.genesisTime) / (_clSpec.slotsPerEpoch * _clSpec.secondsPerSlot);
    }

    /// @notice Retrieve the first epoch id of the frame of the provided epoch id
    /// @param _epochId Epoch id used to get the frame
    /// @param _clSpec CL spec parameters
    function _getFrameFirstEpochId(uint256 _epochId, CLSpec.CLSpecStruct memory _clSpec)
        internal
        pure
        returns (uint256)
    {
        return (_epochId / _clSpec.epochsPerFrame) * _clSpec.epochsPerFrame;
    }

    /// @notice Clear reporting data
    /// @param _epochId Next expected epoch id (first epoch of the next frame)
    function _clearReporting(uint256 _epochId) internal {
        ReportsPositions.clear();
        ReportsVariants.clear();
        ExpectedEpochId.set(_epochId);
        emit ExpectedEpochIdUpdated(_epochId);
    }

    /// @notice Encode report into one slot. Last 16 bits are free to use for vote counting.
    /// @param _clBalance Total validator balance
    /// @param _clValidators Total validator count
    function _encodeReport(uint64 _clBalance, uint32 _clValidators) internal pure returns (uint256) {
        return (uint256(_clBalance) << 48) | (uint256(_clValidators) << 16);
    }

    /// @notice Decode report from one slot to two variables, ignoring the last 16 bits
    /// @param _value Encoded report
    function _decodeReport(uint256 _value) internal pure returns (uint64 _clBalance, uint32 _clValidators) {
        _clBalance = uint64(_value >> 48);
        _clValidators = uint32(_value >> 16);
    }

    /// @notice Retrieve the vote count from the encoded report (last 16 bits)
    /// @param _report Encoded report
    function _getReportCount(uint256 _report) internal pure returns (uint16) {
        return uint16(_report);
    }

    function _maxIncrease(uint256 _prevTotalEth, uint256 _timeElapsed) internal view returns (uint256) {
        uint256 annualAprUpperBound = ReportBounds.get().annualAprUpperBound;
        return (_prevTotalEth * annualAprUpperBound * _timeElapsed) / uint256(10000 * 365 days);
    }

    /// @notice Performs sanity checks to prevent an erroneous update to the River system
    /// @param _postTotalEth Total validator balance after update
    /// @param _prevTotalEth Total validator balance before update
    /// @param _timeElapsed Time since last update
    function _sanityChecks(uint256 _postTotalEth, uint256 _prevTotalEth, uint256 _timeElapsed) internal view {
        if (_postTotalEth >= _prevTotalEth) {
            // increase                 = _postTotalPooledEther - _preTotalPooledEther,
            // relativeIncrease         = increase / _preTotalPooledEther,
            // annualRelativeIncrease   = relativeIncrease / (timeElapsed / 365 days),
            // annualRelativeIncreaseBp = annualRelativeIncrease * 10000, in basis points 0.01% (1e-4)
            uint256 annualAprUpperBound = ReportBounds.get().annualAprUpperBound;
            // check that annualRelativeIncreaseBp <= allowedAnnualRelativeIncreaseBp
            if (
                LibBasisPoints.BASIS_POINTS_MAX * ONE_YEAR * (_postTotalEth - _prevTotalEth)
                    > annualAprUpperBound * _prevTotalEth * _timeElapsed
            ) {
                revert TotalValidatorBalanceIncreaseOutOfBound(
                    _prevTotalEth, _postTotalEth, _timeElapsed, annualAprUpperBound
                );
            }
        } else {
            // decrease           = _preTotalPooledEther - _postTotalPooledEther
            // relativeDecrease   = decrease / _preTotalPooledEther
            // relativeDecreaseBp = relativeDecrease * 10000, in basis points 0.01% (1e-4)
            uint256 relativeLowerBound = ReportBounds.get().relativeLowerBound;
            // check that relativeDecreaseBp <= allowedRelativeDecreaseBp
            if (LibBasisPoints.BASIS_POINTS_MAX * (_prevTotalEth - _postTotalEth) > relativeLowerBound * _prevTotalEth)
            {
                revert TotalValidatorBalanceDecreaseOutOfBound(
                    _prevTotalEth, _postTotalEth, _timeElapsed, relativeLowerBound
                );
            }
        }
    }

    /// @notice Push the new cl data to the river system and performs sanity checks
    /// @param _epochId Id of the epoch
    /// @param _totalBalance Total validator balance
    /// @param _validatorCount Total validator count
    /// @param _clSpec CL spec parameters
    function _pushToRiver(
        uint256 _epochId,
        uint128 _totalBalance,
        uint32 _validatorCount,
        CLSpec.CLSpecStruct memory _clSpec
    ) internal {
        _clearReporting(_epochId + _clSpec.epochsPerFrame);

        IRiverV1 river = IRiverV1(payable(RiverAddress.get()));
        uint256 prevTotalEth = river.totalUnderlyingSupply();
        uint256 timeElapsed = (_epochId - LastEpochId.get()) * _clSpec.slotsPerEpoch * _clSpec.secondsPerSlot;
        uint256 maxIncrease = _maxIncrease(prevTotalEth, timeElapsed);
        river.setConsensusLayerData(_validatorCount, _totalBalance, bytes32(_epochId), maxIncrease);
        uint256 postTotalEth = river.totalUnderlyingSupply();

        _sanityChecks(postTotalEth, prevTotalEth, timeElapsed);
        LastEpochId.set(_epochId);

        emit PostTotalShares(postTotalEth, prevTotalEth, timeElapsed, river.totalSupply());
    }
}
