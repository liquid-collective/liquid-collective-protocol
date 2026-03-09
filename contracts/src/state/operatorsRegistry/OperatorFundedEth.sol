//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

/// @title Operator Funded ETH Storage
/// @notice Utility to manage the per-operator funded ETH amounts in storage
library OperatorFundedEth {
    /// @notice Storage slot of the Operator Funded ETH mapping
    bytes32 internal constant OPERATOR_FUNDED_ETH_SLOT =
        bytes32(uint256(keccak256("river.state.operatorFundedEth")) - 1);

    struct SlotMapping {
        mapping(uint256 => uint256) value;
    }

    /// @notice Retrieve the funded ETH amount for an operator
    /// @param _operatorIndex The operator index
    /// @return The funded ETH amount
    function get(uint256 _operatorIndex) internal view returns (uint256) {
        bytes32 slot = OPERATOR_FUNDED_ETH_SLOT;

        SlotMapping storage r;

        // solhint-disable-next-line no-inline-assembly
        assembly {
            r.slot := slot
        }

        return r.value[_operatorIndex];
    }

    /// @notice Sets the funded ETH amount for an operator
    /// @param _operatorIndex The operator index
    /// @param _newValue New funded ETH amount
    function set(uint256 _operatorIndex, uint256 _newValue) internal {
        bytes32 slot = OPERATOR_FUNDED_ETH_SLOT;

        SlotMapping storage r;

        // solhint-disable-next-line no-inline-assembly
        assembly {
            r.slot := slot
        }

        r.value[_operatorIndex] = _newValue;
    }
}
