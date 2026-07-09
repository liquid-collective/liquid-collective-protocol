// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "forge-std/Test.sol";

import "../src/AttestationBuffer.sol";

/// @title AttestationBufferTest
/// @notice Unit coverage for the AttestationBuffer event relay, ported from the frontrun-mitigation
///         suite. Includes an ecrecover round-trip proving a signer can be recovered purely from the
///         emitted event data (the off-chain collection path).
contract AttestationBufferTest is Test {
    AttestationBuffer internal buffer;

    event AttestationSubmitted(
        uint256 indexed idx, bytes32 indexed depositDataBufferId, bytes32 depositRootHash, bytes signature
    );

    function setUp() public {
        buffer = new AttestationBuffer();
    }

    // -----------------------------------------------------------------------
    // submitAttestation — single
    // -----------------------------------------------------------------------

    function test_SubmitSingle() public {
        bytes32 depositDataBufferId = keccak256("deposit-data-1");
        bytes32 depositRootHash = keccak256("deposit-root-1");
        bytes memory sig = hex"aabbccdd";

        vm.expectEmit(true, true, false, true);
        emit AttestationSubmitted(0, depositDataBufferId, depositRootHash, sig);

        buffer.submitAttestation(depositDataBufferId, depositRootHash, sig);

        assertEq(buffer.lastAttestationIdx(), 1);
    }

    // -----------------------------------------------------------------------
    // submitAttestation — multiple, index increments
    // -----------------------------------------------------------------------

    function test_IndexIncrements() public {
        assertEq(buffer.lastAttestationIdx(), 0);

        buffer.submitAttestation(keccak256("data-1"), keccak256("root-1"), hex"01");
        assertEq(buffer.lastAttestationIdx(), 1);

        buffer.submitAttestation(keccak256("data-2"), keccak256("root-2"), hex"02");
        assertEq(buffer.lastAttestationIdx(), 2);

        buffer.submitAttestation(keccak256("data-3"), keccak256("root-3"), hex"03");
        assertEq(buffer.lastAttestationIdx(), 3);
    }

    // -----------------------------------------------------------------------
    // Anyone can submit (no access control)
    // -----------------------------------------------------------------------

    function test_AnyoneCanSubmit() public {
        bytes32 depositDataBufferId = keccak256("data");
        bytes32 depositRootHash = keccak256("root");
        bytes memory sig = hex"ff";

        vm.prank(makeAddr("alice"));
        buffer.submitAttestation(depositDataBufferId, depositRootHash, sig);
        assertEq(buffer.lastAttestationIdx(), 1);

        vm.prank(makeAddr("bob"));
        buffer.submitAttestation(depositDataBufferId, depositRootHash, sig);
        assertEq(buffer.lastAttestationIdx(), 2);

        vm.prank(makeAddr("charlie"));
        buffer.submitAttestation(depositDataBufferId, depositRootHash, sig);
        assertEq(buffer.lastAttestationIdx(), 3);
    }

    // -----------------------------------------------------------------------
    // lastAttestationIdx reads correctly
    // -----------------------------------------------------------------------

    function test_LastAttestationIdxStartsAtZero() public {
        assertEq(buffer.lastAttestationIdx(), 0);
    }

    // -----------------------------------------------------------------------
    // Event indexed fields
    // -----------------------------------------------------------------------

    function test_EventIndexedFields() public {
        bytes32 depositDataBufferId = keccak256("indexed-data");
        bytes32 depositRootHash = keccak256("indexed-root");
        bytes memory sig = hex"deadbeef";

        // First attestation: idx=0
        vm.expectEmit(true, true, false, true);
        emit AttestationSubmitted(0, depositDataBufferId, depositRootHash, sig);
        buffer.submitAttestation(depositDataBufferId, depositRootHash, sig);

        // Second attestation with different hashes: idx=1
        bytes32 depositDataBufferId2 = keccak256("indexed-data-2");
        bytes32 depositRootHash2 = keccak256("indexed-root-2");
        bytes memory sig2 = hex"cafebabe";

        vm.expectEmit(true, true, false, true);
        emit AttestationSubmitted(1, depositDataBufferId2, depositRootHash2, sig2);
        buffer.submitAttestation(depositDataBufferId2, depositRootHash2, sig2);
    }

    // -----------------------------------------------------------------------
    // ecrecover from event data
    // -----------------------------------------------------------------------

    function _recoverFromSig(bytes32 ethSignedHash, bytes memory emittedSig) internal pure returns (address) {
        bytes32 r;
        bytes32 s;
        uint8 v;
        assembly {
            r := mload(add(emittedSig, 0x20))
            s := mload(add(emittedSig, 0x40))
            v := byte(0, mload(add(emittedSig, 0x60)))
        }
        return ecrecover(ethSignedHash, v, r, s);
    }

    function test_EcrecoverSignerFromEvent() public {
        // 1. Create a known signer with a private key.
        uint256 signerPk = 0xA11CE;
        address signer = vm.addr(signerPk);

        // 2. Build the message the signer attests to.
        bytes32 depositDataBufferId = keccak256("ecrecover-data");
        bytes32 depositRootHash = keccak256("ecrecover-root");

        bytes32 digest = keccak256(abi.encodePacked(depositDataBufferId, depositRootHash));
        bytes32 ethSignedHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", digest));

        // 3. Sign it.
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPk, ethSignedHash);

        // 4. Submit and record logs.
        vm.recordLogs();
        vm.prank(signer);
        buffer.submitAttestation(depositDataBufferId, depositRootHash, abi.encodePacked(r, s, v));

        // 5. Extract the event data.
        Vm.Log[] memory logs = vm.getRecordedLogs();
        assertEq(logs.length, 1);

        (bytes32 emittedRootHash, bytes memory emittedSig) = abi.decode(logs[0].data, (bytes32, bytes));
        bytes32 emittedDepositDataHash = logs[0].topics[2];

        // 6. Reconstruct the digest and ecrecover from the emitted data alone.
        assertEq(emittedSig.length, 65);
        bytes32 recoveredEthSignedHash = keccak256(
            abi.encodePacked(
                "\x19Ethereum Signed Message:\n32", keccak256(abi.encodePacked(emittedDepositDataHash, emittedRootHash))
            )
        );

        // 7. The recovered address must match the original signer.
        assertEq(_recoverFromSig(recoveredEthSignedHash, emittedSig), signer);
    }

    // -----------------------------------------------------------------------
    // Faulty-batch signal — "unhappy path" via depositRootHash == 0
    //
    // There is no separate veto function. A faulty batch is flagged by submitting an ordinary
    // attestation whose depositRootHash is zero; the buffer treats it like any other submission
    // (no special-casing, no revert). Authentication and interpretation happen off-chain.
    // -----------------------------------------------------------------------

    function test_SubmitAttestation_FaultyRootIsAnOrdinarySubmission() public {
        bytes32 depositDataBufferId = keccak256("bad-batch");
        bytes memory sig = hex"aabbccdd";

        // A zero root is emitted as-is and advances the index like any other attestation.
        vm.expectEmit(true, true, false, true);
        emit AttestationSubmitted(0, depositDataBufferId, bytes32(0), sig);

        vm.prank(makeAddr("committeeMember"));
        buffer.submitAttestation(depositDataBufferId, bytes32(0), sig);

        assertEq(buffer.lastAttestationIdx(), 1);
    }

    /// @dev A faulty (root=0) attestation does not block later attestations for the same id: the
    ///      buffer keeps no per-id state, so aggregation is never stopped on-chain.
    function test_SubmitAttestation_FaultyRootDoesNotBlockLaterSubmissions() public {
        bytes32 depositDataBufferId = keccak256("batch");

        buffer.submitAttestation(depositDataBufferId, bytes32(0), hex"aa"); // faulty signal
        buffer.submitAttestation(depositDataBufferId, keccak256("root"), hex"bb"); // still accepted

        assertEq(buffer.lastAttestationIdx(), 2);
    }
}
