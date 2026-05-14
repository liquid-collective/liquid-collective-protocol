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

import "./state/attestationVerifier/DepositCommitteeAttestationQuorum.sol";
import "./state/attestationVerifier/DepositCommitteeAttesters.sol";
import "./state/attestationVerifier/DepositDataBufferAddress.sol";
import "./state/attestationVerifier/DepositDomainValue.sol";
import "./state/attestationVerifier/DomainSeparator.sol";
import "./state/shared/RiverAddress.sol";

/// @title AttestationVerifier (v1)
/// @author Alluvial Finance Inc.
/// @notice Sibling contract that validates attestation-quorum + BLS deposit messages
///         on behalf of River. Extracted from RiverV1 to keep River's deployed
///         bytecode under EIP-170. River delegates to this contract for steps 3 and 4
///         of the attestation deposit flow (quorum/BLS verify, WC + total-amount check)
///         while retaining keeper authorization, slashing-containment gating, ETH
///         execution, operator funding accounting, and balance bookkeeping.
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

    /// @notice Maximum number of signatures accepted. Bounds the O(n^2) duplicate-detection loop.
    uint256 public constant MAX_SIGNATURES = 20;

    /// @notice Maximum number of registered deposit-committee attesters. Defensive cap to bound storage growth.
    uint256 public constant MAX_DEPOSIT_COMMITTEE_ATTESTERS = 32;

    /// @dev Expected lengths for fixed BLS-related fields in a DepositObject.
    uint256 internal constant DEPOSIT_PUBKEY_LENGTH = 48;
    uint256 internal constant DEPOSIT_SIGNATURE_LENGTH = 96;

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

    // -----------------------------------------------------------------------
    // Initialization
    // -----------------------------------------------------------------------

    /// @inheritdoc IAttestationVerifierV1
    function initAttestationVerifierV1(
        address _river,
        address _depositDataBuffer,
        address[] calldata _depositCommitteeAttesters,
        uint256 _quorum,
        bytes4 _genesisForkVersion
    ) external init(0) {
        if (
            _depositCommitteeAttesters.length == 0
                || _depositCommitteeAttesters.length > MAX_DEPOSIT_COMMITTEE_ATTESTERS
        ) {
            revert LibErrors.InvalidArgument();
        }
        if (_quorum == 0) revert ZeroQuorum();
        if (_quorum > MAX_SIGNATURES) revert QuorumExceedsMaxSignatures(_quorum, MAX_SIGNATURES);

        RiverAddress.set(_river);
        emit SetRiver(_river);

        DepositDataBufferAddress.set(_depositDataBuffer);
        emit SetDepositDataBuffer(_depositDataBuffer);

        bytes32 depositDomain = BLS12_381.computeDepositDomain(_genesisForkVersion);
        DepositDomainValue.set(depositDomain);
        emit SetDepositDomain(depositDomain);

        for (uint256 i = 0; i < _depositCommitteeAttesters.length; i++) {
            if (!DepositCommitteeAttesters.isDepositCommitteeAttester(_depositCommitteeAttesters[i])) {
                DepositCommitteeAttesters.setDepositCommitteeAttester(_depositCommitteeAttesters[i], true);
                DepositCommitteeAttesters.setCount(DepositCommitteeAttesters.getCount() + 1);
                emit SetDepositCommitteeAttester(_depositCommitteeAttesters[i], true);
            }
        }
        uint256 depositCommitteeAttesterCount = DepositCommitteeAttesters.getCount();
        if (_quorum > depositCommitteeAttesterCount) {
            revert QuorumExceedsDepositCommitteeAttesterCount(_quorum, depositCommitteeAttesterCount);
        }
        DepositCommitteeAttestationQuorum.set(_quorum);
        emit SetDepositCommitteeAttestationQuorum(_quorum);

        // EIP-712 domain separator binds verifyingContract to River's address, not this
        // verifier's own address. This preserves deposit-committee attester signing tooling that
        // signs against River's identity even if the verifier is later redeployed.
        bytes32 domainSeparator =
            keccak256(abi.encode(EIP712_DOMAIN_TYPEHASH, NAME_HASH, VERSION_HASH, block.chainid, _river));
        DomainSeparator.set(domainSeparator);
        emit SetDomainSeparator(domainSeparator);
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
    function setDepositCommitteeAttester(address depositCommitteeAttester, bool value) external onlyRiverAdmin {
        bool current = DepositCommitteeAttesters.isDepositCommitteeAttester(depositCommitteeAttester);
        if (current == value) revert DepositCommitteeAttesterStatusUnchanged(depositCommitteeAttester, value);

        uint256 count = DepositCommitteeAttesters.getCount();
        uint256 newCount = value ? count + 1 : count - 1;
        if (value && newCount > MAX_DEPOSIT_COMMITTEE_ATTESTERS) {
            revert TooManyDepositCommitteeAttesters(newCount, MAX_DEPOSIT_COMMITTEE_ATTESTERS);
        }
        uint256 currentQuorum = DepositCommitteeAttestationQuorum.get();
        if (!value && currentQuorum > newCount) {
            revert QuorumExceedsDepositCommitteeAttesterCount(currentQuorum, newCount);
        }

        DepositCommitteeAttesters.setCount(newCount);
        DepositCommitteeAttesters.setDepositCommitteeAttester(depositCommitteeAttester, value);
        emit SetDepositCommitteeAttester(depositCommitteeAttester, value);
    }

    /// @inheritdoc IAttestationVerifierV1
    function setDepositCommitteeAttestationQuorum(uint256 newQuorum) external onlyRiverAdmin {
        if (newQuorum == 0) revert ZeroQuorum();
        uint256 depositCommitteeAttesterCount = DepositCommitteeAttesters.getCount();
        if (newQuorum > depositCommitteeAttesterCount) {
            revert QuorumExceedsDepositCommitteeAttesterCount(newQuorum, depositCommitteeAttesterCount);
        }
        if (newQuorum > MAX_SIGNATURES) revert QuorumExceedsMaxSignatures(newQuorum, MAX_SIGNATURES);
        DepositCommitteeAttestationQuorum.set(newQuorum);
        emit SetDepositCommitteeAttestationQuorum(newQuorum);
    }

    // -----------------------------------------------------------------------
    // Views
    // -----------------------------------------------------------------------

    /// @inheritdoc IAttestationVerifierV1
    function isDepositCommitteeAttester(address account) external view returns (bool) {
        return DepositCommitteeAttesters.isDepositCommitteeAttester(account);
    }

    /// @inheritdoc IAttestationVerifierV1
    function getDepositCommitteeAttesterCount() external view returns (uint256) {
        return DepositCommitteeAttesters.getCount();
    }

    /// @inheritdoc IAttestationVerifierV1
    function getDepositCommitteeAttestationQuorum() external view returns (uint256) {
        return DepositCommitteeAttestationQuorum.get();
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

    // -----------------------------------------------------------------------
    // Validate-and-prepare — pure validation, no state changes
    // -----------------------------------------------------------------------

    /// @inheritdoc IAttestationVerifierV1
    function validate(
        bytes32 depositDataBufferId,
        bytes32 depositRootHash,
        bytes[] calldata signatures,
        BLS12_381.DepositY[] calldata depositYs,
        address depositContract,
        bytes32 withdrawalCredentials,
        uint256 committedBalance
    ) external view returns (IDepositDataBuffer.DepositObject[] memory deposits, uint256 totalAmount) {
        // 1. Verify attestation quorum
        _verifyAttestationQuorum(depositDataBufferId, depositRootHash, signatures, depositContract);

        // 2. Get deposit data from buffer
        deposits = IDepositDataBuffer(DepositDataBufferAddress.get()).getDepositData(depositDataBufferId);
        uint256 depositCount = deposits.length;
        if (depositCount == 0) revert NoDeposits();

        // 3. depositYs count must match
        if (depositYs.length != depositCount) revert BLSSignatureCountMismatch(depositCount, depositYs.length);

        // 4. Re-compute and check the bufferId binding so the buffer cannot tamper post-attestation
        bytes32 computedId = keccak256(abi.encode(deposits));
        if (computedId != depositDataBufferId) revert BufferIdMismatch(depositDataBufferId, computedId);

        // 5. Enforce fixed lengths on BLS pubkey/signature and accumulate totalAmount.
        //    The canonical River WC is supplied by the caller and used directly for BLS verification,
        //    so the buffer producer is not trusted on the WC field (no per-deposit WC stored).
        for (uint256 i = 0; i < depositCount; i++) {
            if (deposits[i].pubkey.length != DEPOSIT_PUBKEY_LENGTH) {
                revert InvalidPubkeyLength(i, deposits[i].pubkey.length);
            }
            if (deposits[i].signature.length != DEPOSIT_SIGNATURE_LENGTH) {
                revert InvalidSignatureLength(i, deposits[i].signature.length);
            }
            totalAmount += deposits[i].amount;
        }
        if (totalAmount > committedBalance) revert NotEnoughFunds();

        // 6. Verify BLS signatures against canonical River WC (heaviest step — last so cheap checks fail fast)
        _verifyBLSSignatures(deposits, depositYs, withdrawalCredentials);
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

        uint256 quorum = DepositCommitteeAttestationQuorum.get();
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
            if (!DepositCommitteeAttesters.isDepositCommitteeAttester(signer)) continue;

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

    /// @notice Verify the BLS signatures against the canonical River withdrawal credentials.
    /// @param deposits The deposits.
    /// @param depositYs The deposit Y-coordinates.
    /// @param withdrawalCredentials The canonical River withdrawal credentials.
    function _verifyBLSSignatures(
        IDepositDataBuffer.DepositObject[] memory deposits,
        BLS12_381.DepositY[] calldata depositYs,
        bytes32 withdrawalCredentials
    ) internal view {
        for (uint256 i = 0; i < deposits.length; i++) {
            (bool ok, bytes memory revertData) = address(this)
                .staticcall(
                    abi.encodeCall(
                        this.verifyBLSDeposit,
                        (
                            deposits[i].pubkey,
                            deposits[i].signature,
                            deposits[i].amount,
                            depositYs[i],
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
    /// @dev External only as a self-staticcall trampoline from validate: the call
    ///      promotes the deposit's memory bytes into calldata so BLS12_381 can consume them
    ///      without a memory copy. Not intended for direct external use — reverts on bad
    ///      input but performs no authorization.
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
