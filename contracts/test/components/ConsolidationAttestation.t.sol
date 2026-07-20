// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "forge-std/Test.sol";

import "../../src/AttestationVerifier.1.sol";
import "../../src/ConsolidationAttestation.sol";
import "../../src/interfaces/IAttestationVerifier.1.sol";
import "../../src/interfaces/IConsolidationAttestation.sol";
import "../../src/libraries/LibErrors.sol";
import "../utils/LibImplementationUnbricker.sol";

// ---------------------------------------------------------------------------
// Minimal River admin mock — exposes getAdmin() so AttestationVerifierV1's
// `onlyRiverAdmin` cross-contract lookup resolves to a known admin EOA.
// ---------------------------------------------------------------------------

contract MockRiverAdmin {
    address internal immutable _admin;

    constructor(address admin_) {
        _admin = admin_;
    }

    function getAdmin() external view returns (address) {
        return _admin;
    }
}

contract ConsolidationDepositBufferStub {
    address internal immutable _processor;

    constructor(address processor_) {
        _processor = processor_;
    }

    function getProcessor() external view returns (address) {
        return _processor;
    }
}

contract AttestationVerifierBytesEqualHarness is AttestationVerifierV1 {
    function exposedBytesEqual(bytes calldata a, bytes calldata b) external pure returns (bool) {
        return _bytesEqual(a, b);
    }
}

// ---------------------------------------------------------------------------
// ConsolidationAttestationTest — exercises the consolidation half of
// AttestationVerifierV1. The verifier now takes a `ConsolidationObject` directly
// in calldata; there is no on-chain consolidation buffer.
//
// Setup performs a single combined init. Tests focus on:
//   - happy paths (struct passed directly)
//   - structural validation (lengths, zero fields, pubkey lengths)
//   - bufferId derivation excludes signatures
//   - signature verification (quorum, duplicates, non-committee, malformed)
//   - admin setters
//   - isolation from the deposit flow
// ---------------------------------------------------------------------------

contract ConsolidationAttestationTest is Test {
    AttestationVerifierV1 internal verifier;
    MockRiverAdmin internal river;

    address internal admin = address(0xAD);
    address internal depositBufferStub;

    uint256 internal pk1 = 0xC1;
    uint256 internal pk2 = 0xC2;
    uint256 internal pk3 = 0xC3;
    address internal attester1;
    address internal attester2;
    address internal attester3;

    address internal depositAttester = address(0xD1);

    // EIP-712 constants (must match AttestationVerifierV1)
    bytes32 internal constant EIP712_DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    bytes32 internal constant CONSOLIDATION_NAME_HASH = keccak256("ConsolidationValidation");
    bytes32 internal constant VERSION_HASH = keccak256("1");
    bytes32 internal constant ATTEST_CONSOLIDATION_TYPEHASH = keccak256(
        "AttestConsolidation(address withdrawalAddress,bytes[] sourcePubkeys,bytes[] targetPubkeys,uint256 totalAmount,uint256[] exitEpoch)"
    );

    // Storage slots (must match contracts/src/state/attestationVerifier/*)
    bytes32 internal constant CONSOLIDATION_DOMAIN_SEPARATOR_SLOT =
        bytes32(uint256(keccak256("attestationVerifier.state.consolidationDomainSeparator")) - 1);
    bytes32 internal constant CONSOLIDATION_COMMITTEE_ATTESTATION_QUORUM_SLOT =
        bytes32(uint256(keccak256("attestationVerifier.state.consolidationCommitteeAttestationQuorum")) - 1);

    function setUp() public {
        attester1 = vm.addr(pk1);
        attester2 = vm.addr(pk2);
        attester3 = vm.addr(pk3);

        river = new MockRiverAdmin(admin);
        // The consolidation tests do not exercise the deposit validation path. The verifier
        // init guard only needs a buffer-shaped contract whose processor is River.
        depositBufferStub = address(new ConsolidationDepositBufferStub(address(river)));

        verifier = new AttestationVerifierV1();
        LibImplementationUnbricker.unbrick(vm, address(verifier));

        address[] memory depCommittee = new address[](1);
        depCommittee[0] = depositAttester;
        address[] memory cCommittee = new address[](3);
        cCommittee[0] = attester1;
        cCommittee[1] = attester2;
        cCommittee[2] = attester3;
        verifier.initAttestationVerifierV1(address(river), depositBufferStub, depCommittee, 1, bytes4(0), cCommittee, 2);
    }

    /// @dev Deploy + unbrick a fresh verifier.
    function _deployFreshVerifier() internal returns (AttestationVerifierV1 fresh) {
        fresh = new AttestationVerifierV1();
        LibImplementationUnbricker.unbrick(vm, address(fresh));
    }

    /// @dev Init a fresh verifier with the provided consolidation params, reusing a valid
    ///      1-attester deposit committee. Internal so `vm.expectRevert` pierces through to
    ///      the init external call.
    function _initFreshWithConsolidationParams(
        AttestationVerifierV1 fresh,
        address[] memory consolidationCommittee,
        uint256 consolidationQuorum
    ) internal {
        address[] memory dep = new address[](1);
        dep[0] = depositAttester;
        fresh.initAttestationVerifierV1(
            address(river), depositBufferStub, dep, 1, bytes4(0), consolidationCommittee, consolidationQuorum
        );
    }

    // -----------------------------------------------------------------------
    // Helpers
    // -----------------------------------------------------------------------

    /// @dev 48-byte deterministic pubkey.
    function _pubkey(uint256 seed) internal pure returns (bytes memory) {
        return abi.encodePacked(sha256(abi.encode("pubkey", seed)), bytes16(0));
    }

    /// @dev Wrong-length pubkey for negative tests.
    function _pubkeyOfLength(uint256 seed, uint256 len) internal pure returns (bytes memory out) {
        out = new bytes(len);
        bytes32 src = sha256(abi.encode("pubkey", seed));
        for (uint256 i = 0; i < len; i++) {
            out[i] = src[i % 32];
        }
    }

    /// @dev EIP-712 array-hash for a `bytes[]`. Mirrors `AttestationVerifierV1._hashBytesArray`.
    function _hashBytesArray(bytes[] memory arr) internal pure returns (bytes32) {
        bytes32[] memory hashes = new bytes32[](arr.length);
        for (uint256 i = 0; i < arr.length; i++) {
            hashes[i] = keccak256(arr[i]);
        }
        return keccak256(abi.encodePacked(hashes));
    }

    /// @dev EIP-712 array-hash for a `uint256[]`. Mirrors `AttestationVerifierV1._hashUintArray`.
    function _hashUintArray(uint256[] memory arr) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(arr));
    }

    /// @dev Canonical per-pair exit-epoch array used by the test helpers: one zero entry per
    ///      consolidation pair. The verifier binds this array in the digest, so objects and
    ///      digests must use the same array.
    function _defaultEpochs(uint256 count) internal pure returns (uint256[] memory arr) {
        arr = new uint256[](count);
    }

    /// @dev Compute the EIP-712 digest the consolidation committee is expected to sign,
    ///      derived directly from the request fields (no intermediate bufferId).
    function _consolidationDigest(
        address withdrawalAddress,
        bytes[] memory sources,
        bytes[] memory targets,
        uint256 totalAmount
    ) internal view returns (bytes32) {
        return _consolidationDigest(withdrawalAddress, sources, targets, totalAmount, _defaultEpochs(sources.length));
    }

    function _consolidationDigest(
        address withdrawalAddress,
        bytes[] memory sources,
        bytes[] memory targets,
        uint256 totalAmount,
        uint256[] memory exitEpoch
    ) internal view returns (bytes32) {
        bytes32 domainSep = keccak256(
            abi.encode(EIP712_DOMAIN_TYPEHASH, CONSOLIDATION_NAME_HASH, VERSION_HASH, block.chainid, address(river))
        );
        bytes32 structHash = _consolidationStructHash(withdrawalAddress, sources, targets, totalAmount, exitEpoch);
        return keccak256(abi.encodePacked("\x19\x01", domainSep, structHash));
    }

    function _consolidationStructHash(
        address withdrawalAddress,
        bytes[] memory sources,
        bytes[] memory targets,
        uint256 totalAmount
    ) internal pure returns (bytes32) {
        return _consolidationStructHash(
            withdrawalAddress, sources, targets, totalAmount, _defaultEpochs(sources.length)
        );
    }

    function _consolidationStructHash(
        address withdrawalAddress,
        bytes[] memory sources,
        bytes[] memory targets,
        uint256 totalAmount,
        uint256[] memory exitEpoch
    ) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                ATTEST_CONSOLIDATION_TYPEHASH,
                withdrawalAddress,
                _hashBytesArray(sources),
                _hashBytesArray(targets),
                totalAmount,
                _hashUintArray(exitEpoch)
            )
        );
    }

    /// @dev Sign a precomputed EIP-712 digest with the given private key.
    function _sign(uint256 pk, bytes32 digest) internal view returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, digest);
        return abi.encodePacked(r, s, v);
    }

    /// @dev Build a single-pair consolidation object with two valid signatures (attester1 + attester2).
    function _validConsolidation(address withdrawalAddress, uint256 seed)
        internal
        view
        returns (IAttestationVerifierV1.ConsolidationObject memory consolidation)
    {
        bytes[] memory sources = new bytes[](1);
        sources[0] = _pubkey(seed);
        bytes[] memory targets = new bytes[](1);
        targets[0] = _pubkey(seed + 1000);
        uint256 totalAmount = 32 ether;

        bytes32 bufferId = _consolidationDigest(withdrawalAddress, sources, targets, totalAmount);

        bytes[] memory sigs = new bytes[](2);
        sigs[0] = _sign(pk1, bufferId);
        sigs[1] = _sign(pk2, bufferId);

        consolidation = IAttestationVerifierV1.ConsolidationObject({
            withdrawalAddress: withdrawalAddress,
            sourcePubkeys: sources,
            targetPubkeys: targets,
            totalAmount: totalAmount,
            exitEpoch: _defaultEpochs(sources.length),
            signatures: sigs
        });
    }

    function _validateConsolidationAsRiver(IAttestationVerifierV1.ConsolidationObject memory consolidation) internal {
        vm.prank(address(river));
        verifier.validateConsolidation(consolidation);
    }

    // -----------------------------------------------------------------------
    // Internal helper coverage
    // -----------------------------------------------------------------------

    function testBytesEqual_returnsFalseForDifferentLengths() public {
        AttestationVerifierBytesEqualHarness harness = new AttestationVerifierBytesEqualHarness();

        assertFalse(harness.exposedBytesEqual(hex"0102", hex"010203"));
    }

    function testBytesEqual_returnsFalseForSameLengthDifferentBytes() public {
        AttestationVerifierBytesEqualHarness harness = new AttestationVerifierBytesEqualHarness();

        assertFalse(harness.exposedBytesEqual(hex"010203", hex"010204"));
    }

    // -----------------------------------------------------------------------
    // Happy-path tests
    // -----------------------------------------------------------------------

    function testValidateConsolidation_singlePair_quorumMet() public {
        address user = address(0xBEEF);
        IAttestationVerifierV1.ConsolidationObject memory c = _validConsolidation(user, 1);
        _validateConsolidationAsRiver(c);
    }

    /// @dev Approval signatures accepted and emitted by the L2 relay must be consumable byte-for-byte
    ///      by the L1 verifier. `exitEpoch` is part of the shared five-field digest, so both sides
    ///      must carry the identical array.
    function testL2ApprovalSignaturesAreAcceptedByL1() public {
        address withdrawalAddress = address(0xBEEF);
        bytes[] memory sources = new bytes[](1);
        sources[0] = _pubkey(101);
        bytes[] memory targets = new bytes[](1);
        targets[0] = _pubkey(1101);
        uint256 totalAmount = 32 ether;
        uint256[] memory exitEpoch = _epochs(12345);

        ConsolidationAttestation relay = new ConsolidationAttestation(verifier.getConsolidationDomainSeparator());
        IConsolidationAttestation.ConsolidationObject memory relayConsolidation =
            IConsolidationAttestation.ConsolidationObject({
                withdrawalAddress: withdrawalAddress,
                sourcePubkeys: sources,
                targetPubkeys: targets,
                totalAmount: totalAmount,
                exitEpoch: exitEpoch
            });

        bytes32 structHash = _consolidationStructHash(withdrawalAddress, sources, targets, totalAmount, exitEpoch);
        bytes32 digest = _consolidationDigest(withdrawalAddress, sources, targets, totalAmount, exitEpoch);
        bytes[] memory signatures = new bytes[](2);
        signatures[0] = _sign(pk1, digest);
        signatures[1] = _sign(pk2, digest);

        assertEq(relay.computeConsolidationHash(relayConsolidation), structHash);

        vm.prank(attester1);
        relay.submitAttestation(relayConsolidation, signatures[0], "");
        vm.prank(attester2);
        relay.submitAttestation(relayConsolidation, signatures[1], "");
        assertEq(relay.lastAttestationIdx(), 2);

        IAttestationVerifierV1.ConsolidationObject memory l1Consolidation = IAttestationVerifierV1.ConsolidationObject({
            withdrawalAddress: withdrawalAddress,
            sourcePubkeys: sources,
            targetPubkeys: targets,
            totalAmount: totalAmount,
            exitEpoch: exitEpoch,
            signatures: signatures
        });
        _validateConsolidationAsRiver(l1Consolidation);
    }

    /// @dev A single-element exit-epoch helper for tests that bind a specific epoch.
    function _epochs(uint256 value) internal pure returns (uint256[] memory arr) {
        arr = new uint256[](1);
        arr[0] = value;
    }

    function testValidateConsolidation_multiplePairs_succeeds() public {
        address user = address(0xCAFE);
        bytes[] memory sources = new bytes[](3);
        bytes[] memory targets = new bytes[](3);
        for (uint256 i = 0; i < 3; i++) {
            sources[i] = _pubkey(100 + i);
            targets[i] = _pubkey(200 + i);
        }
        uint256 totalAmount = 96 ether;
        bytes32 id = _consolidationDigest(user, sources, targets, totalAmount);

        bytes[] memory sigs = new bytes[](3);
        sigs[0] = _sign(pk1, id);
        sigs[1] = _sign(pk2, id);
        sigs[2] = _sign(pk3, id);

        IAttestationVerifierV1.ConsolidationObject memory c = IAttestationVerifierV1.ConsolidationObject({
            withdrawalAddress: user,
            sourcePubkeys: sources,
            targetPubkeys: targets,
            totalAmount: totalAmount,
            exitEpoch: _defaultEpochs(sources.length),
            signatures: sigs
        });
        _validateConsolidationAsRiver(c);
    }

    function testValidateConsolidation_exactlyQuorumSignatures() public {
        // Quorum is 2; supplying exactly 2 valid signatures should pass.
        address user = address(0x11);
        IAttestationVerifierV1.ConsolidationObject memory c = _validConsolidation(user, 7);
        _validateConsolidationAsRiver(c);
    }

    function testRevert_validateConsolidation_onlyRiver() public {
        IAttestationVerifierV1.ConsolidationObject memory c = _validConsolidation(address(0xBEEF), 123);
        vm.expectRevert(abi.encodeWithSelector(LibErrors.Unauthorized.selector, address(this)));
        verifier.validateConsolidation(c);
    }

    // -----------------------------------------------------------------------
    // Init / config tests
    // -----------------------------------------------------------------------

    function testInit_revertEmptyAttesterArray() public {
        AttestationVerifierV1 fresh = _deployFreshVerifier();
        address[] memory empty = new address[](0);
        vm.expectRevert(LibErrors.InvalidArgument.selector);
        _initFreshWithConsolidationParams(fresh, empty, 1);
    }

    function testInit_revertTooManyAttesters() public {
        AttestationVerifierV1 fresh = _deployFreshVerifier();
        address[] memory many = new address[](33);
        for (uint256 i = 0; i < 33; i++) {
            many[i] = address(uint160(0x1000 + i));
        }
        vm.expectRevert(LibErrors.InvalidArgument.selector);
        _initFreshWithConsolidationParams(fresh, many, 1);
    }

    function testInit_revertZeroQuorum() public {
        AttestationVerifierV1 fresh = _deployFreshVerifier();
        address[] memory cc = new address[](1);
        cc[0] = attester1;
        vm.expectRevert(IAttestationVerifierV1.ZeroQuorum.selector);
        _initFreshWithConsolidationParams(fresh, cc, 0);
    }

    function testInit_revertQuorumExceedsMaxSignatures() public {
        AttestationVerifierV1 fresh = _deployFreshVerifier();
        address[] memory cc = new address[](32);
        for (uint256 i = 0; i < 32; i++) {
            cc[i] = address(uint160(0x2000 + i));
        }
        vm.expectRevert(
            abi.encodeWithSelector(
                IAttestationVerifierV1.QuorumExceedsMaxSignatures.selector, 21, verifier.MAX_SIGNATURES()
            )
        );
        _initFreshWithConsolidationParams(fresh, cc, 21);
    }

    function testInit_revertQuorumExceedsAttesterCount() public {
        AttestationVerifierV1 fresh = _deployFreshVerifier();
        address[] memory cc = new address[](2);
        cc[0] = attester1;
        cc[1] = attester2;
        vm.expectRevert(
            abi.encodeWithSelector(
                IAttestationVerifierV1.QuorumExceedsConsolidationCommitteeAttesterCount.selector, 3, 2
            )
        );
        _initFreshWithConsolidationParams(fresh, cc, 3);
    }

    function testInit_revertAlreadyInitialized() public {
        // setUp already called init — calling it again must revert.
        address[] memory dep = new address[](1);
        dep[0] = depositAttester;
        address[] memory cc = new address[](1);
        cc[0] = attester1;
        vm.expectRevert(abi.encodeWithSignature("InvalidInitialization(uint256,uint256)", 0, 1));
        verifier.initAttestationVerifierV1(address(river), depositBufferStub, dep, 1, bytes4(0), cc, 1);
    }

    function testInit_consolidationDomainSeparatorDiffersFromDeposit() public {
        bytes32 depositDS = verifier.getDomainSeparator();
        bytes32 consolidationDS = verifier.getConsolidationDomainSeparator();
        assertTrue(depositDS != consolidationDS, "consolidation domain separator must differ from deposit's");
        assertTrue(consolidationDS != bytes32(0), "consolidation domain separator must be set");
    }

    function testInit_setsAttesterCount() public {
        assertEq(verifier.getConsolidationCommitteeAttesterCount(), 3);
        assertTrue(verifier.isConsolidationCommitteeAttester(attester1));
        assertTrue(verifier.isConsolidationCommitteeAttester(attester2));
        assertTrue(verifier.isConsolidationCommitteeAttester(attester3));
        assertEq(verifier.getConsolidationCommitteeAttestationQuorum(), 2);
    }

    function testInit_revertZeroRiver() public {
        AttestationVerifierV1 fresh = _deployFreshVerifier();
        address[] memory dep = new address[](1);
        dep[0] = depositAttester;
        address[] memory cc = new address[](1);
        cc[0] = attester1;
        // RiverAddress.set calls LibSanitize._notZeroAddress before writing the slot.
        vm.expectRevert(LibErrors.InvalidZeroAddress.selector);
        fresh.initAttestationVerifierV1(address(0), depositBufferStub, dep, 1, bytes4(0), cc, 1);
    }

    function testInit_revertZeroAttesterInArray() public {
        AttestationVerifierV1 fresh = _deployFreshVerifier();
        // Length-2 array containing address(0) — passes the length bounds check, then
        // fails inside the registration loop when setConsolidationCommitteeAttester
        // calls LibSanitize._notZeroAddress.
        address[] memory cc = new address[](2);
        cc[0] = address(0);
        cc[1] = attester1;
        vm.expectRevert(LibErrors.InvalidZeroAddress.selector);
        _initFreshWithConsolidationParams(fresh, cc, 1);
    }

    // -----------------------------------------------------------------------
    // Structural validation tests
    // -----------------------------------------------------------------------

    function testRevert_emptySourcePubkeys() public {
        bytes[] memory empty = new bytes[](0);
        IAttestationVerifierV1.ConsolidationObject memory c = IAttestationVerifierV1.ConsolidationObject({
            withdrawalAddress: address(0xAA),
            sourcePubkeys: empty,
            targetPubkeys: empty,
            totalAmount: 1 ether,
            exitEpoch: _defaultEpochs(empty.length),
            signatures: new bytes[](0)
        });
        vm.expectRevert(IAttestationVerifierV1.NoConsolidations.selector);
        _validateConsolidationAsRiver(c);
    }

    function testRevert_sourceTargetLengthMismatch() public {
        bytes[] memory sources = new bytes[](2);
        sources[0] = _pubkey(1);
        sources[1] = _pubkey(2);
        bytes[] memory targets = new bytes[](1);
        targets[0] = _pubkey(3);

        IAttestationVerifierV1.ConsolidationObject memory c = IAttestationVerifierV1.ConsolidationObject({
            withdrawalAddress: address(0xAA),
            sourcePubkeys: sources,
            targetPubkeys: targets,
            totalAmount: 32 ether,
            exitEpoch: _defaultEpochs(sources.length),
            signatures: new bytes[](0)
        });
        vm.expectRevert(abi.encodeWithSelector(IAttestationVerifierV1.ConsolidationArrayLengthMismatch.selector, 2, 1));
        _validateConsolidationAsRiver(c);
    }

    function testRevert_zeroTotalAmount() public {
        bytes[] memory sources = new bytes[](1);
        sources[0] = _pubkey(1);
        bytes[] memory targets = new bytes[](1);
        targets[0] = _pubkey(2);

        IAttestationVerifierV1.ConsolidationObject memory c = IAttestationVerifierV1.ConsolidationObject({
            withdrawalAddress: address(0xAA),
            sourcePubkeys: sources,
            targetPubkeys: targets,
            totalAmount: 0,
            exitEpoch: _defaultEpochs(sources.length),
            signatures: new bytes[](0)
        });
        vm.expectRevert(IAttestationVerifierV1.ZeroConsolidationTotalAmount.selector);
        _validateConsolidationAsRiver(c);
    }

    function testRevert_zeroWithdrawalAddress() public {
        bytes[] memory sources = new bytes[](1);
        sources[0] = _pubkey(1);
        bytes[] memory targets = new bytes[](1);
        targets[0] = _pubkey(2);

        IAttestationVerifierV1.ConsolidationObject memory c = IAttestationVerifierV1.ConsolidationObject({
            withdrawalAddress: address(0),
            sourcePubkeys: sources,
            targetPubkeys: targets,
            totalAmount: 32 ether,
            exitEpoch: _defaultEpochs(sources.length),
            signatures: new bytes[](0)
        });
        vm.expectRevert(IAttestationVerifierV1.ZeroConsolidationWithdrawalAddress.selector);
        _validateConsolidationAsRiver(c);
    }

    function testRevert_sourcePubkeyWrongLength() public {
        bytes[] memory sources = new bytes[](1);
        sources[0] = _pubkeyOfLength(1, 47);
        bytes[] memory targets = new bytes[](1);
        targets[0] = _pubkey(2);

        IAttestationVerifierV1.ConsolidationObject memory c = IAttestationVerifierV1.ConsolidationObject({
            withdrawalAddress: address(0xAA),
            sourcePubkeys: sources,
            targetPubkeys: targets,
            totalAmount: 32 ether,
            exitEpoch: _defaultEpochs(sources.length),
            signatures: new bytes[](0)
        });
        vm.expectRevert(
            abi.encodeWithSelector(IAttestationVerifierV1.InvalidConsolidationPubkeyLength.selector, 0, 47, true)
        );
        _validateConsolidationAsRiver(c);
    }

    function testRevert_zeroSourcePubkey() public {
        bytes[] memory sources = new bytes[](1);
        sources[0] = new bytes(48);
        bytes[] memory targets = new bytes[](1);
        targets[0] = _pubkey(2);

        IAttestationVerifierV1.ConsolidationObject memory c = IAttestationVerifierV1.ConsolidationObject({
            withdrawalAddress: address(0xAA),
            sourcePubkeys: sources,
            targetPubkeys: targets,
            totalAmount: 32 ether,
            exitEpoch: _defaultEpochs(sources.length),
            signatures: new bytes[](0)
        });
        vm.expectRevert(abi.encodeWithSelector(IAttestationVerifierV1.ZeroConsolidationSourcePubkey.selector, 0));
        _validateConsolidationAsRiver(c);
    }

    function testRevert_targetPubkeyWrongLength() public {
        bytes[] memory sources = new bytes[](1);
        sources[0] = _pubkey(1);
        bytes[] memory targets = new bytes[](1);
        targets[0] = _pubkeyOfLength(2, 49);

        IAttestationVerifierV1.ConsolidationObject memory c = IAttestationVerifierV1.ConsolidationObject({
            withdrawalAddress: address(0xAA),
            sourcePubkeys: sources,
            targetPubkeys: targets,
            totalAmount: 32 ether,
            exitEpoch: _defaultEpochs(sources.length),
            signatures: new bytes[](0)
        });
        vm.expectRevert(
            abi.encodeWithSelector(IAttestationVerifierV1.InvalidConsolidationPubkeyLength.selector, 0, 49, false)
        );
        _validateConsolidationAsRiver(c);
    }

    function testRevert_sourcePubkeyLengthCheckedBeforeDomainSeparator() public {
        vm.store(address(verifier), CONSOLIDATION_DOMAIN_SEPARATOR_SLOT, bytes32(0));

        bytes[] memory sources = new bytes[](1);
        sources[0] = _pubkeyOfLength(1, 47);
        bytes[] memory targets = new bytes[](1);
        targets[0] = _pubkey(2);

        IAttestationVerifierV1.ConsolidationObject memory c = IAttestationVerifierV1.ConsolidationObject({
            withdrawalAddress: address(0xAA),
            sourcePubkeys: sources,
            targetPubkeys: targets,
            totalAmount: 32 ether,
            exitEpoch: _defaultEpochs(sources.length),
            signatures: new bytes[](0)
        });
        vm.expectRevert(
            abi.encodeWithSelector(IAttestationVerifierV1.InvalidConsolidationPubkeyLength.selector, 0, 47, true)
        );
        _validateConsolidationAsRiver(c);
    }

    function testRevert_targetPubkeyLengthCheckedBeforeDomainSeparator() public {
        vm.store(address(verifier), CONSOLIDATION_DOMAIN_SEPARATOR_SLOT, bytes32(0));

        bytes[] memory sources = new bytes[](1);
        sources[0] = _pubkey(1);
        bytes[] memory targets = new bytes[](1);
        targets[0] = _pubkeyOfLength(2, 49);

        IAttestationVerifierV1.ConsolidationObject memory c = IAttestationVerifierV1.ConsolidationObject({
            withdrawalAddress: address(0xAA),
            sourcePubkeys: sources,
            targetPubkeys: targets,
            totalAmount: 32 ether,
            exitEpoch: _defaultEpochs(sources.length),
            signatures: new bytes[](0)
        });
        vm.expectRevert(
            abi.encodeWithSelector(IAttestationVerifierV1.InvalidConsolidationPubkeyLength.selector, 0, 49, false)
        );
        _validateConsolidationAsRiver(c);
    }

    // -----------------------------------------------------------------------
    // Signature / bufferId derivation tests
    // -----------------------------------------------------------------------

    function testSignaturesExcludedFromBufferId() public {
        // Two ConsolidationObjects with identical (withdrawalAddress, sources, targets, totalAmount)
        // but different signature sets must derive the same EIP-712 digest. The verifier
        // builds the digest from only the four request fields, so the `signatures` field
        // never enters the hash.
        //
        // Order matters: with replay protection now in place, a successful call marks the
        // request as processed and any subsequent call with the same payload (regardless of
        // signatures) reverts with `ConsolidationAlreadyProcessed`. To still observe that
        // BOTH signature sets are evaluated against the SAME digest, we issue the
        // wrong-signatures call first (reverts at quorum, no state change), then the
        // correct-signatures call (succeeds).
        address user = address(0xBEEF);
        bytes[] memory sources = new bytes[](1);
        sources[0] = _pubkey(1);
        bytes[] memory targets = new bytes[](1);
        targets[0] = _pubkey(2);
        uint256 totalAmount = 32 ether;
        bytes32 expectedDigest = _consolidationDigest(user, sources, targets, totalAmount);

        // --- Wrong-message signatures: revert at the quorum step (no state mutation). ---
        bytes32 unrelatedDigest = keccak256("unrelated digest for signature replay test");
        bytes[] memory sigsB = new bytes[](2);
        sigsB[0] = _sign(pk1, unrelatedDigest);
        sigsB[1] = _sign(pk2, unrelatedDigest);
        vm.expectRevert(
            abi.encodeWithSelector(IAttestationVerifierV1.InsufficientConsolidationAttestations.selector, 0, 2)
        );
        _validateConsolidationAsRiver(
            IAttestationVerifierV1.ConsolidationObject({
                withdrawalAddress: user,
                sourcePubkeys: sources,
                targetPubkeys: targets,
                totalAmount: totalAmount,
                exitEpoch: _defaultEpochs(sources.length),
                signatures: sigsB
            })
        );

        // --- Correct-message signatures over the SAME (withdrawalAddress, sources, targets, totalAmount):
        // succeeds, proving the digest the verifier built didn't depend on signatures. ---
        bytes[] memory sigsA = new bytes[](2);
        sigsA[0] = _sign(pk1, expectedDigest);
        sigsA[1] = _sign(pk2, expectedDigest);
        // Succeeds (does not revert): correct signatures over the same request fields.
        _validateConsolidationAsRiver(
            IAttestationVerifierV1.ConsolidationObject({
                withdrawalAddress: user,
                sourcePubkeys: sources,
                targetPubkeys: targets,
                totalAmount: totalAmount,
                exitEpoch: _defaultEpochs(sources.length),
                signatures: sigsA
            })
        );
    }

    function testRevert_consolidationAlreadyProcessed() public {
        // A successful validateConsolidation marks the request as processed. A second
        // call with the same payload (even with the same valid signatures) must revert.
        address user = address(0xBEEF);
        IAttestationVerifierV1.ConsolidationObject memory c = _validConsolidation(user, 1);
        _validateConsolidationAsRiver(c);

        // The expected key is the EIP-712 structHash over the five request fields.
        bytes32 structHash = keccak256(
            abi.encode(
                ATTEST_CONSOLIDATION_TYPEHASH,
                c.withdrawalAddress,
                _hashBytesArray(c.sourcePubkeys),
                _hashBytesArray(c.targetPubkeys),
                c.totalAmount,
                _hashUintArray(c.exitEpoch)
            )
        );

        vm.expectRevert(
            abi.encodeWithSelector(IAttestationVerifierV1.ConsolidationAlreadyProcessed.selector, structHash)
        );
        _validateConsolidationAsRiver(c);
    }

    function testRevert_consolidationAlreadyProcessedWithDifferentValidSignatures() public {
        address user = address(0xBEEF);
        IAttestationVerifierV1.ConsolidationObject memory c = _validConsolidation(user, 321);
        _validateConsolidationAsRiver(c);

        bytes32 digest = _consolidationDigest(c.withdrawalAddress, c.sourcePubkeys, c.targetPubkeys, c.totalAmount);
        bytes[] memory alternateSigs = new bytes[](2);
        alternateSigs[0] = _sign(pk2, digest);
        alternateSigs[1] = _sign(pk3, digest);
        c.signatures = alternateSigs;

        bytes32 structHash =
            _consolidationStructHash(c.withdrawalAddress, c.sourcePubkeys, c.targetPubkeys, c.totalAmount);
        vm.expectRevert(
            abi.encodeWithSelector(IAttestationVerifierV1.ConsolidationAlreadyProcessed.selector, structHash)
        );
        _validateConsolidationAsRiver(c);
    }

    function testRevert_distinctRequestCannotReuseFirstRequestSignatures() public {
        address user = address(0xCAFE);
        bytes memory sourceA = _pubkey(800);
        bytes memory sourceB = _pubkey(801);

        bytes[] memory firstSources = new bytes[](1);
        firstSources[0] = sourceA;
        bytes[] memory firstTargets = new bytes[](1);
        firstTargets[0] = _pubkey(900);
        uint256 firstAmount = 32 ether;
        bytes32 firstDigest = _consolidationDigest(user, firstSources, firstTargets, firstAmount);
        bytes[] memory firstSigs = new bytes[](2);
        firstSigs[0] = _sign(pk1, firstDigest);
        firstSigs[1] = _sign(pk2, firstDigest);

        bytes[] memory secondSources = new bytes[](1);
        secondSources[0] = sourceB;
        bytes[] memory secondTargets = new bytes[](1);
        secondTargets[0] = _pubkey(901);
        uint256 secondAmount = 32 ether;

        _validateConsolidationAsRiver(
            IAttestationVerifierV1.ConsolidationObject({
                withdrawalAddress: user,
                sourcePubkeys: firstSources,
                targetPubkeys: firstTargets,
                totalAmount: firstAmount,
                exitEpoch: _defaultEpochs(firstSources.length),
                signatures: firstSigs
            })
        );

        vm.expectRevert(
            abi.encodeWithSelector(IAttestationVerifierV1.InsufficientConsolidationAttestations.selector, 0, 2)
        );
        _validateConsolidationAsRiver(
            IAttestationVerifierV1.ConsolidationObject({
                withdrawalAddress: user,
                sourcePubkeys: secondSources,
                targetPubkeys: secondTargets,
                totalAmount: secondAmount,
                exitEpoch: _defaultEpochs(secondSources.length),
                signatures: firstSigs
            })
        );
    }

    function testRevert_overlappingSourceDistinctRequestRevertsBeforeSignatureVerification() public {
        address user = address(0xCAFE);
        bytes memory sourceA = _pubkey(805);
        bytes memory sourceB = _pubkey(806);

        bytes[] memory firstSources = new bytes[](1);
        firstSources[0] = sourceA;
        bytes[] memory firstTargets = new bytes[](1);
        firstTargets[0] = _pubkey(905);
        uint256 firstAmount = 32 ether;
        bytes32 firstDigest = _consolidationDigest(user, firstSources, firstTargets, firstAmount);
        bytes[] memory firstSigs = new bytes[](2);
        firstSigs[0] = _sign(pk1, firstDigest);
        firstSigs[1] = _sign(pk2, firstDigest);

        bytes[] memory secondSources = new bytes[](2);
        secondSources[0] = sourceA;
        secondSources[1] = sourceB;
        bytes[] memory secondTargets = new bytes[](2);
        secondTargets[0] = _pubkey(906);
        secondTargets[1] = _pubkey(907);
        uint256 secondAmount = 64 ether;

        _validateConsolidationAsRiver(
            IAttestationVerifierV1.ConsolidationObject({
                withdrawalAddress: user,
                sourcePubkeys: firstSources,
                targetPubkeys: firstTargets,
                totalAmount: firstAmount,
                exitEpoch: _defaultEpochs(firstSources.length),
                signatures: firstSigs
            })
        );

        vm.expectRevert(
            abi.encodeWithSelector(IAttestationVerifierV1.ConsolidationSourceAlreadyProcessed.selector, sourceA)
        );
        _validateConsolidationAsRiver(
            IAttestationVerifierV1.ConsolidationObject({
                withdrawalAddress: user,
                sourcePubkeys: secondSources,
                targetPubkeys: secondTargets,
                totalAmount: secondAmount,
                exitEpoch: _defaultEpochs(secondSources.length),
                signatures: firstSigs
            })
        );
    }

    function testRevert_overlappingSourceDistinctValidRequest() public {
        address user = address(0xCAFE);
        bytes memory sourceA = _pubkey(810);
        bytes memory sourceB = _pubkey(811);

        bytes[] memory firstSources = new bytes[](1);
        firstSources[0] = sourceA;
        bytes[] memory firstTargets = new bytes[](1);
        firstTargets[0] = _pubkey(910);
        uint256 firstAmount = 32 ether;
        bytes32 firstDigest = _consolidationDigest(user, firstSources, firstTargets, firstAmount);
        bytes[] memory firstSigs = new bytes[](2);
        firstSigs[0] = _sign(pk1, firstDigest);
        firstSigs[1] = _sign(pk2, firstDigest);

        bytes[] memory secondSources = new bytes[](2);
        secondSources[0] = sourceA;
        secondSources[1] = sourceB;
        bytes[] memory secondTargets = new bytes[](2);
        secondTargets[0] = _pubkey(911);
        secondTargets[1] = _pubkey(912);
        uint256 secondAmount = 64 ether;
        bytes32 secondDigest = _consolidationDigest(user, secondSources, secondTargets, secondAmount);
        bytes[] memory secondSigs = new bytes[](2);
        secondSigs[0] = _sign(pk1, secondDigest);
        secondSigs[1] = _sign(pk2, secondDigest);

        _validateConsolidationAsRiver(
            IAttestationVerifierV1.ConsolidationObject({
                withdrawalAddress: user,
                sourcePubkeys: firstSources,
                targetPubkeys: firstTargets,
                totalAmount: firstAmount,
                exitEpoch: _defaultEpochs(firstSources.length),
                signatures: firstSigs
            })
        );

        vm.expectRevert(
            abi.encodeWithSelector(IAttestationVerifierV1.ConsolidationSourceAlreadyProcessed.selector, sourceA)
        );
        _validateConsolidationAsRiver(
            IAttestationVerifierV1.ConsolidationObject({
                withdrawalAddress: user,
                sourcePubkeys: secondSources,
                targetPubkeys: secondTargets,
                totalAmount: secondAmount,
                exitEpoch: _defaultEpochs(secondSources.length),
                signatures: secondSigs
            })
        );
    }

    function testRevert_duplicateSourceWithinSingleRequest() public {
        address user = address(0xCAFE);
        bytes memory sourceA = _pubkey(820);

        bytes[] memory sources = new bytes[](2);
        sources[0] = sourceA;
        sources[1] = sourceA;
        bytes[] memory targets = new bytes[](2);
        targets[0] = _pubkey(920);
        targets[1] = _pubkey(921);
        uint256 totalAmount = 64 ether;
        bytes32 digest = _consolidationDigest(user, sources, targets, totalAmount);
        bytes[] memory sigs = new bytes[](2);
        sigs[0] = _sign(pk1, digest);
        sigs[1] = _sign(pk2, digest);

        vm.expectRevert(
            abi.encodeWithSelector(IAttestationVerifierV1.ConsolidationSourceAlreadyProcessed.selector, sourceA)
        );
        _validateConsolidationAsRiver(
            IAttestationVerifierV1.ConsolidationObject({
                withdrawalAddress: user,
                sourcePubkeys: sources,
                targetPubkeys: targets,
                totalAmount: totalAmount,
                exitEpoch: _defaultEpochs(sources.length),
                signatures: sigs
            })
        );
    }

    /// @dev Sources are marked processed only AFTER quorum succeeds, and the per-source loop
    ///      reverts on the FIRST already-consumed source. A request whose tainted source sits
    ///      at a non-zero index must revert without consuming the (valid) sibling sources that
    ///      precede it — otherwise a failed request would silently burn good source pubkeys.
    function testValidateConsolidation_revertAtNonZeroIndexDoesNotConsumeSiblingSource() public {
        address user = address(0xCAFE);
        bytes memory sourceTainted = _pubkey(830);
        bytes memory sourceGood = _pubkey(831);

        // Consume `sourceTainted` via a first, valid single-pair request.
        bytes[] memory sources = new bytes[](1);
        sources[0] = sourceTainted;
        bytes[] memory targets = new bytes[](1);
        targets[0] = _pubkey(930);
        uint256 totalAmount = 32 ether;
        bytes32 digest = _consolidationDigest(user, sources, targets, totalAmount);
        bytes[] memory signatures = new bytes[](2);
        signatures[0] = _sign(pk1, digest);
        signatures[1] = _sign(pk2, digest);
        _validateConsolidationAsRiver(
            IAttestationVerifierV1.ConsolidationObject({
                withdrawalAddress: user,
                sourcePubkeys: sources,
                targetPubkeys: targets,
                totalAmount: totalAmount,
                exitEpoch: _defaultEpochs(sources.length),
                signatures: signatures
            })
        );

        // Second request: [sourceGood, sourceTainted] — the tainted source is at index 1.
        // Quorum is valid, so the ONLY reason to revert is the already-consumed source.
        sources = new bytes[](2);
        sources[0] = sourceGood;
        sources[1] = sourceTainted;
        targets = new bytes[](2);
        targets[0] = _pubkey(931);
        targets[1] = _pubkey(932);
        totalAmount = 64 ether;
        digest = _consolidationDigest(user, sources, targets, totalAmount);
        signatures = new bytes[](2);
        signatures[0] = _sign(pk1, digest);
        signatures[1] = _sign(pk2, digest);
        vm.expectRevert(
            abi.encodeWithSelector(IAttestationVerifierV1.ConsolidationSourceAlreadyProcessed.selector, sourceTainted)
        );
        _validateConsolidationAsRiver(
            IAttestationVerifierV1.ConsolidationObject({
                withdrawalAddress: user,
                sourcePubkeys: sources,
                targetPubkeys: targets,
                totalAmount: totalAmount,
                exitEpoch: _defaultEpochs(sources.length),
                signatures: signatures
            })
        );

        // `sourceGood` must still be free: a later request consuming it alone succeeds.
        sources = new bytes[](1);
        sources[0] = sourceGood;
        targets = new bytes[](1);
        targets[0] = _pubkey(933);
        totalAmount = 32 ether;
        digest = _consolidationDigest(user, sources, targets, totalAmount);
        signatures = new bytes[](2);
        signatures[0] = _sign(pk1, digest);
        signatures[1] = _sign(pk2, digest);
        bytes32 structHash = _consolidationStructHash(user, sources, targets, totalAmount);
        vm.expectEmit(true, false, false, true);
        emit IAttestationVerifierV1.ConsolidationProcessed(structHash, sources, targets, totalAmount);
        _validateConsolidationAsRiver(
            IAttestationVerifierV1.ConsolidationObject({
                withdrawalAddress: user,
                sourcePubkeys: sources,
                targetPubkeys: targets,
                totalAmount: totalAmount,
                exitEpoch: _defaultEpochs(sources.length),
                signatures: signatures
            })
        );
    }

    /// @dev A request that fails quorum verification must not consume its source pubkeys,
    ///      since marking happens only after quorum succeeds. The same source can then still
    ///      be consumed by a subsequent, properly-attested request.
    function testValidateConsolidation_failedQuorumDoesNotConsumeSource() public {
        address user = address(0xCAFE);
        bytes memory sourceX = _pubkey(840);

        bytes[] memory sources = new bytes[](1);
        sources[0] = sourceX;
        bytes[] memory targets = new bytes[](1);
        targets[0] = _pubkey(940);
        uint256 totalAmount = 32 ether;
        bytes32 digest = _consolidationDigest(user, sources, targets, totalAmount);

        // Only one signature — below the quorum of 2 — so the request reverts at quorum
        // verification, after the per-source checks but before any source is marked.
        bytes[] memory underQuorumSigs = new bytes[](1);
        underQuorumSigs[0] = _sign(pk1, digest);
        vm.expectRevert(
            abi.encodeWithSelector(IAttestationVerifierV1.InsufficientConsolidationAttestations.selector, 1, 2)
        );
        _validateConsolidationAsRiver(
            IAttestationVerifierV1.ConsolidationObject({
                withdrawalAddress: user,
                sourcePubkeys: sources,
                targetPubkeys: targets,
                totalAmount: totalAmount,
                exitEpoch: _defaultEpochs(sources.length),
                signatures: underQuorumSigs
            })
        );

        // `sourceX` was not burned by the failed attempt: the same request now succeeds
        // once a full quorum is supplied.
        bytes[] memory quorumSigs = new bytes[](2);
        quorumSigs[0] = _sign(pk1, digest);
        quorumSigs[1] = _sign(pk2, digest);
        bytes32 structHash = _consolidationStructHash(user, sources, targets, totalAmount);
        vm.expectEmit(true, false, false, true);
        emit IAttestationVerifierV1.ConsolidationProcessed(structHash, sources, targets, totalAmount);
        _validateConsolidationAsRiver(
            IAttestationVerifierV1.ConsolidationObject({
                withdrawalAddress: user,
                sourcePubkeys: sources,
                targetPubkeys: targets,
                totalAmount: totalAmount,
                exitEpoch: _defaultEpochs(sources.length),
                signatures: quorumSigs
            })
        );
    }

    function testValidateConsolidation_emitsConsolidationProcessed() public {
        address user = address(0xBEEF);
        IAttestationVerifierV1.ConsolidationObject memory c = _validConsolidation(user, 99);
        bytes32 structHash = keccak256(
            abi.encode(
                ATTEST_CONSOLIDATION_TYPEHASH,
                c.withdrawalAddress,
                _hashBytesArray(c.sourcePubkeys),
                _hashBytesArray(c.targetPubkeys),
                c.totalAmount,
                _hashUintArray(c.exitEpoch)
            )
        );
        vm.expectEmit(true, false, false, true);
        emit IAttestationVerifierV1.ConsolidationProcessed(structHash, c.sourcePubkeys, c.targetPubkeys, c.totalAmount);
        _validateConsolidationAsRiver(c);
    }

    // -----------------------------------------------------------------------
    // Signature verification tests
    // -----------------------------------------------------------------------

    function testRevert_insufficientSignatures() public {
        address user = address(0x11);
        bytes[] memory sources = new bytes[](1);
        sources[0] = _pubkey(1);
        bytes[] memory targets = new bytes[](1);
        targets[0] = _pubkey(2);
        uint256 totalAmount = 32 ether;
        bytes32 id = _consolidationDigest(user, sources, targets, totalAmount);

        bytes[] memory sigs = new bytes[](1);
        sigs[0] = _sign(pk1, id);

        vm.expectRevert(
            abi.encodeWithSelector(IAttestationVerifierV1.InsufficientConsolidationAttestations.selector, 1, 2)
        );
        _validateConsolidationAsRiver(
            IAttestationVerifierV1.ConsolidationObject({
                withdrawalAddress: user,
                sourcePubkeys: sources,
                targetPubkeys: targets,
                totalAmount: totalAmount,
                exitEpoch: _defaultEpochs(sources.length),
                signatures: sigs
            })
        );
    }

    function testRevert_tooManySignatures() public {
        address user = address(0x11);
        bytes[] memory sources = new bytes[](1);
        sources[0] = _pubkey(1);
        bytes[] memory targets = new bytes[](1);
        targets[0] = _pubkey(2);
        uint256 totalAmount = 32 ether;
        bytes32 id = _consolidationDigest(user, sources, targets, totalAmount);

        bytes[] memory sigs = new bytes[](21);
        for (uint256 i = 0; i < 21; i++) {
            sigs[i] = _sign(pk1, id); // content doesn't matter; just need 21 entries
        }

        vm.expectRevert(abi.encodeWithSelector(IAttestationVerifierV1.TooManySignatures.selector, 21, 20));
        _validateConsolidationAsRiver(
            IAttestationVerifierV1.ConsolidationObject({
                withdrawalAddress: user,
                sourcePubkeys: sources,
                targetPubkeys: targets,
                totalAmount: totalAmount,
                exitEpoch: _defaultEpochs(sources.length),
                signatures: sigs
            })
        );
    }

    function testRevert_duplicateSignerCountsOnce() public {
        address user = address(0x11);
        bytes[] memory sources = new bytes[](1);
        sources[0] = _pubkey(1);
        bytes[] memory targets = new bytes[](1);
        targets[0] = _pubkey(2);
        uint256 totalAmount = 32 ether;
        bytes32 id = _consolidationDigest(user, sources, targets, totalAmount);

        bytes[] memory sigs = new bytes[](2);
        sigs[0] = _sign(pk1, id);
        sigs[1] = _sign(pk1, id); // same signer

        vm.expectRevert(
            abi.encodeWithSelector(IAttestationVerifierV1.InsufficientConsolidationAttestations.selector, 1, 2)
        );
        _validateConsolidationAsRiver(
            IAttestationVerifierV1.ConsolidationObject({
                withdrawalAddress: user,
                sourcePubkeys: sources,
                targetPubkeys: targets,
                totalAmount: totalAmount,
                exitEpoch: _defaultEpochs(sources.length),
                signatures: sigs
            })
        );
    }

    function testRevert_nonCommitteeSigner() public {
        address user = address(0x11);
        bytes[] memory sources = new bytes[](1);
        sources[0] = _pubkey(1);
        bytes[] memory targets = new bytes[](1);
        targets[0] = _pubkey(2);
        uint256 totalAmount = 32 ether;
        bytes32 id = _consolidationDigest(user, sources, targets, totalAmount);

        bytes[] memory sigs = new bytes[](2);
        sigs[0] = _sign(pk1, id);
        sigs[1] = _sign(0xDEAD, id); // not on the consolidation committee

        vm.expectRevert(
            abi.encodeWithSelector(IAttestationVerifierV1.InsufficientConsolidationAttestations.selector, 1, 2)
        );
        _validateConsolidationAsRiver(
            IAttestationVerifierV1.ConsolidationObject({
                withdrawalAddress: user,
                sourcePubkeys: sources,
                targetPubkeys: targets,
                totalAmount: totalAmount,
                exitEpoch: _defaultEpochs(sources.length),
                signatures: sigs
            })
        );
    }

    function testRevert_malformedSignatureShort() public {
        address user = address(0x11);
        bytes[] memory sources = new bytes[](1);
        sources[0] = _pubkey(1);
        bytes[] memory targets = new bytes[](1);
        targets[0] = _pubkey(2);
        uint256 totalAmount = 32 ether;
        bytes32 id = _consolidationDigest(user, sources, targets, totalAmount);

        bytes[] memory sigs = new bytes[](2);
        sigs[0] = _sign(pk1, id);
        sigs[1] = new bytes(64); // wrong length — _recover returns address(0), skipped

        vm.expectRevert(
            abi.encodeWithSelector(IAttestationVerifierV1.InsufficientConsolidationAttestations.selector, 1, 2)
        );
        _validateConsolidationAsRiver(
            IAttestationVerifierV1.ConsolidationObject({
                withdrawalAddress: user,
                sourcePubkeys: sources,
                targetPubkeys: targets,
                totalAmount: totalAmount,
                exitEpoch: _defaultEpochs(sources.length),
                signatures: sigs
            })
        );
    }

    function testRevert_malformedSignatureBadV() public {
        // 65-byte signature with a v byte outside {0,1,27,28} after normalization.
        // _recover returns address(0); the recovery loop silently skips it.
        address user = address(0x11);
        bytes[] memory sources = new bytes[](1);
        sources[0] = _pubkey(1);
        bytes[] memory targets = new bytes[](1);
        targets[0] = _pubkey(2);
        uint256 totalAmount = 32 ether;
        bytes32 id = _consolidationDigest(user, sources, targets, totalAmount);

        bytes memory corrupt = _sign(pk2, id);
        corrupt[64] = bytes1(uint8(42)); // v=42, not in {27,28} → skipped

        bytes[] memory sigs = new bytes[](2);
        sigs[0] = _sign(pk1, id);
        sigs[1] = corrupt;

        vm.expectRevert(
            abi.encodeWithSelector(IAttestationVerifierV1.InsufficientConsolidationAttestations.selector, 1, 2)
        );
        _validateConsolidationAsRiver(
            IAttestationVerifierV1.ConsolidationObject({
                withdrawalAddress: user,
                sourcePubkeys: sources,
                targetPubkeys: targets,
                totalAmount: totalAmount,
                exitEpoch: _defaultEpochs(sources.length),
                signatures: sigs
            })
        );
    }

    function testRevert_zeroSignatures() public {
        // signatures.length == 0 must be rejected at the sigLen<quorum gate before
        // any signer recovery work runs. Distinct from `testRevert_insufficientSignatures`
        // which uses sigLen = 1.
        address user = address(0x11);
        bytes[] memory sources = new bytes[](1);
        sources[0] = _pubkey(1);
        bytes[] memory targets = new bytes[](1);
        targets[0] = _pubkey(2);
        uint256 totalAmount = 32 ether;

        vm.expectRevert(
            abi.encodeWithSelector(IAttestationVerifierV1.InsufficientConsolidationAttestations.selector, 0, 2)
        );
        _validateConsolidationAsRiver(
            IAttestationVerifierV1.ConsolidationObject({
                withdrawalAddress: user,
                sourcePubkeys: sources,
                targetPubkeys: targets,
                totalAmount: totalAmount,
                exitEpoch: _defaultEpochs(sources.length),
                signatures: new bytes[](0)
            })
        );
    }

    function testRevert_zeroDomainSeparator() public {
        // Wipe the consolidation domain separator via vm.store.
        vm.store(address(verifier), CONSOLIDATION_DOMAIN_SEPARATOR_SLOT, bytes32(0));

        address user = address(0x11);
        IAttestationVerifierV1.ConsolidationObject memory c = _validConsolidation(user, 1);

        vm.expectRevert(IAttestationVerifierV1.ZeroConsolidationDomainSeparator.selector);
        _validateConsolidationAsRiver(c);
    }

    function testRevert_zeroConsolidationQuorumStorage() public {
        // The quorum setter rejects zero, but validateConsolidation() still guards the
        // internal verifier helper. If the slot were corrupted to zero, signatures must
        // not become optional for a structurally valid consolidation request.
        vm.store(address(verifier), CONSOLIDATION_COMMITTEE_ATTESTATION_QUORUM_SLOT, bytes32(0));

        IAttestationVerifierV1.ConsolidationObject memory c = _validConsolidation(address(0x11), 2);

        vm.expectRevert(IAttestationVerifierV1.ZeroQuorum.selector);
        _validateConsolidationAsRiver(c);
    }

    // -----------------------------------------------------------------------
    // Admin setter tests
    // -----------------------------------------------------------------------

    function testSetConsolidationCommitteeAttester_addSucceeds() public {
        address newAttester = address(0xABCD);
        vm.prank(admin);
        verifier.setConsolidationCommitteeAttester(newAttester, true);
        assertTrue(verifier.isConsolidationCommitteeAttester(newAttester));
        assertEq(verifier.getConsolidationCommitteeAttesterCount(), 4);
    }

    function testSetConsolidationCommitteeAttester_removeSucceeds() public {
        vm.prank(admin);
        verifier.setConsolidationCommitteeAttester(attester3, false);
        assertFalse(verifier.isConsolidationCommitteeAttester(attester3));
        assertEq(verifier.getConsolidationCommitteeAttesterCount(), 2);
    }

    function testSetConsolidationCommitteeAttester_revertStatusUnchanged() public {
        vm.prank(admin);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAttestationVerifierV1.ConsolidationCommitteeAttesterStatusUnchanged.selector, attester1, true
            )
        );
        verifier.setConsolidationCommitteeAttester(attester1, true);

        address stranger = address(0xC0FFEE);
        vm.prank(admin);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAttestationVerifierV1.ConsolidationCommitteeAttesterStatusUnchanged.selector, stranger, false
            )
        );
        verifier.setConsolidationCommitteeAttester(stranger, false);
    }

    function testSetConsolidationCommitteeAttester_revertTooMany() public {
        // Add up to 32 attesters (3 already registered → add 29).
        for (uint256 i = 0; i < 29; i++) {
            vm.prank(admin);
            verifier.setConsolidationCommitteeAttester(address(uint160(0x9000 + i)), true);
        }
        assertEq(verifier.getConsolidationCommitteeAttesterCount(), 32);

        vm.prank(admin);
        vm.expectRevert(
            abi.encodeWithSelector(IAttestationVerifierV1.TooManyConsolidationCommitteeAttesters.selector, 33, 32)
        );
        verifier.setConsolidationCommitteeAttester(address(0x9999), true);
    }

    function testSetConsolidationCommitteeAttester_revertRemovingBreaksQuorum() public {
        // We start with 3 attesters and quorum 2. Removing two would leave count=1 < quorum=2.
        vm.prank(admin);
        verifier.setConsolidationCommitteeAttester(attester3, false); // 3 → 2

        vm.prank(admin);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAttestationVerifierV1.QuorumExceedsConsolidationCommitteeAttesterCount.selector, 2, 1
            )
        );
        verifier.setConsolidationCommitteeAttester(attester2, false); // would go 2 → 1
    }

    function testSetConsolidationCommitteeAttester_onlyRiverAdmin() public {
        vm.expectRevert(abi.encodeWithSelector(LibErrors.Unauthorized.selector, address(this)));
        verifier.setConsolidationCommitteeAttester(address(0xABCD), true);
    }

    function testSetConsolidationCommitteeAttestationQuorum_succeeds() public {
        vm.prank(admin);
        verifier.setConsolidationCommitteeAttestationQuorum(3);
        assertEq(verifier.getConsolidationCommitteeAttestationQuorum(), 3);
    }

    function testSetConsolidationCommitteeAttestationQuorum_revertZero() public {
        vm.prank(admin);
        vm.expectRevert(IAttestationVerifierV1.ZeroQuorum.selector);
        verifier.setConsolidationCommitteeAttestationQuorum(0);
    }

    function testSetConsolidationCommitteeAttestationQuorum_revertExceedsAttesters() public {
        vm.prank(admin);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAttestationVerifierV1.QuorumExceedsConsolidationCommitteeAttesterCount.selector, 4, 3
            )
        );
        verifier.setConsolidationCommitteeAttestationQuorum(4);
    }

    function testSetConsolidationCommitteeAttestationQuorum_revertExceedsMaxSignatures() public {
        // Push attester count above MAX_SIGNATURES so the count check doesn't fire first.
        for (uint256 i = 0; i < 18; i++) {
            vm.prank(admin);
            verifier.setConsolidationCommitteeAttester(address(uint160(0xA000 + i)), true);
        }
        assertEq(verifier.getConsolidationCommitteeAttesterCount(), 21);

        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(IAttestationVerifierV1.QuorumExceedsMaxSignatures.selector, 21, 20));
        verifier.setConsolidationCommitteeAttestationQuorum(21);
    }

    function testSetConsolidationCommitteeAttestationQuorum_onlyRiverAdmin() public {
        vm.expectRevert(abi.encodeWithSelector(LibErrors.Unauthorized.selector, address(this)));
        verifier.setConsolidationCommitteeAttestationQuorum(3);
    }

    // -----------------------------------------------------------------------
    // Isolation from deposit flow
    // -----------------------------------------------------------------------

    function testIsolation_consolidationAttesterNotADepositAttester() public {
        vm.prank(admin);
        verifier.setConsolidationCommitteeAttester(address(0xBABE), true);
        assertFalse(verifier.isRootAttester(address(0xBABE)));
        assertTrue(verifier.isConsolidationCommitteeAttester(address(0xBABE)));
    }

    function testIsolation_quorumsAreSeparate() public {
        // setUp configured consolidation quorum=2 and deposit quorum=1 — they must read independently.
        assertEq(verifier.getRootAttestationQuorum(), 1);
        assertEq(verifier.getConsolidationCommitteeAttestationQuorum(), 2);
    }

    function testIsolation_changingConsolidationQuorumDoesNotAffectDeposit() public {
        uint256 depositQuorumBefore = verifier.getRootAttestationQuorum();
        vm.prank(admin);
        verifier.setConsolidationCommitteeAttestationQuorum(3);
        assertEq(verifier.getRootAttestationQuorum(), depositQuorumBefore);
        assertEq(verifier.getConsolidationCommitteeAttestationQuorum(), 3);
    }
}
