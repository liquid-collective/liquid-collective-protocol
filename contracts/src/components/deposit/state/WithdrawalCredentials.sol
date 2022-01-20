//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

library WithdrawalCredentials {
    bytes32 public constant WITHDRAWAL_CREDENTIALS_SLOT =
        bytes32(uint256(keccak256("river.state.withdrawalCredentials")) - 1);

    struct Slot {
        bytes32 value;
    }

    function get() internal view returns (bytes32) {
        bytes32 slot = WITHDRAWAL_CREDENTIALS_SLOT;
        Slot storage r;

        assembly {
            r.slot := slot
        }

        return r.value;
    }

    function set(bytes32 newValue) internal {
        bytes32 slot = WITHDRAWAL_CREDENTIALS_SLOT;
        Slot storage r;

        assembly {
            r.slot := slot
        }

        r.value = newValue;
    }
}
