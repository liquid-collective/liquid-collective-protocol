//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "../libraries/Errors.sol";
import "../libraries/Uint256Lib.sol";
import "../libraries/LibOwnable.sol";

import "../state/river/Operators.sol";
import "../state/river/ValidatorKeys.sol";

/// @title Operators Manager (v1)
/// @author Kiln
/// @notice This contract handles the operator and key list
contract OperatorsManagerV1 {
    error OperatorAlreadyExists(string name);
    error InactiveOperator(uint256 index);
    error InvalidFundedKeyDeletionAttempt();
    error InvalidUnsortedIndexes();
    error InvalidArrayLengths();
    error InvalidEmptyArray();
    error InvalidKeyCount();
    error InvalidPublicKeysLength();
    error InvalidSignatureLength();
    error InvalidIndexOutOfBounds();
    error OperatorLimitTooHigh(uint256 limit, uint256 keyCount);

    event AddedOperator(uint256 indexed index, string name, address operatorAddress, address feeRecipientAddress);
    event SetOperatorStatus(uint256 indexed index, bool active);
    event SetOperatorLimit(uint256 indexed index, uint256 newLimit);
    event SetOperatorStoppedValidatorCount(uint256 indexed index, uint256 newStoppedValidatorCount);
    event SetOperatorFeeRecipientAddress(uint256 indexed index, address newOperatorAddress);
    event SetOperatorAddress(uint256 indexed index, address newOperatorAddress);
    event AddedValidatorKeys(uint256 indexed index, bytes publicKeys);
    event RemovedValidatorKey(uint256 indexed index, bytes publicKey);

    /// @notice Prevents unauthorized calls
    modifier onlyAdmin() virtual {
        if (msg.sender != LibOwnable._getAdmin()) {
            revert Errors.Unauthorized(msg.sender);
        }
        _;
    }

    /// @notice Prevents the call from working if the operator is not active
    /// @param _index The name identifying the operator
    modifier active(uint256 _index) {
        if (Operators.getByIndex(_index).active == false) {
            revert InactiveOperator(_index);
        }
        _;
    }

    /// @notice Prevents anyone except the admin or the given operator fee recipient to make the call. Also checks if operator is active
    /// @param _index The name identifying the operator
    modifier operatorFeeRecipientOrAdmin(uint256 _index) {
        if (msg.sender == LibOwnable._getAdmin()) {
            _;
            return;
        }
        Operators.Operator storage operator = Operators.getByIndex(_index);
        if (operator.active == false) {
            revert InactiveOperator(_index);
        }
        if (msg.sender != operator.feeRecipient) {
            revert Errors.Unauthorized(msg.sender);
        }
        _;
    }

    /// @notice Prevents anyone except the admin or the given operator to make the call. Also checks if operator is active
    /// @param _index The name identifying the operator
    modifier operatorOrAdmin(uint256 _index) {
        if (msg.sender == LibOwnable._getAdmin()) {
            _;
            return;
        }
        Operators.Operator storage operator = Operators.getByIndex(_index);
        if (operator.active == false) {
            revert InactiveOperator(_index);
        }
        if (msg.sender != operator.operator) {
            revert Errors.Unauthorized(msg.sender);
        }
        _;
    }

    /// @notice Retrieve the operator details from the operator name
    /// @param _name Name of the operator
    function getOperatorDetails(string calldata _name) external view returns (int256 _index, address _operatorAddress) {
        _index = Operators.indexOf(_name);
        _operatorAddress = Operators.get(_name).operator;
    }

    /// @notice Adds an operator to the registry
    /// @dev Only callable by the administrator
    /// @param _name The name identifying the operator
    /// @param _operator The address representing the operator, receiving the rewards
    /// @param _feeRecipient The address where the rewards are sent
    function addOperator(
        string calldata _name,
        address _operator,
        address _feeRecipient
    ) external onlyAdmin {
        if (Operators.exists(_name) == true) {
            revert OperatorAlreadyExists(_name);
        }

        Operators.Operator memory newOperator = Operators.Operator({
            active: true,
            operator: _operator,
            feeRecipient: _feeRecipient,
            name: _name,
            limit: 0,
            funded: 0,
            keys: 0,
            stopped: 0
        });

        uint256 operatorIndex = Operators.set(_name, newOperator);

        emit AddedOperator(operatorIndex, newOperator.name, newOperator.operator, newOperator.feeRecipient);
    }

    /// @notice Changes the operator address of an operator
    /// @dev Only callable by the administrator or the previous operator address
    /// @param _index The operator index
    /// @param _newOperatorAddress The new address of the operator
    function setOperatorAddress(uint256 _index, address _newOperatorAddress) external operatorOrAdmin(_index) {
        Operators.Operator storage operator = Operators.getByIndex(_index);

        operator.operator = _newOperatorAddress;

        emit SetOperatorAddress(_index, _newOperatorAddress);
    }

    /// @notice Changes the operator fee recipient address
    /// @dev Only callable by the administrator or the previous operator fee recipient address
    /// @param _index The operator index
    /// @param _newOperatorFeeRecipientAddress The new fee recipient address of the operator
    function setOperatorFeeRecipientAddress(uint256 _index, address _newOperatorFeeRecipientAddress)
        external
        operatorFeeRecipientOrAdmin(_index)
    {
        Operators.Operator storage operator = Operators.getByIndex(_index);

        operator.feeRecipient = _newOperatorFeeRecipientAddress;

        emit SetOperatorFeeRecipientAddress(_index, _newOperatorFeeRecipientAddress);
    }

    /// @notice Changes the operator status
    /// @dev Only callable by the administrator
    /// @param _index The operator index
    /// @param _newStatus The new status of the operator
    function setOperatorStatus(uint256 _index, bool _newStatus) external onlyAdmin {
        Operators.Operator storage operator = Operators.getByIndex(_index);

        operator.active = _newStatus;

        emit SetOperatorStatus(_index, _newStatus);
    }

    /// @notice Changes the operator stopped validator cound
    /// @dev Only callable by the administrator
    /// @param _index The operator index
    /// @param _newStoppedValidatorCount The new stopped validator count of the operator
    function setOperatorStoppedValidatorCount(uint256 _index, uint256 _newStoppedValidatorCount) external onlyAdmin {
        Operators.Operator storage operator = Operators.getByIndex(_index);

        if (_newStoppedValidatorCount > operator.funded) {
            revert Errors.InvalidArgument();
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
    function setOperatorLimits(uint256[] calldata _operatorIndexes, uint256[] calldata _newLimits) external onlyAdmin {
        if (_operatorIndexes.length != _newLimits.length) {
            revert InvalidArrayLengths();
        }
        if (_operatorIndexes.length == 0) {
            revert InvalidEmptyArray();
        }
        for (uint256 idx = 0; idx < _operatorIndexes.length; ) {
            Operators.Operator storage operator = Operators.getByIndex(_operatorIndexes[idx]);
            if (_newLimits[idx] > operator.keys) {
                revert OperatorLimitTooHigh(_newLimits[idx], operator.keys);
            }

            operator.limit = _newLimits[idx];

            emit SetOperatorLimit(_operatorIndexes[idx], operator.limit);

            unchecked {
                ++idx;
            }
        }
    }

    /// @notice Adds new keys for an operator
    /// @dev Only callable by the administrator or the operator address
    /// @param _index The operator index
    /// @param _keyCount The amount of keys provided
    /// @param _publicKeys Public keys of the validator, concatenated
    /// @param _signatures Signatures of the validator keys, concatenated
    function addValidators(
        uint256 _index,
        uint256 _keyCount,
        bytes calldata _publicKeys,
        bytes calldata _signatures
    ) external operatorOrAdmin(_index) {
        if (_keyCount == 0) {
            revert InvalidKeyCount();
        }

        if (_publicKeys.length != _keyCount * ValidatorKeys.PUBLIC_KEY_LENGTH) {
            revert InvalidPublicKeysLength();
        }

        if (_signatures.length != _keyCount * ValidatorKeys.SIGNATURE_LENGTH) {
            revert InvalidSignatureLength();
        }

        Operators.Operator storage operator = Operators.getByIndex(_index);

        for (uint256 idx = 0; idx < _keyCount; ) {
            bytes memory publicKey = BytesLib.slice(
                _publicKeys,
                idx * ValidatorKeys.PUBLIC_KEY_LENGTH,
                ValidatorKeys.PUBLIC_KEY_LENGTH
            );
            bytes memory signature = BytesLib.slice(
                _signatures,
                idx * ValidatorKeys.SIGNATURE_LENGTH,
                ValidatorKeys.SIGNATURE_LENGTH
            );
            ValidatorKeys.set(_index, operator.keys + idx, publicKey, signature);
            unchecked {
                ++idx;
            }
        }

        operator.keys += _keyCount;

        emit AddedValidatorKeys(_index, _publicKeys);
    }

    /// @notice Remove validator keys
    /// @dev Only callable by the administrator or the operator address
    /// @dev The indexes must be provided sorted in decreasing order, otherwise the method will revert
    /// @dev The operator limit will be set to the lowest deleted key index
    /// @param _index The operator index
    /// @param _indexes The indexes of the keys to remove
    function removeValidators(uint256 _index, uint256[] calldata _indexes) external operatorOrAdmin(_index) {
        Operators.Operator storage operator = Operators.getByIndex(_index);

        if (_indexes.length == 0) {
            revert InvalidKeyCount();
        }

        for (uint256 idx = 0; idx < _indexes.length; ) {
            uint256 keyIndex = _indexes[idx];

            if (keyIndex < operator.funded) {
                revert InvalidFundedKeyDeletionAttempt();
            }

            if (keyIndex >= operator.keys) {
                revert InvalidIndexOutOfBounds();
            }

            if (idx > 0 && _indexes[idx] >= _indexes[idx - 1]) {
                revert InvalidUnsortedIndexes();
            }

            uint256 lastKeyIndex = operator.keys - 1;
            (bytes memory removedPublicKey, ) = ValidatorKeys.get(_index, keyIndex);
            (bytes memory lastPublicKey, bytes memory lastSignature) = ValidatorKeys.get(_index, lastKeyIndex);
            ValidatorKeys.set(_index, keyIndex, lastPublicKey, lastSignature);
            ValidatorKeys.set(_index, lastKeyIndex, new bytes(0), new bytes(0));
            operator.keys -= 1;
            emit RemovedValidatorKey(_index, removedPublicKey);
            unchecked {
                ++idx;
            }
        }

        if (_indexes[_indexes.length - 1] < operator.limit) {
            operator.limit = _indexes[_indexes.length - 1];
        }
    }

    /// @notice Get operator details by name
    /// @param _name The name identifying the operator
    function getOperatorByName(string calldata _name) external view returns (Operators.Operator memory) {
        return Operators.get(_name);
    }

    /// @notice Get operator details
    /// @param _index The index of the operator
    function getOperator(uint256 _index) external view returns (Operators.Operator memory) {
        return Operators.getByIndex(_index);
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
        returns (
            bytes memory publicKey,
            bytes memory signature,
            bool funded
        )
    {
        (publicKey, signature) = ValidatorKeys.get(_operatorIndex, _validatorIndex);
        funded = _validatorIndex < Operators.getByIndex(_operatorIndex).funded;
    }

    /// @notice Internal utility to concatenate bytes arrays together
    function _concatenateByteArrays(bytes[] memory arr1, bytes[] memory arr2)
        internal
        pure
        returns (bytes[] memory res)
    {
        res = new bytes[](arr1.length + arr2.length);
        for (uint256 idx = 0; idx < arr1.length; ) {
            res[idx] = arr1[idx];
            unchecked {
                ++idx;
            }
        }
        for (uint256 idx = 0; idx < arr2.length; ) {
            res[idx + arr1.length] = arr2[idx];
            unchecked {
                ++idx;
            }
        }
    }

    /// @notice Handler called whenever a deposit to the consensus layer is made. Should retrieve _requestedAmount or lower keys
    /// @param _requestedAmount Amount of keys required. Contract is expected to send _requestedAmount or lower.
    function _getNextValidatorsFromActiveOperators(uint256 _requestedAmount)
        internal
        returns (bytes[] memory publicKeys, bytes[] memory signatures)
    {
        Operators.CachedOperator[] memory operators = Operators.getAllFundable();

        if (operators.length == 0) {
            return (new bytes[](0), new bytes[](0));
        }

        uint256 selectedOperatorIndex = 0;
        for (uint256 idx = 1; idx < operators.length; ) {
            if (
                operators[idx].funded - operators[idx].stopped <
                operators[selectedOperatorIndex].funded - operators[selectedOperatorIndex].stopped
            ) {
                selectedOperatorIndex = idx;
            }
            unchecked {
                ++idx;
            }
        }

        uint256 selectedOperatorAvailableKeys = Uint256Lib.min(
            operators[selectedOperatorIndex].keys,
            operators[selectedOperatorIndex].limit
        ) - operators[selectedOperatorIndex].funded;

        if (selectedOperatorAvailableKeys == 0) {
            return (new bytes[](0), new bytes[](0));
        }

        Operators.Operator storage operator = Operators.get(operators[selectedOperatorIndex].name);
        if (selectedOperatorAvailableKeys >= _requestedAmount) {
            (publicKeys, signatures) = ValidatorKeys.getKeys(
                operators[selectedOperatorIndex].index,
                operators[selectedOperatorIndex].funded,
                _requestedAmount
            );
            operator.funded += _requestedAmount;
        } else {
            (publicKeys, signatures) = ValidatorKeys.getKeys(
                operators[selectedOperatorIndex].index,
                operators[selectedOperatorIndex].funded,
                selectedOperatorAvailableKeys
            );
            operator.funded += selectedOperatorAvailableKeys;
            (
                bytes[] memory additionalPublicKeys,
                bytes[] memory additionalSignatures
            ) = _getNextValidatorsFromActiveOperators(_requestedAmount - selectedOperatorAvailableKeys);
            publicKeys = _concatenateByteArrays(publicKeys, additionalPublicKeys);
            signatures = _concatenateByteArrays(signatures, additionalSignatures);
        }
    }
}
