//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "../../libraries/LibErrors.sol";
import "../../libraries/LibUnstructuredStorage.sol";

library WithdrawalCredentials {
    bytes32 internal constant WITHDRAWAL_CREDENTIALS_SLOT =
        bytes32(uint256(keccak256("river.state.withdrawalCredentials")) - 1);

    function get() internal view returns (bytes32) {
        return LibUnstructuredStorage.getStorageBytes32(WITHDRAWAL_CREDENTIALS_SLOT);
    }

    function set(bytes32 newValue) internal {
        if (newValue == bytes32(0)) {
            revert LibErrors.InvalidArgument();
        }
        LibUnstructuredStorage.setStorageBytes32(WITHDRAWAL_CREDENTIALS_SLOT, newValue);
    }
}
