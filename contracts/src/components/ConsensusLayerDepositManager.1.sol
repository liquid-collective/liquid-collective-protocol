//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../interfaces/components/IConsensusLayerDepositManager.1.sol";
import "../interfaces/IDepositContract.sol";
import "../interfaces/IDepositDataBuffer.sol";

import "../libraries/LibBytes.sol";
import "../libraries/LibUint256.sol";
import "../libraries/LibErrors.sol";
import "../libraries/BLS12_381.sol";

import "../state/river/DepositContractAddress.sol";
import "../state/river/WithdrawalCredentials.sol";
import "../state/river/BalanceToDeposit.sol";
import "../state/river/CommittedBalance.sol";
import "../state/river/KeeperAddress.sol";
import "../state/river/TotalDepositedETH.sol";
import "../state/river/InFlightDeposit.sol";
import "../state/river/DepositDataBufferAddress.sol";
import "../state/river/AttestationThreshold.sol";
import "../state/river/Attesters.sol";
import "../state/river/DepositDomainValue.sol";

import "./DepositToConsensusLayerValidation.sol";

/// @title Consensus Layer Deposit Manager (v1)
/// @author Alluvial Finance Inc.
/// @notice This contract handles the interactions with the official deposit contract, funding all validators.
abstract contract ConsensusLayerDepositManagerV1 is IConsensusLayerDepositManagerV1, DepositToConsensusLayerValidation {
    /// @notice Size of a BLS Public key in bytes
    uint256 public constant PUBLIC_KEY_LENGTH = 48;
    /// @notice Size of a BLS Signature in bytes
    uint256 public constant SIGNATURE_LENGTH = 96;
    /// @notice Size of a deposit in ETH
    uint256 public constant DEPOSIT_SIZE = 32 ether;

    /// @dev ASCII bytes for "operator:" prefix used in metadata encoding
    bytes9 internal constant OPERATOR_PREFIX = "operator:";

    // -----------------------------------------------------------------------
    // Modifiers
    // -----------------------------------------------------------------------

    modifier onlyRiverAdmin() {
        if (msg.sender != _getRiverAdmin()) revert LibErrors.Unauthorized(msg.sender);
        _;
    }

    // -----------------------------------------------------------------------
    // Virtual hooks — must be overridden
    // -----------------------------------------------------------------------

    /// @notice Handler called to retrieve the internal River admin address
    /// @dev Must be Overridden
    function _getRiverAdmin() internal view virtual returns (address);

    /// @notice Handler called to increment the funded ETH for the operators
    /// @param _fundedETH The array of funded ETH amounts
    /// @param _publicKeys The array of public keys
    function _incrementFundedETH(uint256[] memory _fundedETH, bytes[][] memory _publicKeys) internal virtual;

    /// @notice Handler called to change the committed balance to deposit
    /// @param newCommittedBalance The new committed balance value
    function _setCommittedBalance(uint256 newCommittedBalance) internal virtual;

    /// @notice Internal helper called to update operator funded ETH from buffer-based deposits
    /// @dev Must be overridden by River.1.sol
    function _updateFundedETHFromBuffer(IDepositDataBuffer.DepositObject[] memory deposits) internal virtual;

    /// @notice Handler to check if slashing containment mode is active
    /// @dev Must be overridden
    function _getSlashingContainmentMode() internal view virtual returns (bool);

    // -----------------------------------------------------------------------
    // DepositToConsensusLayerValidation overrides — unstructured storage hooks
    // -----------------------------------------------------------------------

    function _isAttester(address account) internal view override returns (bool) {
        return Attesters.isAttester(account);
    }

    function _setAttester(address account, bool value) internal override {
        Attesters.setAttester(account, value);
    }

    function _depositCommitteeQuorum() internal view override returns (uint256) {
        return AttestationThreshold.get();
    }

    function _setDepositCommitteeQuorum(uint256 value) internal override {
        AttestationThreshold.set(value);
    }

    function _depositDataBuffer() internal view override returns (IDepositDataBuffer) {
        return IDepositDataBuffer(DepositDataBufferAddress.get());
    }

    function _depositContract() internal view override returns (IDepositContract) {
        return IDepositContract(DepositContractAddress.get());
    }

    function _depositDomain() internal view override returns (bytes32) {
        return DepositDomainValue.get();
    }

    /// @notice Initializer to set the deposit contract address and the withdrawal credentials to use
    /// @param _depositContractAddress The address of the deposit contract
    /// @param _withdrawalCredentials The withdrawal credentials to apply to all deposits
    function initConsensusLayerDepositManagerV1(address _depositContractAddress, bytes32 _withdrawalCredentials)
        internal
    {
        DepositContractAddress.set(_depositContractAddress);
        emit SetDepositContractAddress(_depositContractAddress);

        WithdrawalCredentials.set(_withdrawalCredentials);
        emit SetWithdrawalCredentials(_withdrawalCredentials);
    }

    /// @notice Initializer to update the withdrawal credentials to use
    /// @param _withdrawalCredentials The withdrawal credentials to apply to all deposits
    function initConsensusLayerDepositManagerV2(bytes32 _withdrawalCredentials) internal {
        WithdrawalCredentials.set(_withdrawalCredentials);
        emit SetWithdrawalCredentials(_withdrawalCredentials);
    }

    function _setKeeper(address _keeper) internal {
        KeeperAddress.set(_keeper);
        emit SetKeeper(_keeper);
    }

    /// @inheritdoc IConsensusLayerDepositManagerV1
    function getCommittedBalance() external view returns (uint256) {
        return CommittedBalance.get();
    }

    /// @inheritdoc IConsensusLayerDepositManagerV1
    function getBalanceToDeposit() external view returns (uint256) {
        return BalanceToDeposit.get();
    }

    /// @inheritdoc IConsensusLayerDepositManagerV1
    function getWithdrawalCredentials() external view returns (bytes32) {
        return WithdrawalCredentials.get();
    }

    /// @inheritdoc IConsensusLayerDepositManagerV1
    function getTotalDepositedETH() external view returns (uint256) {
        return TotalDepositedETH.get();
    }

    /// @inheritdoc IConsensusLayerDepositManagerV1
    function getKeeper() external view returns (address) {
        return KeeperAddress.get();
    }

    /// @inheritdoc IConsensusLayerDepositManagerV1
    function getDepositDataBuffer() external view returns (address) {
        return DepositDataBufferAddress.get();
    }

    /// @inheritdoc IConsensusLayerDepositManagerV1
    function getAttestationThreshold() external view returns (uint256) {
        return AttestationThreshold.get();
    }

    /// @inheritdoc IConsensusLayerDepositManagerV1
    function getAttesterCount() external view returns (uint256) {
        return Attesters.getCount();
    }

    /// @inheritdoc IConsensusLayerDepositManagerV1
    function getIsAttester(address attester) external view returns (bool) {
        return Attesters.isAttester(attester);
    }

    // -----------------------------------------------------------------------
    // Admin setters
    // -----------------------------------------------------------------------

    /// @notice Set the DepositDataBuffer contract address. Admin only.
    function setDepositDataBuffer(address _depositDataBuffer) external onlyRiverAdmin {
        if (_depositDataBuffer == address(0)) revert ZeroAddress();
        DepositDataBufferAddress.set(_depositDataBuffer);
        emit SetDepositDataBuffer(_depositDataBuffer);
    }

    /// @notice Add or remove an attester. Admin only.
    function setAttester(address attester, bool value) external onlyRiverAdmin {
        if (attester == address(0)) revert ZeroAddress();

        bool current = Attesters.isAttester(attester);
        if (current == value) return; // no-op

        uint256 count = Attesters.getCount();
        uint256 newCount = value ? count + 1 : count - 1;
        uint256 depositCommitteeQuorum = _depositCommitteeQuorum();
        if (!value && depositCommitteeQuorum >= newCount) {
            revert ThresholdExceedsAttesterCount(depositCommitteeQuorum, newCount);
        }
        Attesters.setCount(newCount);
        _setAttester(attester, value);
        emit SetAttester(attester, value);
    }

    /// @notice Set the attestation threshold. Admin only.
    function setAttestationThreshold(uint256 newThreshold) external onlyRiverAdmin {
        if (newThreshold == 0) revert ZeroThreshold();
        uint256 attesterCount = Attesters.getCount();
        if (newThreshold >= attesterCount) {
            revert ThresholdExceedsAttesterCount(newThreshold, attesterCount);
        }
        if (newThreshold > MAX_SIGNATURES) {
            revert ThresholdExceedsMaxSignatures(newThreshold, MAX_SIGNATURES);
        }
        _setThreshold(newThreshold);
        emit SetAttestationThreshold(newThreshold);
    }

    // -----------------------------------------------------------------------
    // Attestation-based deposit function
    // -----------------------------------------------------------------------

    /// @inheritdoc IConsensusLayerDepositManagerV1
    function depositToConsensusLayerWithAttestation(
        bytes32 depositDataBufferId,
        bytes32 depositRootHash,
        bytes[] calldata signatures,
        BLS12_381.DepositY[] calldata depositYs
    ) external {
        // 1. Keeper check
        if (msg.sender != KeeperAddress.get()) {
            revert OnlyKeeper();
        }

        if (_getSlashingContainmentMode()) {
            revert SlashingContainmentModeEnabled();
        }

        // 2. Check withdrawal credentials (cheap SLOAD — fail fast before expensive BLS work)
        bytes32 withdrawalCredentials = WithdrawalCredentials.get();
        if (withdrawalCredentials == 0) {
            revert InvalidWithdrawalCredentials();
        }

        // 3. Validate attestation quorum + BLS signatures; get deposits
        IDepositDataBuffer.DepositObject[] memory deposits =
            validate(depositDataBufferId, depositRootHash, signatures, depositYs);

        // 4. Validate total amount against CommittedBalance and check per-deposit withdrawal credentials
        uint256 committedBalance = CommittedBalance.get();
        uint256 totalAmount = 0;
        uint256 len = deposits.length;
        for (uint256 i = 0; i < len; i++) {
            totalAmount += deposits[i].amount;
            bytes32 depositWC;
            bytes memory wc = deposits[i].withdrawalCredentials;
            assembly {
                depositWC := mload(add(wc, 32))
            }
            if (depositWC != withdrawalCredentials) {
                revert WithdrawalCredentialsMismatch(i, withdrawalCredentials, depositWC);
            }
        }
        if (totalAmount > committedBalance) {
            revert NotEnoughFunds();
        }

        // 5. Update operator funded validator accounting
        _updateFundedETHFromBuffer(deposits);

        // 6. Execute deposits
        address depositContract = DepositContractAddress.get();
        for (uint256 i = 0; i < len; i++) {
            _depositValidator(
                deposits[i].pubkey, deposits[i].signature, deposits[i].amount, withdrawalCredentials, depositContract
            );
        }

        // 7. Update balances and counters
        _setCommittedBalance(committedBalance - totalAmount);

        uint256 currentInFlightETH = InFlightDeposit.get();
        InFlightDeposit.set(currentInFlightETH + totalAmount);
        emit SetInFlightETH(currentInFlightETH, currentInFlightETH + totalAmount);

        uint256 currentTotalDepositedETH = TotalDepositedETH.get();
        TotalDepositedETH.set(currentTotalDepositedETH + totalAmount);
        emit SetTotalDepositedETH(currentTotalDepositedETH, currentTotalDepositedETH + totalAmount);

        emit DepositsExecutedWithAttestation(depositDataBufferId, depositRootHash, totalAmount);
    }

    // -----------------------------------------------------------------------
    // Internal — metadata parsing
    // -----------------------------------------------------------------------

    /// @notice Parse an operator index from a bytes32 metadata field.
    ///         Expected format: left-aligned ASCII "operator:N" zero-padded on the right.
    /// @param metadata The metadata bytes32 value
    /// @return operatorIndex The parsed operator index
    function _parseOperatorIndex(bytes32 metadata) internal pure returns (uint256 operatorIndex) {
        // Verify "operator:" prefix (first 9 bytes)
        bytes9 prefix;
        assembly {
            prefix := metadata
        }
        if (prefix != OPERATOR_PREFIX) {
            revert InvalidOperatorMetadata(metadata);
        }

        // Parse decimal digits starting at byte 9
        operatorIndex = 0;
        bool hasDigit = false;
        for (uint256 i = 9; i < 32; i++) {
            uint8 c = uint8(bytes1(metadata << (i * 8)));
            if (c == 0) break; // null terminator
            if (c < 0x30 || c > 0x39) revert InvalidOperatorMetadata(metadata); // not ASCII digit
            operatorIndex = operatorIndex * 10 + (c - 0x30);
            hasDigit = true;
        }
        if (!hasDigit) revert InvalidOperatorMetadata(metadata);
    }

    /// @notice Deposits _depositAmount ETH to the official Deposit contract
    /// @param _publicKey The public key of the validator
    /// @param _signature The signature provided by the operator
    /// @param _withdrawalCredentials The withdrawal credentials provided by River
    /// @param _depositContract The address of the deposit contract
    function _depositValidator(
        bytes memory _publicKey,
        bytes memory _signature,
        uint256 _depositAmount,
        bytes32 _withdrawalCredentials,
        address _depositContract
    ) internal {
        if (_depositAmount < 1 ether || _depositAmount > 2048 ether || _depositAmount % 1 gwei != 0) {
            revert InvalidDepositSize(_depositAmount);
        }
        uint256 depositAmount = _depositAmount / 1 gwei;

        bytes32 pubkeyRoot = sha256(bytes.concat(_publicKey, bytes16(0)));
        bytes32 signatureRoot = sha256(
            bytes.concat(
                sha256(LibBytes.slice(_signature, 0, 64)),
                sha256(bytes.concat(LibBytes.slice(_signature, 64, SIGNATURE_LENGTH - 64), bytes32(0)))
            )
        );

        bytes32 depositDataRoot = sha256(
            bytes.concat(
                sha256(bytes.concat(pubkeyRoot, _withdrawalCredentials)),
                sha256(bytes.concat(bytes32(LibUint256.toLittleEndian64(depositAmount)), signatureRoot))
            )
        );

        uint256 targetBalance = address(this).balance - _depositAmount;

        IDepositContract(_depositContract).deposit{value: _depositAmount}(
            _publicKey, abi.encodePacked(_withdrawalCredentials), _signature, depositDataRoot
        );
        if (address(this).balance != targetBalance) {
            revert ErrorOnDeposit();
        }
    }
}
