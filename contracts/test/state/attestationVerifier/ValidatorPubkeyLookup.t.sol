//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "forge-std/Test.sol";
import "../../../src/state/attestationVerifier/ValidatorPubkeyLookup.sol";

/// @dev Thin wrapper that exposes the ValidatorPubkeyLookup library functions as external
///      methods so the test can exercise storage operations against a real address.
contract ValidatorPubkeyLookupInputs {
    function hasValidatorPubkey(bytes calldata pubkey) external view returns (bool) {
        return ValidatorPubkeyLookup.hasValidatorPubkey(pubkey);
    }

    function getRawValidatorPubkeyEntry(bytes calldata pubkey) external view returns (uint256) {
        return ValidatorPubkeyLookup.getRawValidatorPubkeyEntry(pubkey);
    }

    function lookupValidatorPubkey(bytes calldata pubkey) external view returns (bool exists, uint256 operatorIdx) {
        return ValidatorPubkeyLookup.lookupValidatorPubkey(pubkey);
    }

    function addValidatorPubkey(bytes calldata pubkey, uint256 operatorIdx) external {
        ValidatorPubkeyLookup.addValidatorPubkey(pubkey, operatorIdx);
    }

    function removeValidatorPubkey(bytes calldata pubkey) external {
        ValidatorPubkeyLookup.removeValidatorPubkey(pubkey);
    }
}

contract ValidatorPubkeyLookupTest is Test {
    ValidatorPubkeyLookupInputs internal inputs;

    /// @dev Must match `ValidatorPubkeyLookup.VALIDATOR_PUBKEY_LOOKUP_MAPPING_BASE_SLOT`.
    ///      The cross-check is the slot-derivation test below.
    bytes32 internal constant EXPECTED_BASE_SLOT =
        bytes32(uint256(keccak256("attestationVerifier.state.validatorPubkeyLookup.mapping")) - 1);

    function setUp() public {
        inputs = new ValidatorPubkeyLookupInputs();
    }

    /// @dev Build a deterministic 48-byte BLS-shaped pubkey from a seed.
    function _pubkey(bytes32 seed) internal pure returns (bytes memory) {
        return abi.encodePacked(seed, bytes16(seed));
    }

    function testInitiallyUnset() public {
        bytes memory pk = _pubkey(keccak256("unmarked-pubkey"));
        assertFalse(inputs.hasValidatorPubkey(pk));
        assertEq(inputs.getRawValidatorPubkeyEntry(pk), 0);
    }

    function testAddThenHas() public {
        bytes memory pk = _pubkey(keccak256("pubkey-A"));
        inputs.addValidatorPubkey(pk, 0);
        assertTrue(inputs.hasValidatorPubkey(pk));
    }

    function testAddRecordsOperator() public {
        bytes memory pk = _pubkey(keccak256("pubkey-with-op-5"));
        inputs.addValidatorPubkey(pk, 5);
        // Stored sentinel is operatorIdx + 1.
        assertEq(inputs.getRawValidatorPubkeyEntry(pk), 6);
    }

    function testHasValidatorPubkeyTrueAfterAdd() public {
        bytes memory pk = _pubkey(keccak256("pubkey-bool-wrapper"));
        inputs.addValidatorPubkey(pk, 7);
        assertTrue(inputs.hasValidatorPubkey(pk));
    }

    /// @dev Operator 0 must still produce a non-zero sentinel (1), distinguishing
    ///      "funded by operator 0" from "never funded".
    function testAddOperatorZero_isDistinctFromUnset() public {
        bytes memory pk = _pubkey(keccak256("pubkey-op-zero"));
        assertEq(inputs.getRawValidatorPubkeyEntry(pk), 0);
        inputs.addValidatorPubkey(pk, 0);
        assertEq(inputs.getRawValidatorPubkeyEntry(pk), 1);
        assertTrue(inputs.hasValidatorPubkey(pk));
    }

    function testAddDoesNotLeakToOtherKeys() public {
        bytes memory pkA = _pubkey(keccak256("pubkey-A"));
        bytes memory pkB = _pubkey(keccak256("pubkey-B"));

        inputs.addValidatorPubkey(pkA, 3);
        assertTrue(inputs.hasValidatorPubkey(pkA));
        assertEq(inputs.getRawValidatorPubkeyEntry(pkA), 4);
        assertFalse(inputs.hasValidatorPubkey(pkB));
        assertEq(inputs.getRawValidatorPubkeyEntry(pkB), 0);
    }

    function testRemoveClearsOperator() public {
        bytes memory pk = _pubkey(keccak256("pubkey-C"));
        inputs.addValidatorPubkey(pk, 9);
        assertTrue(inputs.hasValidatorPubkey(pk));
        assertEq(inputs.getRawValidatorPubkeyEntry(pk), 10);

        inputs.removeValidatorPubkey(pk);
        assertFalse(inputs.hasValidatorPubkey(pk));
        assertEq(inputs.getRawValidatorPubkeyEntry(pk), 0);
    }

    function testAddIsIdempotent() public {
        bytes memory pk = _pubkey(keccak256("pubkey-D"));
        inputs.addValidatorPubkey(pk, 2);
        inputs.addValidatorPubkey(pk, 2);
        assertTrue(inputs.hasValidatorPubkey(pk));
        assertEq(inputs.getRawValidatorPubkeyEntry(pk), 3);
    }

    /// @dev `lookupValidatorPubkey` returns (false, 0) for an unset entry and (true, operatorIdx)
    ///      after adding. Locks the decode contract so callers never need to do `stored - 1`.
    function testLookupValidatorPubkey() public {
        bytes memory pk = _pubkey(keccak256("pubkey-lookup"));

        (bool exists, uint256 op) = inputs.lookupValidatorPubkey(pk);
        assertFalse(exists);
        assertEq(op, 0);

        inputs.addValidatorPubkey(pk, 11);
        (exists, op) = inputs.lookupValidatorPubkey(pk);
        assertTrue(exists);
        assertEq(op, 11);

        inputs.removeValidatorPubkey(pk);
        (exists, op) = inputs.lookupValidatorPubkey(pk);
        assertFalse(exists);
        assertEq(op, 0);
    }

    /// @dev `lookupValidatorPubkey` must return the canonical operator index 0 (not the sentinel
    ///      value 1) for a pubkey funded by operator 0 — proves the decode mirrors the encode.
    function testLookupValidatorPubkey_operatorZero() public {
        bytes memory pk = _pubkey(keccak256("pubkey-lookup-zero"));
        inputs.addValidatorPubkey(pk, 0);
        (bool exists, uint256 op) = inputs.lookupValidatorPubkey(pk);
        assertTrue(exists);
        assertEq(op, 0);
    }

    /// @dev Slot derivation cross-check: a direct `vm.store` at the expected slot must be
    ///      observable via `getRawValidatorPubkeyEntry`. Guards against accidental rename of the
    ///      namespace string in either the library or any consumer (e.g., the harness in
    ///      ConsensusLayerDepositManagerAttestation.t.sol which uses the same slot).
    function testSlotDerivation() public {
        bytes memory pk = _pubkey(keccak256("pubkey-E"));
        bytes32 slot = keccak256(abi.encode(EXPECTED_BASE_SLOT, pk));

        // Before: unset.
        assertEq(inputs.getRawValidatorPubkeyEntry(pk), 0);
        assertFalse(inputs.hasValidatorPubkey(pk));

        // Write directly to the derived slot — the stored value is interpreted as the raw
        // sentinel (operatorIdx + 1). 7 → "funded by operator 6".
        vm.store(address(inputs), slot, bytes32(uint256(7)));
        assertEq(inputs.getRawValidatorPubkeyEntry(pk), 7);
        assertTrue(inputs.hasValidatorPubkey(pk));

        // Clear directly.
        vm.store(address(inputs), slot, bytes32(0));
        assertEq(inputs.getRawValidatorPubkeyEntry(pk), 0);
        assertFalse(inputs.hasValidatorPubkey(pk));
    }
}
