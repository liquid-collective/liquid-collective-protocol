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
import "./state/operatorsRegistry/TotalETHExitsRequested.sol";
import "./state/operatorsRegistry/CurrentETHExitsDemand.sol";
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
        _migrateOperators_V2_3();

        CurrentETHExitsDemand.set(CurrentValidatorExitsDemand.get() * 32 ether);
        TotalETHExitsRequested.set(TotalValidatorExitsRequested.get() * 32 ether);
    }

    /// @notice Internal utility to migrate the operators from V2 to V3 format
    function _migrateOperators_V2_3() internal {
        uint256 opCount = OperatorsV2.getCount();
        for (uint256 idx = 0; idx < opCount; ++idx) {
            OperatorsV2.Operator memory operator = OperatorsV2.get(idx);
            OperatorsV3.push(
                OperatorsV3.Operator({
                    funded: operator.funded * 32 ether,
                    requestedExits: operator.requestedExits * 32 ether,
                    active: operator.active,
                    name: operator.name,
                    operator: operator.operator
                })
            );
        }

        // we migrate the exited ETH array from V2 to V3 format
        uint32[] memory stoppedValidators = OperatorsV2.getStoppedValidators();
        uint256[] memory exitedETH = new uint256[](stoppedValidators.length);

        for (uint256 idx = 0; idx < stoppedValidators.length; ++idx) {
            exitedETH[idx] = stoppedValidators[idx] * 32 ether;
        }
        OperatorsV3.setRawExitedETH(exitedETH);
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
    function getTotalETHExitsRequested() external view returns (uint256) {
        return TotalETHExitsRequested.get();
    }

    /// @inheritdoc IOperatorsRegistryV1
    function getCurrentETHExitsDemand() external view returns (uint256) {
        return CurrentETHExitsDemand.get();
    }

    /// @inheritdoc IOperatorsRegistryV1
    function getExitedETHAndRequestedExitAmounts() external view returns (uint256, uint256) {
        return (_getTotalExitedETH(), TotalETHExitsRequested.get() + CurrentETHExitsDemand.get());
    }

    /// @inheritdoc IOperatorsRegistryV1
    function getOperatorCount() external view returns (uint256) {
        return OperatorsV3.getCount();
    }

    /// @inheritdoc IOperatorsRegistryV1
    function getExitedETHPerOperator() external view returns (uint256[] memory) {
        uint256[] memory rawExitedETH = OperatorsV3.getExitedETH();
        uint256 listLength = rawExitedETH.length;
        if (listLength > 0) {
            assembly {
                // no need to use free memory pointer as we reuse the same memory range

                // erase previous word storing length
                mstore(rawExitedETH, 0)

                // move memory pointer up by a word
                rawExitedETH := add(rawExitedETH, 0x20)

                // store updated length at new memory pointer location
                mstore(rawExitedETH, sub(listLength, 1))
            }
        }
        return rawExitedETH;
    }

    /// @inheritdoc IOperatorsRegistryV1
    function listActiveOperators() external view returns (OperatorsV3.Operator[] memory) {
        return OperatorsV3.getAllActive();
    }

    /// @inheritdoc IOperatorsRegistryV1
    function incrementFundedETH(uint256[] calldata _fundedETH) external onlyRiver {
        uint256 fundedETHLength = _fundedETH.length;
        if (fundedETHLength == 0) {
            revert InvalidEmptyArray();
        }
        for (uint256 idx = 0; idx < fundedETHLength; ++idx) {
            // We have this check to avoid unnecessary storage reads for operators with no funded ETH
            if (_fundedETH[idx] == 0) {
                continue;
            }
            OperatorsV3.Operator storage operator = OperatorsV3.get(idx);
            if (!operator.active) {
                revert InactiveOperator(idx);
            }
            if (operator.requestedExits > OperatorsV3.getExitedETHAtIndex(idx)) {
                revert OperatorIgnoredExitRequests(idx);
            }
            operator.funded += _fundedETH[idx];
        }
    }

    /// @inheritdoc IOperatorsRegistryV1
    function reportExitedETH(uint256[] calldata _exitedETH, uint256 _totalDepositedETH) external onlyRiver {
        _setExitedETH(_exitedETH, _totalDepositedETH);
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
    function requestValidatorExits(ExitETHAllocation[] calldata _allocations) external {
        uint256 _operatorIndexesLength = _operatorIndexes.length;
        if (_operatorIndexesLength != _newLimits.length) {
            revert InvalidArrayLengths();
        }
        if (_operatorIndexesLength == 0) {
            revert InvalidEmptyArray();
        }
        for (uint256 idx = 0; idx < _operatorIndexesLength; ++idx) {
            uint256 operatorIndex = _operatorIndexes[idx];
            uint32 newLimit = _newLimits[idx];

            // prevents duplicates
            if (idx > 0 && !(operatorIndex > _operatorIndexes[idx - 1])) {
                revert UnorderedOperatorList();
            }

            OperatorsV2.Operator storage operator = OperatorsV2.get(operatorIndex);

            uint32 currentLimit = operator.limit;
            if (newLimit == currentLimit) {
                emit OperatorLimitUnchanged(operatorIndex, newLimit);
                continue;
            }

            // we enter this condition if the operator edited its keys after the off-chain key audit was made
            // we will skip any limit update on that operator unless it was a decrease in the initial limit
            if (_snapshotBlock < operator.latestKeysEditBlockNumber && newLimit > currentLimit) {
                emit OperatorEditsAfterSnapshot(
                    operatorIndex, currentLimit, newLimit, operator.latestKeysEditBlockNumber, _snapshotBlock
                );
                continue;
            }

            // otherwise, we check for limit invariants that shouldn't happen if the off-chain key audit
            // was made properly, and if everything is respected, we update the limit

            if (newLimit > operator.keys) {
                revert OperatorLimitTooHigh(operatorIndex, newLimit, operator.keys);
            }

            if (newLimit < operator.funded) {
                revert OperatorLimitTooLow(operatorIndex, newLimit, operator.funded);
            }

            operator.limit = newLimit;
            emit SetOperatorLimit(operatorIndex, newLimit);
        }
    }

    /// @inheritdoc IOperatorsRegistryV1
    function addValidators(uint256 _index, uint32 _keyCount, bytes calldata _publicKeysAndSignatures)
        external
        onlyOperatorOrAdmin(_index)
    {
        if (_keyCount == 0) {
            revert InvalidKeyCount();
        }

        if (
            _publicKeysAndSignatures.length
                != _keyCount * (ValidatorKeys.PUBLIC_KEY_LENGTH + ValidatorKeys.SIGNATURE_LENGTH)
        ) {
            revert InvalidKeysLength();
        }

        OperatorsV2.Operator storage operator = OperatorsV2.get(_index);
        uint256 totalKeys = uint256(operator.keys);
        for (uint256 idx = 0; idx < _keyCount; ++idx) {
            bytes memory publicKeyAndSignature = LibBytes.slice(
                _publicKeysAndSignatures,
                idx * (ValidatorKeys.PUBLIC_KEY_LENGTH + ValidatorKeys.SIGNATURE_LENGTH),
                ValidatorKeys.PUBLIC_KEY_LENGTH + ValidatorKeys.SIGNATURE_LENGTH
            );
            ValidatorKeys.set(_index, totalKeys + idx, publicKeyAndSignature);
        }
        OperatorsV2.setKeys(_index, uint32(totalKeys) + _keyCount);

        emit AddedValidatorKeys(_index, _publicKeysAndSignatures);
    }

    /// @inheritdoc IOperatorsRegistryV1
    function removeValidators(uint256 _index, uint256[] calldata _indexes) external onlyOperatorOrAdmin(_index) {
        uint256 indexesLength = _indexes.length;
        if (indexesLength == 0) {
            revert InvalidKeyCount();
        }

        OperatorsV2.Operator storage operator = OperatorsV2.get(_index);

        uint32 totalKeys = operator.keys;

        if (!(_indexes[0] < totalKeys)) {
            revert InvalidIndexOutOfBounds();
        }

        uint256 lastIndex = _indexes[indexesLength - 1];

        if (lastIndex < operator.funded) {
            revert InvalidFundedKeyDeletionAttempt();
        }

        bool limitEqualsKeyCount = totalKeys == operator.limit;
        OperatorsV2.setKeys(_index, totalKeys - uint32(indexesLength));

        for (uint256 idx; idx < indexesLength;) {
            uint256 keyIndex = _indexes[idx];

            if (idx > 0 && !(keyIndex < _indexes[idx - 1])) {
                revert InvalidUnsortedIndexes();
            }
            unchecked {
                ++idx;
            }

            uint256 lastKeyIndex = totalKeys - idx;

            (bytes memory removedPublicKey,) = ValidatorKeys.get(_index, keyIndex);
            (bytes memory lastPublicKeyAndSignature) = ValidatorKeys.getRaw(_index, lastKeyIndex);
            ValidatorKeys.set(_index, keyIndex, lastPublicKeyAndSignature);
            ValidatorKeys.set(_index, lastKeyIndex, new bytes(0));

            emit RemovedValidatorKey(_index, removedPublicKey);
        }

        if (limitEqualsKeyCount) {
            operator.limit = operator.keys;
            emit SetOperatorLimit(_index, operator.keys);
        } else if (lastIndex < operator.limit) {
            operator.limit = uint32(lastIndex);
            emit SetOperatorLimit(_index, lastIndex);
        }
    }

    /// @inheritdoc IOperatorsRegistryV1
        if (msg.sender != IConsensusLayerDepositManagerV1(RiverAddress.get()).getKeeper()) {
            revert IConsensusLayerDepositManagerV1.OnlyKeeper();
        }

        uint256 currentETHExitsDemand = CurrentETHExitsDemand.get();
        if (currentETHExitsDemand == 0) {
            revert NoExitRequestsToPerform();
        }

        uint256 allocationsLength = _allocations.length;
        if (allocationsLength == 0) {
            revert InvalidEmptyArray();
        }

        uint256 requestedETHAmount = 0;

        // Check that the exits requested do not exceed the funded ETH count of the operator
        for (uint256 i = 0; i < allocationsLength; ++i) {
            uint256 operatorIndex = _allocations[i].operatorIndex;
            uint256 ethAmount = _allocations[i].ethAmount;

            if (ethAmount == 0) {
                revert AllocationWithZeroETHAmount();
            }
            if (i > 0 && !(operatorIndex > _allocations[i - 1].operatorIndex)) {
                revert UnorderedOperatorList();
            }

            requestedETHAmount += ethAmount;

            OperatorsV3.Operator storage operator = OperatorsV3.get(operatorIndex);
            if (!operator.active) {
                revert InactiveOperator(operatorIndex);
            }

            uint256 opRequestedExits = operator.requestedExits;
            uint256 available = operator.funded - opRequestedExits;
            if (ethAmount > available) {
                // Operator has insufficient available ETH
                revert ExitsRequestedExceedAvailableFundedAmount(operatorIndex, ethAmount, available);
            }
            // Operator has sufficient ETH
            opRequestedExits += ethAmount;
            operator.requestedExits = opRequestedExits;
            emit RequestedETHExits(operatorIndex, opRequestedExits);
        }

        // Check that the exits requested do not exceed the current ETH exits demand
        if (requestedETHAmount > currentETHExitsDemand) {
            revert ExitsRequestedExceedDemand(requestedETHAmount, currentETHExitsDemand);
        }

        uint256 savedCurrentETHExitsDemand = currentETHExitsDemand;
        currentETHExitsDemand -= requestedETHAmount;

        uint256 totalETHExitsRequested = TotalETHExitsRequested.get();
        _setTotalETHExitsRequested(totalETHExitsRequested, totalETHExitsRequested + requestedETHAmount);
        _setCurrentETHExitsDemand(savedCurrentETHExitsDemand, currentETHExitsDemand);
    }

    /// @inheritdoc IOperatorsRegistryV1
    function demandETHExits(uint256 _exitAmountToRequest, uint256 _totalDepositedETH) external onlyRiver {
        uint256 currentETHExitsDemand = CurrentETHExitsDemand.get();
        uint256 totalETHExitsRequested = TotalETHExitsRequested.get();
        if (_totalDepositedETH < (totalETHExitsRequested + currentETHExitsDemand)) {
            revert DemandedETHExitsExceedsDepositedETH();
        }
        _exitAmountToRequest =
            LibUint256.min(_exitAmountToRequest, _totalDepositedETH - (totalETHExitsRequested + currentETHExitsDemand));
        if (_exitAmountToRequest > 0) {
            _setCurrentETHExitsDemand(currentETHExitsDemand, currentETHExitsDemand + _exitAmountToRequest);
        }
    }

    /// @notice Internal utility to retrieve the total exited ETH
    /// @return The total exited ETH
    function _getTotalExitedETH() internal view returns (uint256) {
        uint256[] storage exitedETH = OperatorsV3.getExitedETH();
        if (exitedETH.length == 0) {
            return 0;
        }
        return exitedETH[0];
    }

    /// @notice Internal utility to set the current ETH exits demand
    /// @param _currentValue The current value
    /// @param _newValue The new value
    function _setCurrentETHExitsDemand(uint256 _currentValue, uint256 _newValue) internal {
        CurrentETHExitsDemand.set(_newValue);
        emit SetCurrentETHExitsDemand(_currentValue, _newValue);
    }

    /// @notice Internal structure to hold variables for the _setExitedETH method
    struct SetExitedETHInternalVars {
        uint256 exitedETHLength;
        uint256[] currentExitedETH;
        uint256 currentExitedETHLength;
        uint256 totalExitedETH;
        uint256 amountOfExitedETH;
        uint256 currentETHExitsDemand;
        uint256 cachedCurrentETHExitsDemand;
        uint256 totalRequestedETHExits;
        uint256 cachedTotalRequestedETHExits;
    }

    function _setExitedETH(uint256[] calldata _exitedETH, uint256 _totalDepositedETH) internal {
        SetExitedETHInternalVars memory vars;
        // we check that the array is not empty
        vars.exitedETHLength = _exitedETH.length;
        if (vars.exitedETHLength == 0) {
            revert InvalidEmptyArray();
        }

        OperatorsV3.Operator[] storage operators = OperatorsV3.getAll();

        // we check that the cells containing operator stopped values are no more than the current operator count
        if (vars.exitedETHLength - 1 > operators.length) {
            revert ExitedETHArrayLengthExceedsOperatorCount();
        }

        vars.currentExitedETH = OperatorsV3.getExitedETH();
        vars.currentExitedETHLength = vars.currentExitedETH.length;

        // we check that the number of stopped values is not decreasing
        if (vars.exitedETHLength < vars.currentExitedETHLength) {
            revert ExitedETHArrayShrinking();
        }

        vars.totalExitedETH = _exitedETH[0];
        vars.amountOfExitedETH = 0;

        // create value to track unsolicited exits (e.g. to cover cases when Node Operator exit ETH without being requested to)
        vars.currentETHExitsDemand = CurrentETHExitsDemand.get();
        vars.cachedCurrentETHExitsDemand = vars.currentETHExitsDemand;
        vars.totalRequestedETHExits = TotalETHExitsRequested.get();
        vars.cachedTotalRequestedETHExits = vars.totalRequestedETHExits;

        uint256 idx = 1;
        uint256 unsolicitedExitsSum;
        uint256 opRequestedExits;
        for (; idx < vars.currentExitedETHLength; ++idx) {
            // if the previous array was long enough, we check that the values are not decreasing
            if (_exitedETH[idx] < vars.currentExitedETH[idx]) {
                revert ExitedETHPerOperatorDecreased();
            }

            // we check that the amount of exited ETH is not above the funded ETH of an operator
            if (_exitedETH[idx] > operators[idx - 1].funded) {
                revert ExitedETHExceedsFundedETH(idx - 1, _exitedETH[idx], operators[idx - 1].funded);
            }

            // if the reported exited ETH for this operator is greater than its recorded requestedExits,
            // treat the difference as unsolicited exits and set requestedExits to the reported exited ETH.
            opRequestedExits = operators[idx - 1].requestedExits;
            if (_exitedETH[idx] > opRequestedExits) {
                emit UpdatedRequestedETHExitsUponStopped(idx - 1, opRequestedExits, _exitedETH[idx]);
                unsolicitedExitsSum += _exitedETH[idx] - opRequestedExits;
                operators[idx - 1].requestedExits = _exitedETH[idx];
            }
            emit SetOperatorExitedETH(idx - 1, _exitedETH[idx]);

            // we recompute the total to ensure it's not an invalid sum
            vars.amountOfExitedETH += _exitedETH[idx];
        }

        // In case of a new operator we do not check against the current exited ETH (would revert OOB)
        for (; idx < vars.exitedETHLength; ++idx) {
            // we check that the amount of exited ETH is not above the funded ETH of an operator
            if (_exitedETH[idx] > operators[idx - 1].funded) {
                revert ExitedETHExceedsFundedETH(idx - 1, _exitedETH[idx], operators[idx - 1].funded);
            }

            // if the reported exited ETH for this operator is greater than its recorded requestedExits,
            // treat the difference as unsolicited exits and set requestedExits to the reported exited ETH.
            opRequestedExits = operators[idx - 1].requestedExits;
            if (_exitedETH[idx] > opRequestedExits) {
                emit UpdatedRequestedETHExitsUponStopped(idx - 1, opRequestedExits, _exitedETH[idx]);
                unsolicitedExitsSum += _exitedETH[idx] - opRequestedExits;
                operators[idx - 1].requestedExits = _exitedETH[idx];
            }
            emit SetOperatorExitedETH(idx - 1, _exitedETH[idx]);

            // we recompute the total to ensure it's not an invalid sum
            vars.amountOfExitedETH += _exitedETH[idx];
        }

        vars.totalRequestedETHExits += unsolicitedExitsSum;
        // we decrease the demand, considering unsolicited exits as if they were answering the demand
        vars.currentETHExitsDemand -= LibUint256.min(unsolicitedExitsSum, vars.currentETHExitsDemand);

        if (vars.totalRequestedETHExits != vars.cachedTotalRequestedETHExits) {
            _setTotalETHExitsRequested(vars.cachedTotalRequestedETHExits, vars.totalRequestedETHExits);
        }

        if (vars.currentETHExitsDemand != vars.cachedCurrentETHExitsDemand) {
            _setCurrentETHExitsDemand(vars.cachedCurrentETHExitsDemand, vars.currentETHExitsDemand);
        }

        // we check that the total is matching the sum of the individual values
        if (vars.totalExitedETH != vars.amountOfExitedETH) {
            revert ExitedETHSumMismatch();
        }
        // we check that the total is not higher than the current deposited ETH
        if (vars.totalExitedETH > _totalDepositedETH) {
            revert ExitedETHExceedsDeposited();
        }

        // we set the exited ETH
        OperatorsV3.setRawExitedETH(_exitedETH);
        emit UpdatedExitedETH(_exitedETH);
    }

    /// @notice Internal utility to set the total ETH exits requested by the system
    /// @param _currentValue The current value of the total ETH exits requested
    /// @param _newValue The new value of the total ETH exits requested
    function _setTotalETHExitsRequested(uint256 _currentValue, uint256 _newValue) internal {
        TotalETHExitsRequested.set(_newValue);
        emit SetTotalETHExitsRequested(_currentValue, _newValue);
    }

    /// @inheritdoc IProtocolVersion
    function version() external pure returns (string memory) {
        return "1.2.1";
    }
}
