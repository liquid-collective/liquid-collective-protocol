//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "../state/oracle/CLSpec.sol";
import "../state/oracle/ReportBounds.sol";

/// @title Oracle (v1)
/// @author Kiln
/// @notice This contract handles the input from the allowed oracle members. Highly inspired by Lido's implementation.
interface IOracleV1 {
    event CLReported(uint256 _epochId, uint128 _newCLBalance, uint32 _newCLValidatorCount, address _oracleMember);
    event SetQuorum(uint256 _newQuorum);
    event ExpectedEpochIdUpdated(uint256 _epochId);
    event BeaconReported(
        uint256 _epochId, uint128 _newBeaconBalance, uint32 _newBeaconValidatorCount, address indexed _oracleMember
    );
    event PostTotalShares(uint256 _postTotalEth, uint256 _prevTotalEth, uint256 _timeElapsed, uint256 _totalShares);
    event AddMember(address indexed member);
    event RemoveMember(address indexed member);
    event SetMember(address indexed oldAddress, address indexed newAddress);
    event SetSpec(uint64 _epochsPerFrame, uint64 _slotsPerEpoch, uint64 _secondsPerSlot, uint64 _genesisTime);
    event SetBounds(uint256 _annualAprUpperBound, uint256 _relativeLowerBound);
    event SetRiver(address _river);

    error EpochTooOld(uint256 _providedEpochId, uint256 _minExpectedEpochId);
    error NotFrameFirstEpochId(uint256 _providedEpochId, uint256 _expectedFrameFirstEpochId);
    error AlreadyReported(uint256 _epochId, address _member);
    error TotalValidatorBalanceIncreaseOutOfBound(
        uint256 _prevTotalEth, uint256 _postTotalEth, uint256 _timeElapsed, uint256 _annualAprUpperBound
    );
    error TotalValidatorBalanceDecreaseOutOfBound(
        uint256 _prevTotalEth, uint256 _postTotalEth, uint256 _timeElapsed, uint256 _relativeLowerBound
    );
    error AddressAlreadyInUse(address _newAddress);

    function initOracleV1(
        address _riverContractAddress,
        address _administratorAddress,
        uint64 _epochsPerFrame,
        uint64 _slotsPerEpoch,
        uint64 _secondsPerSlot,
        uint64 _genesisTime,
        uint256 _annualAprUpperBound,
        uint256 _relativeLowerBound
    ) external;

    function getRiver() external view returns (address);
    function getTime() external view returns (uint256);
    function getExpectedEpochId() external view returns (uint256);
    function getMemberReportStatus(address _oracleMember) external view returns (bool);
    function getGlobalReportStatus() external view returns (uint256);
    function getReportVariantsCount() external view returns (uint256);
    function getReportVariant(uint256 _idx)
        external
        view
        returns (uint64 _clBalance, uint32 _clValidators, uint16 _reportCount);
    function getLastCompletedEpochId() external view returns (uint256);
    function getCurrentEpochId() external view returns (uint256);
    function getQuorum() external view returns (uint256);
    function getCLSpec() external view returns (CLSpec.CLSpecStruct memory);
    function getCurrentFrame() external view returns (uint256 _startEpochId, uint256 _startTime, uint256 _endTime);
    function getFrameFirstEpochId(uint256 _epochId) external view returns (uint256);
    function getReportBounds() external view returns (ReportBounds.ReportBoundsStruct memory);
    function getOracleMembers() external view returns (address[] memory);
    function isMember(address _memberAddress) external view returns (bool);
    function addMember(address _newOracleMember, uint256 _newQuorum) external;
    function removeMember(address _oracleMember, uint256 _newQuorum) external;
    function setMember(address _oracleMember, address _newAddress) external;
    function setCLSpec(uint64 _epochsPerFrame, uint64 _slotsPerEpoch, uint64 _secondsPerSlot, uint64 _genesisTime)
        external;
    function setReportBounds(uint256 _annualAprUpperBound, uint256 _relativeLowerBound) external;
    function setQuorum(uint256 _newQuorum) external;
    function reportConsensusLayerData(uint256 _epochId, uint64 _clBalance, uint32 _clValidators) external;
}
