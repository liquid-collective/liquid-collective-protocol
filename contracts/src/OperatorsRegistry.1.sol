//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "./interfaces/IOperatorRegistry.1.sol";

import "./libraries/LibUint256.sol";

import "./Initializable.sol";
import "./Administrable.sol";

import "./state/operatorsRegistry/Operators.sol";
import "./state/operatorsRegistry/ValidatorKeys.sol";
import "./state/shared/RiverAddress.sol";

/// @title OperatorsRegistry (v1)
/// @author Kiln
/// @notice This contract handles the list of operators and their keys
contract OperatorsRegistryV1 is IOperatorsRegistryV1, Initializable, Administrable {
    /// @notice Initializes the operators registry
    /// @param _admin Admin in charge of managing operators
    /// @param _river Address of River system
    function initOperatorsRegistryV1(address _admin, address _river) external init(0) {
        _setAdmin(_admin);
        RiverAddress.set(_river);
        emit SetRiver(_river);
    }

    modifier onlyRiver() virtual {
        if (msg.sender != RiverAddress.get()) {
            revert LibErrors.Unauthorized(msg.sender);
        }
        _;
    }

    /// @notice Prevents anyone except the admin or the given operator to make the call. Also checks if operator is active
    /// @param _index The name identifying the operator
    modifier onlyOperatorOrAdmin(uint256 _index) {
        if (msg.sender == _getAdmin()) {
            _;
            return;
        }
        Operators.Operator storage operator = Operators.get(_index);
        if (!operator.active) {
            revert InactiveOperator(_index);
        }
        if (msg.sender != operator.operator) {
            revert LibErrors.Unauthorized(msg.sender);
        }
        _;
    }

    /// @notice Retrieve the River address
    function getRiver() external view returns (address) {
        return RiverAddress.get();
    }

    /// @notice Retrieve the active operator set
    function listActiveOperators() external view returns (Operators.Operator[] memory) {
        return Operators.getAllActive();
    }

    /// @notice Adds an operator to the registry
    /// @dev Only callable by the administrator
    /// @param _name The name identifying the operator
    /// @param _operator The address representing the operator, receiving the rewards
    function addOperator(string calldata _name, address _operator) external onlyAdmin returns (uint256) {
        Operators.Operator memory newOperator = Operators.Operator({
            active: true,
            operator: _operator,
            name: _name,
            limit: 0,
            funded: 0,
            keys: 0,
            stopped: 0,
            lastEdit: block.number
        });

        uint256 operatorIndex = Operators.push(newOperator) - 1;

        emit AddedOperator(operatorIndex, newOperator.name, newOperator.operator);
        return operatorIndex;
    }

    /// @notice Changes the operator address of an operator
    /// @dev Only callable by the administrator or the previous operator address
    /// @param _index The operator index
    /// @param _newOperatorAddress The new address of the operator
    function setOperatorAddress(uint256 _index, address _newOperatorAddress) external onlyOperatorOrAdmin(_index) {
        LibSanitize._notZeroAddress(_newOperatorAddress);
        Operators.Operator storage operator = Operators.get(_index);

        operator.operator = _newOperatorAddress;

        emit SetOperatorAddress(_index, _newOperatorAddress);
    }

    /// @notice Changes the operator name
    /// @dev Only callable by the administrator or the operator
    /// @dev No name conflict can exist
    /// @param _index The operator index
    /// @param _newName The new operator name
    function setOperatorName(uint256 _index, string calldata _newName) external onlyOperatorOrAdmin(_index) {
        LibSanitize._notEmptyString(_newName);
        Operators.Operator storage operator = Operators.get(_index);
        operator.name = _newName;

        emit SetOperatorName(_index, _newName);
    }

    /// @notice Changes the operator status
    /// @dev Only callable by the administrator
    /// @param _index The operator index
    /// @param _newStatus The new status of the operator
    function setOperatorStatus(uint256 _index, bool _newStatus) external onlyAdmin {
        Operators.Operator storage operator = Operators.get(_index);
        operator.active = _newStatus;

        emit SetOperatorStatus(_index, _newStatus);
    }

    /// @notice Changes the operator stopped validator cound
    /// @dev Only callable by the administrator
    /// @param _index The operator index
    /// @param _newStoppedValidatorCount The new stopped validator count of the operator
    function setOperatorStoppedValidatorCount(uint256 _index, uint256 _newStoppedValidatorCount) external onlyAdmin {
        Operators.Operator storage operator = Operators.get(_index);

        if (_newStoppedValidatorCount > operator.funded) {
            revert LibErrors.InvalidArgument();
        }

        operator.stopped = _newStoppedValidatorCount;

        emit SetOperatorStoppedValidatorCount(_index, operator.stopped);
    }

    /// @notice Changes the operator staking limit
    /// @dev Only callable by the administrator
    /// @dev The limit cannot exceed the total key count of the operator
    /// @dev The _indexes and _newLimits must have the same length.
    /// @dev Each limit value is applied to the operator index at the same index in the _indexes array.
    /// @param _operatorIndexes The operator indexes
    /// @param _newLimits The new staking limit of the operators
    function setOperatorLimits(
        uint256[] calldata _operatorIndexes,
        uint256[] calldata _newLimits,
        uint256 _snapshotBlock
    ) external onlyAdmin {
        if (_operatorIndexes.length != _newLimits.length) {
            revert InvalidArrayLengths();
        }
        if (_operatorIndexes.length == 0) {
            revert InvalidEmptyArray();
        }
        for (uint256 idx = 0; idx < _operatorIndexes.length;) {
            Operators.Operator storage operator = Operators.get(_operatorIndexes[idx]);
            if (_newLimits[idx] > operator.keys) {
                revert OperatorLimitTooHigh(_operatorIndexes[idx], _newLimits[idx], operator.keys);
            }

            if (_newLimits[idx] < operator.funded) {
                revert OperatorLimitTooLow(_operatorIndexes[idx], _newLimits[idx], operator.funded);
            }

            if (_snapshotBlock < operator.lastEdit && _newLimits[idx] > operator.funded) {
                emit OperatorEditsAfterSnapshot(
                    _operatorIndexes[idx], _newLimits[idx], operator.lastEdit, _snapshotBlock
                    );
            } else {
                operator.limit = _newLimits[idx];
                emit SetOperatorLimit(_operatorIndexes[idx], operator.limit);
            }

            unchecked {
                ++idx;
            }
        }
    }

    error InvalidKeysLength();

    /// @notice Adds new keys for an operator
    /// @dev Only callable by the administrator or the operator address
    /// @param _index The operator index
    /// @param _keyCount The amount of keys provided
    /// @param _publicKeysAndSignatures Public keys of the validator, concatenated
    function addValidators(uint256 _index, uint256 _keyCount, bytes calldata _publicKeysAndSignatures)
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

        Operators.Operator storage operator = Operators.get(_index);

        for (uint256 idx = 0; idx < _keyCount;) {
            bytes memory publicKeyAndSignature = LibBytes.slice(
                _publicKeysAndSignatures,
                idx * (ValidatorKeys.PUBLIC_KEY_LENGTH + ValidatorKeys.SIGNATURE_LENGTH),
                ValidatorKeys.PUBLIC_KEY_LENGTH + ValidatorKeys.SIGNATURE_LENGTH
            );
            ValidatorKeys.set(_index, operator.keys + idx, publicKeyAndSignature);
            unchecked {
                ++idx;
            }
        }

        operator.keys += _keyCount;
        operator.lastEdit = block.number;

        emit AddedValidatorKeys(_index, _publicKeysAndSignatures);
    }

    /// @notice Remove validator keys
    /// @dev Only callable by the administrator or the operator address
    /// @dev The indexes must be provided sorted in decreasing order, otherwise the method will revert
    /// @dev The operator limit will be set to the lowest deleted key index
    /// @param _index The operator index
    /// @param _indexes The indexes of the keys to remove
    function removeValidators(uint256 _index, uint256[] calldata _indexes) external onlyOperatorOrAdmin(_index) {
        uint256 indexesLength = _indexes.length;
        if (indexesLength == 0) {
            revert InvalidKeyCount();
        }

        Operators.Operator storage operator = Operators.get(_index);

        uint256 totalKeys = operator.keys;

        if (!(_indexes[0] < totalKeys)) {
            revert InvalidIndexOutOfBounds();
        }

        uint256 lastIndex = _indexes[indexesLength - 1];

        if (lastIndex < operator.funded) {
            revert InvalidFundedKeyDeletionAttempt();
        }

        bool limitEqualsKeyCount = operator.keys == operator.limit;
        operator.keys = totalKeys - indexesLength;

        uint256 idx;
        for (; idx < indexesLength;) {
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
        } else if (lastIndex < operator.limit) {
            operator.limit = lastIndex;
        }

        operator.lastEdit = block.number;
    }

    /// @notice Get operator details
    /// @param _index The index of the operator
    function getOperator(uint256 _index) external view returns (Operators.Operator memory) {
        return Operators.get(_index);
    }

    /// @notice Get operator count
    function getOperatorCount() external view returns (uint256) {
        return Operators.getCount();
    }

    /// @notice Get the details of a validator
    /// @param _operatorIndex The index of the operator
    /// @param _validatorIndex The index of the validator
    function getValidator(uint256 _operatorIndex, uint256 _validatorIndex)
        external
        view
        returns (bytes memory publicKey, bytes memory signature, bool funded)
    {
        (publicKey, signature) = ValidatorKeys.get(_operatorIndex, _validatorIndex);
        funded = _validatorIndex < Operators.get(_operatorIndex).funded;
    }

    /// @notice Retrieve validator keys based on operator statuses
    /// @param _count Max amount of keys requested
    function pickNextValidators(uint256 _count)
        external
        onlyRiver
        returns (bytes[] memory publicKeys, bytes[] memory signatures)
    {
        return _pickNextValidatorsFromActiveOperators(_count);
    }

    /// @notice Internal utility to concatenate bytes arrays together
    function _concatenateByteArrays(bytes[] memory arr1, bytes[] memory arr2)
        internal
        pure
        returns (bytes[] memory res)
    {
        res = new bytes[](arr1.length + arr2.length);
        for (uint256 idx = 0; idx < arr1.length;) {
            res[idx] = arr1[idx];
            unchecked {
                ++idx;
            }
        }
        for (uint256 idx = 0; idx < arr2.length;) {
            res[idx + arr1.length] = arr2[idx];
            unchecked {
                ++idx;
            }
        }
    }

    uint256 internal constant MAX_VALIDATOR_ATTRIBUTION_PER_ROUND = 5;

    function _hasFundableKeys(Operators.CachedOperator memory _operator) internal pure returns (bool) {
        return (_operator.funded + _operator.picked) < _operator.limit;
    }

    function _getActiveKeyCount(Operators.CachedOperator memory _operator) internal pure returns (uint256) {
        return (_operator.funded + _operator.picked) - _operator.stopped;
    }

    /// @notice Handler called whenever a deposit to the consensus layer is made. Should retrieve _requestedAmount or lower keys
    /// @param _count Amount of keys required. Contract is expected to send _count or lower.
    function _pickNextValidatorsFromActiveOperators(uint256 _count)
        internal
        returns (bytes[] memory publicKeys, bytes[] memory signatures)
    {
        Operators.CachedOperator[] memory operators = Operators.getAllFundable();

        if (operators.length == 0) {
            return (new bytes[](0), new bytes[](0));
        }

        while (_count > 0) {
            // loop on operators to find the first that has fundable keys, taking into account previous loop round attributions
            uint256 selectedOperatorIndex = 0;
            for (; selectedOperatorIndex < operators.length;) {
                if (_hasFundableKeys(operators[selectedOperatorIndex])) {
                    break;
                }
                unchecked {
                    ++selectedOperatorIndex;
                }
            }

            // if we reach the end, we have allocated all keys
            if (selectedOperatorIndex == operators.length) {
                break;
            }

            // we start from the next operator and we try to find one that has fundable keys but a lower (funded + picked) - stopped value
            for (uint256 idx = selectedOperatorIndex + 1; idx < operators.length;) {
                if (
                    _getActiveKeyCount(operators[idx]) < _getActiveKeyCount(operators[selectedOperatorIndex])
                        && _hasFundableKeys(operators[idx])
                ) {
                    selectedOperatorIndex = idx;
                }
                unchecked {
                    ++idx;
                }
            }

            // we take the smallest value between limit - (funded + picked), _requestedAmount and MAX_VALIDATOR_ATTRIBUTION_PER_ROUND
            uint256 pickedKeyCount = LibUint256.min(
                LibUint256.min(
                    operators[selectedOperatorIndex].limit
                        - (operators[selectedOperatorIndex].funded + operators[selectedOperatorIndex].picked),
                    MAX_VALIDATOR_ATTRIBUTION_PER_ROUND
                ),
                _count
            );

            // we update the cached picked amount
            operators[selectedOperatorIndex].picked += pickedKeyCount;

            // we update the requested amount count
            _count -= pickedKeyCount;
        }

        // we loop on all operators
        for (uint256 idx = 0; idx < operators.length; ++idx) {
            // if we picked keys on any operator, we extract the keys from storage and concatenate them in the result
            // we then update the funded value
            if (operators[idx].picked > 0) {
                (bytes[] memory _publicKeys, bytes[] memory _signatures) =
                    ValidatorKeys.getKeys(operators[idx].index, operators[idx].funded, operators[idx].picked);
                publicKeys = _concatenateByteArrays(publicKeys, _publicKeys);
                signatures = _concatenateByteArrays(signatures, _signatures);
                (Operators.get(operators[idx].index)).funded += operators[idx].picked;
            }
        }
    }
}
