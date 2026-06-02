//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "forge-std/Test.sol";
import "../../../src/state/attestationVerifier/PrePectraValidatorPubkeyLookup.sol";

/// @dev Thin wrapper that exposes the PrePectraValidatorPubkeyLookup library functions
///      as external methods so the test can exercise storage operations against a real address.
contract PrePectraValidatorPubkeyLookupInputs {
    function isPubkeyFunded(bytes calldata pubkey) external view returns (bool) {
        return PrePectraValidatorPubkeyLookup.isPubkeyFunded(pubkey);
    }

    function add(bytes calldata pubkey) external {
        PrePectraValidatorPubkeyLookup.add(pubkey);
    }
}

contract PrePectraValidatorPubkeyLookupTest is Test {
    PrePectraValidatorPubkeyLookupInputs internal inputs;

    /// @dev Must match `PrePectraValidatorPubkeyLookup.PRE_PECTRA_VALIDATOR_PUBKEY_LOOKUP_MAPPING_BASE_SLOT`.
    ///      The cross-check is the slot-derivation test below.
    bytes32 internal constant EXPECTED_BASE_SLOT =
        bytes32(uint256(keccak256("attestationVerifier.state.prePectraValidatorPubkeyLookup.mapping")) - 1);

    function setUp() public {
        inputs = new PrePectraValidatorPubkeyLookupInputs();
    }

    /// @dev Build a deterministic 48-byte BLS-shaped pubkey from a seed.
    function _pubkey(bytes32 seed) internal pure returns (bytes memory) {
        return abi.encodePacked(seed, bytes16(seed));
    }

    function testInitiallyUnset() public {
        bytes memory pk = _pubkey(keccak256("unmarked-pre-pectra-pubkey"));
        assertFalse(inputs.isPubkeyFunded(pk));
    }

    function testAddThenHas() public {
        bytes memory pk = _pubkey(keccak256("pre-pectra-pubkey-A"));
        inputs.add(pk);
        assertTrue(inputs.isPubkeyFunded(pk));
    }

    function testAddDoesNotLeakToOtherKeys() public {
        bytes memory pkA = _pubkey(keccak256("pre-pectra-pubkey-A"));
        bytes memory pkB = _pubkey(keccak256("pre-pectra-pubkey-B"));

        inputs.add(pkA);
        assertTrue(inputs.isPubkeyFunded(pkA));
        assertFalse(inputs.isPubkeyFunded(pkB));
    }

    function testAddIsIdempotent() public {
        bytes memory pk = _pubkey(keccak256("pre-pectra-pubkey-C"));
        inputs.add(pk);
        inputs.add(pk);
        assertTrue(inputs.isPubkeyFunded(pk));
    }

    /// @dev Slot derivation cross-check: a direct `vm.store` at the expected slot must be
    ///      observable via `isPubkeyFunded`. Guards against accidental namespace changes.
    function testSlotDerivation() public {
        bytes memory pk = _pubkey(keccak256("pre-pectra-pubkey-D"));
        bytes32 slot = keccak256(abi.encode(EXPECTED_BASE_SLOT, pk));

        assertFalse(inputs.isPubkeyFunded(pk));

        vm.store(address(inputs), slot, bytes32(uint256(1)));
        assertTrue(inputs.isPubkeyFunded(pk));

        vm.store(address(inputs), slot, bytes32(0));
        assertFalse(inputs.isPubkeyFunded(pk));
    }
}
