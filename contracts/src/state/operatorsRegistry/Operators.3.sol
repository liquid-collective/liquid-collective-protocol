//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../../libraries/LibSanitize.sol";

/// @title Operators Storage (v3)
/// @notice Utility to manage the Operators in storage
/// @dev V3 removes the key-management fields (limit, keys, latestKeysEditBlockNumber) that are no longer
/// @dev needed after migrating to off-chain key submission at deposit time. V3 uses ETH-based accounting.
library OperatorsV3 {
    /// @notice Storage slot of the Operators
    bytes32 internal constant OPERATORS_SLOT = bytes32(uint256(keccak256("river.state.v3.operators")) - 1);

    /// @notice The Operator structure in storage
    struct Operator {
        /// @custom:attribute The cumulative amount of funded ETH(wei)
        uint256 funded;
        /// @custom:attribute The cumulative amount of requested ETH(wei) exits
        uint256 requestedExits;
        /// @custom:attribute The amount of ETH(wei) that is active on the consensus layer
        uint256 activeCLETH;
        /// @custom:attribute True if the operator is active and allowed to operate on River
        bool active;
        /// @custom:attribute Display name of the operator
        string name;
        /// @custom:attribute Address of the operator
        address operator;
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

    /// @notice Retrieve the operators in storage
    /// @return The Operator structure array
    function getAll() internal view returns (Operator[] storage) {
        bytes32 slot = OPERATORS_SLOT;

        SlotOperator storage r;

        // solhint-disable-next-line no-inline-assembly
        assembly {
            r.slot := slot
        }

        return r.value;
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
        Operator[] memory activeOperators = new Operator[](operatorCount);

        for (uint256 idx = 0; idx < operatorCount; ++idx) {
            if (r.value[idx].active) {
                activeOperators[activeCount] = r.value[idx];
                unchecked {
                    ++activeCount;
                }
            }
        }
        assembly ("memory-safe") {
            mstore(activeOperators, activeCount)
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

    /// @notice Storage slot of the Exited ETH
    bytes32 internal constant EXITED_ETH_SLOT = bytes32(uint256(keccak256("river.state.exitedETH")) - 1);

    // This slot is used to store the exited ETH for each operator
    // the array is encoded as [sum, op0, op1, ...]
    // the sum is the total exited ETH for all operators
    // the op0 is the exited ETH for operator 0
    // the op1 is the exited ETH for operator 1
    // and so on
    struct SlotExitedETH {
        uint256[] value;
    }

    /// @notice Retrieve the storage pointer of the Exited ETH array
    /// @return The Exited ETH storage pointer
    function getExitedETH() internal view returns (uint256[] storage) {
        bytes32 slot = EXITED_ETH_SLOT;

        SlotExitedETH storage r;

        // solhint-disable-next-line no-inline-assembly
        assembly {
            r.slot := slot
        }

        return r.value;
    }

    /// @notice Retrieve the exited ETH for an operator by its index
    /// @param index The index of the operator to lookup
    /// @return The exited ETH for the given operator index
    function getExitedETH(uint256 index) internal view returns (uint256) {
        return _getExitedETH(getExitedETH(), index);
    }

    /// @notice Retrieve the exited ETH for an operator by its index
    /// @param exitedETH The storage pointer to the raw array containing the exited ETH
    /// @param index The index of the operator to lookup
    /// @return The exited ETH for the given operator index
    function _getExitedETH(uint256[] storage exitedETH, uint256 index) internal view returns (uint256) {
        if (index + 1 >= exitedETH.length) {
            return 0;
        }
        return exitedETH[index + 1];
    }

    /// @notice Sets the entire exited ETH array
    /// @param value The new exited ETH array
    function setRawExitedETH(uint256[] memory value) internal {
        bytes32 slot = EXITED_ETH_SLOT;

        SlotExitedETH storage r;

        // solhint-disable-next-line no-inline-assembly
        assembly {
            r.slot := slot
        }

        r.value = value;
    }

    /// @notice Storage slot of the Released ETH
    bytes32 internal constant RELEASED_ETH_SLOT = bytes32(uint256(keccak256("river.state.releasedETH")) - 1);

    // This slot stores the cumulative amount of exit reservations that have been released per operator,
    // encoded exactly like `exitedETH`: [sum, op0, op1, ...] where the first cell is the total across
    // all operators. Keeping the layout identical lets a future oracle-reported release path compare a
    // cumulative report array element-for-element against this one with no reshaping.
    struct SlotReleasedETH {
        uint256[] value;
    }

    /// @notice Retrieve the storage pointer of the Released ETH array
    /// @return The Released ETH storage pointer
    function getReleasedETH() internal view returns (uint256[] storage) {
        bytes32 slot = RELEASED_ETH_SLOT;

        SlotReleasedETH storage r;

        // solhint-disable-next-line no-inline-assembly
        assembly {
            r.slot := slot
        }

        return r.value;
    }

    /// @notice Retrieve the cumulative released ETH for an operator by its index
    /// @param index The index of the operator to lookup
    /// @return The released ETH for the given operator index
    function getReleasedETH(uint256 index) internal view returns (uint256) {
        return _getReleasedETH(getReleasedETH(), index);
    }

    /// @notice Retrieve the cumulative released ETH for an operator by its index
    /// @dev Returns 0 for indexes the array has not grown to yet, mirroring `_getExitedETH`
    /// @param releasedETH The storage pointer to the raw array containing the released ETH
    /// @param index The index of the operator to lookup
    /// @return The released ETH for the given operator index
    function _getReleasedETH(uint256[] storage releasedETH, uint256 index) internal view returns (uint256) {
        if (index + 1 >= releasedETH.length) {
            return 0;
        }
        return releasedETH[index + 1];
    }

    /// @notice Adds to the cumulative released ETH of an operator, growing the array lazily
    /// @dev This is the single writer of the released ETH accumulator: the admin break-glass path and any
    ///      future oracle-reported release path both funnel their (clamped) deltas through here, so the
    ///      accumulator can never diverge between the two.
    /// @param operatorIndex The index of the operator whose reservation is being released
    /// @param amount The ETH(wei) amount released
    function addReleasedETH(uint256 operatorIndex, uint256 amount) internal {
        if (amount == 0) {
            return;
        }
        uint256[] storage releasedETH = getReleasedETH();

        // slot 0 holds the sum, so operator `operatorIndex` lives at `operatorIndex + 1`
        uint256 requiredLength = operatorIndex + 2;
        while (releasedETH.length < requiredLength) {
            releasedETH.push(0);
        }

        releasedETH[0] += amount;
        releasedETH[operatorIndex + 1] += amount;
    }
}
