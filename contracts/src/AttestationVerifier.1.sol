//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import {ECDSA} from "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";

import "./Initializable.sol";
import "./interfaces/IAdministrable.sol";
import "./interfaces/IAttestationVerifier.1.sol";
import "./interfaces/IDepositContract.sol";
import "./interfaces/IDepositDataBuffer.sol";

import "./libraries/BLS12_381.sol";
import "./libraries/LibErrors.sol";

import "./state/attestationVerifier/ConsolidationCommitteeAttestationQuorum.sol";
import "./state/attestationVerifier/ConsolidationCommitteeAttesters.sol";
import "./state/attestationVerifier/ConsolidationDomainSeparator.sol";
import "./state/attestationVerifier/ProcessedConsolidations.sol";
import "./state/attestationVerifier/RootAttestationQuorum.sol";
import "./state/attestationVerifier/RootAttesters.sol";
import "./state/attestationVerifier/DepositDataBufferAddress.sol";
import "./state/attestationVerifier/DepositDomainValue.sol";
import "./state/attestationVerifier/DomainSeparator.sol";
import "./state/attestationVerifier/ProcessedDepositDataBufferIds.sol";
import "./state/attestationVerifier/PectraValidatorPubkeyLookup.sol";
import "./state/shared/RiverAddress.sol";

/// @title AttestationVerifier (v1)
/// @author Alluvial Finance Inc.
/// @notice Sibling contract that validates committee attestations on behalf of River
///         for two independent flows, each with its own committee, quorum, and EIP-712
///         domain separator anchored to River:
///
///         1. Deposit flow (`validateDeposits`):
///            Validates attestation-quorum + BLS deposit messages over a batch fetched
///            from the `DepositDataBuffer`, enforces withdrawal-credentials and
///            committed-balance bounds, and returns the validated batch + total
///            amount for River to execute. River retains keeper authorization,
///            slashing-containment gating, ETH execution, operator funding accounting,
///            and balance bookkeeping. View-only.
///
///         2. Consolidation flow (`validateConsolidation`):
///            Validates EIP-7251 consolidation requests passed in directly as a
///            `ConsolidationObject` struct (no on-chain buffer). Verifies the
///            consolidation-committee attestation quorum over a typed-data digest
///            built from the request fields, and marks the request as processed
///            for replay protection. State-mutating.
///
///         Extracted from RiverV1 to keep River's deployed bytecode under EIP-170.
contract AttestationVerifierV1 is Initializable, IAttestationVerifierV1 {
    // -----------------------------------------------------------------------
    // EIP-712
    // -----------------------------------------------------------------------

    bytes32 internal constant EIP712_DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    bytes32 internal constant NAME_HASH = keccak256("DepositToConsensusLayerValidation");
    bytes32 internal constant VERSION_HASH = keccak256("1");

    bytes32 internal constant ATTEST_TYPEHASH =
        keccak256("Attest(bytes32 depositDataBufferId,bytes32 depositRootHash)");

    /// @notice EIP-712 name used by the consolidation-attestation domain separator.
    /// @dev    Distinct from `NAME_HASH` so attestor signatures cannot be replayed
    ///         across the deposit and consolidation flows even if the rest of the
    ///         domain (chainId, verifyingContract, version) were identical.
    bytes32 internal constant CONSOLIDATION_NAME_HASH = keccak256("ConsolidationValidation");

    /// @dev EIP-712 typehash for a consolidation attestation. The four request fields are
    ///      hashed directly into the EIP-712 struct (rather than first being squashed into a
    ///      single `bytes32` id). `bytes[]` fields follow EIP-712 dynamic-array rules:
    ///      each element is replaced by `keccak256(element)`, then the resulting `bytes32`
    ///      array is concatenated and hashed (`_hashBytesArray`).
    bytes32 internal constant ATTEST_CONSOLIDATION_TYPEHASH = keccak256(
        "AttestConsolidation(address withdrawalAddress,bytes[] sourcePubkeys,bytes[] targetPubkeys,uint256 totalAmount)"
    );

    /// @notice Maximum number of signatures accepted. Bounds the O(n^2) duplicate-detection loop.
    uint256 public constant MAX_SIGNATURES = 20;

    /// @notice Maximum number of registered root attesters. Defensive cap to bound storage growth.
    uint256 public constant MAX_ROOT_ATTESTERS = 32;

    /// @notice Maximum number of registered consolidation-committee attesters. Defensive cap to bound storage growth.
    uint256 public constant MAX_CONSOLIDATION_COMMITTEE_ATTESTERS = 32;

    /// @dev Expected lengths for fixed BLS-related fields in a DepositObject.
    uint256 internal constant DEPOSIT_PUBKEY_LENGTH = 48;
    uint256 internal constant DEPOSIT_SIGNATURE_LENGTH = 96;

    /// @dev Expected length for BLS pubkeys in a ConsolidationObject (source or target).
    uint256 internal constant CONSOLIDATION_PUBKEY_LENGTH = 48;

    // -----------------------------------------------------------------------
    // Modifiers
    // -----------------------------------------------------------------------

    /// @notice Restrict to River's admin via cross-contract view call.
    /// @dev Single source of truth for governance — same admin manages River and this verifier.
    modifier onlyRiverAdmin() {
        if (msg.sender != IAdministrable(RiverAddress.get()).getAdmin()) {
            revert LibErrors.Unauthorized(msg.sender);
        }
        _;
    }

    /// @notice Restrict to River itself (the deposit-execution path), not its admin.
    /// @dev Used to gate state-mutating callbacks that should only fire as part of a
    ///      River-initiated deposit flow (e.g. `recordNewlyFundedPubkeys`).
    modifier onlyRiver() {
        if (msg.sender != RiverAddress.get()) {
            revert LibErrors.Unauthorized(msg.sender);
        }
        _;
    }

    // -----------------------------------------------------------------------
    // Initialization
    // -----------------------------------------------------------------------

    /// @inheritdoc IAttestationVerifierV1
    function initAttestationVerifierV1(
        address _river,
        address _depositDataBuffer,
        address[] calldata _rootAttesters,
        uint256 _quorum,
        bytes4 _genesisForkVersion,
        address[] calldata _consolidationCommitteeAttesters,
        uint256 _consolidationQuorum
    ) external init(0) {
        // ---- Validate deposit-side parameters ----
        if (_rootAttesters.length == 0 || _rootAttesters.length > MAX_ROOT_ATTESTERS) {
            revert LibErrors.InvalidArgument();
        }
        if (_quorum == 0) revert ZeroQuorum();
        if (_quorum > MAX_SIGNATURES) revert QuorumExceedsMaxSignatures(_quorum, MAX_SIGNATURES);

        // ---- Validate consolidation-side parameters ----
        if (
            _consolidationCommitteeAttesters.length == 0
                || _consolidationCommitteeAttesters.length > MAX_CONSOLIDATION_COMMITTEE_ATTESTERS
        ) {
            revert LibErrors.InvalidArgument();
        }
        if (_consolidationQuorum == 0) revert ZeroQuorum();
        if (_consolidationQuorum > MAX_SIGNATURES) {
            revert QuorumExceedsMaxSignatures(_consolidationQuorum, MAX_SIGNATURES);
        }

        // ---- Validate consolidation-side parameters ----
        if (
            _consolidationCommitteeAttesters.length == 0
                || _consolidationCommitteeAttesters.length > MAX_CONSOLIDATION_COMMITTEE_ATTESTERS
        ) {
            revert LibErrors.InvalidArgument();
        }
        if (_consolidationQuorum == 0) revert ZeroQuorum();
        if (_consolidationQuorum > MAX_SIGNATURES) {
            revert QuorumExceedsMaxSignatures(_consolidationQuorum, MAX_SIGNATURES);
        }

        // ---- River + buffers + BLS deposit domain ----
        RiverAddress.set(_river);
        emit SetRiver(_river);

        DepositDataBufferAddress.set(_depositDataBuffer);
        emit SetDepositDataBuffer(_depositDataBuffer);

        bytes32 depositDomain = BLS12_381.computeDepositDomain(_genesisForkVersion);
        DepositDomainValue.set(depositDomain);
        emit SetDepositDomain(depositDomain);

        for (uint256 i = 0; i < _rootAttesters.length; i++) {
            if (!RootAttesters.isRootAttester(_rootAttesters[i])) {
                RootAttesters.setRootAttester(_rootAttesters[i], true);
                RootAttesters.setCount(RootAttesters.getCount() + 1);
                emit SetRootAttester(_rootAttesters[i], true);
            }
        }
        {
            uint256 rootAttesterCount = RootAttesters.getCount();
            if (_quorum > rootAttesterCount) {
                revert QuorumExceedsRootAttesterCount(_quorum, rootAttesterCount);
            }
            RootAttestationQuorum.set(_quorum);
            emit SetRootAttestationQuorum(_quorum);
        }

        // ---- Consolidation committee + quorum ----
        for (uint256 i = 0; i < _consolidationCommitteeAttesters.length; i++) {
            if (!ConsolidationCommitteeAttesters.isConsolidationCommitteeAttester(_consolidationCommitteeAttesters[i]))
            {
                ConsolidationCommitteeAttesters.setConsolidationCommitteeAttester(
                    _consolidationCommitteeAttesters[i], true
                );
                ConsolidationCommitteeAttesters.setCount(ConsolidationCommitteeAttesters.getCount() + 1);
                emit SetConsolidationCommitteeAttester(_consolidationCommitteeAttesters[i], true);
            }
        }
        {
            uint256 consolidationAttesterCount = ConsolidationCommitteeAttesters.getCount();
            if (_consolidationQuorum > consolidationAttesterCount) {
                revert QuorumExceedsConsolidationCommitteeAttesterCount(
                    _consolidationQuorum, consolidationAttesterCount
                );
            }
            ConsolidationCommitteeAttestationQuorum.set(_consolidationQuorum);
            emit SetConsolidationCommitteeAttestationQuorum(_consolidationQuorum);
        }
        {
            // EIP-712 domain separator binds verifyingContract to River's address, not this
            // verifier's own address. This preserves root attester signing tooling that
            // signs against River's identity even if the verifier is later redeployed.
            bytes32 domainSeparator =
                keccak256(abi.encode(EIP712_DOMAIN_TYPEHASH, NAME_HASH, VERSION_HASH, block.chainid, _river));
            DomainSeparator.set(domainSeparator);
            emit SetDomainSeparator(domainSeparator);

            domainSeparator = keccak256(
                abi.encode(EIP712_DOMAIN_TYPEHASH, CONSOLIDATION_NAME_HASH, VERSION_HASH, block.chainid, _river)
            );
            ConsolidationDomainSeparator.set(domainSeparator);
            emit SetConsolidationDomainSeparator(domainSeparator);
        }
    }

    // -----------------------------------------------------------------------
    // Admin setters
    // -----------------------------------------------------------------------

    /// @inheritdoc IAttestationVerifierV1
    function setDepositDataBuffer(address _depositDataBuffer) external onlyRiverAdmin {
        DepositDataBufferAddress.set(_depositDataBuffer);
        emit SetDepositDataBuffer(_depositDataBuffer);
    }

    /// @inheritdoc IAttestationVerifierV1
    function setRootAttester(address rootAttester, bool value) external onlyRiverAdmin {
        bool current = RootAttesters.isRootAttester(rootAttester);
        if (current == value) revert RootAttesterStatusUnchanged(rootAttester, value);

        uint256 count = RootAttesters.getCount();
        uint256 newCount = value ? count + 1 : count - 1;
        if (value && newCount > MAX_ROOT_ATTESTERS) {
            revert TooManyRootAttesters(newCount, MAX_ROOT_ATTESTERS);
        }
        uint256 currentQuorum = RootAttestationQuorum.get();
        if (!value && currentQuorum > newCount) {
            revert QuorumExceedsRootAttesterCount(currentQuorum, newCount);
        }

        RootAttesters.setCount(newCount);
        RootAttesters.setRootAttester(rootAttester, value);
        emit SetRootAttester(rootAttester, value);
    }

    /// @inheritdoc IAttestationVerifierV1
    function setRootAttestationQuorum(uint256 newQuorum) external onlyRiverAdmin {
        if (newQuorum == 0) revert ZeroQuorum();
        uint256 rootAttesterCount = RootAttesters.getCount();
        if (newQuorum > rootAttesterCount) {
            revert QuorumExceedsRootAttesterCount(newQuorum, rootAttesterCount);
        }
        if (newQuorum > MAX_SIGNATURES) revert QuorumExceedsMaxSignatures(newQuorum, MAX_SIGNATURES);
        RootAttestationQuorum.set(newQuorum);
        emit SetRootAttestationQuorum(newQuorum);
    }

    /// @inheritdoc IAttestationVerifierV1
    function setConsolidationCommitteeAttester(address consolidationCommitteeAttester, bool value)
        external
        onlyRiverAdmin
    {
        bool current = ConsolidationCommitteeAttesters.isConsolidationCommitteeAttester(consolidationCommitteeAttester);
        if (current == value) {
            revert ConsolidationCommitteeAttesterStatusUnchanged(consolidationCommitteeAttester, value);
        }

        uint256 count = ConsolidationCommitteeAttesters.getCount();
        uint256 newCount = value ? count + 1 : count - 1;
        if (value && newCount > MAX_CONSOLIDATION_COMMITTEE_ATTESTERS) {
            revert TooManyConsolidationCommitteeAttesters(newCount, MAX_CONSOLIDATION_COMMITTEE_ATTESTERS);
        }
        uint256 currentQuorum = ConsolidationCommitteeAttestationQuorum.get();
        if (!value && currentQuorum > newCount) {
            revert QuorumExceedsConsolidationCommitteeAttesterCount(currentQuorum, newCount);
        }

        ConsolidationCommitteeAttesters.setCount(newCount);
        ConsolidationCommitteeAttesters.setConsolidationCommitteeAttester(consolidationCommitteeAttester, value);
        emit SetConsolidationCommitteeAttester(consolidationCommitteeAttester, value);
    }

    /// @inheritdoc IAttestationVerifierV1
    function setConsolidationCommitteeAttestationQuorum(uint256 newQuorum) external onlyRiverAdmin {
        if (newQuorum == 0) revert ZeroQuorum();
        uint256 attesterCount = ConsolidationCommitteeAttesters.getCount();
        if (newQuorum > attesterCount) {
            revert QuorumExceedsConsolidationCommitteeAttesterCount(newQuorum, attesterCount);
        }
        if (newQuorum > MAX_SIGNATURES) revert QuorumExceedsMaxSignatures(newQuorum, MAX_SIGNATURES);
        ConsolidationCommitteeAttestationQuorum.set(newQuorum);
        emit SetConsolidationCommitteeAttestationQuorum(newQuorum);
    }

    // -----------------------------------------------------------------------
    // Views
    // -----------------------------------------------------------------------

    /// @inheritdoc IAttestationVerifierV1
    function isRootAttester(address account) external view returns (bool) {
        return RootAttesters.isRootAttester(account);
    }

    /// @inheritdoc IAttestationVerifierV1
    function getRootAttesterCount() external view returns (uint256) {
        return RootAttesters.getCount();
    }

    /// @inheritdoc IAttestationVerifierV1
    function getRootAttestationQuorum() external view returns (uint256) {
        return RootAttestationQuorum.get();
    }

    /// @inheritdoc IAttestationVerifierV1
    function getDepositDataBuffer() external view returns (address) {
        return DepositDataBufferAddress.get();
    }

    /// @inheritdoc IAttestationVerifierV1
    function getDomainSeparator() external view returns (bytes32) {
        return DomainSeparator.get();
    }

    /// @inheritdoc IAttestationVerifierV1
    // solhint-disable-next-line func-name-mixedcase
    function DEPOSIT_DOMAIN() external view returns (bytes32) {
        return DepositDomainValue.get();
    }

    /// @inheritdoc IAttestationVerifierV1
    function getRiver() external view returns (address) {
        return RiverAddress.get();
    }

    /// @inheritdoc IAttestationVerifierV1
    function isConsolidationCommitteeAttester(address account) external view returns (bool) {
        return ConsolidationCommitteeAttesters.isConsolidationCommitteeAttester(account);
    }

    /// @inheritdoc IAttestationVerifierV1
    function getConsolidationCommitteeAttesterCount() external view returns (uint256) {
        return ConsolidationCommitteeAttesters.getCount();
    }

    /// @inheritdoc IAttestationVerifierV1
    function getConsolidationCommitteeAttestationQuorum() external view returns (uint256) {
        return ConsolidationCommitteeAttestationQuorum.get();
    }

    /// @inheritdoc IAttestationVerifierV1
    function getConsolidationDomainSeparator() external view returns (bytes32) {
        return ConsolidationDomainSeparator.get();
    }

    // -----------------------------------------------------------------------
    // Validate-and-prepare entry points
    // -----------------------------------------------------------------------

    /// @inheritdoc IAttestationVerifierV1
    function validateDeposits(
        bytes32 depositDataBufferId,
        bytes32 depositRootHash,
        bytes[] calldata signatures,
        address depositContract,
        bytes32 withdrawalCredentials,
        uint256 committedBalance
    ) external view returns (IDepositDataBuffer.DepositObject memory batch, uint256 totalAmount) {
        // 0. Replay protection — reject any batch ID already processed
        if (ProcessedDepositDataBufferIds.isProcessed(depositDataBufferId)) {
            revert DepositDataBufferIdAlreadyProcessed(depositDataBufferId);
        }

        // 1. Verify attestation quorum
        _verifyAttestationQuorum(depositDataBufferId, depositRootHash, signatures, depositContract);

        // 2. Get deposit batch from buffer
        batch = IDepositDataBuffer(DepositDataBufferAddress.get()).getDepositData(depositDataBufferId);
        uint256 depositCount = batch.deposits.length;
        uint256 topUpCount = batch.topUps.length;
        if (depositCount == 0 && topUpCount == 0) revert NoDeposits();

        // 3. Re-compute and check the bufferId binding so the buffer cannot tamper post-attestation
        bytes32 computedId = keccak256(abi.encode(batch));
        if (computedId != depositDataBufferId) revert BufferIdMismatch(depositDataBufferId, computedId);

        // 4. Validate initial deposits: field lengths, amount bounds, pubkey-not-already-funded
        //    and no in-batch duplicates. The cross-array "pubkey in both deposits and topUps"
        //    case is implicitly forbidden: an initial deposit reverts PubkeyAlreadyFunded if
        //    the pubkey is in the lookup, and a top-up reverts TopUpPubkeyNotFunded if it
        //    isn't — so no pubkey can pass both branches in one batch.
        bytes32[] memory pubkeyHashes = new bytes32[](depositCount);
        for (uint256 i = 0; i < depositCount; i++) {
            IDepositDataBuffer.Deposit memory d = batch.deposits[i];
            if (d.pubkey.length != DEPOSIT_PUBKEY_LENGTH) {
                revert InvalidPubkeyLength(i, d.pubkey.length);
            }
            if (d.signature.length != DEPOSIT_SIGNATURE_LENGTH) {
                revert InvalidSignatureLength(i, d.signature.length);
            }
            // Mirrors the bound check inside `_depositValidator` so we fail early
            if (d.amount < 1 ether || d.amount > 2048 ether || d.amount % 1 gwei != 0) {
                revert InvalidDepositAmount(i, d.amount);
            }
            totalAmount += d.amount;

            bytes32 pkHash = keccak256(d.pubkey);
            pubkeyHashes[i] = pkHash;

            if (PectraValidatorPubkeyLookup.isPubkeyFunded(d.pubkey)) {
                revert PubkeyAlreadyFunded(d.pubkey);
            }
            for (uint256 j = 0; j < i; j++) {
                if (pubkeyHashes[j] == pkHash) {
                    revert PubkeyAlreadyFunded(d.pubkey);
                }
            }
        }

        // 5. Validate top-ups: field length on pubkey, amount bounds, pubkey-must-be-funded.
        //    Per-batch duplicate top-up pubkeys are allowed.
        for (uint256 i = 0; i < topUpCount; i++) {
            IDepositDataBuffer.TopUp memory t = batch.topUps[i];
            if (t.pubkey.length != DEPOSIT_PUBKEY_LENGTH) {
                revert InvalidPubkeyLength(i, t.pubkey.length);
            }
            if (t.amount < 1 ether || t.amount > 2048 ether || t.amount % 1 gwei != 0) {
                revert InvalidDepositAmount(i, t.amount);
            }
            totalAmount += t.amount;

            if (!PectraValidatorPubkeyLookup.isPubkeyFunded(t.pubkey)) {
                revert TopUpPubkeyNotFunded(t.pubkey);
            }
        }
        if (totalAmount > committedBalance) revert NotEnoughFunds();

        // 6. Verify BLS signatures against canonical River WC (initials only).
        _verifyBLSSignatures(batch.deposits, withdrawalCredentials);
    }

    // -----------------------------------------------------------------------
    // Initial-deposit recording (callback from River after the deposit-execution loop)
    // -----------------------------------------------------------------------

    /// @inheritdoc IAttestationVerifierV1
    /// @dev Assumes `pubkeys` is already deduplicated against the lookup and against itself —
    ///      `validateDeposits()` enforces both invariants (initial-deposit branch at the top of
    ///      `validateDeposits()`) and runs in the same transaction. Re-checking here would only fire
    ///      on a `validateDeposits()` regression and would cost a cold SLOAD per pubkey for a
    ///      condition that cannot occur in production.
    function recordNewlyFundedPubkeys(bytes[] calldata pubkeys) external onlyRiver {
        uint256 len = pubkeys.length;
        for (uint256 i = 0; i < len; ++i) {
            PectraValidatorPubkeyLookup.add(pubkeys[i]);
        }
    }

    /// @inheritdoc IAttestationVerifierV1
    function isPubkeyFunded(bytes calldata pubkey) external view returns (bool) {
        return PectraValidatorPubkeyLookup.isPubkeyFunded(pubkey);
    }

    /// @inheritdoc IAttestationVerifierV1
    function markDepositDataBufferIdProcessed(bytes32 depositDataBufferId) external onlyRiver {
        ProcessedDepositDataBufferIds.markProcessed(depositDataBufferId);
    }

    /// @inheritdoc IAttestationVerifierV1
    function isDepositDataBufferIdProcessed(bytes32 depositDataBufferId) external view returns (bool) {
        return ProcessedDepositDataBufferIds.isProcessed(depositDataBufferId);
    }

    /// @inheritdoc IAttestationVerifierV1
    /// @dev Trust boundary: this function only validates structural shape (array shapes
    ///      and pubkey byte lengths) and the attestation quorum (ECDSA signature recovery
    ///      against the consolidation committee). It does NOT check:
    ///        - Source/target pubkey uniqueness within the request (EIP-7251 single-use
    ///          source rule). A source pubkey appearing twice, or a pubkey appearing in
    ///          both source and target arrays, is not rejected here.
    ///        - `totalAmount` gwei alignment, upper bound, or correlation with the number
    ///          of (source, target) pairs.
    ///        - Whether the source validators actually exist on the consensus layer or
    ///          carry the protocol's withdrawal credentials.
    ///      These are the responsibility of the caller (off-chain pipeline) and the
    ///      consolidation committee that signs the request. The eventual
    ///      `mintLsETHForConsolidation` River integration is the place to enforce any
    ///      additional financial caps on `totalAmount`.
    function validateConsolidation(IAttestationVerifierV1.ConsolidationObject calldata consolidation)
        external
        onlyRiver
        returns (bool)
    {
        // 1. Structural checks (cheapest first — fail fast)
        uint256 sourceLen = consolidation.sourcePubkeys.length;
        uint256 targetLen = consolidation.targetPubkeys.length;
        if (sourceLen == 0) revert NoConsolidations();
        if (sourceLen != targetLen) revert ConsolidationArrayLengthMismatch(sourceLen, targetLen);
        if (consolidation.totalAmount == 0) revert ZeroConsolidationTotalAmount();
        if (consolidation.withdrawalAddress == address(0)) revert ZeroConsolidationWithdrawalAddress();

        // 2. Per-pair pubkey length checks
        for (uint256 i = 0; i < sourceLen; i++) {
            if (consolidation.sourcePubkeys[i].length != CONSOLIDATION_PUBKEY_LENGTH) {
                revert InvalidConsolidationPubkeyLength(i, consolidation.sourcePubkeys[i].length, true);
            }
            if (consolidation.targetPubkeys[i].length != CONSOLIDATION_PUBKEY_LENGTH) {
                revert InvalidConsolidationPubkeyLength(i, consolidation.targetPubkeys[i].length, false);
            }
        }

        // 3. Compute the EIP-712 digest the committee signed.
        //    The struct's `signatures` field is NOT part of the typed data — only the four
        //    request fields are. `bytes[]` arrays follow EIP-712 array rules: each element
        //    becomes `keccak256(element)`, then the array hashes to `keccak256` over the
        //    concatenation of those 32-byte element hashes.
        bytes32 domainSep = ConsolidationDomainSeparator.get();
        if (domainSep == bytes32(0)) revert ZeroConsolidationDomainSeparator();
        bytes32 structHash = keccak256(
            abi.encode(
                ATTEST_CONSOLIDATION_TYPEHASH,
                consolidation.withdrawalAddress,
                _hashBytesArray(consolidation.sourcePubkeys),
                _hashBytesArray(consolidation.targetPubkeys),
                consolidation.totalAmount
            )
        );

        // 4. Replay protection — reject any consolidation we've already accepted.
        //    Checked BEFORE quorum verification so a previously-accepted request fails fast
        //    even if the supplied signatures happen to be valid again.
        if (ProcessedConsolidations.isProcessed(structHash)) {
            revert ConsolidationAlreadyProcessed(structHash);
        }

        // 5. Verify the consolidation attestation quorum from the supplied signatures
        bytes32 digest = ECDSA.toTypedDataHash(domainSep, structHash);
        _verifyConsolidationAttestationQuorum(digest, consolidation.signatures);

        // 6. Mark as processed and emit
        ProcessedConsolidations.markProcessed(structHash);
        emit ConsolidationProcessed(structHash);

        return true;
    }

    // -----------------------------------------------------------------------
    // Internal — attestation quorum + BLS verification
    // -----------------------------------------------------------------------

    /// @notice Verify the attestation quorum.
    /// @param depositDataBufferId The deposit data buffer ID.
    /// @param depositRootHash The deposit root hash.
    /// @param signatures The signatures.
    /// @param depositContract The official ETH deposit contract supplied by River.
    function _verifyAttestationQuorum(
        bytes32 depositDataBufferId,
        bytes32 depositRootHash,
        bytes[] calldata signatures,
        address depositContract
    ) internal view {
        uint256 sigLen = signatures.length;
        if (sigLen > MAX_SIGNATURES) revert TooManySignatures(sigLen, MAX_SIGNATURES);

        uint256 quorum = RootAttestationQuorum.get();
        if (quorum == 0) revert ZeroQuorum();
        if (sigLen < quorum) revert InsufficientAttestations(sigLen, quorum);

        // Whilst this could be checked earlier in the flow, this way the function is self-contained and performs all the checks required to ensure the attestations are valid in one place.
        bytes32 onChainRoot = IDepositContract(depositContract).get_deposit_root();
        if (onChainRoot != depositRootHash) revert DepositRootMismatch(depositRootHash, onChainRoot);

        bytes32 domainSep = DomainSeparator.get();
        if (domainSep == bytes32(0)) revert ZeroDomainSeparator();
        bytes32 structHash = keccak256(abi.encode(ATTEST_TYPEHASH, depositDataBufferId, depositRootHash));
        bytes32 digest = ECDSA.toTypedDataHash(domainSep, structHash);

        uint256 validCount = 0;
        address[] memory seen = new address[](sigLen);

        for (uint256 i = 0; i < sigLen; i++) {
            address signer = _recover(digest, signatures[i]);
            if (signer == address(0)) continue;
            if (!RootAttesters.isRootAttester(signer)) continue;

            bool duplicate = false;
            for (uint256 j = 0; j < validCount; j++) {
                if (seen[j] == signer) {
                    duplicate = true;
                    break;
                }
            }
            if (duplicate) continue;

            seen[validCount] = signer;
            validCount++;
        }

        if (validCount < quorum) revert InsufficientAttestations(validCount, quorum);
    }

    /// @notice Verify the consolidation-attestation quorum over the supplied signatures.
    /// @dev    Pure signature-recovery loop. The caller has already constructed the EIP-712
    ///         digest from the request fields and looked up the consolidation domain separator;
    ///         this helper only enforces bounds, recovers signers, dedups them against the
    ///         registered committee, and asserts the quorum.
    /// @param digest      The EIP-712 digest the committee signed
    /// @param signatures  Signatures supplied alongside the consolidation request
    function _verifyConsolidationAttestationQuorum(bytes32 digest, bytes[] calldata signatures) internal view {
        uint256 sigLen = signatures.length;
        if (sigLen > MAX_SIGNATURES) revert TooManySignatures(sigLen, MAX_SIGNATURES);

        uint256 quorum = ConsolidationCommitteeAttestationQuorum.get();
        if (quorum == 0) revert ZeroQuorum();
        if (sigLen < quorum) revert InsufficientConsolidationAttestations(sigLen, quorum);

        uint256 validCount = 0;
        address[] memory seen = new address[](sigLen);

        for (uint256 i = 0; i < sigLen; i++) {
            address signer = _recover(digest, signatures[i]);
            if (signer == address(0)) continue;
            if (!ConsolidationCommitteeAttesters.isConsolidationCommitteeAttester(signer)) continue;

            bool duplicate = false;
            for (uint256 j = 0; j < validCount; j++) {
                if (seen[j] == signer) {
                    duplicate = true;
                    break;
                }
            }
            if (duplicate) continue;

            seen[validCount] = signer;
            validCount++;
        }

        if (validCount < quorum) revert InsufficientConsolidationAttestations(validCount, quorum);
    }

    /// @dev EIP-712 array hash for a `bytes[]` field. Each element is replaced by its
    ///      `keccak256`, and the resulting `bytes32[]` is concatenated and hashed.
    function _hashBytesArray(bytes[] calldata arr) internal pure returns (bytes32) {
        bytes32[] memory hashes = new bytes32[](arr.length);
        for (uint256 i = 0; i < arr.length; i++) {
            hashes[i] = keccak256(arr[i]);
        }
        return keccak256(abi.encodePacked(hashes));
    }

    /// @notice Verify the BLS signatures of all initial deposits against the canonical River
    ///         withdrawal credentials. Top-ups are handled by the caller and never reach this
    ///         function — they're cleared upstream in `validateDeposits()` via the membership check
    ///         on `PectraValidatorPubkeyLookup`.
    /// @param deposits The initial deposits.
    /// @param withdrawalCredentials The canonical River withdrawal credentials.
    function _verifyBLSSignatures(IDepositDataBuffer.Deposit[] memory deposits, bytes32 withdrawalCredentials)
        internal
        view
    {
        for (uint256 i = 0; i < deposits.length; i++) {
            (bool ok, bytes memory revertData) = address(this)
                .staticcall(
                    abi.encodeCall(
                        this.verifyBLSDeposit,
                        (
                            deposits[i].pubkey,
                            deposits[i].signature,
                            deposits[i].amount,
                            deposits[i].depositY,
                            withdrawalCredentials
                        )
                    )
                );
            if (!ok) {
                assembly {
                    revert(add(revertData, 32), mload(revertData))
                }
            }
        }
    }

    /// @notice Verify a single BLS deposit message against the cached deposit domain.
    /// @dev External only as a self-staticcall trampoline from validateDeposits: the call
    ///      promotes the deposit's memory bytes into calldata so BLS12_381 can consume them
    ///      without a memory copy. Direct external callers revert with `OnlySelfCall` —
    ///      the function is restricted to `address(this)` and not part of the contract's
    ///      public API.
    /// @param pubkey The BLS public key (48 bytes)
    /// @param signature The BLS signature (96 bytes)
    /// @param amount The deposit amount in wei (must be gwei-aligned; verified inside BLS12_381.verifyDepositMessage)
    /// @param depositY The Y-coordinates required for BLS decompression
    /// @param withdrawalCredentials The 32-byte withdrawal credentials
    function verifyBLSDeposit(
        bytes calldata pubkey,
        bytes calldata signature,
        uint256 amount,
        BLS12_381.DepositY calldata depositY,
        bytes32 withdrawalCredentials
    ) external view {
        if (msg.sender != address(this)) revert OnlySelfCall();
        bytes32 depositDomain = DepositDomainValue.get();
        if (depositDomain == bytes32(0)) revert ZeroDepositDomain();
        BLS12_381.verifyDepositMessage(pubkey, signature, amount, depositY, withdrawalCredentials, depositDomain);
    }

    // -----------------------------------------------------------------------
    // Internal helpers
    // -----------------------------------------------------------------------

    /// @dev Recover signer from a 65-byte EIP-712 signature, normalizing v.
    /// @param digest The digest.
    /// @param sig The signature.
    /// @return The recovered signer.
    function _recover(bytes32 digest, bytes calldata sig) internal pure returns (address) {
        if (sig.length != 65) return address(0);

        uint8 v = uint8(sig[64]);
        if (v < 27) v += 27;
        if (v != 27 && v != 28) return address(0);

        bytes32 r;
        bytes32 s;
        assembly {
            r := calldataload(sig.offset)
            s := calldataload(add(sig.offset, 0x20))
        }

        (address recovered, ECDSA.RecoverError err) = ECDSA.tryRecover(digest, v, r, s);
        if (err != ECDSA.RecoverError.NoError) return address(0);
        return recovered;
    }
}
