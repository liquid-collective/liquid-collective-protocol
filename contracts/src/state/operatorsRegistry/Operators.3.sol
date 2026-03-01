//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../../libraries/LibSanitize.sol";

/// @title Operators Storage (V3)
/// @notice Utility to manage the Operators in storage with ETH-denominated balance fields
/// @dev This version replaces count-based validator tracking (uint32 funded/requestedExits)
///      with wei-denominated balance tracking (uint256 fundedBalance/requestedExitBalance)
///      to support EIP-7251/MaxEB variable-size deposits.
library OperatorsV3 {
    /// @notice Storage slot of the Operators
    bytes32 internal constant OPERATORS_SLOT = bytes32(uint256(keccak256("river.state.v3.operators")) - 1);

    /// @notice The Operator structure in storage
    struct Operator {
        /// @custom:attribute The total funded balance in wei for this operator
        uint256 fundedBalance;
        /// @custom:attribute The total balance in wei for which exit requests have been made
        uint256 requestedExitBalance;
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

    /// @notice Storage slot of the Stopped Balances
    bytes32 internal constant STOPPED_BALANCES_SLOT = bytes32(uint256(keccak256("river.state.stoppedBalances")) - 1);

    struct SlotStoppedBalances {
        uint256[] value;
    }

    /// @notice Retrieve the storage pointer of the Stopped Balances array
    /// @return The Stopped Balances storage pointer
    function getStoppedBalances() internal view returns (uint256[] storage) {
        bytes32 slot = STOPPED_BALANCES_SLOT;

        SlotStoppedBalances storage r;

        // solhint-disable-next-line no-inline-assembly
        assembly {
            r.slot := slot
        }

        return r.value;
    }

    /// @notice Sets the entire stopped balances array
    /// @param value The new stopped balances array
    function setRawStoppedBalances(uint256[] memory value) internal {
        bytes32 slot = STOPPED_BALANCES_SLOT;

        SlotStoppedBalances storage r;

        // solhint-disable-next-line no-inline-assembly
        assembly {
            r.slot := slot
        }

        r.value = value;
    }

    /// @notice Retrieve the stopped balance for an operator by its index
    /// @param stoppedBalances The storage pointer to the raw array containing the stopped balances
    /// @param index The index of the operator to lookup
    /// @return The stopped balance in wei for the given operator index
    function _getStoppedBalanceAtIndex(uint256[] storage stoppedBalances, uint256 index)
        internal
        view
        returns (uint256)
    {
        if (index + 1 >= stoppedBalances.length) {
            return 0;
        }
        return stoppedBalances[index + 1];
    }
}
