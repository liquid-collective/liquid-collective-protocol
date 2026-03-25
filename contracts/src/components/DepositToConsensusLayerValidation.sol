// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import {IDepositDataBuffer} from "../interfaces/IDepositDataBuffer.sol";
import {IDepositContract} from "../interfaces/IDepositContract.sol";
import {BLS12_381} from "../libraries/BLS12_381.sol";
import {ECDSA} from "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";

/// @title DepositToConsensusLayerValidation
/// @notice Abstract contract that validates attestation quorum signatures and BLS deposit data.
///         Storage hooks (_isAttester, _threshold, _domainSeparator) are virtual so that
///         proxy-based deployments (River) can override them with unstructured storage,
///         while standalone deployments use simple Solidity storage.
abstract contract DepositToConsensusLayerValidation {
    // -----------------------------------------------------------------------
    // Events
    // -----------------------------------------------------------------------

    /// @notice Emitted after attestation quorum is met and all deposits are executed.
    event DepositsExecuted(bytes32 indexed depositDataBufferId, bytes32 indexed depositRootHash, uint256 depositCount);

    // -----------------------------------------------------------------------
    // Errors
    // -----------------------------------------------------------------------

    error InsufficientAttestations(uint256 valid, uint256 threshold);
    error NoDeposits();
    error DepositRootMismatch(bytes32 expected, bytes32 actual);
    error TooManySignatures(uint256 count, uint256 max);
    error IncorrectDepositEther(uint256 expected, uint256 actual);
    error BLSSignatureCountMismatch(uint256 depositCount, uint256 yCount);
    error ZeroThreshold();
    error ThresholdExceedsAttesterCount(uint256 threshold, uint256 attesterCount);
    error ThresholdExceedsMaxSignatures(uint256 threshold, uint256 max);
    error ZeroAddress();
    error DuplicateAttester(address attester);

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

    // -----------------------------------------------------------------------
    // Virtual storage hooks — override in proxy-based deployments
    // -----------------------------------------------------------------------

    function _isAttester(address account) internal view virtual returns (bool);
    function _setAttester(address account, bool value) internal virtual;
    function _threshold() internal view virtual returns (uint256);
    function _setThreshold(uint256 value) internal virtual;

    /// @dev Override in proxy deployments to compute dynamically (using proxy address).
    ///      Default: compute using address(this) — correct for standalone (non-proxy) use.
    function _domainSeparator() internal view virtual returns (bytes32) {
        return keccak256(abi.encode(EIP712_DOMAIN_TYPEHASH, NAME_HASH, VERSION_HASH, block.chainid, address(this)));
    }

    /// @dev Override in proxy deployments to read the deposit data buffer from unstructured storage.
    function _depositDataBuffer() internal view virtual returns (IDepositDataBuffer);

    /// @dev Override in proxy deployments to read the deposit contract from unstructured storage.
    function _depositContract() internal view virtual returns (IDepositContract);

    /// @dev Override to return the BLS deposit domain for the target chain.
    ///      In River proxy deployments, reads from DepositDomainValue unstructured storage.
    ///      In standalone deployments, may return a hardcoded value or a stored immutable.
    function _depositDomain() internal view virtual returns (bytes32);

    // -----------------------------------------------------------------------
    // Public view getters (delegate to virtual hooks)
    // -----------------------------------------------------------------------

    function isAttester(address a) public view returns (bool) {
        return _isAttester(a);
    }

    function threshold() public view returns (uint256) {
        return _threshold();
    }

    function DEPOSIT_DOMAIN() public view returns (bytes32) {
        return _depositDomain();
    }

    // -----------------------------------------------------------------------
    // Validate — pure attestation+BLS validation, no ETH effects
    // -----------------------------------------------------------------------

    /// @notice Validate attestation signatures and BLS deposit data.
    ///         Returns the validated deposits array for use by the caller.
    /// @param depositDataBufferId  Batch identifier in the DepositDataBuffer
    /// @param depositRootHash      Current deposit contract root hash co-signed by attesters
    /// @param signatures           EIP-712 signatures from attesters
    /// @param depositYs            Y-coordinates for BLS decompression, one per deposit
    /// @return deposits            The validated deposit batch
    // solhint-disable-next-line code-complexity
    function validate(
        bytes32 depositDataBufferId,
        bytes32 depositRootHash,
        bytes[] calldata signatures,
        BLS12_381.DepositY[] calldata depositYs
    ) public view returns (IDepositDataBuffer.DepositObject[] memory deposits) {
        // 1. Bound signature count
        if (signatures.length > MAX_SIGNATURES) {
            revert TooManySignatures(signatures.length, MAX_SIGNATURES);
        }

        // 2. EIP-712 digest
        bytes32 structHash = keccak256(abi.encode(ATTEST_TYPEHASH, depositDataBufferId, depositRootHash));
        bytes32 digest = ECDSA.toTypedDataHash(_domainSeparator(), structHash);

        // 3. Verify signatures, check attester set, reject duplicates
        uint256 validCount = 0;
        uint256 sigLen = signatures.length;
        address[] memory seen = new address[](sigLen);

        for (uint256 i = 0; i < sigLen; i++) {
            address signer = _recover(digest, signatures[i]);
            if (signer == address(0)) continue;
            if (!_isAttester(signer)) continue;

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

        // 4. Check quorum
        uint256 thresh = _threshold();
        if (validCount < thresh) {
            revert InsufficientAttestations(validCount, thresh);
        }

        // 5. Get deposit data from buffer
        deposits = _depositDataBuffer().getDepositData(depositDataBufferId);

        if (deposits.length == 0) revert NoDeposits();

        // 6. Check depositYs count
        if (depositYs.length != deposits.length) {
            revert BLSSignatureCountMismatch(deposits.length, depositYs.length);
        }

        // 7. Verify deposit contract root
        bytes32 onChainRoot = _depositContract().get_deposit_root();
        if (onChainRoot != depositRootHash) {
            revert DepositRootMismatch(depositRootHash, onChainRoot);
        }

        // 8. Verify BLS signatures
        for (uint256 i = 0; i < deposits.length; i++) {
            bytes32 wc = abi.decode(deposits[i].withdrawalCredentials, (bytes32));
            (bool ok, bytes memory revertData) = address(this).staticcall(
                abi.encodeCall(
                    this.verifyBLSDeposit,
                    (deposits[i].pubkey, deposits[i].signature, deposits[i].amount, depositYs[i], wc)
                )
            );
            if (!ok) {
                assembly {
                    revert(add(revertData, 32), mload(revertData))
                }
            }
        }
    }

    // -----------------------------------------------------------------------
    // validateAndDeposit — standalone entry point (non-proxy use)
    // -----------------------------------------------------------------------

    /// @notice Validate attestation signatures and execute ETH2 beacon deposits.
    ///         For standalone (non-proxy) deployments. Uses msg.value for ETH.
    function validateAndDeposit(
        bytes32 depositDataBufferId,
        bytes32 depositRootHash,
        bytes[] calldata signatures,
        BLS12_381.DepositY[] calldata depositYs
    ) external payable {
        IDepositDataBuffer.DepositObject[] memory deposits =
            validate(depositDataBufferId, depositRootHash, signatures, depositYs);

        uint256 totalAmount = 0;
        for (uint256 i = 0; i < deposits.length; i++) {
            totalAmount += deposits[i].amount;
        }
        if (msg.value != totalAmount) {
            revert IncorrectDepositEther(totalAmount, msg.value);
        }

        IDepositContract dc = _depositContract();
        for (uint256 i = 0; i < deposits.length; i++) {
            dc.deposit{value: deposits[i].amount}(
                deposits[i].pubkey,
                deposits[i].withdrawalCredentials,
                deposits[i].signature,
                deposits[i].depositDataRoot
            );
        }

        emit DepositsExecuted(depositDataBufferId, depositRootHash, deposits.length);
    }

    // -----------------------------------------------------------------------
    // BLS verification helper (called via staticcall for calldata layout)
    // -----------------------------------------------------------------------

    /// @notice Verify a single BLS deposit. Called via staticcall from validate()
    ///         so that memory bytes land in calldata for the BLS12_381 library.
    function verifyBLSDeposit(
        bytes calldata pubkey,
        bytes calldata signature,
        uint256 amount,
        BLS12_381.DepositY calldata depositY,
        bytes32 withdrawalCredentials
    ) external view {
        BLS12_381.verifyDepositMessage(pubkey, signature, amount, depositY, withdrawalCredentials, _depositDomain());
    }

    // -----------------------------------------------------------------------
    // Internal helpers
    // -----------------------------------------------------------------------

    /// @dev Recover signer from a 65-byte EIP-712 signature, normalizing v.
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
