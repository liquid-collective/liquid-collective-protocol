//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "../libraries/Errors.sol";
import "../libraries/Uint256Lib.sol";
import "../libraries/LibOwnable.sol";

import "../state/river/Operators.sol";
import "../state/river/ValidatorKeys.sol";

/// @title Operators Manager (v1)
/// @author SkillZ
/// @notice This contract handles the operator and key list
contract OperatorsManagerV1 {
    error OperatorAlreadyExists(string name);
    error InactiveOperator(string name);
    error InvalidFundedKeyDeletionAttempt();
    error InvalidUnsortedIndexes();
    error InvalidKeyCount();
    error InvalidPublicKeysLength();
    error InvalidSignatureLength();
    error InvalidIndexOutOfBounds();

    event AddedOperator(string indexed name, address operatorAddress);
    event SetOperatorStatus(string indexed name, bool active);
    event SetOperatorLimit(string indexed name, uint256 newLimit);
    event SetOperatorStoppedValidatorCount(string indexed name, uint256 newStoppedValidatorCount);
    event SetOperatorAddress(string indexed name, address newOperatorAddress);
    event AddedValidatorKeys(string indexed name, uint256 totalKeyCount);
    event RemovedValidatorKeys(string indexed name, uint256 keyCount);

    /// @notice Prevents unauthorized calls
    modifier onlyAdmin() virtual {
        if (msg.sender != LibOwnable._getAdmin()) {
            revert Errors.Unauthorized(msg.sender);
        }
        _;
    }

    /// @notice Prevents the call from working if the operator is not active
    /// @param _name The name identifying the operator
    modifier active(string memory _name) {
        if (Operators.get(_name).active == false) {
            revert InactiveOperator(_name);
        }
        _;
    }

    /// @notice Prevents anyone except the admin or the given operator to make the call. Also checks if operator is active
    /// @param _name The name identifying the operator
    modifier operatorOrAdmin(string calldata _name) {
        Operators.Operator storage operator = Operators.get(_name);
        if (operator.active == false) {
            revert InactiveOperator(_name);
        }
        if (msg.sender != operator.operator && msg.sender != LibOwnable._getAdmin()) {
            revert Errors.Unauthorized(msg.sender);
        }
        _;
    }

    /// @notice Adds an operator to the registry
    /// @dev Only callable by the administrator
    /// @param _name The name identifying the operator
    /// @param _operator The address representing the operator, receiving the rewards
    function addOperator(string calldata _name, address _operator) external onlyAdmin {
        if (Operators.exists(_name) == true) {
            revert OperatorAlreadyExists(_name);
        }

        Operators.Operator memory newOperator = Operators.Operator({
            active: true,
            operator: _operator,
            name: _name,
            limit: 0,
            funded: 0,
            keys: 0,
            stopped: 0
        });

        Operators.set(_name, newOperator);

        emit AddedOperator(_name, newOperator.operator);
    }

    /// @notice Changes the operator address of an operator
    /// @dev Only callable by the administrator or the previous operator address
    /// @param _name The name identifying the operator
    /// @param _newOperatorAddress The new address representing the operator
    function setOperatorAddress(string calldata _name, address _newOperatorAddress) external operatorOrAdmin(_name) {
        Operators.Operator storage operator = Operators.get(_name);

        operator.operator = _newOperatorAddress;

        emit SetOperatorAddress(_name, operator.operator);
    }

    /// @notice Changes the operator status
    /// @dev Only callable by the administrator
    /// @param _name The name identifying the operator
    /// @param _newStatus The new status of the operator
    function setOperatorStatus(string calldata _name, bool _newStatus) external onlyAdmin {
        Operators.Operator storage operator = Operators.get(_name);

        operator.active = _newStatus;

        emit SetOperatorStatus(_name, _newStatus);
    }

    /// @notice Changes the operator stopped validator cound
    /// @dev Only callable by the administrator
    /// @param _name The name identifying the operator
    /// @param _newStoppedValidatorCount The new stopped validator count of the operator
    function setOperatorStoppedValidatorCount(string calldata _name, uint256 _newStoppedValidatorCount)
        external
        onlyAdmin
    {
        Operators.Operator storage operator = Operators.get(_name);

        operator.stopped = _newStoppedValidatorCount;

        emit SetOperatorStoppedValidatorCount(_name, operator.stopped);
    }

    /// @notice Changes the operator staking limit
    /// @dev Only callable by the administrator
    /// @param _name The name identifying the operator
    /// @param _newLimit The new staking limit of the operator
    function setOperatorLimit(string calldata _name, uint256 _newLimit) external onlyAdmin {
        Operators.Operator storage operator = Operators.get(_name);

        operator.limit = _newLimit;

        emit SetOperatorLimit(_name, operator.limit);
    }

    /// @notice Adds new keys for an operator
    /// @dev Only callable by the administrator or the operator address
    /// @param _name The name identifying the operator
    /// @param _keyCount The amount of keys provided
    /// @param _publicKeys Public keys of the validator, concatenated
    /// @param _signatures Signatures of the validator keys, concatenated
    function addValidators(
        string calldata _name,
        uint256 _keyCount,
        bytes calldata _publicKeys,
        bytes calldata _signatures
    ) external operatorOrAdmin(_name) {
        if (_keyCount == 0) {
            revert InvalidKeyCount();
        }

        if (_publicKeys.length != _keyCount * ValidatorKeys.PUBLIC_KEY_LENGTH) {
            revert InvalidPublicKeysLength();
        }

        if (_signatures.length != _keyCount * ValidatorKeys.SIGNATURE_LENGTH) {
            revert InvalidSignatureLength();
        }

        Operators.Operator storage operator = Operators.get(_name);

        for (uint256 idx = 0; idx < _keyCount; ++idx) {
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
            ValidatorKeys.set(operator.name, operator.keys + idx, publicKey, signature);
        }

        operator.keys += _keyCount;

        emit AddedValidatorKeys(_name, operator.keys);
    }

    /// @notice Remove validator keys
    /// @dev Only callable by the administrator or the operator address
    /// @dev The indexes must be provided sorted in decreasing order, otherwise the method will revert
    /// @param _name The name identifying the operator
    /// @param _indexes The indexes of the keys to remove
    function removeValidators(string calldata _name, uint256[] calldata _indexes) external operatorOrAdmin(_name) {
        Operators.Operator storage operator = Operators.get(_name);

        if (_indexes.length == 0) {
            revert InvalidKeyCount();
        }

        for (uint256 idx = 0; idx < _indexes.length; ++idx) {
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
            (bytes memory lastPublicKey, bytes memory lastSignature) = ValidatorKeys.get(_name, lastKeyIndex);
            ValidatorKeys.set(_name, keyIndex, lastPublicKey, lastSignature);
            ValidatorKeys.set(_name, lastKeyIndex, new bytes(0), new bytes(0));
            operator.keys -= 1;
        }

        emit RemovedValidatorKeys(_name, operator.keys);
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

    /// @notice Get the key of an operator at a specific index
    /// @param _operatorName The name identifying the operator
    /// @param _index The key index
    function getKey(string calldata _operatorName, uint256 _index)
        external
        view
        returns (
            bytes memory publicKey,
            bytes memory signature,
            bool funded
        )
    {
        (publicKey, signature) = ValidatorKeys.get(_operatorName, _index);
        funded = _index <= Operators.get(_operatorName).funded;
    }

    /// @notice Internal utility to concatenate bytes arrays together
    function _concatenateByteArrays(bytes[] memory arr1, bytes[] memory arr2)
        internal
        pure
        returns (bytes[] memory res)
    {
        res = new bytes[](arr1.length + arr2.length);
        for (uint256 idx = 0; idx < arr1.length; ++idx) {
            res[idx] = arr1[idx];
        }
        for (uint256 idx = 0; idx < arr2.length; ++idx) {
            res[idx + arr1.length] = arr2[idx];
        }
    }

    /// @notice Handler called whenever a deposit to the consensus layer is made. Should retrieve _requestedAmount or lower keys
    /// @param _requestedAmount Amount of keys required. Contract is expected to send _requestedAmount or lower.
    function _getNextValidatorsFromActiveOperators(uint256 _requestedAmount)
        internal
        returns (bytes[] memory publicKeys, bytes[] memory signatures)
    {
        Operators.Operator[] memory operators = Operators.getAllFundable();

        if (operators.length == 0) {
            return (new bytes[](0), new bytes[](0));
        }

        uint256 selectedOperatorIndex = 0;
        for (uint256 idx = 1; idx < operators.length; ++idx) {
            if (operators[idx].funded < operators[selectedOperatorIndex].funded) {
                selectedOperatorIndex = idx;
            }
        }

        uint256 availableOperatorKeys = Uint256Lib.min(
            operators[selectedOperatorIndex].keys,
            operators[selectedOperatorIndex].limit
        ) - operators[selectedOperatorIndex].funded;

        Operators.Operator storage operator = Operators.get(operators[selectedOperatorIndex].name);
        if (availableOperatorKeys >= _requestedAmount) {
            (publicKeys, signatures) = ValidatorKeys.getKeys(
                operators[selectedOperatorIndex].name,
                operators[selectedOperatorIndex].funded,
                _requestedAmount
            );
            operator.funded += _requestedAmount;
        } else {
            (publicKeys, signatures) = ValidatorKeys.getKeys(
                operators[selectedOperatorIndex].name,
                operators[selectedOperatorIndex].funded,
                availableOperatorKeys
            );
            operator.funded += availableOperatorKeys;
            (
                bytes[] memory additionalPublicKeys,
                bytes[] memory additionalSignatures
            ) = _getNextValidatorsFromActiveOperators(_requestedAmount - availableOperatorKeys);
            publicKeys = _concatenateByteArrays(publicKeys, additionalPublicKeys);
            signatures = _concatenateByteArrays(signatures, additionalSignatures);
        }
    }
}
