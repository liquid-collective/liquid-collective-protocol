//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "../../libraries/LibUnstructuredStorage.sol";

library LastOracleRoundId {
    bytes32 internal constant LAST_ORACLE_ROUND_ID_SLOT =
        bytes32(uint256(keccak256("river.state.lastOracleRoundId")) - 1);

    function get() internal view returns (bytes32) {
        return LibUnstructuredStorage.getStorageBytes32(LAST_ORACLE_ROUND_ID_SLOT);
    }

    function set(bytes32 newValue) internal {
        LibUnstructuredStorage.setStorageBytes32(LAST_ORACLE_ROUND_ID_SLOT, newValue);
    }
}
