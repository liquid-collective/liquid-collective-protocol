// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "forge-std/Test.sol";

import "../src/ConsolidationAttestationBuffer.sol";

/// @title ConsolidationAttestationBufferTest
/// @notice Unit coverage for the consolidation attestation event relay.
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
}
