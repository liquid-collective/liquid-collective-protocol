//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "forge-std/Test.sol";
import "../../../src/state/attestationVerifier/InitialDepositedPubkeys.sol";

/// @dev Thin wrapper that exposes the InitialDepositedPubkeys library functions as external
///      methods so the test can exercise storage operations against a real address.
contract InitialDepositedPubkeysInputs {
    function hasInitialDeposit(bytes32 pubkeyHash) external view returns (bool) {
        return InitialDepositedPubkeys.hasInitialDeposit(pubkeyHash);
    }

    function markInitialDeposited(bytes32 pubkeyHash) external {
        InitialDepositedPubkeys.markInitialDeposited(pubkeyHash);
    }

    function unmarkInitialDeposited(bytes32 pubkeyHash) external {
        InitialDepositedPubkeys.unmarkInitialDeposited(pubkeyHash);
    }
}

contract InitialDepositedPubkeysTest is Test {
    InitialDepositedPubkeysInputs internal inputs;

    /// @dev Must match `InitialDepositedPubkeys.INITIAL_DEPOSITED_PUBKEYS_MAPPING_BASE_SLOT`.
    ///      The cross-check is the slot-derivation test below.
    bytes32 internal constant EXPECTED_BASE_SLOT =
        bytes32(uint256(keccak256("attestationVerifier.state.initialDepositedPubkeys.mapping")) - 1);

    function setUp() public {
        inputs = new InitialDepositedPubkeysInputs();
    }

    function testInitiallyUnset() public {
        bytes32 pkh = keccak256(abi.encodePacked("unmarked-pubkey"));
        assertFalse(inputs.hasInitialDeposit(pkh));
    }

    function testMarkThenIs() public {
        bytes32 pkh = keccak256(abi.encodePacked("pubkey-A"));
        inputs.markInitialDeposited(pkh);
        assertTrue(inputs.hasInitialDeposit(pkh));
    }

    function testMarkDoesNotLeakToOtherKeys() public {
        bytes32 pkhA = keccak256(abi.encodePacked("pubkey-A"));
        bytes32 pkhB = keccak256(abi.encodePacked("pubkey-B"));

        inputs.markInitialDeposited(pkhA);
        assertTrue(inputs.hasInitialDeposit(pkhA));
        assertFalse(inputs.hasInitialDeposit(pkhB));
    }

    function testUnmarkClears() public {
        bytes32 pkh = keccak256(abi.encodePacked("pubkey-C"));
        inputs.markInitialDeposited(pkh);
        assertTrue(inputs.hasInitialDeposit(pkh));

        inputs.unmarkInitialDeposited(pkh);
        assertFalse(inputs.hasInitialDeposit(pkh));
    }

    function testMarkIsIdempotent() public {
        bytes32 pkh = keccak256(abi.encodePacked("pubkey-D"));
        inputs.markInitialDeposited(pkh);
        inputs.markInitialDeposited(pkh);
        assertTrue(inputs.hasInitialDeposit(pkh));
    }

    /// @dev Slot derivation cross-check: a direct `vm.store` at the expected slot must be
    ///      observable via `hasInitialDeposit`. Guards against accidental rename of the
    ///      namespace string in either the library or any consumer (e.g., the harness in
    ///      ConsensusLayerDepositManagerAttestation.t.sol which uses the same slot).
    function testSlotDerivation() public {
        bytes32 pkh = keccak256(abi.encodePacked("pubkey-E"));
        bytes32 slot = keccak256(abi.encode(EXPECTED_BASE_SLOT, pkh));

        // Before: unset.
        assertFalse(inputs.hasInitialDeposit(pkh));

        // Write directly to the derived slot.
        vm.store(address(inputs), slot, bytes32(uint256(1)));
        assertTrue(inputs.hasInitialDeposit(pkh));

        // Clear directly.
        vm.store(address(inputs), slot, bytes32(0));
        assertFalse(inputs.hasInitialDeposit(pkh));
    }
}
