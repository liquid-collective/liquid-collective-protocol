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

    function getFundedOperator(bytes32 pubkeyHash) external view returns (uint256) {
        return InitialDepositedPubkeys.getFundedOperator(pubkeyHash);
    }

    function markInitialDeposited(bytes32 pubkeyHash, uint256 operatorIdx) external {
        InitialDepositedPubkeys.markInitialDeposited(pubkeyHash, operatorIdx);
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
        assertEq(inputs.getFundedOperator(pkh), 0);
    }

    function testMarkThenIs() public {
        bytes32 pkh = keccak256(abi.encodePacked("pubkey-A"));
        inputs.markInitialDeposited(pkh, 0);
        assertTrue(inputs.hasInitialDeposit(pkh));
    }

    function testMarkRecordsOperator() public {
        bytes32 pkh = keccak256(abi.encodePacked("pubkey-with-op-5"));
        inputs.markInitialDeposited(pkh, 5);
        // Stored sentinel is operatorIdx + 1.
        assertEq(inputs.getFundedOperator(pkh), 6);
    }

    function testHasInitialDepositTrueAfterMark() public {
        bytes32 pkh = keccak256(abi.encodePacked("pubkey-bool-wrapper"));
        inputs.markInitialDeposited(pkh, 7);
        assertTrue(inputs.hasInitialDeposit(pkh));
    }

    /// @dev Operator 0 must still produce a non-zero sentinel (1), distinguishing
    ///      "funded by operator 0" from "never funded".
    function testMarkOperatorZero_isDistinctFromUnset() public {
        bytes32 pkh = keccak256(abi.encodePacked("pubkey-op-zero"));
        assertEq(inputs.getFundedOperator(pkh), 0);
        inputs.markInitialDeposited(pkh, 0);
        assertEq(inputs.getFundedOperator(pkh), 1);
        assertTrue(inputs.hasInitialDeposit(pkh));
    }

    function testMarkDoesNotLeakToOtherKeys() public {
        bytes32 pkhA = keccak256(abi.encodePacked("pubkey-A"));
        bytes32 pkhB = keccak256(abi.encodePacked("pubkey-B"));

        inputs.markInitialDeposited(pkhA, 3);
        assertTrue(inputs.hasInitialDeposit(pkhA));
        assertEq(inputs.getFundedOperator(pkhA), 4);
        assertFalse(inputs.hasInitialDeposit(pkhB));
        assertEq(inputs.getFundedOperator(pkhB), 0);
    }

    function testUnmarkClearsOperator() public {
        bytes32 pkh = keccak256(abi.encodePacked("pubkey-C"));
        inputs.markInitialDeposited(pkh, 9);
        assertTrue(inputs.hasInitialDeposit(pkh));
        assertEq(inputs.getFundedOperator(pkh), 10);

        inputs.unmarkInitialDeposited(pkh);
        assertFalse(inputs.hasInitialDeposit(pkh));
        assertEq(inputs.getFundedOperator(pkh), 0);
    }

    function testMarkIsIdempotent() public {
        bytes32 pkh = keccak256(abi.encodePacked("pubkey-D"));
        inputs.markInitialDeposited(pkh, 2);
        inputs.markInitialDeposited(pkh, 2);
        assertTrue(inputs.hasInitialDeposit(pkh));
        assertEq(inputs.getFundedOperator(pkh), 3);
    }

    /// @dev Slot derivation cross-check: a direct `vm.store` at the expected slot must be
    ///      observable via `getFundedOperator`. Guards against accidental rename of the
    ///      namespace string in either the library or any consumer (e.g., the harness in
    ///      ConsensusLayerDepositManagerAttestation.t.sol which uses the same slot).
    function testSlotDerivation() public {
        bytes32 pkh = keccak256(abi.encodePacked("pubkey-E"));
        bytes32 slot = keccak256(abi.encode(EXPECTED_BASE_SLOT, pkh));

        // Before: unset.
        assertEq(inputs.getFundedOperator(pkh), 0);
        assertFalse(inputs.hasInitialDeposit(pkh));

        // Write directly to the derived slot — the stored value is interpreted as the raw
        // sentinel (operatorIdx + 1). 7 → "funded by operator 6".
        vm.store(address(inputs), slot, bytes32(uint256(7)));
        assertEq(inputs.getFundedOperator(pkh), 7);
        assertTrue(inputs.hasInitialDeposit(pkh));

        // Clear directly.
        vm.store(address(inputs), slot, bytes32(0));
        assertEq(inputs.getFundedOperator(pkh), 0);
        assertFalse(inputs.hasInitialDeposit(pkh));
    }
}
