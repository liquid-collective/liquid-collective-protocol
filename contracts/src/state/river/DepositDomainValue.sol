//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../../libraries/LibUnstructuredStorage.sol";

/// @title DepositDomainValue
/// @notice Library for storing the domain value of the DepositDataBuffer contract.
library DepositDomainValue {
    bytes32 internal constant DEPOSIT_DOMAIN_SLOT = bytes32(uint256(keccak256("river.state.depositDomain")) - 1);

    function get() internal view returns (bytes32) {
        return LibUnstructuredStorage.getStorageBytes32(DEPOSIT_DOMAIN_SLOT);
    }

    function set(bytes32 newValue) internal {
        LibUnstructuredStorage.setStorageBytes32(DEPOSIT_DOMAIN_SLOT, newValue);
    }
}
