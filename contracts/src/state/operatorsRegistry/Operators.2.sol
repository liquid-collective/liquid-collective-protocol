//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "../../libraries/LibSanitize.sol";

/// @title Operators Storage
/// @notice Utility to manage the Operators in storage
library OperatorsV2 {
    /// @notice Storage slot of the Operators
    bytes32 internal constant OPERATORS_SLOT = bytes32(uint256(keccak256("river.state.v2.operators")) - 1);

    /// @notice The Operator structure in storage
    struct Operator {
        /// @dev The following values respect this invariant:
        /// @dev     keys >= limit >= funded >= RequestedExits

        /// @custom:attribute Staking limit of the operator
        uint32 limit;
        /// @custom:attribute The count of funded validators
        uint32 funded;
        /// @custom:attribute The count of exit requests made to this operator
        uint32 requestedExits;
        /// @custom:attribute The total count of keys of the operator
        uint32 keys;
        /// @custom attribute The block at which the last edit happened in the operator details
        uint64 latestKeysEditBlockNumber;
        /// @custom:attribute True if the operator is active and allowed to operate on River
        bool active;
        /// @custom:attribute Display name of the operator
        string name;
        /// @custom:attribute Address of the operator
        address operator;
    }

    /// @notice The Operator structure when loaded in memory
    struct CachedOperator {
        /// @custom:attribute Staking limit of the operator
        uint32 limit;
        /// @custom:attribute The count of funded validators
        uint32 funded;
        /// @custom:attribute The count of exit requests made to this operator
        uint32 requestedExits;
        /// @custom:attribute The original index of the operator
        uint32 index;
        /// @custom:attribute The amount of picked keys, buffer used before changing funded in storage
        uint32 picked;
    }

    /// @notice The structure at the storage slot
    struct SlotOperator {
        /// @custom:attribute Array containing all the operators
        Operator[] value;
    }

    /// @notice The operator was not found
    /// @param index The provided index
    error OperatorNotFound(uint256 index);

    /// @notice Retrieve the operator in storage
    /// @param _index The index of the operator
    /// @return The Operator structure
    function get(uint256 _index) internal view returns (Operator storage) {
        bytes32 slot = OPERATORS_SLOT;

        SlotOperator storage r;

        // solhint-disable-next-line no-inline-assembly
        assembly {
            r.slot := slot
        }

        if (r.value.length <= _index) {
            revert OperatorNotFound(_index);
        }

        return r.value[_index];
    }

    /// @notice Retrieve the operator count in storage
    /// @return The count of operators in storage
    function getCount() internal view returns (uint256) {
        bytes32 slot = OPERATORS_SLOT;

        SlotOperator storage r;

        // solhint-disable-next-line no-inline-assembly
        assembly {
            r.slot := slot
        }

        return r.value.length;
    }

    /// @notice Retrieve all the active operators
    /// @return The list of active operator structures
    function getAllActive() internal view returns (Operator[] memory) {
        bytes32 slot = OPERATORS_SLOT;

        SlotOperator storage r;

        // solhint-disable-next-line no-inline-assembly
        assembly {
            r.slot := slot
        }

        uint256 activeCount = 0;
        uint256 operatorCount = r.value.length;

        for (uint256 idx = 0; idx < operatorCount;) {
            if (r.value[idx].active) {
                unchecked {
                    ++activeCount;
                }
            }
            unchecked {
                ++idx;
            }
        }

        Operator[] memory activeOperators = new Operator[](activeCount);

        uint256 activeIdx = 0;
        for (uint256 idx = 0; idx < operatorCount;) {
            if (r.value[idx].active) {
                activeOperators[activeIdx] = r.value[idx];
                unchecked {
                    ++activeIdx;
                }
            }
            unchecked {
                ++idx;
            }
        }

        return activeOperators;
    }

    /// @notice Retrieve the stopped validator count for an operator by its index
    /// @param stoppedValidatorCounts The storage pointer to the raw array containing the stopped validator counts
    /// @param index The index of the operator to lookup
    /// @return The amount of stopped validators for the given operator index
    function _getStoppedValidatorCountAtIndex(uint32[] storage stoppedValidatorCounts, uint256 index)
        internal
        view
        returns (uint32)
    {
        if (index + 1 >= stoppedValidatorCounts.length) {
            return 0;
        }
        return stoppedValidatorCounts[index + 1];
    }

    /// @notice Retrieve all the active and fundable operators
    /// @return The list of active and fundable operators
    function getAllFundable(uint32[] storage stoppedValidatorCounts) internal view returns (CachedOperator[] memory) {
        bytes32 slot = OPERATORS_SLOT;

        SlotOperator storage r;

        // solhint-disable-next-line no-inline-assembly
        assembly {
            r.slot := slot
        }

        uint256 activeCount = 0;
        uint256 operatorCount = r.value.length;

        for (uint256 idx = 0; idx < operatorCount;) {
            if (
                _hasFundableKeys(r.value[idx])
                    && _getStoppedValidatorCountAtIndex(stoppedValidatorCounts, idx) >= r.value[idx].requestedExits
            ) {
                unchecked {
                    ++activeCount;
                }
            }
            unchecked {
                ++idx;
            }
        }

        CachedOperator[] memory activeOperators = new CachedOperator[](activeCount);

        uint256 activeIdx = 0;
        for (uint256 idx = 0; idx < operatorCount;) {
            Operator storage op = r.value[idx];
            if (
                _hasFundableKeys(op)
                    && _getStoppedValidatorCountAtIndex(stoppedValidatorCounts, idx) >= op.requestedExits
            ) {
                activeOperators[activeIdx] = CachedOperator({
                    limit: op.limit,
                    funded: op.funded,
                    requestedExits: op.requestedExits,
                    index: uint32(idx),
                    picked: 0
                });
                unchecked {
                    ++activeIdx;
                }
            }
            unchecked {
                ++idx;
            }
        }

        return activeOperators;
    }

    /// @notice Retrieve all the active and fundable operators
    /// @return The list of active and fundable operators
    function getAllExitable() internal view returns (CachedOperator[] memory) {
        bytes32 slot = OPERATORS_SLOT;

        SlotOperator storage r;

        // solhint-disable-next-line no-inline-assembly
        assembly {
            r.slot := slot
        }

        uint256 activeCount = 0;
        uint256 operatorCount = r.value.length;

        for (uint256 idx = 0; idx < operatorCount;) {
            if (_hasExitableKeys(r.value[idx])) {
                unchecked {
                    ++activeCount;
                }
            }
            unchecked {
                ++idx;
            }
        }

        CachedOperator[] memory activeOperators = new CachedOperator[](activeCount);

        uint256 activeIdx = 0;
        for (uint256 idx = 0; idx < operatorCount;) {
            Operator memory op = r.value[idx];
            if (_hasExitableKeys(op)) {
                activeOperators[activeIdx] = CachedOperator({
                    limit: op.limit,
                    funded: op.funded,
                    requestedExits: op.requestedExits,
                    index: uint32(idx),
                    picked: 0
                });
                unchecked {
                    ++activeIdx;
                }
            }
            unchecked {
                ++idx;
            }
        }

        return activeOperators;
    }

    /// @notice Add a new operator in storage
    /// @param _newOperator Value of the new operator
    /// @return The size of the operator array after the operation
    function push(Operator memory _newOperator) internal returns (uint256) {
        LibSanitize._notZeroAddress(_newOperator.operator);
        LibSanitize._notEmptyString(_newOperator.name);
        bytes32 slot = OPERATORS_SLOT;

        SlotOperator storage r;

        // solhint-disable-next-line no-inline-assembly
        assembly {
            r.slot := slot
        }

        r.value.push(_newOperator);

        return r.value.length;
    }

    /// @notice Atomic operation to set the key count and update the latestKeysEditBlockNumber field at the same time
    /// @param _index The operator index
    /// @param _newKeys The new value for the key count
    function setKeys(uint256 _index, uint32 _newKeys) internal {
        Operator storage op = get(_index);

        op.keys = _newKeys;
        op.latestKeysEditBlockNumber = uint64(block.number);
    }

    /// @notice Checks if an operator is active and has fundable keys
    /// @param _operator The operator details
    /// @return True if active and fundable
    function _hasFundableKeys(OperatorsV2.Operator memory _operator) internal pure returns (bool) {
        return (_operator.active && _operator.limit > _operator.funded);
    }

    /// @notice Checks if an operator is active and has exitable keys
    /// @param _operator The operator details
    /// @return True if active and exitable
    function _hasExitableKeys(OperatorsV2.Operator memory _operator) internal pure returns (bool) {
        return (_operator.active && _operator.funded > _operator.requestedExits);
    }
}
