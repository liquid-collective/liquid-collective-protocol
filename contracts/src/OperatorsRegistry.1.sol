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
import "./state/operatorsRegistry/ValidatorKeys.sol";
import "./state/operatorsRegistry/TotalETHExitsRequested.sol";
import "./state/operatorsRegistry/CurrentETHExitsDemand.sol";
import "./state/operatorsRegistry/TotalValidatorExitsRequested.sol";
import "./state/operatorsRegistry/CurrentValidatorExitsDemand.sol";
import "./state/shared/RiverAddress.sol";

import "./state/migration/OperatorsRegistry_FundedKeyEventRebroadcasting_KeyIndex.sol";
import "./state/migration/OperatorsRegistry_FundedKeyEventRebroadcasting_OperatorIndex.sol";

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

    function initOperatorsRegistryV1_2() external init(2) {
        _migrateOperators_V2_3();

        CurrentETHExitsDemand.set(CurrentValidatorExitsDemand.get() * 32 ether);
        TotalETHExitsRequested.set(TotalValidatorExitsRequested.get() * 32 ether);

        uint32[] memory stoppedValidators = OperatorsV2.getStoppedValidators();
        uint256[] memory exitedETHs = new uint256[](stoppedValidators.length);
        for (uint256 idx = 0; idx < stoppedValidators.length; ++idx) {
            exitedETHs[idx] = stoppedValidators[idx] * 32 ether;
        }
        OperatorsV3.setRawExitedETH(exitedETHs);
    }

    function _migrateOperators_V2_3() internal {
        uint256 opCount = OperatorsV2.getCount();
        for (uint256 idx = 0; idx < opCount; ++idx) {
            OperatorsV2.Operator memory operator = OperatorsV2.get(idx);
            OperatorsV3.push(OperatorsV3.Operator({
                funded: operator.funded * 32 ether,
                requestedExits: operator.requestedExits * 32 ether,
                keys: uint32(operator.keys),
                latestKeysEditBlockNumber: uint64(operator.latestKeysEditBlockNumber),
                active: operator.active,
                name: operator.name,
                operator: operator.operator
            }));
        }
    }

    /// MIGRATION: FUNDED VALIDATOR KEY EVENT REBROADCASTING
    /// As the event for funded keys was moved from River to this contract because we needed to be able to bind
    /// operator indexes to public keys, we need to rebroadcast the past funded validator keys with the new event
    /// to keep retro-compatibility

    /// Emitted when the event rebroadcasting is done and we attempt to broadcast new events
    error FundedKeyEventMigrationComplete();

    /// Utility to force the broadcasting of events. Will keep its progress in storage to prevent being DoSed by the number of keys
    /// @param _amountToEmit The amount of events to emit at maximum in this call
    function forceFundedValidatorKeysEventEmission(uint256 _amountToEmit) external {
        uint256 operatorIndex = OperatorsRegistry_FundedKeyEventRebroadcasting_OperatorIndex.get();
        if (operatorIndex == type(uint256).max) {
            revert FundedKeyEventMigrationComplete();
        }
        if (OperatorsV2.getCount() == 0) {
            OperatorsRegistry_FundedKeyEventRebroadcasting_OperatorIndex.set(type(uint256).max);
            return;
        }
        uint256 keyIndex = OperatorsRegistry_FundedKeyEventRebroadcasting_KeyIndex.get();
        while (_amountToEmit > 0 && operatorIndex != type(uint256).max) {
            OperatorsV2.Operator memory operator = OperatorsV2.get(operatorIndex);

            (bytes[] memory publicKeys,) = ValidatorKeys.getKeys(
                operatorIndex, keyIndex, LibUint256.min(_amountToEmit, operator.funded - keyIndex)
            );
            emit FundedValidatorKeys(operatorIndex, publicKeys, true);
            if (keyIndex + publicKeys.length == operator.funded) {
                keyIndex = 0;
                if (operatorIndex == OperatorsV2.getCount() - 1) {
                    operatorIndex = type(uint256).max;
                } else {
                    unchecked {
                        ++operatorIndex;
                    }
                }
            } else {
                keyIndex += publicKeys.length;
            }
            _amountToEmit -= publicKeys.length;
        }
        OperatorsRegistry_FundedKeyEventRebroadcasting_OperatorIndex.set(operatorIndex);
        OperatorsRegistry_FundedKeyEventRebroadcasting_KeyIndex.set(keyIndex);
    }

    /// @inheritdoc IOperatorsRegistryV1
    function initOperatorsRegistryV1_1() external init(1) {
        _migrateOperators_V1_1();
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
    function getCurrentValidatorExitsDemand() external view returns (uint256) {
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
        uint256 opCount = OperatorsV3.getCount();
        uint256[] memory exitedETHs = new uint256[](opCount);
        for (uint256 idx = 0; idx < opCount; ++idx) {
            exitedETHs[idx] = OperatorsV3.get(idx).requestedExits;
        }
        return exitedETHs;
    }

    /// @inheritdoc IOperatorsRegistryV1
    function getValidator(uint256 _operatorIndex, uint256 _validatorIndex)
        external
        view
        returns (bytes memory publicKey, bytes memory signature, bool funded)
    {
        (publicKey, signature) = ValidatorKeys.get(_operatorIndex, _validatorIndex);
        funded = _validatorIndex < OperatorsV3.get(_operatorIndex).funded / 32 ether;
    }

    /// @inheritdoc IOperatorsRegistryV1
    function getNextValidatorsToDepositFromActiveOperators(OperatorAllocation[] memory _allocations)
        external
        view
        returns (bytes[] memory publicKeys, bytes[] memory signatures)
    {
        (bytes[][] memory perOpKeys, bytes[][] memory perOpSigs) =
            _getPerOperatorValidatorKeysForAllocations(_allocations);
        publicKeys = _flattenByteArrays(perOpKeys);
        signatures = _flattenByteArrays(perOpSigs);
    }

    /// @inheritdoc IOperatorsRegistryV1
    function listActiveOperators() external view returns (OperatorsV3.Operator[] memory) {
        return OperatorsV3.getAllActive();
    }

    /// @inheritdoc IOperatorsRegistryV1
    function reportExitedETH(uint256[] calldata _exitedETHs, uint256 _totalDepositedETH) external onlyRiver {
        _setExitedETH(_exitedETHs, _totalDepositedETH);
    }

    /// @inheritdoc IOperatorsRegistryV1
    function addOperator(string calldata _name, address _operator) external onlyAdmin returns (uint256) {
        OperatorsV3.Operator memory newOperator = OperatorsV3.Operator({
            active: true,
            operator: _operator,
            name: _name,
            funded: 0,
            requestedExits: 0,
            keys: 0,
            latestKeysEditBlockNumber: uint64(block.number)
        });

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

        OperatorsV3.Operator storage operator = OperatorsV3.get(_index);
        uint256 totalKeys = uint256(operator.keys);
        for (uint256 idx = 0; idx < _keyCount; ++idx) {
            bytes memory publicKeyAndSignature = LibBytes.slice(
                _publicKeysAndSignatures,
                idx * (ValidatorKeys.PUBLIC_KEY_LENGTH + ValidatorKeys.SIGNATURE_LENGTH),
                ValidatorKeys.PUBLIC_KEY_LENGTH + ValidatorKeys.SIGNATURE_LENGTH
            );
            ValidatorKeys.set(_index, totalKeys + idx, publicKeyAndSignature);
        }
        OperatorsV3.setKeys(_index, uint32(totalKeys) + _keyCount);

        emit AddedValidatorKeys(_index, _publicKeysAndSignatures);
    }

    /// @inheritdoc IOperatorsRegistryV1
    function removeValidators(uint256 _index, uint256[] calldata _indexes) external onlyOperatorOrAdmin(_index) {
        uint256 indexesLength = _indexes.length;
        if (indexesLength == 0) {
            revert InvalidKeyCount();
        }

        OperatorsV3.Operator storage operator = OperatorsV3.get(_index);

        uint32 totalKeys = operator.keys;

        if (!(_indexes[0] < totalKeys)) {
            revert InvalidIndexOutOfBounds();
        }

        uint256 lastIndex = _indexes[indexesLength - 1];

        if (lastIndex < operator.funded / 32 ether) {
            revert InvalidFundedKeyDeletionAttempt();
        }

        OperatorsV3.setKeys(_index, totalKeys - uint32(indexesLength));

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
    }

    /// @inheritdoc IOperatorsRegistryV1
    function pickNextValidatorsToDeposit(OperatorAllocation[] calldata _allocations)
        external
        onlyRiver
        returns (bytes[] memory publicKeys, bytes[] memory signatures)
    {
        // The dimensions of the bytes arrays must match the validator counts for each operator in the allocations
        (bytes[][] memory perOpKeys, bytes[][] memory perOpSigs) =
            _getPerOperatorValidatorKeysForAllocations(_allocations);
        for (uint256 i = 0; i < perOpKeys.length; ++i) {
            // perOpKeys[i] and perOpSigs[i] each have length == _allocations[i].validatorCount,
            // guaranteed by _getPerOperatorValidatorKeysForAllocations.
            emit FundedValidatorKeys(_allocations[i].operatorIndex, perOpKeys[i], false);
            OperatorsV3.get(_allocations[i].operatorIndex).funded += uint32(perOpKeys[i].length) * 32 ether;
        }
        publicKeys = _flattenByteArrays(perOpKeys);
        signatures = _flattenByteArrays(perOpSigs);
    }

    /// @inheritdoc IOperatorsRegistryV1
    function requestValidatorExits(ExitETHAllocation[] calldata _allocations) external {
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
            if (ethAmount > (operator.funded - operator.requestedExits)) {
                // Operator has insufficient available funded validators
                revert ExitsRequestedExceedAvailableFundedCount(
                    operatorIndex, ethAmount, operator.funded - operator.requestedExits
                );
            }
            // Operator has sufficient funded validators
            operator.requestedExits += ethAmount;
            emit RequestedETHExits(operatorIndex, operator.requestedExits);
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
        _exitAmountToRequest = LibUint256.min(
            _exitAmountToRequest, _totalDepositedETH - (totalETHExitsRequested + currentETHExitsDemand)
        );
        if (_exitAmountToRequest > 0) {
            _setCurrentETHExitsDemand(currentETHExitsDemand, currentETHExitsDemand + _exitAmountToRequest);
        }
    }

    /// @notice Internal utility to get the funded count for an active operator if it is fundable
    /// @param _operatorIndex The operator index
    /// @param _validatorCount The validator count
    /// @return fundedCount The funded count of the operator
    function _getFundedCountForOperatorIfFundable(uint256 _operatorIndex, uint256 _validatorCount)
        internal
        view
        returns (uint32)
    {
        OperatorsV3.Operator memory operator = OperatorsV3.get(_operatorIndex);
        if (!operator.active) {
            revert InactiveOperator(_operatorIndex);
        }
        if (OperatorsV3.getExitedETHAtIndex(_operatorIndex) < operator.requestedExits) {
            revert OperatorIgnoredExitRequests(_operatorIndex);
        }
        uint256 fundedCount = operator.funded / 32 ether;
        uint256 availableKeys = operator.keys - fundedCount;
        if (_validatorCount > availableKeys) {
            revert OperatorHasInsufficientFundableKeys(_operatorIndex, _validatorCount, availableKeys);
        }
        return uint32(fundedCount);
    }

    /// @notice Internal view utility that retrieves the validator keys for the given allocations
    /// @param _allocations The operator allocations sorted by operator index
    /// @return perOperatorKeys Per-operator arrays of public keys
    /// @return perOperatorSigs Per-operator arrays of signatures
    function _getPerOperatorValidatorKeysForAllocations(OperatorAllocation[] memory _allocations)
        internal
        view
        returns (bytes[][] memory perOperatorKeys, bytes[][] memory perOperatorSigs)
    {
        uint256 allocationsLength = _allocations.length;
        if (allocationsLength == 0) {
            revert InvalidEmptyArray();
        }
        perOperatorKeys = new bytes[][](allocationsLength);
        perOperatorSigs = new bytes[][](allocationsLength);
        for (uint256 i = 0; i < allocationsLength; ++i) {
            if (i > 0 && !(_allocations[i].operatorIndex > _allocations[i - 1].operatorIndex)) {
                revert UnorderedOperatorList();
            }
            if (_allocations[i].validatorCount == 0) {
                revert AllocationWithZeroValidatorCount();
            }
            uint32 fundedCount =
                _getFundedCountForOperatorIfFundable(_allocations[i].operatorIndex, _allocations[i].validatorCount);
            (perOperatorKeys[i], perOperatorSigs[i]) =
                ValidatorKeys.getKeys(_allocations[i].operatorIndex, fundedCount, _allocations[i].validatorCount);
        }
    }

    /// @notice Internal utility to retrieve the total exited ETH
    /// @return exitedETH The total exited ETH
    function _getTotalExitedETH() internal view returns (uint256 exitedETH) {
        uint256[] storage exitedETHs = OperatorsV3.getExitedETH();
        return exitedETHs[0];
    }

    /// @notice Internal utility to set the current validator exits demand
    /// @param _currentValue The current value
    /// @param _newValue The new value
    function _setCurrentETHExitsDemand(uint256 _currentValue, uint256 _newValue) internal {
        CurrentETHExitsDemand.set(_newValue);
        emit SetCurrentValidatorExitsDemand(_currentValue, _newValue);
    }

    /// @notice Internal structure to hold variables for the _setExitedETH method
    struct SetExitedETHInternalVars {
        uint256 stoppedExitedETHsLength;
        uint256[] currentExitedETHs;
        uint256 currentExitedETHsLength;
        uint256 totalExitedETH;
        uint256 amountOfExitedETH;
        uint256 currentETHExitsDemand;
        uint256 cachedCurrentETHExitsDemand;
        uint256 totalRequestedETHExits;
        uint256 cachedTotalExitedETH;
    }

    function _setExitedETH(uint256[] calldata _exitedETHs, uint256 _totalDepositedETH) internal {
        SetExitedETHInternalVars memory vars;
        // we check that the array is not empty
        vars.stoppedExitedETHsLength = _exitedETHs.length;
        if (vars.stoppedExitedETHsLength == 0) {
            revert InvalidEmptyArray();
        }

        OperatorsV3.Operator[] storage operators = OperatorsV3.getAll();

        // we check that the cells containing operator stopped values are no more than the current operator count
        if (vars.stoppedExitedETHsLength - 1 > operators.length) {
            revert ExitedETHCountTooHigh();
        }

        vars.currentExitedETHs = OperatorsV3.getExitedETH();
        vars.currentExitedETHsLength = vars.currentExitedETHs.length;

        // we check that the number of stopped values is not decreasing
        if (vars.stoppedExitedETHsLength < vars.currentExitedETHsLength) {
            revert ExitedETHArrayShrinking();
        }

        vars.totalExitedETH = _exitedETHs[0];
        vars.amountOfExitedETH = 0;

        // create value to track unsolicited validator exits (e.g. to cover cases when Node Operator exit a validator without being requested to)
        vars.currentETHExitsDemand = CurrentETHExitsDemand.get();
        vars.cachedCurrentETHExitsDemand = vars.currentETHExitsDemand;
        vars.totalRequestedETHExits = TotalETHExitsRequested.get();
        vars.cachedTotalExitedETH = vars.totalRequestedETHExits;

        uint256 idx = 1;
        uint256 unsolicitedExitsSum;
        for (; idx < vars.currentExitedETHsLength; ++idx) {
            // if the previous array was long enough, we check that the values are not decreasing
            if (_exitedETHs[idx] < vars.currentExitedETHs[idx]) {
                revert ExitedETHArrayDecreased();
            }

            // we check that the amount of exited ETH is not above the funded ETH of an operator
            if (_exitedETHs[idx] > operators[idx - 1].funded) {
                revert ExitedETHAboveFundedETH(
                    idx - 1, _exitedETHs[idx], operators[idx - 1].funded
                );
            }

            // if the amount of exited ETH is greater than the current exited ETH, we update the exited ETH
            if (_exitedETHs[idx] > operators[idx - 1].requestedExits) {
                emit UpdatedRequestedETHExitsUponStopped(
                    idx - 1, operators[idx - 1].requestedExits, _exitedETHs[idx]
                );
                unsolicitedExitsSum += _exitedETHs[idx] - operators[idx - 1].requestedExits;
                operators[idx - 1].requestedExits = _exitedETHs[idx];
            }
            emit SetOperatorExitedETH(idx - 1, _exitedETHs[idx]);

            // we recompute the total to ensure it's not an invalid sum
            vars.amountOfExitedETH += _exitedETHs[idx];
        }

        // In case of a new operator we do not check against the current exited ETH (would revert OOB)
        for (; idx < vars.stoppedExitedETHsLength; ++idx) {
            // we check that the amount of exited ETH is not above the funded ETH of an operator
            if (_exitedETHs[idx] > operators[idx - 1].funded) {
                revert ExitedETHAboveFundedETH(
                    idx - 1, _exitedETHs[idx], operators[idx - 1].funded
                );
            }

            // if the stopped validator count is greater than its requested exit count, we update the requested exit count
            if (_exitedETHs[idx] > operators[idx - 1].requestedExits) {
                emit UpdatedRequestedETHExitsUponStopped(
                    idx - 1, operators[idx - 1].requestedExits, _exitedETHs[idx]
                );
                unsolicitedExitsSum += _exitedETHs[idx] - operators[idx - 1].requestedExits;
                operators[idx - 1].requestedExits = _exitedETHs[idx];
            }
            emit SetOperatorExitedETH(idx - 1, _exitedETHs[idx]);

            // we recompute the total to ensure it's not an invalid sum
            vars.amountOfExitedETH += _exitedETHs[idx];
        }

        vars.totalRequestedETHExits += unsolicitedExitsSum;
        // we decrease the demand, considering unsolicited exits as if they were answering the demand
        vars.currentETHExitsDemand -= LibUint256.min(unsolicitedExitsSum, vars.currentETHExitsDemand);

        if (vars.totalRequestedETHExits != vars.cachedTotalExitedETH) {
            _setTotalETHExitsRequested(vars.cachedTotalExitedETH, vars.totalRequestedETHExits);
        }

        if (vars.currentETHExitsDemand != vars.cachedCurrentETHExitsDemand) {
            _setCurrentETHExitsDemand(vars.cachedCurrentETHExitsDemand, vars.currentETHExitsDemand);
        }

        // we check that the total is matching the sum of the individual values
        if (vars.totalExitedETH != vars.amountOfExitedETH) {
            revert InvalidExitedETHsSum();
        }
        // we check that the total is not higher than the current deposited validator count
        if (vars.totalExitedETH > _totalDepositedETH) {
            revert ExitedETHsTooHigh();
        }

        // we set the EXITED ETH 
        OperatorsV3.setRawExitedETH(_exitedETHs);
        emit UpdatedExitedETHs(_exitedETHs);
    }

    /// @notice Internal utility to flatten a 2D bytes array into a 1D bytes array with a single allocation
    /// @param _arrays The 2D array to flatten
    /// @return result The flattened 1D array
    function _flattenByteArrays(bytes[][] memory _arrays) internal pure returns (bytes[] memory result) {
        uint256 totalLength = 0;
        for (uint256 i = 0; i < _arrays.length; ++i) {
            totalLength += _arrays[i].length;
        }
        result = new bytes[](totalLength);
        uint256 offset = 0;
        for (uint256 i = 0; i < _arrays.length; ++i) {
            bytes[] memory inner = _arrays[i];
            for (uint256 j = 0; j < inner.length; ++j) {
                result[offset++] = inner[j];
            }
        }
    }

    /// @notice Internal utility to set the total validator exits requested by the system
    /// @param _currentValue The current value of the total validator exits requested
    /// @param _newValue The new value of the total validator exits requested
    function _setTotalETHExitsRequested(uint256 _currentValue, uint256 _newValue) internal {
        TotalETHExitsRequested.set(_newValue);
        emit SetTotalValidatorExitsRequested(_currentValue, _newValue);
    }

    /// @inheritdoc IProtocolVersion
    function version() external pure returns (string memory) {
        return "1.2.1";
    }
}
