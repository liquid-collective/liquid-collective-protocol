//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "../../libraries/UnstructuredStorage.sol";

library LastOracleRoundId {
    /* Hardcoded hex is: bytes32(uint256(keccak256("river.state.lastOracleRoundId")) - 1) */
    bytes32 public constant LAST_ORACLE_ROUND_ID_SLOT =
        hex"d7f2d45e512a86049f7a113657b39731b6b558609584243063a52cd31a8eb528";

    function get() internal view returns (bytes32) {
        return UnstructuredStorage.getStorageBytes32(LAST_ORACLE_ROUND_ID_SLOT);
    }

    function set(bytes32 newValue) internal {
        UnstructuredStorage.setStorageBytes32(LAST_ORACLE_ROUND_ID_SLOT, newValue);
    }
}
