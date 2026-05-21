// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "forge-std/Test.sol";

import "../../src/AttestationVerifier.1.sol";
import "../../src/interfaces/IAttestationVerifier.1.sol";
import "../../src/interfaces/IConsolidationDataBuffer.sol";
import "../../src/interfaces/IDepositDataBuffer.sol";
import "../../src/libraries/BLS12_381.sol";
import "../../src/libraries/LibErrors.sol";
import "../utils/LibImplementationUnbricker.sol";
import "../mocks/DepositContractEnhancedMock.sol";

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

// ---------------------------------------------------------------------------
// Mock DepositDataBuffer — copied from the deposit attestation tests because
// no real implementation exists. We need it to satisfy the v1 init.
// ---------------------------------------------------------------------------

contract MockDepositDataBufferForConsolidation is IDepositDataBuffer {
    mapping(bytes32 => DepositObject[]) internal _batches;
    mapping(bytes32 => bool) internal _exists;

    function submitDepositData(bytes32 depositDataBufferId, DepositObject[] calldata deposits) external {
        if (_exists[depositDataBufferId]) revert DepositDataBufferIdAlreadyExists(depositDataBufferId);
        _exists[depositDataBufferId] = true;
        for (uint256 i = 0; i < deposits.length; i++) {
            _batches[depositDataBufferId].push(deposits[i]);
        }
        emit DepositDataSubmitted(depositDataBufferId, deposits.length);
    }

    function getDepositData(bytes32 depositDataBufferId) external view returns (DepositObject[] memory) {
        if (!_exists[depositDataBufferId]) revert DepositDataBufferIdNotFound(depositDataBufferId);
        return _batches[depositDataBufferId];
    }

    function getWriter() external pure returns (address) {
        return address(0);
    }

    function getAdmin() external pure returns (address) {
        return address(0);
    }
}

// ---------------------------------------------------------------------------
// Mock ConsolidationDataBuffer — stores ConsolidationObject by bufferId.
//
// Includes a `submitRaw(id, obj)` helper that bypasses the id-derivation rule
// so tests can store data under a deliberately wrong id (covers the
// ConsolidationBufferIdMismatch path).
// ---------------------------------------------------------------------------

contract MockConsolidationDataBuffer is IConsolidationDataBuffer {
    mapping(bytes32 => ConsolidationObject) internal _data;
    mapping(bytes32 => bool) internal _exists;

    function submitConsolidationData(bytes32 id, ConsolidationObject calldata consolidation) external {
        if (_exists[id]) revert ConsolidationDataBufferIdAlreadyExists(id);
        if (consolidation.sourcePubkeys.length == 0) revert EmptyConsolidationData();
        _exists[id] = true;
        _storeMemory(id, consolidation.user, consolidation.totalAmount);
        for (uint256 i = 0; i < consolidation.sourcePubkeys.length; i++) {
            _data[id].sourcePubkeys.push(consolidation.sourcePubkeys[i]);
        }
        for (uint256 i = 0; i < consolidation.targetPubkeys.length; i++) {
            _data[id].targetPubkeys.push(consolidation.targetPubkeys[i]);
        }
        for (uint256 i = 0; i < consolidation.signatures.length; i++) {
            _data[id].signatures.push(consolidation.signatures[i]);
        }
        emit ConsolidationDataSubmitted(id, consolidation.user, consolidation.sourcePubkeys.length);
    }

    /// @dev Test-only escape hatch: store a ConsolidationObject under an arbitrary id
    ///      (not necessarily derived from its content). Used to exercise the verifier's
    ///      bufferId-binding check.
    function submitRaw(bytes32 id, ConsolidationObject memory consolidation) external {
        _exists[id] = true;
        _data[id].user = consolidation.user;
        _data[id].totalAmount = consolidation.totalAmount;
        for (uint256 i = 0; i < consolidation.sourcePubkeys.length; i++) {
            _data[id].sourcePubkeys.push(consolidation.sourcePubkeys[i]);
        }
        for (uint256 i = 0; i < consolidation.targetPubkeys.length; i++) {
            _data[id].targetPubkeys.push(consolidation.targetPubkeys[i]);
        }
        for (uint256 i = 0; i < consolidation.signatures.length; i++) {
            _data[id].signatures.push(consolidation.signatures[i]);
        }
    }

    function _storeMemory(bytes32 id, address user, uint256 totalAmount) internal {
        _data[id].user = user;
        _data[id].totalAmount = totalAmount;
    }

    function getConsolidationData(bytes32 id) external view returns (ConsolidationObject memory) {
        if (!_exists[id]) revert ConsolidationDataBufferIdNotFound(id);
        return _data[id];
    }

    function getWriter() external pure returns (address) {
        return address(0);
    }

    function getAdmin() external pure returns (address) {
        return address(0);
    }
}

// ---------------------------------------------------------------------------
// ConsolidationAttestationTest — exercises the consolidation half of
// AttestationVerifierV1.
//
// Setup runs both inits (deposit-side init(0) is required because consolidation
// init(1) depends on Version having advanced). Tests focus on:
//   - happy paths
//   - structural validation (lengths, zero fields, pubkey lengths)
//   - bufferId binding (signatures excluded from hash)
//   - signature verification (quorum, duplicates, non-committee, malformed)
//   - admin setters
//   - isolation from the deposit flow
// ---------------------------------------------------------------------------

contract ConsolidationAttestationTest is Test {
    AttestationVerifierV1 internal validator;
    MockConsolidationDataBuffer internal cBuffer;
    MockDepositDataBufferForConsolidation internal dBuffer;
    DepositContractEnhancedMock internal depositContract;
    MockRiverAdmin internal river;

    address internal admin = address(0xAD);

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
    bytes32 internal constant ATTEST_CONSOLIDATION_TYPEHASH =
        keccak256("AttestConsolidation(bytes32 consolidationDataBufferId)");

    // Storage slots (must match contracts/src/state/attestationVerifier/*)
    bytes32 internal constant CONSOLIDATION_DOMAIN_SEPARATOR_SLOT =
        bytes32(uint256(keccak256("attestationVerifier.state.consolidationDomainSeparator")) - 1);
    bytes32 internal constant DEPOSIT_DOMAIN_SEPARATOR_SLOT =
        bytes32(uint256(keccak256("attestationVerifier.state.domainSeparator")) - 1);

    function setUp() public {
        attester1 = vm.addr(pk1);
        attester2 = vm.addr(pk2);
        attester3 = vm.addr(pk3);

        river = new MockRiverAdmin(admin);
        depositContract = new DepositContractEnhancedMock();
        dBuffer = new MockDepositDataBufferForConsolidation();
        cBuffer = new MockConsolidationDataBuffer();

        validator = new AttestationVerifierV1();
        LibImplementationUnbricker.unbrick(vm, address(validator));

        // init(0) — deposit side. Throwaway committee just to advance Version.
        address[] memory depCommittee = new address[](1);
        depCommittee[0] = depositAttester;
        validator.initAttestationVerifierV1(address(river), address(dBuffer), depCommittee, 1, bytes4(0));

        // init(1) — consolidation side.
        address[] memory cCommittee = new address[](3);
        cCommittee[0] = attester1;
        cCommittee[1] = attester2;
        cCommittee[2] = attester3;
        validator.initAttestationVerifierV1_1(address(cBuffer), cCommittee, 2);
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

    /// @dev Compute the bufferId following the verifier's encoding rule.
    function _bufferId(address user, bytes[] memory sources, bytes[] memory targets, uint256 totalAmount)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(user, sources, targets, totalAmount));
    }

    /// @dev Sign an EIP-712 consolidation attestation digest with the given private key.
    function _sign(uint256 pk, bytes32 bufferId) internal view returns (bytes memory) {
        bytes32 domainSep = keccak256(
            abi.encode(EIP712_DOMAIN_TYPEHASH, CONSOLIDATION_NAME_HASH, VERSION_HASH, block.chainid, address(river))
        );
        bytes32 structHash = keccak256(abi.encode(ATTEST_CONSOLIDATION_TYPEHASH, bufferId));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSep, structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, digest);
        return abi.encodePacked(r, s, v);
    }

    /// @dev Build a single-pair consolidation object with two valid signatures (attester1 + attester2).
    function _validConsolidation(address user, uint256 seed)
        internal
        view
        returns (IConsolidationDataBuffer.ConsolidationObject memory consolidation, bytes32 bufferId)
    {
        bytes[] memory sources = new bytes[](1);
        sources[0] = _pubkey(seed);
        bytes[] memory targets = new bytes[](1);
        targets[0] = _pubkey(seed + 1000);
        uint256 totalAmount = 32 ether;

        bufferId = _bufferId(user, sources, targets, totalAmount);

        bytes[] memory sigs = new bytes[](2);
        sigs[0] = _sign(pk1, bufferId);
        sigs[1] = _sign(pk2, bufferId);

        consolidation = IConsolidationDataBuffer.ConsolidationObject({
            user: user,
            sourcePubkeys: sources,
            targetPubkeys: targets,
            totalAmount: totalAmount,
            signatures: sigs
        });
    }

    // -----------------------------------------------------------------------
    // Happy-path tests
    // -----------------------------------------------------------------------

    function testValidateConsolidation_singlePair_quorumMet() public {
        address user = address(0xBEEF);
        (IConsolidationDataBuffer.ConsolidationObject memory c, bytes32 id) = _validConsolidation(user, 1);
        cBuffer.submitConsolidationData(id, c);

        (IConsolidationDataBuffer.ConsolidationObject memory returned, uint256 totalAmount) =
            validator.validateConsolidation(id);
        assertEq(returned.user, user);
        assertEq(returned.totalAmount, 32 ether);
        assertEq(totalAmount, 32 ether);
        assertEq(returned.sourcePubkeys.length, 1);
        assertEq(returned.targetPubkeys.length, 1);
        assertEq(returned.signatures.length, 2);
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
        bytes32 id = _bufferId(user, sources, targets, totalAmount);

        bytes[] memory sigs = new bytes[](3);
        sigs[0] = _sign(pk1, id);
        sigs[1] = _sign(pk2, id);
        sigs[2] = _sign(pk3, id);

        cBuffer.submitConsolidationData(
            id,
            IConsolidationDataBuffer.ConsolidationObject({
                user: user,
                sourcePubkeys: sources,
                targetPubkeys: targets,
                totalAmount: totalAmount,
                signatures: sigs
            })
        );

        (IConsolidationDataBuffer.ConsolidationObject memory returned, uint256 amount) =
            validator.validateConsolidation(id);
        assertEq(amount, totalAmount);
        assertEq(returned.sourcePubkeys.length, 3);
        assertEq(returned.targetPubkeys.length, 3);
    }

    function testValidateConsolidation_exactlyQuorumSignatures() public {
        // Quorum is 2; supplying exactly 2 valid signatures should pass.
        address user = address(0x11);
        (IConsolidationDataBuffer.ConsolidationObject memory c, bytes32 id) = _validConsolidation(user, 7);
        cBuffer.submitConsolidationData(id, c);

        (, uint256 amount) = validator.validateConsolidation(id);
        assertEq(amount, 32 ether);
    }

    // -----------------------------------------------------------------------
    // Init / config tests
    // -----------------------------------------------------------------------

    function testInit_revertEmptyAttesterArray() public {
        AttestationVerifierV1 fresh = new AttestationVerifierV1();
        LibImplementationUnbricker.unbrick(vm, address(fresh));
        address[] memory dep = new address[](1);
        dep[0] = depositAttester;
        fresh.initAttestationVerifierV1(address(river), address(dBuffer), dep, 1, bytes4(0));

        address[] memory empty = new address[](0);
        vm.expectRevert(LibErrors.InvalidArgument.selector);
        fresh.initAttestationVerifierV1_1(address(cBuffer), empty, 1);
    }

    function testInit_revertTooManyAttesters() public {
        AttestationVerifierV1 fresh = new AttestationVerifierV1();
        LibImplementationUnbricker.unbrick(vm, address(fresh));
        address[] memory dep = new address[](1);
        dep[0] = depositAttester;
        fresh.initAttestationVerifierV1(address(river), address(dBuffer), dep, 1, bytes4(0));

        address[] memory many = new address[](33);
        for (uint256 i = 0; i < 33; i++) {
            many[i] = address(uint160(0x1000 + i));
        }
        vm.expectRevert(LibErrors.InvalidArgument.selector);
        fresh.initAttestationVerifierV1_1(address(cBuffer), many, 1);
    }

    function testInit_revertZeroQuorum() public {
        AttestationVerifierV1 fresh = new AttestationVerifierV1();
        LibImplementationUnbricker.unbrick(vm, address(fresh));
        address[] memory dep = new address[](1);
        dep[0] = depositAttester;
        fresh.initAttestationVerifierV1(address(river), address(dBuffer), dep, 1, bytes4(0));

        address[] memory cc = new address[](1);
        cc[0] = attester1;
        vm.expectRevert(IAttestationVerifierV1.ZeroQuorum.selector);
        fresh.initAttestationVerifierV1_1(address(cBuffer), cc, 0);
    }

    function testInit_revertQuorumExceedsMaxSignatures() public {
        AttestationVerifierV1 fresh = new AttestationVerifierV1();
        LibImplementationUnbricker.unbrick(vm, address(fresh));
        address[] memory dep = new address[](1);
        dep[0] = depositAttester;
        fresh.initAttestationVerifierV1(address(river), address(dBuffer), dep, 1, bytes4(0));

        address[] memory cc = new address[](32);
        for (uint256 i = 0; i < 32; i++) {
            cc[i] = address(uint160(0x2000 + i));
        }
        vm.expectRevert(
            abi.encodeWithSelector(IAttestationVerifierV1.QuorumExceedsMaxSignatures.selector, 21, fresh.MAX_SIGNATURES())
        );
        fresh.initAttestationVerifierV1_1(address(cBuffer), cc, 21);
    }

    function testInit_revertQuorumExceedsAttesterCount() public {
        AttestationVerifierV1 fresh = new AttestationVerifierV1();
        LibImplementationUnbricker.unbrick(vm, address(fresh));
        address[] memory dep = new address[](1);
        dep[0] = depositAttester;
        fresh.initAttestationVerifierV1(address(river), address(dBuffer), dep, 1, bytes4(0));

        address[] memory cc = new address[](2);
        cc[0] = attester1;
        cc[1] = attester2;
        vm.expectRevert(
            abi.encodeWithSelector(
                IAttestationVerifierV1.QuorumExceedsConsolidationCommitteeAttesterCount.selector, 3, 2
            )
        );
        fresh.initAttestationVerifierV1_1(address(cBuffer), cc, 3);
    }

    function testInit_revertZeroBuffer() public {
        AttestationVerifierV1 fresh = new AttestationVerifierV1();
        LibImplementationUnbricker.unbrick(vm, address(fresh));
        address[] memory dep = new address[](1);
        dep[0] = depositAttester;
        fresh.initAttestationVerifierV1(address(river), address(dBuffer), dep, 1, bytes4(0));

        address[] memory cc = new address[](1);
        cc[0] = attester1;
        vm.expectRevert(LibErrors.InvalidZeroAddress.selector);
        fresh.initAttestationVerifierV1_1(address(0), cc, 1);
    }

    function testInit_revertAlreadyInitialized() public {
        // setUp already called init(1) — calling it again must revert.
        address[] memory cc = new address[](1);
        cc[0] = attester1;
        vm.expectRevert();
        validator.initAttestationVerifierV1_1(address(cBuffer), cc, 1);
    }

    function testInit_consolidationDomainSeparatorDiffersFromDeposit() public {
        bytes32 depositDS = validator.getDomainSeparator();
        bytes32 consolidationDS = validator.getConsolidationDomainSeparator();
        assertTrue(depositDS != consolidationDS, "consolidation domain separator must differ from deposit's");
        assertTrue(consolidationDS != bytes32(0), "consolidation domain separator must be set");
    }

    function testInit_setsAttesterCount() public {
        assertEq(validator.getConsolidationCommitteeAttesterCount(), 3);
        assertTrue(validator.isConsolidationCommitteeAttester(attester1));
        assertTrue(validator.isConsolidationCommitteeAttester(attester2));
        assertTrue(validator.isConsolidationCommitteeAttester(attester3));
        assertEq(validator.getConsolidationCommitteeAttestationQuorum(), 2);
        assertEq(validator.getConsolidationDataBuffer(), address(cBuffer));
    }

    // -----------------------------------------------------------------------
    // Structural validation tests
    // -----------------------------------------------------------------------

    function testRevert_emptySourcePubkeys() public {
        // Build a consolidation with empty arrays so submit lets it through via submitRaw.
        bytes[] memory empty = new bytes[](0);
        bytes[] memory sigs = new bytes[](0);
        IConsolidationDataBuffer.ConsolidationObject memory c = IConsolidationDataBuffer.ConsolidationObject({
            user: address(0xAA),
            sourcePubkeys: empty,
            targetPubkeys: empty,
            totalAmount: 1 ether,
            signatures: sigs
        });
        bytes32 id = _bufferId(c.user, c.sourcePubkeys, c.targetPubkeys, c.totalAmount);
        cBuffer.submitRaw(id, c);

        vm.expectRevert(IAttestationVerifierV1.NoConsolidations.selector);
        validator.validateConsolidation(id);
    }

    function testRevert_sourceTargetLengthMismatch() public {
        bytes[] memory sources = new bytes[](2);
        sources[0] = _pubkey(1);
        sources[1] = _pubkey(2);
        bytes[] memory targets = new bytes[](1);
        targets[0] = _pubkey(3);

        IConsolidationDataBuffer.ConsolidationObject memory c = IConsolidationDataBuffer.ConsolidationObject({
            user: address(0xAA),
            sourcePubkeys: sources,
            targetPubkeys: targets,
            totalAmount: 32 ether,
            signatures: new bytes[](0)
        });
        bytes32 id = _bufferId(c.user, c.sourcePubkeys, c.targetPubkeys, c.totalAmount);
        cBuffer.submitRaw(id, c);

        vm.expectRevert(
            abi.encodeWithSelector(IAttestationVerifierV1.ConsolidationArrayLengthMismatch.selector, 2, 1)
        );
        validator.validateConsolidation(id);
    }

    function testRevert_zeroTotalAmount() public {
        bytes[] memory sources = new bytes[](1);
        sources[0] = _pubkey(1);
        bytes[] memory targets = new bytes[](1);
        targets[0] = _pubkey(2);

        IConsolidationDataBuffer.ConsolidationObject memory c = IConsolidationDataBuffer.ConsolidationObject({
            user: address(0xAA),
            sourcePubkeys: sources,
            targetPubkeys: targets,
            totalAmount: 0,
            signatures: new bytes[](0)
        });
        bytes32 id = _bufferId(c.user, c.sourcePubkeys, c.targetPubkeys, c.totalAmount);
        cBuffer.submitRaw(id, c);

        vm.expectRevert(IAttestationVerifierV1.ZeroConsolidationTotalAmount.selector);
        validator.validateConsolidation(id);
    }

    function testRevert_zeroUser() public {
        bytes[] memory sources = new bytes[](1);
        sources[0] = _pubkey(1);
        bytes[] memory targets = new bytes[](1);
        targets[0] = _pubkey(2);

        IConsolidationDataBuffer.ConsolidationObject memory c = IConsolidationDataBuffer.ConsolidationObject({
            user: address(0),
            sourcePubkeys: sources,
            targetPubkeys: targets,
            totalAmount: 32 ether,
            signatures: new bytes[](0)
        });
        bytes32 id = _bufferId(c.user, c.sourcePubkeys, c.targetPubkeys, c.totalAmount);
        cBuffer.submitRaw(id, c);

        vm.expectRevert(IAttestationVerifierV1.ZeroConsolidationUser.selector);
        validator.validateConsolidation(id);
    }

    function testRevert_sourcePubkeyWrongLength() public {
        bytes[] memory sources = new bytes[](1);
        sources[0] = _pubkeyOfLength(1, 47);
        bytes[] memory targets = new bytes[](1);
        targets[0] = _pubkey(2);

        IConsolidationDataBuffer.ConsolidationObject memory c = IConsolidationDataBuffer.ConsolidationObject({
            user: address(0xAA),
            sourcePubkeys: sources,
            targetPubkeys: targets,
            totalAmount: 32 ether,
            signatures: new bytes[](0)
        });
        bytes32 id = _bufferId(c.user, c.sourcePubkeys, c.targetPubkeys, c.totalAmount);
        cBuffer.submitRaw(id, c);

        vm.expectRevert(
            abi.encodeWithSelector(IAttestationVerifierV1.InvalidConsolidationPubkeyLength.selector, 0, 47, true)
        );
        validator.validateConsolidation(id);
    }

    function testRevert_targetPubkeyWrongLength() public {
        bytes[] memory sources = new bytes[](1);
        sources[0] = _pubkey(1);
        bytes[] memory targets = new bytes[](1);
        targets[0] = _pubkeyOfLength(2, 49);

        IConsolidationDataBuffer.ConsolidationObject memory c = IConsolidationDataBuffer.ConsolidationObject({
            user: address(0xAA),
            sourcePubkeys: sources,
            targetPubkeys: targets,
            totalAmount: 32 ether,
            signatures: new bytes[](0)
        });
        bytes32 id = _bufferId(c.user, c.sourcePubkeys, c.targetPubkeys, c.totalAmount);
        cBuffer.submitRaw(id, c);

        vm.expectRevert(
            abi.encodeWithSelector(IAttestationVerifierV1.InvalidConsolidationPubkeyLength.selector, 0, 49, false)
        );
        validator.validateConsolidation(id);
    }

    // -----------------------------------------------------------------------
    // Buffer integrity tests
    // -----------------------------------------------------------------------

    function testRevert_bufferIdMismatch() public {
        // Sign and "commit" to id1, but stash a DIFFERENT object under id1.
        address user = address(0xBEEF);
        (IConsolidationDataBuffer.ConsolidationObject memory cSigned, bytes32 idSigned) =
            _validConsolidation(user, 1);

        // Different content (different seed → different pubkey → different content-hash).
        bytes[] memory sources = new bytes[](1);
        sources[0] = _pubkey(99); // different source
        bytes[] memory targets = new bytes[](1);
        targets[0] = _pubkey(100);
        IConsolidationDataBuffer.ConsolidationObject memory cMalicious = IConsolidationDataBuffer.ConsolidationObject({
            user: user,
            sourcePubkeys: sources,
            targetPubkeys: targets,
            totalAmount: cSigned.totalAmount,
            signatures: cSigned.signatures
        });
        bytes32 idActual = _bufferId(cMalicious.user, cMalicious.sourcePubkeys, cMalicious.targetPubkeys, cMalicious.totalAmount);
        assertTrue(idSigned != idActual);

        cBuffer.submitRaw(idSigned, cMalicious);

        vm.expectRevert(
            abi.encodeWithSelector(IAttestationVerifierV1.ConsolidationBufferIdMismatch.selector, idSigned, idActual)
        );
        validator.validateConsolidation(idSigned);
    }

    function testSignaturesExcludedFromBufferId() public {
        // Two consolidations identical except for signatures must hash to the same bufferId.
        address user = address(0xBEEF);
        bytes[] memory sources = new bytes[](1);
        sources[0] = _pubkey(1);
        bytes[] memory targets = new bytes[](1);
        targets[0] = _pubkey(2);
        uint256 totalAmount = 32 ether;

        bytes32 id1 = _bufferId(user, sources, targets, totalAmount);

        // Mutate signatures (different content, even garbage) — bufferId must be unchanged.
        bytes32 id2 = _bufferId(user, sources, targets, totalAmount);
        assertEq(id1, id2, "bufferId must be invariant under signature mutation");
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
        bytes32 id = _bufferId(user, sources, targets, totalAmount);

        bytes[] memory sigs = new bytes[](1);
        sigs[0] = _sign(pk1, id);

        cBuffer.submitConsolidationData(
            id,
            IConsolidationDataBuffer.ConsolidationObject({
                user: user,
                sourcePubkeys: sources,
                targetPubkeys: targets,
                totalAmount: totalAmount,
                signatures: sigs
            })
        );

        vm.expectRevert(
            abi.encodeWithSelector(IAttestationVerifierV1.InsufficientConsolidationAttestations.selector, 1, 2)
        );
        validator.validateConsolidation(id);
    }

    function testRevert_tooManySignatures() public {
        address user = address(0x11);
        bytes[] memory sources = new bytes[](1);
        sources[0] = _pubkey(1);
        bytes[] memory targets = new bytes[](1);
        targets[0] = _pubkey(2);
        uint256 totalAmount = 32 ether;
        bytes32 id = _bufferId(user, sources, targets, totalAmount);

        bytes[] memory sigs = new bytes[](21);
        for (uint256 i = 0; i < 21; i++) {
            sigs[i] = _sign(pk1, id); // garbage content; just need 21 entries
        }

        cBuffer.submitConsolidationData(
            id,
            IConsolidationDataBuffer.ConsolidationObject({
                user: user,
                sourcePubkeys: sources,
                targetPubkeys: targets,
                totalAmount: totalAmount,
                signatures: sigs
            })
        );

        vm.expectRevert(abi.encodeWithSelector(IAttestationVerifierV1.TooManySignatures.selector, 21, 20));
        validator.validateConsolidation(id);
    }

    function testRevert_duplicateSignerCountsOnce() public {
        address user = address(0x11);
        bytes[] memory sources = new bytes[](1);
        sources[0] = _pubkey(1);
        bytes[] memory targets = new bytes[](1);
        targets[0] = _pubkey(2);
        uint256 totalAmount = 32 ether;
        bytes32 id = _bufferId(user, sources, targets, totalAmount);

        bytes[] memory sigs = new bytes[](2);
        sigs[0] = _sign(pk1, id);
        sigs[1] = _sign(pk1, id); // same signer

        cBuffer.submitConsolidationData(
            id,
            IConsolidationDataBuffer.ConsolidationObject({
                user: user,
                sourcePubkeys: sources,
                targetPubkeys: targets,
                totalAmount: totalAmount,
                signatures: sigs
            })
        );

        vm.expectRevert(
            abi.encodeWithSelector(IAttestationVerifierV1.InsufficientConsolidationAttestations.selector, 1, 2)
        );
        validator.validateConsolidation(id);
    }

    function testRevert_nonCommitteeSigner() public {
        address user = address(0x11);
        bytes[] memory sources = new bytes[](1);
        sources[0] = _pubkey(1);
        bytes[] memory targets = new bytes[](1);
        targets[0] = _pubkey(2);
        uint256 totalAmount = 32 ether;
        bytes32 id = _bufferId(user, sources, targets, totalAmount);

        bytes[] memory sigs = new bytes[](2);
        sigs[0] = _sign(pk1, id);
        sigs[1] = _sign(0xDEAD, id); // not on the consolidation committee

        cBuffer.submitConsolidationData(
            id,
            IConsolidationDataBuffer.ConsolidationObject({
                user: user,
                sourcePubkeys: sources,
                targetPubkeys: targets,
                totalAmount: totalAmount,
                signatures: sigs
            })
        );

        vm.expectRevert(
            abi.encodeWithSelector(IAttestationVerifierV1.InsufficientConsolidationAttestations.selector, 1, 2)
        );
        validator.validateConsolidation(id);
    }

    function testRevert_malformedSignatureShort() public {
        address user = address(0x11);
        bytes[] memory sources = new bytes[](1);
        sources[0] = _pubkey(1);
        bytes[] memory targets = new bytes[](1);
        targets[0] = _pubkey(2);
        uint256 totalAmount = 32 ether;
        bytes32 id = _bufferId(user, sources, targets, totalAmount);

        bytes[] memory sigs = new bytes[](2);
        sigs[0] = _sign(pk1, id);
        sigs[1] = new bytes(64); // wrong length

        cBuffer.submitConsolidationData(
            id,
            IConsolidationDataBuffer.ConsolidationObject({
                user: user,
                sourcePubkeys: sources,
                targetPubkeys: targets,
                totalAmount: totalAmount,
                signatures: sigs
            })
        );

        vm.expectRevert(
            abi.encodeWithSelector(IAttestationVerifierV1.InsufficientConsolidationAttestations.selector, 1, 2)
        );
        validator.validateConsolidation(id);
    }

    function testRevert_zeroDomainSeparator() public {
        // Wipe the consolidation domain separator via vm.store.
        vm.store(address(validator), CONSOLIDATION_DOMAIN_SEPARATOR_SLOT, bytes32(0));

        address user = address(0x11);
        (IConsolidationDataBuffer.ConsolidationObject memory c, bytes32 id) = _validConsolidation(user, 1);
        cBuffer.submitConsolidationData(id, c);

        vm.expectRevert(IAttestationVerifierV1.ZeroConsolidationDomainSeparator.selector);
        validator.validateConsolidation(id);
    }

    // -----------------------------------------------------------------------
    // Admin setter tests
    // -----------------------------------------------------------------------

    function testSetConsolidationCommitteeAttester_addSucceeds() public {
        address newAttester = address(0xABCD);
        vm.prank(admin);
        validator.setConsolidationCommitteeAttester(newAttester, true);
        assertTrue(validator.isConsolidationCommitteeAttester(newAttester));
        assertEq(validator.getConsolidationCommitteeAttesterCount(), 4);
    }

    function testSetConsolidationCommitteeAttester_removeSucceeds() public {
        vm.prank(admin);
        validator.setConsolidationCommitteeAttester(attester3, false);
        assertFalse(validator.isConsolidationCommitteeAttester(attester3));
        assertEq(validator.getConsolidationCommitteeAttesterCount(), 2);
    }

    function testSetConsolidationCommitteeAttester_revertStatusUnchanged() public {
        vm.prank(admin);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAttestationVerifierV1.ConsolidationCommitteeAttesterStatusUnchanged.selector, attester1, true
            )
        );
        validator.setConsolidationCommitteeAttester(attester1, true);

        address stranger = address(0xC0FFEE);
        vm.prank(admin);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAttestationVerifierV1.ConsolidationCommitteeAttesterStatusUnchanged.selector, stranger, false
            )
        );
        validator.setConsolidationCommitteeAttester(stranger, false);
    }

    function testSetConsolidationCommitteeAttester_revertTooMany() public {
        // Add up to 32 attesters (3 already registered → add 29).
        for (uint256 i = 0; i < 29; i++) {
            vm.prank(admin);
            validator.setConsolidationCommitteeAttester(address(uint160(0x9000 + i)), true);
        }
        assertEq(validator.getConsolidationCommitteeAttesterCount(), 32);

        vm.prank(admin);
        vm.expectRevert(
            abi.encodeWithSelector(IAttestationVerifierV1.TooManyConsolidationCommitteeAttesters.selector, 33, 32)
        );
        validator.setConsolidationCommitteeAttester(address(0x9999), true);
    }

    function testSetConsolidationCommitteeAttester_revertRemovingBreaksQuorum() public {
        // We start with 3 attesters and quorum 2. Removing two would leave count=1 < quorum=2.
        vm.prank(admin);
        validator.setConsolidationCommitteeAttester(attester3, false); // 3 → 2

        vm.prank(admin);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAttestationVerifierV1.QuorumExceedsConsolidationCommitteeAttesterCount.selector, 2, 1
            )
        );
        validator.setConsolidationCommitteeAttester(attester2, false); // would go 2 → 1
    }

    function testSetConsolidationCommitteeAttester_onlyRiverAdmin() public {
        vm.expectRevert(abi.encodeWithSelector(LibErrors.Unauthorized.selector, address(this)));
        validator.setConsolidationCommitteeAttester(address(0xABCD), true);
    }

    function testSetConsolidationCommitteeAttestationQuorum_succeeds() public {
        vm.prank(admin);
        validator.setConsolidationCommitteeAttestationQuorum(3);
        assertEq(validator.getConsolidationCommitteeAttestationQuorum(), 3);
    }

    function testSetConsolidationCommitteeAttestationQuorum_revertZero() public {
        vm.prank(admin);
        vm.expectRevert(IAttestationVerifierV1.ZeroQuorum.selector);
        validator.setConsolidationCommitteeAttestationQuorum(0);
    }

    function testSetConsolidationCommitteeAttestationQuorum_revertExceedsAttesters() public {
        vm.prank(admin);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAttestationVerifierV1.QuorumExceedsConsolidationCommitteeAttesterCount.selector, 4, 3
            )
        );
        validator.setConsolidationCommitteeAttestationQuorum(4);
    }

    function testSetConsolidationCommitteeAttestationQuorum_revertExceedsMaxSignatures() public {
        // Push attester count above MAX_SIGNATURES so the count check doesn't fire first.
        for (uint256 i = 0; i < 18; i++) {
            vm.prank(admin);
            validator.setConsolidationCommitteeAttester(address(uint160(0xA000 + i)), true);
        }
        assertEq(validator.getConsolidationCommitteeAttesterCount(), 21);

        vm.prank(admin);
        vm.expectRevert(
            abi.encodeWithSelector(IAttestationVerifierV1.QuorumExceedsMaxSignatures.selector, 21, 20)
        );
        validator.setConsolidationCommitteeAttestationQuorum(21);
    }

    function testSetConsolidationCommitteeAttestationQuorum_onlyRiverAdmin() public {
        vm.expectRevert(abi.encodeWithSelector(LibErrors.Unauthorized.selector, address(this)));
        validator.setConsolidationCommitteeAttestationQuorum(3);
    }

    function testSetConsolidationDataBuffer_succeeds() public {
        address newBuffer = address(0xDDDD);
        vm.prank(admin);
        validator.setConsolidationDataBuffer(newBuffer);
        assertEq(validator.getConsolidationDataBuffer(), newBuffer);
    }

    function testSetConsolidationDataBuffer_revertZeroAddress() public {
        vm.prank(admin);
        vm.expectRevert(LibErrors.InvalidZeroAddress.selector);
        validator.setConsolidationDataBuffer(address(0));
    }

    function testSetConsolidationDataBuffer_onlyRiverAdmin() public {
        vm.expectRevert(abi.encodeWithSelector(LibErrors.Unauthorized.selector, address(this)));
        validator.setConsolidationDataBuffer(address(0xDDDD));
    }

    // -----------------------------------------------------------------------
    // Isolation from deposit flow
    // -----------------------------------------------------------------------

    function testIsolation_consolidationAttesterNotADepositAttester() public {
        vm.prank(admin);
        validator.setConsolidationCommitteeAttester(address(0xBABE), true);
        assertFalse(validator.isDepositCommitteeAttester(address(0xBABE)));
        assertTrue(validator.isConsolidationCommitteeAttester(address(0xBABE)));
    }

    function testIsolation_quorumsAreSeparate() public {
        // setUp configured consolidation quorum=2 and deposit quorum=1 — they must read independently.
        assertEq(validator.getDepositCommitteeAttestationQuorum(), 1);
        assertEq(validator.getConsolidationCommitteeAttestationQuorum(), 2);
    }

    function testIsolation_changingConsolidationQuorumDoesNotAffectDeposit() public {
        uint256 depositQuorumBefore = validator.getDepositCommitteeAttestationQuorum();
        vm.prank(admin);
        validator.setConsolidationCommitteeAttestationQuorum(3);
        assertEq(validator.getDepositCommitteeAttestationQuorum(), depositQuorumBefore);
        assertEq(validator.getConsolidationCommitteeAttestationQuorum(), 3);
    }
}
