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
import "./state/oracle/ReportsPositions.sol";

/// @title Oracle (v1)
/// @author Kiln
/// @notice This contract handles the input from the allowed oracle members. Highly inspired by Lido's implementation.
contract OracleV1 is IOracleV1, Initializable, Administrable {
    /// @notice One Year value
    uint256 internal constant ONE_YEAR = 365 days;

    /// @notice Received ETH input has only 9 decimals
    uint128 internal constant DENOMINATION_OFFSET = 1e9;

    /// @inheritdoc IOracleV1
    function initOracleV1(
        address _riverAddress,
        address _administratorAddress,
        uint64 _epochsPerFrame,
        uint64 _slotsPerEpoch,
        uint64 _secondsPerSlot,
        uint64 _genesisTime,
        uint256 _annualAprUpperBound,
        uint256 _relativeLowerBound
    ) external init(0) {
        _setAdmin(_administratorAddress);
        RiverAddress.set(_riverAddress);
        emit SetRiver(_riverAddress);
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
        Quorum.set(0);
        emit SetQuorum(0);
    }

    /// @inheritdoc IOracleV1
    function getRiver() external view returns (address) {
        return RiverAddress.get();
    }

    /// @inheritdoc IOracleV1
    function getMemberReportStatus(address _oracleMember) external view returns (bool) {
        int256 memberIndex = OracleMembers.indexOf(_oracleMember);
        return memberIndex != -1 && ReportsPositions.get(uint256(memberIndex));
    }

    /// @inheritdoc IOracleV1
    function getGlobalReportStatus() external view returns (uint256) {
        return ReportsPositions.getRaw();
    }

    /// @inheritdoc IOracleV1
    function getReportVariantsCount() external view returns (uint256) {
        return reportVariants.length;
    }

    error ReportIndexOutOfBounds(uint256 index, uint256 length);

    /// @inheritdoc IOracleV1
    function getReportVariantDetails(uint256 _idx) external view returns (ReportVariantDetails memory) {
        if (reportVariants.length <= _idx) {
            revert ReportIndexOutOfBounds(_idx, reportVariants.length);
        }
        return reportVariants[_idx];
    }

    /// @inheritdoc IOracleV1
    function getLastCompletedReportEpoch() external view returns (uint256) {
        return lastCompletedReportEpoch;
    }

    /// @inheritdoc IOracleV1
    function getQuorum() external view returns (uint256) {
        return Quorum.get();
    }

    /// @inheritdoc IOracleV1
    function getOracleMembers() external view returns (address[] memory) {
        return OracleMembers.get();
    }

    /// @inheritdoc IOracleV1
    function isMember(address _memberAddress) external view returns (bool) {
        return OracleMembers.indexOf(_memberAddress) >= 0;
    }

    /// @inheritdoc IOracleV1
    function addMember(address _newOracleMember, uint256 _newQuorum) external onlyAdmin {
        int256 memberIdx = OracleMembers.indexOf(_newOracleMember);
        if (memberIdx >= 0) {
            revert AddressAlreadyInUse(_newOracleMember);
        }
        OracleMembers.push(_newOracleMember);
        uint256 previousQuorum = Quorum.get();
        _clearReportsAndSetQuorum(_newQuorum, previousQuorum);
        emit AddMember(_newOracleMember);
    }

    /// @inheritdoc IOracleV1
    function removeMember(address _oracleMember, uint256 _newQuorum) external onlyAdmin {
        int256 memberIdx = OracleMembers.indexOf(_oracleMember);
        if (memberIdx < 0) {
            revert LibErrors.InvalidCall();
        }
        OracleMembers.deleteItem(uint256(memberIdx));
        uint256 previousQuorum = Quorum.get();
        _clearReportsAndSetQuorum(_newQuorum, previousQuorum);
        emit RemoveMember(_oracleMember);
    }

    /// @inheritdoc IOracleV1
    function setQuorum(uint256 _newQuorum) external onlyAdmin {
        uint256 previousQuorum = Quorum.get();
        if (previousQuorum == _newQuorum) {
            revert LibErrors.InvalidArgument();
        }
        _clearReportsAndSetQuorum(_newQuorum, previousQuorum);
    }

    /// @notice Internal utility to clear all the reports and edit the quorum if a new value is provided
    /// @dev Ensures that the quorum respects invariants
    /// @dev The admin is in charge of providing a proper quorum based on the oracle member count
    /// @dev The quorum value Q should respect the following invariant, where O is oracle member count
    /// @dev (O / 2) + 1 <= Q <= O
    /// @param _newQuorum New quorum value
    /// @param _previousQuorum The old quorum value
    function _clearReportsAndSetQuorum(uint256 _newQuorum, uint256 _previousQuorum) internal {
        uint256 memberCount = OracleMembers.get().length;
        if ((_newQuorum == 0 && memberCount > 0) || _newQuorum > memberCount) {
            revert LibErrors.InvalidArgument();
        }
        _clearReports();
        if (_newQuorum != _previousQuorum) {
            Quorum.set(_newQuorum);
            emit SetQuorum(_newQuorum);
        }
    }

    // rework beyond this point

    event ReportedConsensusLayerData(
        address indexed member, bytes32 indexed variant, IRiverV1.ConsensusLayerReport report, uint256 voteCount
    );
    event SetLastReportedEpoch(uint256 lastReportedEpoch);
    event ClearedReporting();

    error InvalidEpoch(uint256 epoch);

    uint256 internal lastReportedEpoch;
    uint256 internal lastCompletedReportEpoch;
    ReportVariantDetails[] internal reportVariants;

    function _reportChecksum(IRiverV1.ConsensusLayerReport calldata report) internal pure returns (bytes32) {
        return keccak256(abi.encode(report));
    }

    function _clearReports() internal {
        delete reportVariants;
        ReportsPositions.clear();
        emit ClearedReporting();
    }

    function _getReportVariant(bytes32 variant) internal view returns (int256, uint256) {
        uint256 reportVariantsLength = reportVariants.length;
        for (uint256 idx = 0; idx < reportVariantsLength;) {
            if (reportVariants[idx].variant == variant) {
                return (int256(idx), reportVariants[idx].votes);
            }
            unchecked {
                ++idx;
            }
        }
        return (-1, 0);
    }

    function reportConsensusLayerData(IRiverV1.ConsensusLayerReport calldata report) external {
        int256 memberIndex = OracleMembers.indexOf(msg.sender);
        if (memberIndex == -1) {
            revert LibErrors.Unauthorized(msg.sender);
        }

        uint256 lastReportedEpochValue = lastReportedEpoch;

        if (report.epoch < lastReportedEpochValue) {
            revert EpochTooOld(report.epoch, lastReportedEpoch);
        }
        IRiverV1 river = IRiverV1(payable(RiverAddress.get()));
        if (!river.isValidEpoch(report.epoch)) {
            revert InvalidEpoch(report.epoch);
        }
        if (report.epoch > lastReportedEpochValue) {
            _clearReports();
            lastReportedEpoch = report.epoch;
            emit SetLastReportedEpoch(report.epoch);
        }

        if (ReportsPositions.get(uint256(memberIndex))) {
            revert AlreadyReported(report.epoch, msg.sender);
        }
        ReportsPositions.register(uint256(memberIndex));

        bytes32 variant = _reportChecksum(report);
        (int256 variantIndex, uint256 variantVotes) = _getReportVariant(variant);
        uint256 quorum = Quorum.get();

        emit ReportedConsensusLayerData(msg.sender, variant, report, variantVotes + 1);

        if (variantVotes + 1 >= quorum) {
            river.setConsensusLayerData(report);
            _clearReports();
            lastCompletedReportEpoch = lastReportedEpochValue;
            lastReportedEpoch = lastReportedEpochValue + 1;
            emit SetLastReportedEpoch(lastReportedEpochValue + 1);
        } else if (variantVotes == 0) {
            reportVariants.push(ReportVariantDetails({variant: variant, votes: 1}));
        } else {
            reportVariants[uint256(variantIndex)].votes += 1;
        }
    }

    modifier onlyAdminOrMember(address _oracleMember) {
        if (msg.sender != _getAdmin() && msg.sender != _oracleMember) {
            revert LibErrors.Unauthorized(msg.sender);
        }
        _;
    }

    /// @inheritdoc IOracleV1
    function setMember(address _oracleMember, address _newAddress) external onlyAdminOrMember(_oracleMember) {
        LibSanitize._notZeroAddress(_newAddress);
        if (OracleMembers.indexOf(_newAddress) >= 0) {
            revert AddressAlreadyInUse(_newAddress);
        }
        int256 memberIdx = OracleMembers.indexOf(_oracleMember);
        if (memberIdx < 0) {
            revert LibErrors.InvalidCall();
        }
        OracleMembers.set(uint256(memberIdx), _newAddress);
        emit SetMember(_oracleMember, _newAddress);
        _clearReports();
    }

    function _river() internal view returns (IRiverV1) {
        return IRiverV1(payable(RiverAddress.get()));
    }

    function isValidEpoch(uint256 epoch) external view returns (bool) {
        return _river().isValidEpoch(epoch);
    }

    function getTime() external view returns (uint256) {
        return _river().getTime();
    }

    function getExpectedEpochId() external view returns (uint256) {
        return _river().getExpectedEpochId();
    }

    function getLastCompletedEpochId() external view returns (uint256) {
        return _river().getLastCompletedEpochId();
    }

    function getCurrentEpochId() external view returns (uint256) {
        return _river().getCurrentEpochId();
    }

    function getCLSpec() external view returns (CLSpec.CLSpecStruct memory) {
        return _river().getCLSpec();
    }

    function getCurrentFrame() external view returns (uint256 _startEpochId, uint256 _startTime, uint256 _endTime) {
        return _river().getCurrentFrame();
    }

    function getFrameFirstEpochId(uint256 _epochId) external view returns (uint256) {
        return _river().getFrameFirstEpochId(_epochId);
    }

    function getReportBounds() external view returns (ReportBounds.ReportBoundsStruct memory) {
        return _river().getReportBounds();
    }
}
