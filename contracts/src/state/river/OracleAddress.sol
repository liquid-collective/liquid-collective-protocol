//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "../../libraries/UnstructuredStorage.sol";

library OracleAddress {
    /* Hardcoded hex is: bytes32(uint256(keccak256("river.state.oracleAddress")) - 1) */
    bytes32 internal constant ORACLE_ADDRESS_SLOT =
        hex"c8cbea9407c380ae944f052b5a442330057683c5abdbd453493f9750806afeca";

    function get() internal view returns (address) {
        return UnstructuredStorage.getStorageAddress(ORACLE_ADDRESS_SLOT);
    }

    function set(address newValue) internal {
        UnstructuredStorage.setStorageAddress(ORACLE_ADDRESS_SLOT, newValue);
    }
}
