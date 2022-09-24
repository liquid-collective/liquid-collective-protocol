//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "../../interfaces/IDepositContract.sol";
import "../../libraries/LibErrors.sol";
import "../../libraries/LibSanitize.sol";
import "../../libraries/LibUnstructuredStorage.sol";

library DepositContractAddress {
    bytes32 internal constant DEPOSIT_CONTRACT_ADDRESS_SLOT =
        bytes32(uint256(keccak256("river.state.depositContractAddress")) - 1);

    function get() internal view returns (IDepositContract) {
        return IDepositContract(LibUnstructuredStorage.getStorageAddress(DEPOSIT_CONTRACT_ADDRESS_SLOT));
    }

    function set(IDepositContract newValue) internal {
        LibSanitize._notZeroAddress(address(newValue));
        return LibUnstructuredStorage.setStorageAddress(DEPOSIT_CONTRACT_ADDRESS_SLOT, address(newValue));
    }
}
