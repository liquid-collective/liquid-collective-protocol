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

    /// @notice Set the initial oracle address
    /// @param _oracle Address of the oracle
    function initOracleManagerV1(address _oracle) internal {
        OracleAddress.set(_oracle);
        emit SetOracle(_oracle);
    }

    /// @notice Initializes version 1.1 of the oracle manager
    /// @param _epochsPerFrame The amounts of epochs in a frame
    /// @param _slotsPerEpoch The slots inside an epoch
    /// @param _secondsPerSlot The seconds inside a slot
    /// @param _genesisTime The genesis timestamp
    /// @param _epochsToAssumedFinality The number of epochs before an epoch is considered final on-chain
    /// @param _annualAprUpperBound The reporting upper bound
    /// @param _relativeLowerBound The reporting lower bound
    function initOracleManagerV1_1(
        uint64 _epochsPerFrame,
        uint64 _slotsPerEpoch,
        uint64 _secondsPerSlot,
        uint64 _genesisTime,
        uint64 _epochsToAssumedFinality,
        uint256 _annualAprUpperBound,
        uint256 _relativeLowerBound
    ) internal {
        CLSpec.set(
            CLSpec.CLSpecStruct({
                epochsPerFrame: _epochsPerFrame,
                slotsPerEpoch: _slotsPerEpoch,
                secondsPerSlot: _secondsPerSlot,
                genesisTime: _genesisTime,
                epochsToAssumedFinality: _epochsToAssumedFinality
            })
        );
        emit SetSpec(_epochsPerFrame, _slotsPerEpoch, _secondsPerSlot, _genesisTime, _epochsToAssumedFinality);
        ReportBounds.set(
            ReportBounds.ReportBoundsStruct({
                annualAprUpperBound: _annualAprUpperBound, relativeLowerBound: _relativeLowerBound
            })
        );
        emit SetBounds(_annualAprUpperBound, _relativeLowerBound);
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
        uint256 currentEpoch = _currentEpoch(cls);
        return LibUint256.max(
            LastConsensusLayerReport.get().epoch + cls.epochsPerFrame,
            currentEpoch - (currentEpoch % cls.epochsPerFrame)
        );
    }

    /// @inheritdoc IOracleManagerV1
    function isValidEpoch(uint256 _epoch) external view returns (bool) {
        return _isValidEpoch(CLSpec.get(), _epoch);
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
        return _currentEpoch(CLSpec.get());
    }

    /// @inheritdoc IOracleManagerV1
    function getCLSpec() external view returns (CLSpec.CLSpecStruct memory) {
        return CLSpec.get();
    }

    /// @inheritdoc IOracleManagerV1
    function getCurrentFrame() external view returns (uint256 _startEpochId, uint256 _startTime, uint256 _endTime) {
        CLSpec.CLSpecStruct memory cls = CLSpec.get();
        uint256 currentEpoch = _currentEpoch(cls);
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

    /// @notice Retrieve the current epoch based on the current timestamp
    /// @param _cls The consensus layer spec struct
    /// @return The current epoch
    function _currentEpoch(CLSpec.CLSpecStruct memory _cls) internal view returns (uint256) {
        return ((block.timestamp - _cls.genesisTime) / _cls.secondsPerSlot) / _cls.slotsPerEpoch;
    }

    /// @notice Verifies if the given epoch is valid
    /// @param _cls The consensus layer spec struct
    /// @param _epoch The epoch to verify
    /// @return True if valid
    function _isValidEpoch(CLSpec.CLSpecStruct memory _cls, uint256 _epoch) internal view returns (bool) {
        return (_currentEpoch(_cls) >= _epoch + _cls.epochsToAssumedFinality
                && _epoch > LastConsensusLayerReport.get().epoch && _epoch % _cls.epochsPerFrame == 0);
    }
}
