//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "../../interfaces/IDepositContract.sol";
import "../../libraries/UnstructuredStorage.sol";

library DepositContractAddress {
    /* Hardcoded hex is: bytes32(uint256(keccak256("river.state.depositContractAddress")) - 1) */
    bytes32 internal constant DEPOSIT_CONTRACT_ADDRESS_SLOT =
        hex"35efb61d8784060218d9d6aa40eae55904de43779c1afc79c74dfefcfdf9125f";

    function get() internal view returns (IDepositContract) {
        return IDepositContract(UnstructuredStorage.getStorageAddress(DEPOSIT_CONTRACT_ADDRESS_SLOT));
    }

    function set(IDepositContract newValue) internal {
        return UnstructuredStorage.setStorageAddress(DEPOSIT_CONTRACT_ADDRESS_SLOT, address(newValue));
    }
}
