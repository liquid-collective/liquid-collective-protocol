//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "./interfaces/IOperatorRegistry.1.sol";
import "./interfaces/IRiver.1.sol";
import "./interfaces/IProtocolVersion.sol";

import "./libraries/LibUint256.sol";

import "./Initializable.sol";
import "./Administrable.sol";

import "./state/operatorsRegistry/Operators.1.sol";
import "./state/operatorsRegistry/Operators.2.sol";
import "./state/operatorsRegistry/Operators.3.sol";
import "./state/operatorsRegistry/TotalValidatorExitsRequested.sol";
import "./state/operatorsRegistry/CurrentValidatorExitsDemand.sol";
import "./state/shared/RiverAddress.sol";

/// @title Operators Registry (v1)
/// @author Alluvial Finance Inc.
/// @notice This contract handles the list of operators and their keys
/// @dev Operator index is the position in the operators array. Operators are only
/// @dev added, never removed, so the operator at index i is always the one at
/// @dev array position i and indices are stable over time.
contract OperatorsRegistryV1 is IOperatorsRegistryV1, Initializable, Administrable, IProtocolVersion {
    /// @inheritdoc IOperatorsRegistryV1
    function initOperatorsRegistryV1(address _admin, address _river) external init(0) {
        _setAdmin(_admin);
        RiverAddress.set(_river);
        emit SetRiver(_river);
    }

    /// @notice Internal migration utility to migrate all operators to OperatorsV2 format
    function _migrateOperators_V1_1() internal {
        uint256 opCount = OperatorsV1.getCount();

        for (uint256 idx = 0; idx < opCount; ++idx) {
            OperatorsV1.Operator memory oldOperatorValue = OperatorsV1.get(idx);

            OperatorsV2.push(
                OperatorsV2.Operator({
                    limit: uint32(oldOperatorValue.limit),
                    funded: uint32(oldOperatorValue.funded),
                    requestedExits: 0,
                    keys: uint32(oldOperatorValue.keys),
                    latestKeysEditBlockNumber: uint64(oldOperatorValue.latestKeysEditBlockNumber),
                    active: oldOperatorValue.active,
                    name: oldOperatorValue.name,
                    operator: oldOperatorValue.operator
                })
            );
        }
    }

    /// @inheritdoc IOperatorsRegistryV1
    function initOperatorsRegistryV1_1() external init(1) {
        _migrateOperators_V1_1();
    }

    /// @inheritdoc IOperatorsRegistryV1
    function initOperatorsRegistryV1_2() external init(2) {
        uint256 opCount = OperatorsV2.getCount();
        for (uint256 idx = 0; idx < opCount; ++idx) {
            OperatorsV2.Operator memory old = OperatorsV2.get(idx);
            OperatorsV3.push(
                OperatorsV3.Operator({
                    funded: old.funded,
                    requestedExits: old.requestedExits,
                    active: old.active,
                    name: old.name,
                    operator: old.operator
                })
            );
        }
    }

    /// @notice Prevent unauthorized calls
    modifier onlyRiver() virtual {
        if (msg.sender != RiverAddress.get()) {
            revert LibErrors.Unauthorized(msg.sender);
        }
        _;
    }

    /// @notice Prevents anyone except the admin or the given operator to make the call. Also checks if operator is active
    /// @notice The admin is able to call this method on behalf of any operator, even if inactive
    /// @param _index The index identifying the operator
    modifier onlyOperatorOrAdmin(uint256 _index) {
        if (msg.sender == _getAdmin()) {
            _;
            return;
        }
        OperatorsV3.Operator storage operator = OperatorsV3.get(_index);
        if (!operator.active) {
            revert InactiveOperator(_index);
        }
        if (msg.sender != operator.operator) {
            revert LibErrors.Unauthorized(msg.sender);
        }
        _;
    }

    /// @inheritdoc IOperatorsRegistryV1
    function getRiver() external view returns (address) {
        return RiverAddress.get();
    }

    /// @inheritdoc IOperatorsRegistryV1
    function getOperator(uint256 _index) external view returns (OperatorsV3.Operator memory) {
        return OperatorsV3.get(_index);
    }

    /// @inheritdoc IOperatorsRegistryV1
    function getOperatorStoppedValidatorCount(uint256 _idx) external view returns (uint32) {
        return _getStoppedValidatorsCount(_idx);
    }

    /// @inheritdoc IOperatorsRegistryV1
    function getTotalStoppedValidatorCount() external view returns (uint32) {
        return _getTotalStoppedValidatorCount();
    }

    /// @inheritdoc IOperatorsRegistryV1
    function getTotalValidatorExitsRequested() external view returns (uint256) {
        return TotalValidatorExitsRequested.get();
    }

    /// @inheritdoc IOperatorsRegistryV1
    function getCurrentValidatorExitsDemand() external view returns (uint256) {
        return CurrentValidatorExitsDemand.get();
    }

    /// @inheritdoc IOperatorsRegistryV1
    function getStoppedAndRequestedExitCounts() external view returns (uint32, uint256) {
        return
            (_getTotalStoppedValidatorCount(), TotalValidatorExitsRequested.get() + CurrentValidatorExitsDemand.get());
    }

    /// @inheritdoc IOperatorsRegistryV1
    function getOperatorCount() external view returns (uint256) {
        return OperatorsV3.getCount();
    }

    /// @inheritdoc IOperatorsRegistryV1
    function getStoppedValidatorCountPerOperator() external view returns (uint32[] memory) {
        uint32[] memory completeList = OperatorsV3.getStoppedValidators();
        uint256 listLength = completeList.length;

        if (listLength > 0) {
            assembly {
                // no need to use free memory pointer as we reuse the same memory range

                // erase previous word storing length
                mstore(completeList, 0)

                // move memory pointer up by a word
                completeList := add(completeList, 0x20)

                // store updated length at new memory pointer location
                mstore(completeList, sub(listLength, 1))
            }
        }

        return completeList;
    }

    /// @inheritdoc IOperatorsRegistryV1
    function listActiveOperators() external view returns (OperatorsV3.Operator[] memory) {
        return OperatorsV3.getAllActive();
    }

    /// @inheritdoc IOperatorsRegistryV1
    function reportStoppedValidatorCounts(uint32[] calldata _stoppedValidatorCounts, uint256 _depositedValidatorCount)
        external
        onlyRiver
    {
        _setStoppedValidatorCounts(_stoppedValidatorCounts, _depositedValidatorCount);
    }

    /// @inheritdoc IOperatorsRegistryV1
    function addOperator(string calldata _name, address _operator) external onlyAdmin returns (uint256) {
        OperatorsV3.Operator memory newOperator =
            OperatorsV3.Operator({active: true, operator: _operator, name: _name, funded: 0, requestedExits: 0});

        uint256 operatorIndex = OperatorsV3.push(newOperator) - 1;

        emit AddedOperator(operatorIndex, _name, _operator);
        return operatorIndex;
    }

    /// @inheritdoc IOperatorsRegistryV1
    function setOperatorAddress(uint256 _index, address _newOperatorAddress) external onlyOperatorOrAdmin(_index) {
        LibSanitize._notZeroAddress(_newOperatorAddress);
        OperatorsV3.Operator storage operator = OperatorsV3.get(_index);

        operator.operator = _newOperatorAddress;

        emit SetOperatorAddress(_index, _newOperatorAddress);
    }

    /// @inheritdoc IOperatorsRegistryV1
    function setOperatorName(uint256 _index, string calldata _newName) external onlyOperatorOrAdmin(_index) {
        LibSanitize._notEmptyString(_newName);
        OperatorsV3.Operator storage operator = OperatorsV3.get(_index);
        operator.name = _newName;

        emit SetOperatorName(_index, _newName);
    }

    /// @inheritdoc IOperatorsRegistryV1
    function setOperatorStatus(uint256 _index, bool _newStatus) external onlyAdmin {
        OperatorsV3.Operator storage operator = OperatorsV3.get(_index);
        operator.active = _newStatus;

        emit SetOperatorStatus(_index, _newStatus);
    }

    /// @inheritdoc IOperatorsRegistryV1
    function requestValidatorExits(OperatorAllocation[] calldata _allocations) external {
        if (msg.sender != IConsensusLayerDepositManagerV1(RiverAddress.get()).getKeeper()) {
            revert IConsensusLayerDepositManagerV1.OnlyKeeper();
        }

        uint256 currentValidatorExitsDemand = CurrentValidatorExitsDemand.get();
        if (currentValidatorExitsDemand == 0) {
            revert NoExitRequestsToPerform();
        }

        uint256 allocationsLength = _allocations.length;
        if (allocationsLength == 0) {
            revert InvalidEmptyArray();
        }

        uint256 requestedExitCount = 0;

        // Check that the exits requested do not exceed the funded validator count of the operator
        for (uint256 i = 0; i < allocationsLength; ++i) {
            uint256 operatorIndex = _allocations[i].operatorIndex;
            uint256 count = _allocations[i].validatorCount;

            if (count == 0) {
                revert AllocationWithZeroValidatorCount();
            }
            if (i > 0 && !(operatorIndex > _allocations[i - 1].operatorIndex)) {
                revert UnorderedOperatorList();
            }

            requestedExitCount += count;

            OperatorsV3.Operator storage operator = OperatorsV3.get(operatorIndex);
            if (!operator.active) {
                revert InactiveOperator(operatorIndex);
            }
            uint256 available = operator.funded - operator.requestedExits;
            if (count > available) {
                // Operator has insufficient available funded validators
                revert ExitsRequestedExceedAvailableFundedCount(operatorIndex, count, available);
            }
            // Operator has sufficient funded validators
            operator.requestedExits += uint32(count);
            emit RequestedValidatorExits(operatorIndex, operator.requestedExits);
        }

        // Check that the exits requested do not exceed the current validator exits demand
        if (requestedExitCount > currentValidatorExitsDemand) {
            revert ExitsRequestedExceedDemand(requestedExitCount, currentValidatorExitsDemand);
        }

        uint256 savedCurrentValidatorExitsDemand = currentValidatorExitsDemand;
        currentValidatorExitsDemand -= requestedExitCount;

        uint256 totalRequestedExitsValue = TotalValidatorExitsRequested.get();
        _setTotalValidatorExitsRequested(totalRequestedExitsValue, totalRequestedExitsValue + requestedExitCount);
        _setCurrentValidatorExitsDemand(savedCurrentValidatorExitsDemand, currentValidatorExitsDemand);
    }

    /// @inheritdoc IOperatorsRegistryV1
    function incrementFundedValidators(uint256 _operatorIndex, bytes[] calldata _publicKeys) external onlyRiver {
        OperatorsV3.Operator storage operator = OperatorsV3.get(_operatorIndex);
        if (!operator.active) {
            revert InactiveOperator(_operatorIndex);
        }
        if (_getStoppedValidatorsCount(_operatorIndex) < operator.requestedExits) {
            revert OperatorIgnoredExitRequests(_operatorIndex);
        }
        operator.funded += uint32(_publicKeys.length);
        emit FundedValidatorKeys(_operatorIndex, _publicKeys, false);
    }

    /// @inheritdoc IOperatorsRegistryV1
    function demandValidatorExits(uint256 _count, uint256 _depositedValidatorCount) external onlyRiver {
        uint256 currentValidatorExitsDemand = CurrentValidatorExitsDemand.get();
        uint256 totalValidatorExitsRequested = TotalValidatorExitsRequested.get();
        _count = LibUint256.min(
            _count, _depositedValidatorCount - (totalValidatorExitsRequested + currentValidatorExitsDemand)
        );
        if (_count > 0) {
            _setCurrentValidatorExitsDemand(currentValidatorExitsDemand, currentValidatorExitsDemand + _count);
        }
    }

    /// @notice Internal utility to retrieve the total stopped validator count
    /// @return The total stopped validator count
    function _getTotalStoppedValidatorCount() internal view returns (uint32) {
        uint32[] storage stoppedValidatorCounts = OperatorsV3.getStoppedValidators();
        if (stoppedValidatorCounts.length == 0) {
            return 0;
        }
        return stoppedValidatorCounts[0];
    }

    /// @notice Internal utility to set the current validator exits demand
    /// @param _currentValue The current value
    /// @param _newValue The new value
    function _setCurrentValidatorExitsDemand(uint256 _currentValue, uint256 _newValue) internal {
        CurrentValidatorExitsDemand.set(_newValue);
        emit SetCurrentValidatorExitsDemand(_currentValue, _newValue);
    }

    /// @notice Internal structure to hold variables for the _setStoppedValidatorCounts method
    struct SetStoppedValidatorCountInternalVars {
        uint256 stoppedValidatorCountsLength;
        uint32[] currentStoppedValidatorCounts;
        uint256 currentStoppedValidatorCountsLength;
        uint32 totalStoppedValidatorCount;
        uint32 count;
        uint256 currentValidatorExitsDemand;
        uint256 cachedCurrentValidatorExitsDemand;
        uint256 totalRequestedExits;
        uint256 cachedTotalRequestedExits;
    }

    /// @notice Internal utility to set the stopped validator array after sanity checks
    /// @param _stoppedValidatorCounts The stopped validators counts for every operator + the total count in index 0
    /// @param _depositedValidatorCount The current deposited validator count
    function _setStoppedValidatorCounts(uint32[] calldata _stoppedValidatorCounts, uint256 _depositedValidatorCount)
        internal
    {
        SetStoppedValidatorCountInternalVars memory vars;
        // we check that the array is not empty
        vars.stoppedValidatorCountsLength = _stoppedValidatorCounts.length;
        if (vars.stoppedValidatorCountsLength == 0) {
            revert InvalidEmptyStoppedValidatorCountsArray();
        }

        OperatorsV3.Operator[] storage operators = OperatorsV3.getAll();

        // we check that the cells containing operator stopped values are no more than the current operator count
        if (vars.stoppedValidatorCountsLength - 1 > operators.length) {
            revert StoppedValidatorCountsTooHigh();
        }

        vars.currentStoppedValidatorCounts = OperatorsV3.getStoppedValidators();
        vars.currentStoppedValidatorCountsLength = vars.currentStoppedValidatorCounts.length;

        // we check that the number of stopped values is not decreasing
        if (vars.stoppedValidatorCountsLength < vars.currentStoppedValidatorCountsLength) {
            revert StoppedValidatorCountArrayShrinking();
        }

        vars.totalStoppedValidatorCount = _stoppedValidatorCounts[0];
        vars.count = 0;

        // create value to track unsolicited validator exits (e.g. to cover cases when Node Operator exit a validator without being requested to)
        vars.currentValidatorExitsDemand = CurrentValidatorExitsDemand.get();
        vars.cachedCurrentValidatorExitsDemand = vars.currentValidatorExitsDemand;
        vars.totalRequestedExits = TotalValidatorExitsRequested.get();
        vars.cachedTotalRequestedExits = vars.totalRequestedExits;

        uint256 idx = 1;
        uint256 unsolicitedExitsSum;
        for (; idx < vars.currentStoppedValidatorCountsLength; ++idx) {
            // if the previous array was long enough, we check that the values are not decreasing
            if (_stoppedValidatorCounts[idx] < vars.currentStoppedValidatorCounts[idx]) {
                revert StoppedValidatorCountsDecreased();
            }

            // we check that the count of stopped validators is not above the funded validator count of an operator
            if (_stoppedValidatorCounts[idx] > operators[idx - 1].funded) {
                revert StoppedValidatorCountAboveFundedCount(
                    idx - 1, _stoppedValidatorCounts[idx], operators[idx - 1].funded
                );
            }

            // if the stopped validator count is greater than its requested exit count, we update the requested exit count
            if (_stoppedValidatorCounts[idx] > operators[idx - 1].requestedExits) {
                emit UpdatedRequestedValidatorExitsUponStopped(
                    idx - 1, operators[idx - 1].requestedExits, _stoppedValidatorCounts[idx]
                );
                unsolicitedExitsSum += _stoppedValidatorCounts[idx] - operators[idx - 1].requestedExits;
                operators[idx - 1].requestedExits = _stoppedValidatorCounts[idx];
            }
            emit SetOperatorStoppedValidatorCount(idx - 1, _stoppedValidatorCounts[idx]);

            // we recompute the total to ensure it's not an invalid sum
            vars.count += _stoppedValidatorCounts[idx];
        }

        // In case of a new operator we do not check against the current stopped validator count (would revert OOB)
        for (; idx < vars.stoppedValidatorCountsLength; ++idx) {
            // we check that the count of stopped validators is not above the funded validator count of an operator
            if (_stoppedValidatorCounts[idx] > operators[idx - 1].funded) {
                revert StoppedValidatorCountAboveFundedCount(
                    idx - 1, _stoppedValidatorCounts[idx], operators[idx - 1].funded
                );
            }

            // if the stopped validator count is greater than its requested exit count, we update the requested exit count
            if (_stoppedValidatorCounts[idx] > operators[idx - 1].requestedExits) {
                emit UpdatedRequestedValidatorExitsUponStopped(
                    idx - 1, operators[idx - 1].requestedExits, _stoppedValidatorCounts[idx]
                );
                unsolicitedExitsSum += _stoppedValidatorCounts[idx] - operators[idx - 1].requestedExits;
                operators[idx - 1].requestedExits = _stoppedValidatorCounts[idx];
            }
            emit SetOperatorStoppedValidatorCount(idx - 1, _stoppedValidatorCounts[idx]);

            // we recompute the total to ensure it's not an invalid sum
            vars.count += _stoppedValidatorCounts[idx];
        }

        vars.totalRequestedExits += unsolicitedExitsSum;
        // we decrease the demand, considering unsolicited exits as if they were answering the demand
        vars.currentValidatorExitsDemand -= LibUint256.min(unsolicitedExitsSum, vars.currentValidatorExitsDemand);

        if (vars.totalRequestedExits != vars.cachedTotalRequestedExits) {
            _setTotalValidatorExitsRequested(vars.cachedTotalRequestedExits, vars.totalRequestedExits);
        }

        if (vars.currentValidatorExitsDemand != vars.cachedCurrentValidatorExitsDemand) {
            _setCurrentValidatorExitsDemand(vars.cachedCurrentValidatorExitsDemand, vars.currentValidatorExitsDemand);
        }

        // we check that the total is matching the sum of the individual values
        if (vars.totalStoppedValidatorCount != vars.count) {
            revert InvalidStoppedValidatorCountsSum();
        }
        // we check that the total is not higher than the current deposited validator count
        if (vars.totalStoppedValidatorCount > _depositedValidatorCount) {
            revert StoppedValidatorCountsTooHigh();
        }
        // we set the new stopped validators counts
        OperatorsV3.setRawStoppedValidators(_stoppedValidatorCounts);
        emit UpdatedStoppedValidators(_stoppedValidatorCounts);
    }

    /// @notice Internal utility to retrieve the actual stopped validator count of an operator from the reported array
    /// @param _operatorIndex The operator index
    /// @return The count of stopped validators
    function _getStoppedValidatorsCount(uint256 _operatorIndex) internal view returns (uint32) {
        return OperatorsV3._getStoppedValidatorCountAtIndex(OperatorsV3.getStoppedValidators(), _operatorIndex);
    }

    /// @notice Internal utility to set the total validator exits requested by the system
    /// @param _currentValue The current value of the total validator exits requested
    /// @param _newValue The new value of the total validator exits requested
    function _setTotalValidatorExitsRequested(uint256 _currentValue, uint256 _newValue) internal {
        TotalValidatorExitsRequested.set(_newValue);
        emit SetTotalValidatorExitsRequested(_currentValue, _newValue);
    }

    /// @inheritdoc IProtocolVersion
    function version() external pure returns (string memory) {
        return "1.2.1";
    }
}
