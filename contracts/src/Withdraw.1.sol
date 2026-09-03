//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";

import "./Initializable.sol";
import "./interfaces/IRiver.1.sol";
import "./interfaces/IWithdraw.1.sol";
import "./interfaces/IProtocolVersion.sol";
import "./interfaces/IAttestationVerifier.1.sol";
import "./interfaces/IAttestationVerifierPectraMigration.1.sol";
import "./libraries/LibErrors.sol";
import "./libraries/LibUint256.sol";

import "./state/shared/RiverAddress.sol";
import "./state/shared/OperatorsRegistryAddress.sol";
import "./state/shared/AttestationVerifierAddress.sol";
import "./state/withdraw/PectraWithdrawalContractAddress.sol";
import "./state/withdraw/PectraConsolidationContractAddress.sol";

/// @title Withdraw (v1)
/// @author Alluvial Finance Inc.
/// @notice This contract is the withdrawal address for all LC validators.
/// @notice It is in charge of holding the exited and skimmed funds and allows river to pull these funds.
/// @notice Furthermore, it enables consolidation of LC validators.
/// @notice LC validators (0x02) can be EL-exited using partial or full EL withdrawals via the withdraw function.
/// @dev REMOVED INITIALIZERS. Every deployed proxy is at `Version == 1`, so the `init(N)` guard on
///      this can never pass again; it was deleted to reclaim bytecode. Recorded here so the version
///      counter's history stays readable, and so nobody reuses this slot:
///        init(0)  initializeWithdrawV1(address)         -- _river, called _setRiver
///      `init(1)` is still live below as `initWithdrawV1_1`.
///      Body preserved verbatim in contracts/test/utils/LegacyInit.sol (WithdrawV1WithLegacyInit).
contract WithdrawV1 is IWithdrawV1, Initializable, ReentrancyGuard, IProtocolVersion {
    modifier onlyRiver() {
        if (msg.sender != RiverAddress.get()) {
            revert LibErrors.Unauthorized(msg.sender);
        }
        _;
    }

    /// @inheritdoc IWithdrawV1
    function initWithdrawV1_1(
        address _pectraWithdrawalContractAddress,
        address _pectraConsolidationContractAddress,
        address _operatorsRegistry,
        address _attestationVerifier
    ) external init(1) {
        PectraWithdrawalContractAddress.set(_pectraWithdrawalContractAddress);
        PectraConsolidationContractAddress.set(_pectraConsolidationContractAddress);
        OperatorsRegistryAddress.set(_operatorsRegistry);
        AttestationVerifierAddress.set(_attestationVerifier);
    }

    /// @inheritdoc IWithdrawV1
    function getCredentials() external view returns (bytes32) {
        return
            bytes32(
                uint256(uint160(address(this))) + 0x0200000000000000000000000000000000000000000000000000000000000000
            );
    }

    /// @inheritdoc IWithdrawV1
    function getRiver() external view returns (address) {
        return RiverAddress.get();
    }

    /// @inheritdoc IWithdrawV1
    function pullEth(uint256 _max) external onlyRiver {
        uint256 amountToPull = LibUint256.min(address(this).balance, _max);
        if (amountToPull > 0) {
            IRiverV1(payable(RiverAddress.get())).sendCLFunds{value: amountToPull}();
        }
    }

    /// @inheritdoc IWithdrawV1
    function withdraw(
        bytes[] calldata pubkeys,
        uint64[] calldata amount,
        uint256 maxFeePerWithdrawal,
        address excessFeeRecipient
    ) external payable nonReentrant {
        if (msg.sender != OperatorsRegistryAddress.get()) {
            revert LibErrors.Unauthorized(msg.sender);
        }
        if (pubkeys.length == 0) {
            revert InvalidEmptyArray();
        }
        if (pubkeys.length != amount.length) {
            revert LengthMismatch(pubkeys.length, amount.length);
        }

        uint256 maxFeePayable = maxFeePerWithdrawal * pubkeys.length;
        _validateSufficientValueForFee(msg.value, maxFeePayable);

        address withdrawalContract = PectraWithdrawalContractAddress.get();
        uint256 fee = _validateAndReturnFee(withdrawalContract, maxFeePerWithdrawal);

        uint256 totalFeePaid = 0;
        for (uint256 i = 0; i < pubkeys.length; i++) {
            _validatePubkeyLength(pubkeys[i]);
            bytes memory callData = abi.encodePacked(pubkeys[i], amount[i]);
            (bool writeOK,) = withdrawalContract.call{value: fee}(callData);
            if (!writeOK) {
                revert RequestFailed();
            }
            totalFeePaid += fee;
            emit WithdrawalRequested(pubkeys[i], amount[i], fee);
        }

        _refundExcessFee(msg.value, totalFeePaid, excessFeeRecipient);
    }

    /// @inheritdoc IWithdrawV1
    function consolidate(
        IWithdrawV1.ConsolidationRequest[] calldata requests,
        uint256 maxFeePerConsolidation,
        address excessFeeRecipient
    ) external payable onlyRiver nonReentrant {
        // River-initiated consolidations (external minting / Pectra migration) carry their own replay
        // protection through the attestation flow. Self-consolidation stays allowed here: it is the
        // on-chain 0x01 -> 0x02 credential upgrade.
        uint256 totalFeeRequired = _consolidate(requests, maxFeePerConsolidation, false);
        _refundExcessFee(msg.value, totalFeeRequired, excessFeeRecipient);
    }

    /// @inheritdoc IWithdrawV1
    function consolidateForExit(
        IWithdrawV1.ConsolidationRequest[] calldata requests,
        uint256 maxFeePerConsolidation,
        address excessFeeRecipient
    ) external payable nonReentrant {
        if (msg.sender != OperatorsRegistryAddress.get()) {
            revert LibErrors.Unauthorized(msg.sender);
        }
        // Source pubkeys are not deduplicated on-chain: the exited-ETH attribution supplied alongside
        // these requests in `OperatorsRegistry.requestETHExits` is keeper-supplied and keeper-trusted
        // anyway, and every source still has to be a known funded validator (see `_processConsolidationRequest`).
        // Self-consolidation is rejected: it is a credential upgrade, not an exit, so it would never
        // release the exited ETH this flow reserves against.
        uint256 totalFeeRequired = _consolidate(requests, maxFeePerConsolidation, true);
        _refundExcessFee(msg.value, totalFeeRequired, excessFeeRecipient);
    }

    /// @notice Internal: shared consolidation logic. Validates fees, dispatches every request to the
    /// EL consolidation contract and returns the total fee consumed. Refunds are handled by the caller.
    /// @param rejectSelfConsolidation When true, any request whose source equals its target reverts
    function _consolidate(
        IWithdrawV1.ConsolidationRequest[] calldata requests,
        uint256 maxFeePerConsolidation,
        bool rejectSelfConsolidation
    ) internal returns (uint256 totalConsolidationFeePaid) {
        if (requests.length == 0) {
            revert InvalidEmptyArray();
        }
        address consolidationContract = PectraConsolidationContractAddress.get();
        uint256 fee = _validateAndReturnFee(consolidationContract, maxFeePerConsolidation);

        uint256 totalNumOfConsolidationOperations = 0;
        for (uint256 i = 0; i < requests.length; i++) {
            if (requests[i].srcPubkeys.length == 0) {
                revert InvalidEmptyArray();
            }
            totalNumOfConsolidationOperations += requests[i].srcPubkeys.length;
        }
        totalConsolidationFeePaid = fee * totalNumOfConsolidationOperations;
        _validateSufficientValueForFee(msg.value, totalConsolidationFeePaid);

        IAttestationVerifierV1 attestationVerifier = IAttestationVerifierV1(AttestationVerifierAddress.get());

        for (uint256 i = 0; i < requests.length; i++) {
            _processConsolidationRequest(
                requests[i], consolidationContract, attestationVerifier, fee, rejectSelfConsolidation
            );
        }
    }

    /// @notice Internal: validate and dispatch a single consolidation request to the EL contract
    /// @dev Split out of `consolidate` to keep the outer frame small enough for non-viaIR builds (forge coverage).
    /// @param rejectSelfConsolidation When true, a source equal to the target reverts instead of being dispatched
    function _processConsolidationRequest(
        IWithdrawV1.ConsolidationRequest calldata request,
        address consolidationContract,
        IAttestationVerifierV1 attestationVerifier,
        uint256 fee,
        bool rejectSelfConsolidation
    ) internal {
        bytes calldata targetPubkey = request.targetPubkey;
        _validatePubkeyLength(targetPubkey);

        bool isTargetFunded = attestationVerifier.isPubkeyFunded(targetPubkey);
        bool isSelfConsolidation =
            request.srcPubkeys.length == 1 && keccak256(request.srcPubkeys[0]) == keccak256(targetPubkey);

        // A consolidation target must be post-Pectra funded (0x02), or be the self-consolidation
        // of a known pre-Pectra (0x01) key — i.e. the on-chain 0x01 -> 0x02 upgrade.
        bool check = isTargetFunded
            || (isSelfConsolidation && _isKnownPrePectraValidatorPubkey(attestationVerifier, targetPubkey));

        if (!check) {
            revert TargetPubkeyNotFunded(targetPubkey);
        }

        for (uint256 j = 0; j < request.srcPubkeys.length; j++) {
            bytes calldata srcPubkey = request.srcPubkeys[j];
            _validatePubkeyLength(srcPubkey);
            // Checked per source rather than via `isSelfConsolidation` so that a self-pair hidden in a
            // multi-source request is caught too.
            if (rejectSelfConsolidation && keccak256(srcPubkey) == keccak256(targetPubkey)) {
                revert SelfConsolidationNotAllowed(srcPubkey);
            }
            if (!_isKnownValidatorPubkey(attestationVerifier, srcPubkey)) {
                revert SourcePubkeyNotFunded(srcPubkey);
            }

            bytes memory callData = bytes.concat(srcPubkey, targetPubkey);
            (check,) = consolidationContract.call{value: fee}(callData);
            if (!check) {
                revert RequestFailed();
            }
            emit ConsolidationRequested(srcPubkey, targetPubkey, fee);
        }
    }

    /// @notice Internal utility to set the river address
    /// @dev Retained for the legacy-init test harness; the production v1.0 initializer that called it
    ///      has been removed, so this is unreachable onchain and stripped from the deployed bytecode.
    /// @param _river The new river address
    function _setRiver(address _river) internal {
        RiverAddress.set(_river);
        emit SetRiver(_river);
    }

    /// @notice Internal: validate fee from EL contract and ensure it does not exceed max
    function _validateAndReturnFee(address feeContract, uint256 _maxAllowedFee) internal view returns (uint256 _fee) {
        (bool readOK, bytes memory feeData) = feeContract.staticcall("");
        if (!readOK) {
            revert FeeReadFailed();
        }
        _fee = abi.decode(feeData, (uint256));

        if (_fee > _maxAllowedFee) {
            revert FeeTooHigh(_fee, _maxAllowedFee);
        }
    }

    /// @notice Internal: ensure value sent is at least total fee required
    function _validateSufficientValueForFee(uint256 _value, uint256 _totalFee) internal pure {
        if (_value < _totalFee) {
            revert InsufficientValueForFee(_value, _totalFee);
        }
    }

    /// @notice Internal: validate pubkey is exactly 48 bytes
    function _validatePubkeyLength(bytes calldata pubkey) internal pure {
        if (pubkey.length != 48) {
            revert InvalidPubkeyLength(pubkey.length);
        }
    }

    /// @notice Internal: check whether a pubkey is in either funded validator lookup
    function _isKnownValidatorPubkey(IAttestationVerifierV1 attestationVerifier, bytes calldata pubkey)
        internal
        view
        returns (bool)
    {
        IAttestationVerifierPectraMigrationV1 pectraMigration =
            IAttestationVerifierPectraMigrationV1(address(attestationVerifier));

        return attestationVerifier.isPubkeyFunded(pubkey) || pectraMigration.isPrePectraValidatorPubkeyFunded(pubkey);
    }

    /// @notice Internal: check whether a pubkey is a known pre-Pectra (0x01) funded validator
    function _isKnownPrePectraValidatorPubkey(IAttestationVerifierV1 attestationVerifier, bytes calldata pubkey)
        internal
        view
        returns (bool)
    {
        return
            IAttestationVerifierPectraMigrationV1(address(attestationVerifier)).isPrePectraValidatorPubkeyFunded(pubkey);
    }

    /// @notice Internal: refund excess fee to recipient
    function _refundExcessFee(uint256 _totalValueReceived, uint256 _totalFeePaid, address _excessFeeRecipient)
        internal
    {
        if (_excessFeeRecipient == address(0)) {
            revert LibErrors.InvalidZeroAddress();
        }
        if (_totalValueReceived > _totalFeePaid) {
            uint256 excess = _totalValueReceived - _totalFeePaid;
            (bool success,) = payable(_excessFeeRecipient).call{value: excess}("");
            if (!success) {
                emit UnsentExcessFee(_excessFeeRecipient, excess);
            }
        }
    }

    /// @inheritdoc IProtocolVersion
    function version() external pure returns (string memory) {
        return "1.3.0";
    }
}
