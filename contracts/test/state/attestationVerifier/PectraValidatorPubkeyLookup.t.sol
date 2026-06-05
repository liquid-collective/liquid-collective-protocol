//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "forge-std/Test.sol";
import "../../../src/state/attestationVerifier/PectraValidatorPubkeyLookup.sol";

/// @dev Thin wrapper that exposes the PectraValidatorPubkeyLookup library functions as external
///      methods so the test can exercise storage operations against a real address.
contract PectraValidatorPubkeyLookupInputs {
    function isPubkeyFunded(bytes calldata pubkey) external view returns (bool) {
        return PectraValidatorPubkeyLookup.isPubkeyFunded(pubkey);
    }

    function add(bytes calldata pubkey) external {
        PectraValidatorPubkeyLookup.add(pubkey);
    }

    function remove(bytes calldata pubkey) external {
        PectraValidatorPubkeyLookup.remove(pubkey);
    }
}

contract PectraValidatorPubkeyLookupTest is Test {
    PectraValidatorPubkeyLookupInputs internal inputs;

    /// @dev Must match `PectraValidatorPubkeyLookup.PECTRA_VALIDATOR_PUBKEY_LOOKUP_MAPPING_BASE_SLOT`.
    ///      The cross-check is the slot-derivation test below.
    bytes32 internal constant EXPECTED_BASE_SLOT =
        bytes32(uint256(keccak256("attestationVerifier.state.pectraValidatorPubkeyLookup.mapping")) - 1);

    function setUp() public {
        inputs = new PectraValidatorPubkeyLookupInputs();
    }

    /// @dev Build a deterministic 48-byte BLS-shaped pubkey from a seed.
    function _pubkey(bytes32 seed) internal pure returns (bytes memory) {
        return abi.encodePacked(seed, bytes16(seed));
    }

    function testInitiallyUnset() public {
        bytes memory pk = _pubkey(keccak256("unmarked-pubkey"));
        assertFalse(inputs.isPubkeyFunded(pk));
    }

    function testAddThenHas() public {
        bytes memory pk = _pubkey(keccak256("pubkey-A"));
        inputs.add(pk);
        assertTrue(inputs.isPubkeyFunded(pk));
    }

    function testAddDoesNotLeakToOtherKeys() public {
        bytes memory pkA = _pubkey(keccak256("pubkey-A"));
        bytes memory pkB = _pubkey(keccak256("pubkey-B"));

        inputs.add(pkA);
        assertTrue(inputs.isPubkeyFunded(pkA));
        assertFalse(inputs.isPubkeyFunded(pkB));
    }

    function testRemoveClearsEntry() public {
        bytes memory pk = _pubkey(keccak256("pubkey-C"));
        inputs.add(pk);
        assertTrue(inputs.isPubkeyFunded(pk));

        inputs.remove(pk);
        assertFalse(inputs.isPubkeyFunded(pk));
    }

    function testAddIsIdempotent() public {
        bytes memory pk = _pubkey(keccak256("pubkey-D"));
        inputs.add(pk);
        inputs.add(pk);
        assertTrue(inputs.isPubkeyFunded(pk));
    }

    /// @dev Slot derivation cross-check: a direct `vm.store` at the expected slot must be
    ///      observable via `isPubkeyFunded`. Guards against accidental rename of the
    ///      namespace string in either the library or any consumer (e.g., the harness in
    ///      ConsensusLayerDepositManagerAttestation.t.sol which uses the same slot).
    function testSlotDerivation() public {
        bytes memory pk = _pubkey(keccak256("pubkey-E"));
        bytes32 slot = keccak256(abi.encode(EXPECTED_BASE_SLOT, pk));

        // Before: unset.
        assertFalse(inputs.isPubkeyFunded(pk));

        // Write directly to the derived slot — any non-zero value means "recorded".
        vm.store(address(inputs), slot, bytes32(uint256(1)));
        assertTrue(inputs.isPubkeyFunded(pk));

        // Clear directly.
        vm.store(address(inputs), slot, bytes32(0));
        assertFalse(inputs.isPubkeyFunded(pk));
    }
}
