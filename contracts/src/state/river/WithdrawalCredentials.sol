//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;
import "../../libraries/UnstructuredStorage.sol";

library WithdrawalCredentials {
    /* Hardcoded hex is: bytes32(uint256(keccak256("river.state.withdrawalCredentials")) - 1); */
    bytes32 internal constant WITHDRAWAL_CREDENTIALS_SLOT =
        hex"b649e50315f962b32d487e696a81b4828631b11f8424daaaa37e9e97766a2c41";

    function get() internal view returns (bytes32) {
        return UnstructuredStorage.getStorageBytes32(WITHDRAWAL_CREDENTIALS_SLOT);
    }

    function set(bytes32 newValue) internal {
        UnstructuredStorage.setStorageBytes32(WITHDRAWAL_CREDENTIALS_SLOT, newValue);
    }
}
