// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "forge-std/Test.sol";

import "../src/ConsolidationAttestationBuffer.sol";

/// @title ConsolidationAttestationBufferTest
/// @notice Unit coverage for the consolidation attestation event relay and sticky error path.
contract ConsolidationAttestationBufferTest is Test {
    bytes32 internal constant ATTEST_CONSOLIDATION_TYPEHASH = keccak256(
        "AttestConsolidation(address withdrawalAddress,bytes[] sourcePubkeys,bytes[] targetPubkeys,uint256 totalAmount,uint256 exitEpoch)"
    );

    ConsolidationAttestationBuffer internal buffer;

    event ConsolidationAttestationSubmitted(
        uint256 indexed idx,
        bytes32 indexed consolidationHash,
        address indexed withdrawalAddress,
        bytes[] sourcePubkeys,
        bytes[] targetPubkeys,
        uint256 totalAmount,
        uint256 exitEpoch,
        bytes signature
    );

    event ConsolidationAttestationError(
        uint256 indexed idx,
        bytes32 indexed consolidationHash,
        address indexed raiser,
        uint256 errorCode,
        bytes errorMessage,
        bytes[] invalidPubkeys
    );

    event InvalidConsolidationPubkeysRecorded(bytes32 indexed consolidationHash, bytes[] invalidPubkeys);

    function setUp() public {
        buffer = new ConsolidationAttestationBuffer();
    }

    function _pubkey(uint256 seed) internal pure returns (bytes memory) {
        return abi.encodePacked(sha256(abi.encode("consolidation-pubkey", seed)), bytes16(0));
    }

    function _hashBytesArray(bytes[] memory arr) internal pure returns (bytes32) {
        bytes32[] memory hashes = new bytes32[](arr.length);
        for (uint256 i = 0; i < arr.length; i++) {
            hashes[i] = keccak256(arr[i]);
        }
        return keccak256(abi.encodePacked(hashes));
    }

    function _expectedHash(IConsolidationAttestationBuffer.ConsolidationObject memory consolidation)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                ATTEST_CONSOLIDATION_TYPEHASH,
                consolidation.withdrawalAddress,
                _hashBytesArray(consolidation.sourcePubkeys),
                _hashBytesArray(consolidation.targetPubkeys),
                consolidation.totalAmount,
                consolidation.exitEpoch
            )
        );
    }

    function _consolidation(address withdrawalAddress, uint256 seed, uint256 exitEpoch)
        internal
        pure
        returns (IConsolidationAttestationBuffer.ConsolidationObject memory consolidation)
    {
        bytes[] memory sources = new bytes[](2);
        sources[0] = _pubkey(seed);
        sources[1] = _pubkey(seed + 1);

        bytes[] memory targets = new bytes[](2);
        targets[0] = _pubkey(seed + 100);
        targets[1] = _pubkey(seed + 101);

        consolidation = IConsolidationAttestationBuffer.ConsolidationObject({
            withdrawalAddress: withdrawalAddress,
            sourcePubkeys: sources,
            targetPubkeys: targets,
            totalAmount: 64 ether,
            exitEpoch: exitEpoch
        });
    }

    function _invalidPubkeys(uint256 seed, uint256 count) internal pure returns (bytes[] memory invalidPubkeys) {
        invalidPubkeys = new bytes[](count);
        for (uint256 i = 0; i < count; i++) {
            invalidPubkeys[i] = _pubkey(seed + i);
        }
    }

    function test_SubmitSingle_EmitsHashObjectSignatureAndIncrements() public {
        IConsolidationAttestationBuffer.ConsolidationObject memory c = _consolidation(makeAddr("withdrawal"), 1, 12345);
        bytes memory sig = hex"aabbccdd";
        bytes32 consolidationHash = _expectedHash(c);

        assertEq(buffer.computeConsolidationHash(c), consolidationHash);

        vm.expectEmit(true, true, true, true);
        emit ConsolidationAttestationSubmitted(
            0, consolidationHash, c.withdrawalAddress, c.sourcePubkeys, c.targetPubkeys, c.totalAmount, c.exitEpoch, sig
        );

        buffer.submitAttestation(c, sig);

        assertEq(buffer.lastAttestationIdx(), 1);
    }

    function test_IndexIncrements() public {
        assertEq(buffer.lastAttestationIdx(), 0);

        buffer.submitAttestation(_consolidation(address(0x1), 1, 10), hex"01");
        assertEq(buffer.lastAttestationIdx(), 1);

        buffer.submitAttestation(_consolidation(address(0x2), 2, 20), hex"02");
        assertEq(buffer.lastAttestationIdx(), 2);

        buffer.submitAttestation(_consolidation(address(0x3), 3, 30), hex"03");
        assertEq(buffer.lastAttestationIdx(), 3);
    }

    function test_AnyoneCanSubmit() public {
        IConsolidationAttestationBuffer.ConsolidationObject memory c = _consolidation(makeAddr("withdrawal"), 11, 99);

        vm.prank(makeAddr("alice"));
        buffer.submitAttestation(c, hex"aa");
        assertEq(buffer.lastAttestationIdx(), 1);

        vm.prank(makeAddr("bob"));
        buffer.submitAttestation(c, hex"bb");
        assertEq(buffer.lastAttestationIdx(), 2);
    }

    function test_HashChangesWhenOnlyExitEpochChanges() public {
        IConsolidationAttestationBuffer.ConsolidationObject memory early =
            _consolidation(makeAddr("withdrawal"), 21, 1000);
        IConsolidationAttestationBuffer.ConsolidationObject memory late =
            _consolidation(makeAddr("withdrawal"), 21, 1001);

        bytes32 earlyHash = buffer.computeConsolidationHash(early);
        bytes32 lateHash = buffer.computeConsolidationHash(late);

        assertEq(earlyHash, _expectedHash(early));
        assertEq(lateHash, _expectedHash(late));
        assertTrue(earlyHash != lateHash);
    }

    function test_RaiseError_EmitsFlagsStoresInvalidPubkeys() public {
        IConsolidationAttestationBuffer.ConsolidationObject memory c = _consolidation(makeAddr("withdrawal"), 31, 777);
        bytes[] memory invalidPubkeys = _invalidPubkeys(800, 2);
        bytes32 consolidationHash = _expectedHash(c);
        address raiser = makeAddr("committeeMember");

        assertFalse(buffer.isConsolidationErrored(consolidationHash));

        vm.expectEmit(true, false, false, true);
        emit InvalidConsolidationPubkeysRecorded(consolidationHash, invalidPubkeys);
        vm.expectEmit(true, true, true, true);
        emit ConsolidationAttestationError(
            0, consolidationHash, raiser, 42, bytes("source pubkey not exited"), invalidPubkeys
        );

        vm.prank(raiser);
        buffer.raiseError(c, invalidPubkeys, 42, bytes("source pubkey not exited"));

        assertTrue(buffer.isConsolidationErrored(consolidationHash));
        assertEq(buffer.lastErrorIdx(), 1);
        assertEq(buffer.invalidPubkeyCount(consolidationHash), 2);
        assertEq(buffer.invalidPubkeyAt(consolidationHash, 0), invalidPubkeys[0]);
        assertEq(buffer.invalidPubkeyAt(consolidationHash, 1), invalidPubkeys[1]);
        assertTrue(buffer.isInvalidPubkey(invalidPubkeys[0]));
        assertTrue(buffer.isInvalidPubkey(invalidPubkeys[1]));

        bytes[] memory stored = buffer.getInvalidPubkeys(consolidationHash);
        assertEq(stored.length, 2);
        assertEq(stored[0], invalidPubkeys[0]);
        assertEq(stored[1], invalidPubkeys[1]);
    }

    function test_InvalidPubkeyMembershipViews() public {
        IConsolidationAttestationBuffer.ConsolidationObject memory c = _consolidation(makeAddr("withdrawal"), 81, 444);
        bytes[] memory invalidPubkeys = _invalidPubkeys(1200, 2);

        buffer.raiseError(c, invalidPubkeys, 1, hex"01");

        assertTrue(buffer.isInvalidPubkey(invalidPubkeys[0]));
        assertTrue(buffer.isInvalidPubkey(invalidPubkeys[1]));
        assertTrue(buffer.isInvalidPubkeyHash(keccak256(invalidPubkeys[0])));
        assertEq(buffer.isInvalidPubkeyHash(keccak256(invalidPubkeys[0])), buffer.isInvalidPubkey(invalidPubkeys[0]));

        bytes memory unknown = _pubkey(9999);
        assertFalse(buffer.isInvalidPubkey(unknown));
        assertFalse(buffer.isInvalidPubkeyHash(keccak256(unknown)));
    }

    function test_HasInvalidPubkeys_ReturnsTrueForInvalidSourcePubkey() public {
        IConsolidationAttestationBuffer.ConsolidationObject memory sourceHit =
            _consolidation(makeAddr("withdrawal"), 91, 555);
        bytes[] memory invalidPubkeys = new bytes[](1);
        invalidPubkeys[0] = sourceHit.sourcePubkeys[0];

        buffer.raiseError(_consolidation(makeAddr("reporter"), 92, 556), invalidPubkeys, 1, hex"01");

        assertTrue(buffer.hasInvalidPubkeys(sourceHit));
    }

    function test_HasInvalidPubkeys_ReturnsTrueForInvalidTargetPubkey() public {
        IConsolidationAttestationBuffer.ConsolidationObject memory targetHit =
            _consolidation(makeAddr("withdrawal"), 101, 666);
        bytes[] memory invalidPubkeys = new bytes[](1);
        invalidPubkeys[0] = targetHit.targetPubkeys[1];

        buffer.raiseError(_consolidation(makeAddr("reporter"), 102, 667), invalidPubkeys, 1, hex"01");

        assertTrue(buffer.hasInvalidPubkeys(targetHit));
    }

    function test_HasInvalidPubkeys_ReturnsFalseWhenObjectKeysAreNotInvalid() public {
        IConsolidationAttestationBuffer.ConsolidationObject memory clean =
            _consolidation(makeAddr("withdrawal"), 111, 777);
        buffer.raiseError(_consolidation(makeAddr("reporter"), 112, 778), _invalidPubkeys(3000, 2), 1, hex"01");

        assertFalse(buffer.hasInvalidPubkeys(clean));
    }

    function test_SubmitAttestation_RevertsForInvalidSourcePubkey() public {
        IConsolidationAttestationBuffer.ConsolidationObject memory sourceHit =
            _consolidation(makeAddr("withdrawal"), 121, 888);
        bytes[] memory invalidPubkeys = new bytes[](1);
        invalidPubkeys[0] = sourceHit.sourcePubkeys[0];

        buffer.raiseError(_consolidation(makeAddr("reporter"), 122, 889), invalidPubkeys, 1, hex"01");

        vm.expectRevert(
            abi.encodeWithSelector(
                IConsolidationAttestationBuffer.InvalidConsolidationPubkey.selector, invalidPubkeys[0]
            )
        );
        buffer.submitAttestation(sourceHit, hex"aa");

        assertEq(buffer.lastAttestationIdx(), 0);
    }

    function test_SubmitAttestation_RevertsForInvalidTargetPubkey() public {
        IConsolidationAttestationBuffer.ConsolidationObject memory targetHit =
            _consolidation(makeAddr("withdrawal"), 131, 999);
        bytes[] memory invalidPubkeys = new bytes[](1);
        invalidPubkeys[0] = targetHit.targetPubkeys[1];

        buffer.raiseError(_consolidation(makeAddr("reporter"), 132, 1000), invalidPubkeys, 1, hex"01");

        vm.expectRevert(
            abi.encodeWithSelector(
                IConsolidationAttestationBuffer.InvalidConsolidationPubkey.selector, invalidPubkeys[0]
            )
        );
        buffer.submitAttestation(targetHit, hex"bb");

        assertEq(buffer.lastAttestationIdx(), 0);
    }

    function test_RaiseError_AnyoneCanRaise() public {
        vm.prank(makeAddr("alice"));
        buffer.raiseError(_consolidation(address(0xA11CE), 41, 1), _invalidPubkeys(1, 1), 1, hex"01");

        vm.prank(makeAddr("bob"));
        buffer.raiseError(_consolidation(address(0xB0B), 42, 2), _invalidPubkeys(2, 1), 2, hex"02");

        assertEq(buffer.lastErrorIdx(), 2);
    }

    function test_RaiseError_ReRaiseEmitsAgainAndPreservesFirstStoredInvalidPubkeys() public {
        IConsolidationAttestationBuffer.ConsolidationObject memory c = _consolidation(makeAddr("withdrawal"), 51, 888);
        bytes[] memory firstInvalidPubkeys = _invalidPubkeys(900, 2);
        bytes[] memory secondInvalidPubkeys = _invalidPubkeys(950, 1);
        bytes32 consolidationHash = _expectedHash(c);

        buffer.raiseError(c, firstInvalidPubkeys, 1, hex"01");

        vm.expectEmit(true, true, true, true);
        emit ConsolidationAttestationError(1, consolidationHash, address(this), 2, hex"02", secondInvalidPubkeys);
        buffer.raiseError(c, secondInvalidPubkeys, 2, hex"02");

        assertTrue(buffer.isConsolidationErrored(consolidationHash));
        assertEq(buffer.lastErrorIdx(), 2);
        assertEq(buffer.invalidPubkeyCount(consolidationHash), 2);
        assertEq(buffer.invalidPubkeyAt(consolidationHash, 0), firstInvalidPubkeys[0]);
        assertEq(buffer.invalidPubkeyAt(consolidationHash, 1), firstInvalidPubkeys[1]);
        assertTrue(buffer.isInvalidPubkey(firstInvalidPubkeys[0]));
        assertTrue(buffer.isInvalidPubkey(firstInvalidPubkeys[1]));
        assertFalse(buffer.isInvalidPubkey(secondInvalidPubkeys[0]));
    }

    function test_SubmitAttestation_RevertsAfterFlag() public {
        IConsolidationAttestationBuffer.ConsolidationObject memory c = _consolidation(makeAddr("withdrawal"), 61, 999);
        bytes32 consolidationHash = _expectedHash(c);

        buffer.raiseError(c, _invalidPubkeys(1000, 1), 1, hex"aa");

        vm.expectRevert(
            abi.encodeWithSelector(IConsolidationAttestationBuffer.ConsolidationNotReady.selector, consolidationHash)
        );
        buffer.submitAttestation(c, hex"bb");
    }

    function test_SubmitAttestation_UnflaggedDifferentExitEpochStillWorks() public {
        IConsolidationAttestationBuffer.ConsolidationObject memory flagged =
            _consolidation(makeAddr("withdrawal"), 71, 100);
        IConsolidationAttestationBuffer.ConsolidationObject memory other =
            _consolidation(makeAddr("withdrawal"), 71, 101);
        bytes32 flaggedHash = _expectedHash(flagged);
        bytes32 otherHash = _expectedHash(other);

        buffer.raiseError(flagged, _invalidPubkeys(1100, 1), 1, hex"aa");

        buffer.submitAttestation(other, hex"bb");
        assertEq(buffer.lastAttestationIdx(), 1);
        assertTrue(buffer.isConsolidationErrored(flaggedHash));
        assertFalse(buffer.isConsolidationErrored(otherHash));
    }

    function test_UnknownHashReturnsFalseAndEmptyInvalidPubkeys() public {
        bytes32 neverSeen = keccak256("never-seen");

        assertFalse(buffer.isConsolidationErrored(neverSeen));
        assertEq(buffer.invalidPubkeyCount(neverSeen), 0);

        bytes[] memory stored = buffer.getInvalidPubkeys(neverSeen);
        assertEq(stored.length, 0);
    }
}
