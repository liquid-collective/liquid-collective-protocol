//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

/// @title Stopped Validator ETH Storage
/// @notice Utility to manage the per-operator stopped validator ETH amounts in storage
/// @notice Layout mirrors stopped validator counts: index 0 is total, index i+1 is operator i
library StoppedValidatorEth {
    /// @notice Storage slot of the Stopped Validator ETH array
    bytes32 internal constant STOPPED_VALIDATOR_ETH_SLOT =
        bytes32(uint256(keccak256("river.state.stoppedValidatorEth")) - 1);

    struct SlotStoppedValidatorEth {
        uint256[] value;
    }

    /// @notice Retrieve the storage pointer of the Stopped Validator ETH array
    /// @return The Stopped Validator ETH storage pointer
    function getAll() internal view returns (uint256[] storage) {
        bytes32 slot = STOPPED_VALIDATOR_ETH_SLOT;

        SlotStoppedValidatorEth storage r;

        // solhint-disable-next-line no-inline-assembly
        assembly {
            r.slot := slot
        }

        return r.value;
    }

    /// @notice Sets the entire stopped validator ETH array
    /// @param _value The new stopped validator ETH array
    function setAll(uint256[] memory _value) internal {
        bytes32 slot = STOPPED_VALIDATOR_ETH_SLOT;

        SlotStoppedValidatorEth storage r;

        // solhint-disable-next-line no-inline-assembly
        assembly {
            r.slot := slot
        }

        r.value = _value;
    }

    /// @notice Retrieve the stopped ETH amount for an operator
    /// @param _operatorIndex The operator index
    /// @return The stopped ETH amount for the operator (0 if not set)
    function getAtIndex(uint256 _operatorIndex) internal view returns (uint256) {
        uint256[] storage arr = getAll();
        if (_operatorIndex + 1 >= arr.length) {
            return 0;
        }
        return arr[_operatorIndex + 1];
    }

    /// @notice Retrieve the total stopped ETH amount
    /// @return The total stopped ETH amount (0 if not set)
    function getTotal() internal view returns (uint256) {
        uint256[] storage arr = getAll();
        if (arr.length == 0) {
            return 0;
        }
        return arr[0];
    }
}
