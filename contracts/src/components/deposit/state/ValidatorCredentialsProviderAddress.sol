//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "../interfaces/IValidatorCredentialsProvider.sol";

library ValidatorCredentialsProviderAddress {
    bytes32 public constant VALIDATOR_CREDENTIALS_PROVIDER_ADDRESS_SLOT =
        bytes32(
            uint256(keccak256("river.state.validatorCredentialsProvider")) - 1
        );

    struct Slot {
        IValidatorCredentialsProvider value;
    }

    function get() internal view returns (IValidatorCredentialsProvider) {
        bytes32 slot = VALIDATOR_CREDENTIALS_PROVIDER_ADDRESS_SLOT;
        Slot storage r;

        assembly {
            r.slot := slot
        }

        return r.value;
    }

    function set(IValidatorCredentialsProvider newValue) internal {
        bytes32 slot = VALIDATOR_CREDENTIALS_PROVIDER_ADDRESS_SLOT;
        Slot storage r;

        assembly {
            r.slot := slot
        }

        r.value = newValue;
    }
}
