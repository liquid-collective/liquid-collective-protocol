//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../interfaces/components/IOracleManager.1.sol";

import "../libraries/LibUint256.sol";
import "../libraries/LibOracleReporting.sol";

import "../state/river/LastConsensusLayerReport.sol";
import "../state/river/OracleAddress.sol";

/// @title Oracle Manager (v1)
/// @author Alluvial Finance Inc.
/// @notice This contract handles the inputs provided by the oracle
/// @notice The Oracle contract is plugged to this contract and is in charge of pushing
/// @notice data whenever a new report has been deemed valid. The report consists in two
/// @notice values: the sum of all balances of all deposited validators and the count of
/// @notice validators that have been activated on the consensus layer.
abstract contract OracleManagerV1 is IOracleManagerV1 {
    /// @notice Handler called to retrieve the system administrator address
    /// @dev Must be overridden
    /// @return The system administrator address
    function _getRiverAdmin() internal view virtual returns (address);

    /// @notice Prevents unauthorized calls
    modifier onlyAdmin_OMV1() {
        if (msg.sender != _getRiverAdmin()) {
            revert LibErrors.Unauthorized(msg.sender);
        }
        _;
    }

    /// @inheritdoc IOracleManagerV1
    function getOracle() external view returns (address) {
        return OracleAddress.get();
    }

    /// @inheritdoc IOracleManagerV1
    function getCLValidatorTotalBalance() external view returns (uint256) {
        return LastConsensusLayerReport.get().validatorsBalance;
    }

    /// @inheritdoc IOracleManagerV1
    function getCLValidatorCount() external view returns (uint256) {
        return LastConsensusLayerReport.get().validatorsCount;
    }

    /// @inheritdoc IOracleManagerV1
    function getExpectedEpochId() external view returns (uint256) {
        CLSpec.CLSpecStruct memory cls = CLSpec.get();
        uint256 currentEpoch = LibOracleReporting._currentEpoch(cls);
        return LibUint256.max(
            LastConsensusLayerReport.get().epoch + cls.epochsPerFrame,
            currentEpoch - (currentEpoch % cls.epochsPerFrame)
        );
    }

    /// @inheritdoc IOracleManagerV1
    function isValidEpoch(uint256 _epoch) external view returns (bool) {
        return LibOracleReporting._isValidEpoch(CLSpec.get(), _epoch);
    }

    /// @inheritdoc IOracleManagerV1
    function getTime() external view returns (uint256) {
        return block.timestamp;
    }

    /// @inheritdoc IOracleManagerV1
    function getLastCompletedEpochId() external view returns (uint256) {
        return LastConsensusLayerReport.get().epoch;
    }

    /// @inheritdoc IOracleManagerV1
    function getCurrentEpochId() external view returns (uint256) {
        return LibOracleReporting._currentEpoch(CLSpec.get());
    }

    /// @inheritdoc IOracleManagerV1
    function getCLSpec() external view returns (CLSpec.CLSpecStruct memory) {
        return CLSpec.get();
    }

    /// @inheritdoc IOracleManagerV1
    function getCurrentFrame() external view returns (uint256 _startEpochId, uint256 _startTime, uint256 _endTime) {
        CLSpec.CLSpecStruct memory cls = CLSpec.get();
        uint256 currentEpoch = LibOracleReporting._currentEpoch(cls);
        _startEpochId = currentEpoch - (currentEpoch % cls.epochsPerFrame);
        _startTime = _startEpochId * cls.slotsPerEpoch * cls.secondsPerSlot;
        _endTime = (_startEpochId + cls.epochsPerFrame) * cls.slotsPerEpoch * cls.secondsPerSlot - 1;
    }

    /// @inheritdoc IOracleManagerV1
    function getFrameFirstEpochId(uint256 _epochId) external view returns (uint256) {
        return _epochId - (_epochId % CLSpec.get().epochsPerFrame);
    }

    /// @inheritdoc IOracleManagerV1
    function getReportBounds() external view returns (ReportBounds.ReportBoundsStruct memory) {
        return ReportBounds.get();
    }

    /// @inheritdoc IOracleManagerV1
    function getLastConsensusLayerReport() external view returns (IOracleManagerV1.StoredConsensusLayerReport memory) {
        return LastConsensusLayerReport.get();
    }

    /// @inheritdoc IOracleManagerV1
    function setOracle(address _oracleAddress) external onlyAdmin_OMV1 {
        OracleAddress.set(_oracleAddress);
        emit SetOracle(_oracleAddress);
    }

    /// @inheritdoc IOracleManagerV1
    function setCLSpec(CLSpec.CLSpecStruct calldata _newValue) external onlyAdmin_OMV1 {
        CLSpec.set(_newValue);
        emit SetSpec(
            _newValue.epochsPerFrame,
            _newValue.slotsPerEpoch,
            _newValue.secondsPerSlot,
            _newValue.genesisTime,
            _newValue.epochsToAssumedFinality
        );
    }

    /// @inheritdoc IOracleManagerV1
    function setReportBounds(ReportBounds.ReportBoundsStruct calldata _newValue) external onlyAdmin_OMV1 {
        ReportBounds.set(_newValue);
        emit SetBounds(_newValue.annualAprUpperBound, _newValue.relativeLowerBound);
    }

    /// @inheritdoc IOracleManagerV1
    function setConsensusLayerData(IOracleManagerV1.ConsensusLayerReport calldata _report) external virtual {
        // The full report computation (auth, bound checks, fund pulls, rewards, exit requests,
        // redeem-manager reporting and deposit commitment) lives in LibOracleReporting and runs
        // here via DELEGATECALL, keeping RiverV1's deployed bytecode under EIP-170. Events and
        // storage writes still resolve against River because address(this) is River.
        LibOracleReporting.setConsensusLayerData(_report);
    }
}
