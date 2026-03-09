//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

/// @title Operator Requested Exits ETH Storage
/// @notice Utility to manage the per-operator requested exits ETH amounts in storage
library OperatorRequestedExitsEth {
    /// @notice Storage slot of the Operator Requested Exits ETH mapping
    bytes32 internal constant OPERATOR_REQUESTED_EXITS_ETH_SLOT =
        bytes32(uint256(keccak256("river.state.operatorRequestedExitsEth")) - 1);

    struct SlotMapping {
        mapping(uint256 => uint256) value;
    }

    /// @notice Retrieve the requested exits ETH amount for an operator
    /// @param _operatorIndex The operator index
    /// @return The requested exits ETH amount
    function get(uint256 _operatorIndex) internal view returns (uint256) {
        bytes32 slot = OPERATOR_REQUESTED_EXITS_ETH_SLOT;

        SlotMapping storage r;

        // solhint-disable-next-line no-inline-assembly
        assembly {
            r.slot := slot
        }

        return r.value[_operatorIndex];
    }

    /// @notice Sets the requested exits ETH amount for an operator
    /// @param _operatorIndex The operator index
    /// @param _newValue New requested exits ETH amount
    function set(uint256 _operatorIndex, uint256 _newValue) internal {
        bytes32 slot = OPERATOR_REQUESTED_EXITS_ETH_SLOT;

        SlotMapping storage r;

        // solhint-disable-next-line no-inline-assembly
        assembly {
            r.slot := slot
        }

        r.value[_operatorIndex] = _newValue;
    }
}
