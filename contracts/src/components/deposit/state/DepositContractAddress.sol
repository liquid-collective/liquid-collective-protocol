//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "../interfaces/IDepositContract.sol";

library DepositContractAddress {
    bytes32 public constant DEPOSIT_CONTRACT_ADDRESS_SLOT =
        bytes32(uint256(keccak256("river.state.depositContractAddress")) - 1);

    struct Slot {
        IDepositContract value;
    }

    function get() internal pure returns (Slot storage r) {
        bytes32 slot = DEPOSIT_CONTRACT_ADDRESS_SLOT;
        assembly {
            r.slot := slot
        }
    }
}
