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

    function remove(bytes[] calldata pubkeys) external {
        PrePectraValidatorPubkeyLookup.remove(pubkeys);
    }
}

contract PrePectraValidatorPubkeyLookupTest is Test {
    PrePectraValidatorPubkeyLookupInputs internal inputs;

    /// @dev Must match `PrePectraValidatorPubkeyLookup.PRE_PECTRA_VALIDATOR_PUBKEY_LOOKUP_SLOT`.
    ///      The cross-check is the slot-derivation test below.
    bytes32 internal constant EXPECTED_BASE_SLOT =
        bytes32(uint256(keccak256("attestationVerifier.state.prePectraValidatorPubkeyLookup")) - 1);

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

        // one remove must fully clear it
        bytes[] memory pubkeys = new bytes[](1);
        pubkeys[0] = pk;
        inputs.remove(pubkeys);
        assertFalse(inputs.isPubkeyFunded(pk));
    }

    function testRemoveClearsOnlyRequestedKeys() public {
        bytes memory pkA = _pubkey(keccak256("pre-pectra-pubkey-remove-A"));
        bytes memory pkB = _pubkey(keccak256("pre-pectra-pubkey-remove-B"));
        bytes memory pkC = _pubkey(keccak256("pre-pectra-pubkey-remove-C"));

        inputs.add(pkA);
        inputs.add(pkB);
        inputs.add(pkC);

        bytes[] memory pubkeys = new bytes[](2);
        pubkeys[0] = pkA;
        pubkeys[1] = pkC;

        // Batch removal backs the admin rollback path: each supplied pubkey should be
        // cleared independently while migrated pubkeys omitted from the batch stay funded.
        inputs.remove(pubkeys);

        assertFalse(inputs.isPubkeyFunded(pkA));
        assertTrue(inputs.isPubkeyFunded(pkB));
        assertFalse(inputs.isPubkeyFunded(pkC));
    }

    function testRemoveUnsetKeyIsNoop() public {
        bytes memory fundedPk = _pubkey(keccak256("pre-pectra-pubkey-stays-funded"));
        bytes memory unsetPk = _pubkey(keccak256("pre-pectra-pubkey-never-funded"));
        inputs.add(fundedPk);

        bytes[] memory pubkeys = new bytes[](1);
        pubkeys[0] = unsetPk;

        // Removing an already-unset pubkey can happen when cleanup tooling is retried; it
        // must not disturb any other migrated pubkey in the same lookup namespace.
        inputs.remove(pubkeys);

        assertTrue(inputs.isPubkeyFunded(fundedPk));
        assertFalse(inputs.isPubkeyFunded(unsetPk));
    }

    function testRemoveEmptyBatchDoesNothing() public {
        bytes memory pk = _pubkey(keccak256("pre-pectra-pubkey-empty-remove"));
        inputs.add(pk);

        bytes[] memory pubkeys = new bytes[](0);

        // Empty admin batches are benign no-ops; this documents the loop boundary and
        // prevents a future helper from treating empty cleanup as an error.
        inputs.remove(pubkeys);

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
