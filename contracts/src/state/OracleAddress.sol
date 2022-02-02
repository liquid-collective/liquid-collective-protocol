//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

library OracleAddress {
    bytes32 public constant ORACLE_ADDRESS_SLOT =
        bytes32(uint256(keccak256("river.state.oracleAddress")) - 1);

    struct Slot {
        address value;
    }

    function get() internal view returns (address) {
        bytes32 slot = ORACLE_ADDRESS_SLOT;

        Slot storage r;

        assembly {
            r.slot := slot
        }

        return r.value;
    }

    function set(address newOracle) internal {
        bytes32 slot = ORACLE_ADDRESS_SLOT;

        Slot storage r;

        assembly {
            r.slot := slot
        }

        r.value = newOracle;
    }
}
