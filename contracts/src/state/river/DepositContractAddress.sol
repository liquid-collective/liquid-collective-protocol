//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "../../interfaces/IDepositContract.sol";
import "../../libraries/UnstructuredStorage.sol";

library DepositContractAddress {
    bytes32 public constant DEPOSIT_CONTRACT_ADDRESS_SLOT =
        bytes32(uint256(keccak256("river.state.depositContractAddress")) - 1);

    function get() internal view returns (IDepositContract) {
        return IDepositContract(UnstructuredStorage.getStorageAddress(DEPOSIT_CONTRACT_ADDRESS_SLOT));
    }

    function set(IDepositContract newValue) internal {
        return UnstructuredStorage.setStorageAddress(DEPOSIT_CONTRACT_ADDRESS_SLOT, address(newValue));
    }
}
