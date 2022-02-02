//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "../libraries/BytesLib.sol";

library ValidatorKeys {
    uint256 public constant PUBLIC_KEY_LENGTH = 48;
    uint256 public constant SIGNATURE_LENGTH = 96;

    error InvalidPublicKey();
    error InvalidSignature();

    bytes32 public constant VALIDATOR_KEYS_SLOT =
        bytes32(uint256(keccak256("river.state.validatorKeys")) - 1);

    struct Slot {
        mapping(string => mapping(uint256 => bytes)) value;
    }

    function get(string memory name, uint256 idx)
        internal
        view
        returns (bytes memory publicKey, bytes memory signature)
    {
        bytes32 slot = VALIDATOR_KEYS_SLOT;

        Slot storage r;

        assembly {
            r.slot := slot
        }

        bytes storage entry = r.value[name][idx];

        publicKey = BytesLib.slice(entry, 0, PUBLIC_KEY_LENGTH);
        signature = BytesLib.slice(entry, PUBLIC_KEY_LENGTH, SIGNATURE_LENGTH);
    }

    function set(
        string memory name,
        uint256 idx,
        bytes memory publicKey,
        bytes memory signature
    ) internal {
        if (publicKey.length != PUBLIC_KEY_LENGTH) {
            revert InvalidPublicKey();
        }

        if (signature.length != SIGNATURE_LENGTH) {
            revert InvalidSignature();
        }

        bytes memory concatenatedKeys = BytesLib.concat(publicKey, signature);

        bytes32 slot = VALIDATOR_KEYS_SLOT;

        Slot storage r;

        assembly {
            r.slot := slot
        }

        r.value[name][idx] = concatenatedKeys;
    }
}
