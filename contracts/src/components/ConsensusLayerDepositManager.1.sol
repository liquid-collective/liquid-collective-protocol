//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../interfaces/components/IConsensusLayerDepositManager.1.sol";
import "../interfaces/IOperatorRegistry.1.sol";
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
import "../state/river/DepositedValidatorCount.sol";
import "../state/river/InFlightDeposit.sol";
import "../state/river/DepositDataBufferAddress.sol";
import "../state/river/AttestationThreshold.sol";
import "../state/river/Attesters.sol";
import "../state/river/DepositDomainValue.sol";

import "./DepositToConsensusLayerValidation.sol";

/// @title Consensus Layer Deposit Manager (v1)
/// @author Alluvial Finance Inc.
/// @notice This contract handles the interactions with the official deposit contract, funding all validators.
abstract contract ConsensusLayerDepositManagerV1 is
    IConsensusLayerDepositManagerV1,
    DepositToConsensusLayerValidation
{
    /// @notice Size of a BLS Public key in bytes
    uint256 public constant PUBLIC_KEY_LENGTH = 48;
    /// @notice Size of a BLS Signature in bytes
    uint256 public constant SIGNATURE_LENGTH = 96;
    /// @notice Size of a deposit in ETH
    uint256 public constant DEPOSIT_SIZE = 32 ether;

    /// @dev ASCII bytes for "operator:" prefix used in metadata encoding
    bytes9 internal constant OPERATOR_PREFIX = "operator:";

    /// @notice Handler called to retrieve the internal River admin address
    /// @dev Must be Overridden
    function _getRiverAdmin() internal view virtual returns (address);

    /// @notice Handler called to increment the funded ETH for the operators
    /// @param _fundedETH The array of funded ETH amounts
    function _incrementFundedETH(uint256[] memory _fundedETH) internal virtual;

    /// @notice Handler called to change the committed balance to deposit
    /// @param newCommittedBalance The new committed balance value
    function _setCommittedBalance(uint256 newCommittedBalance) internal virtual;


    /// @notice Internal helper called to update operator funded ETH accounting for buffer-based deposits
    /// @dev Must be overridden by River.1.sol
    function _updateFundedValidatorsFromBuffer(IDepositDataBuffer.DepositObject[] memory deposits)
        internal
        virtual;

    // -----------------------------------------------------------------------
    // DepositToConsensusLayerValidation overrides — unstructured storage hooks
    // -----------------------------------------------------------------------

    function _isAttester(address account) internal view override returns (bool) {
        return Attesters.isAttester(account);
    }

    function _setAttester(address account, bool value) internal override {
        Attesters.setAttester(account, value);
    }

    function _threshold() internal view override returns (uint256) {
        return AttestationThreshold.get();
    }

    function _setThreshold(uint256 value) internal override {
        AttestationThreshold.set(value);
    }

    /// @dev Compute domain separator dynamically so address(this) resolves to the proxy address.
    function _domainSeparator() internal view override returns (bytes32) {
        return keccak256(
            abi.encode(EIP712_DOMAIN_TYPEHASH, NAME_HASH, VERSION_HASH, block.chainid, address(this))
        );
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

    // -----------------------------------------------------------------------
    // Initializer
    // -----------------------------------------------------------------------


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

    function _setKeeper(address _keeper) internal {
        KeeperAddress.set(_keeper);
    }

    // -----------------------------------------------------------------------
    // View functions
    // -----------------------------------------------------------------------

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

    /// @dev Retained for test-file compatibility. Returns count of deposited validators.
    function getDepositedValidatorCount() external view returns (uint256) {
        return DepositedValidatorCount.get();
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
    function setDepositDataBuffer(address _depositDataBuffer) external {
        if (msg.sender != _getRiverAdmin()) revert LibErrors.Unauthorized(msg.sender);
        if (_depositDataBuffer == address(0)) revert ZeroAddress();
        DepositDataBufferAddress.set(_depositDataBuffer);
        emit SetDepositDataBuffer(_depositDataBuffer);
    }

    /// @notice Add or remove an attester. Admin only.
    function setAttester(address attester, bool value) external {
        if (msg.sender != _getRiverAdmin()) revert LibErrors.Unauthorized(msg.sender);
        if (attester == address(0)) revert ZeroAddress();

        bool current = Attesters.isAttester(attester);
        if (current == value) return; // no-op

        if (value) {
            Attesters.setCount(Attesters.getCount() + 1);
        } else {
            uint256 count = Attesters.getCount();
            if (count > 0) Attesters.setCount(count - 1);
        }
        _setAttester(attester, value);
        emit SetAttester(attester, value);
    }

    /// @notice Set the attestation threshold. Admin only.
    function setAttestationThreshold(uint256 newThreshold) external {
        if (msg.sender != _getRiverAdmin()) revert LibErrors.Unauthorized(msg.sender);
        if (newThreshold == 0) revert ZeroThreshold();
        uint256 attesterCount = Attesters.getCount();
        if (newThreshold > attesterCount) {
            revert ThresholdExceedsAttesterCount(newThreshold, attesterCount);
        }
        if (newThreshold > MAX_SIGNATURES) {
            revert ThresholdExceedsMaxSignatures(newThreshold, MAX_SIGNATURES);
        }
        _setThreshold(newThreshold);
        emit SetAttestationThreshold(newThreshold);
    }

    // -----------------------------------------------------------------------
    // Legacy deposit function (unchanged)
    // -----------------------------------------------------------------------

    /// @inheritdoc IConsensusLayerDepositManagerV1
    function depositToConsensusLayerWithDepositRoot(
        IOperatorsRegistryV1.ValidatorDeposit[] calldata _allocations,
        bytes32 _depositRoot
    ) external {
        if (msg.sender != KeeperAddress.get()) {
            revert OnlyKeeper();
        }

        if (_allocations.length == 0) {
            revert EmptyAllocations();
        }

        if (IDepositContract(DepositContractAddress.get()).get_deposit_root() != _depositRoot) {
            revert InvalidDepositRoot();
        }

        uint256 committedBalance = CommittedBalance.get();
        uint256 highestOperatorIndex = 0;
        if (committedBalance == 0) {
            revert NotEnoughFunds();
        }
        // Calculate total deposits and validate key lengths + operator ordering in a single pass
        uint256 totalDeposits = 0;
        for (uint256 i = 0; i < _allocations.length; ++i) {
            if (i > 0 && _allocations[i].operatorIndex < _allocations[i - 1].operatorIndex) {
                revert IOperatorsRegistryV1.UnorderedOperatorList();
            }
            if (_allocations[i].pubkey.length != PUBLIC_KEY_LENGTH) {
                revert InconsistentPublicKey();
            }
            if (_allocations[i].signature.length != SIGNATURE_LENGTH) {
                revert InconsistentSignature();
            }

            totalDeposits += _allocations[i].depositAmount;
            highestOperatorIndex = LibUint256.max(highestOperatorIndex, _allocations[i].operatorIndex);
        }
        uint256[] memory fundedETH = new uint256[](highestOperatorIndex + 1);

        // Check if the total requested exceeds the committed balance
        if (totalDeposits > committedBalance) {
            revert ValidatorDepositsExceedCommittedBalance();
        }

        bytes32 withdrawalCredentials = WithdrawalCredentials.get();

        if (withdrawalCredentials == 0) {
            revert InvalidWithdrawalCredentials();
        }

        for (uint256 idx = 0; idx < _allocations.length; ++idx) {
            _depositValidator(
                _allocations[idx].pubkey,
                _allocations[idx].signature,
                _allocations[idx].depositAmount,
                withdrawalCredentials
            );
            fundedETH[_allocations[idx].operatorIndex] += _allocations[idx].depositAmount;
        }

        _incrementFundedETH(fundedETH);
        _setCommittedBalance(committedBalance - totalDeposits);

        uint256 currentInFlightETH = InFlightDeposit.get();
        InFlightDeposit.set(currentInFlightETH + totalDeposits);
        emit SetInFlightETH(currentInFlightETH, currentInFlightETH + totalDeposits);

        uint256 currentTotalDepositedETH = TotalDepositedETH.get();
        TotalDepositedETH.set(currentTotalDepositedETH + totalDeposits);
        emit SetTotalDepositedETH(currentTotalDepositedETH, currentTotalDepositedETH + totalDeposits);

        DepositedValidatorCount.set(DepositedValidatorCount.get() + _allocations.length);
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

        // 2. Validate attestation quorum + BLS signatures; get deposits
        IDepositDataBuffer.DepositObject[] memory deposits =
            validate(depositDataBufferId, depositRootHash, signatures, depositYs);

        // 3. Validate total amount against CommittedBalance
        uint256 committedBalance = CommittedBalance.get();
        uint256 totalAmount = 0;
        for (uint256 i = 0; i < deposits.length; i++) {
            totalAmount += deposits[i].amount;
        }
        if (totalAmount > committedBalance) {
            revert NotEnoughFunds();
        }

        // 4. Check withdrawal credentials
        bytes32 withdrawalCredentials = WithdrawalCredentials.get();
        if (withdrawalCredentials == 0) {
            revert InvalidWithdrawalCredentials();
        }

        // 5. Update operator funded validator accounting
        _updateFundedValidatorsFromBuffer(deposits);

        // 6. Execute deposits
        for (uint256 i = 0; i < deposits.length; i++) {
            _depositValidator(deposits[i].pubkey, deposits[i].signature, DEPOSIT_SIZE, withdrawalCredentials);
        }

        // 7. Update balances and counters
        uint256 depositCount = deposits.length;
        uint256 totalDeposited = DEPOSIT_SIZE * depositCount;
        _setCommittedBalance(committedBalance - totalDeposited);

        uint256 currentInFlightETH = InFlightDeposit.get();
        InFlightDeposit.set(currentInFlightETH + totalDeposited);
        emit SetInFlightETH(currentInFlightETH, currentInFlightETH + totalDeposited);

        uint256 currentTotalDepositedETH = TotalDepositedETH.get();
        TotalDepositedETH.set(currentTotalDepositedETH + totalDeposited);
        emit SetTotalDepositedETH(currentTotalDepositedETH, currentTotalDepositedETH + totalDeposited);

        emit DepositsExecutedWithAttestation(depositDataBufferId, depositRootHash, depositCount);
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

    // -----------------------------------------------------------------------
    // Internal — deposit execution
    // -----------------------------------------------------------------------

    /// @notice Deposits 32 ETH to the official Deposit contract
    /// @param _publicKey The public key of the validator
    /// @param _signature The signature provided by the operator
    /// @param _withdrawalCredentials The withdrawal credentials provided by River
    function _depositValidator(
        bytes memory _publicKey,
        bytes memory _signature,
        uint256 _depositAmount,
        bytes32 _withdrawalCredentials
    ) internal {
        if (_depositAmount < 1 ether) {
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

        IDepositContract(DepositContractAddress.get()).deposit{value: _depositAmount}(
            _publicKey, abi.encodePacked(_withdrawalCredentials), _signature, depositDataRoot
        );
        if (address(this).balance != targetBalance) {
            revert ErrorOnDeposit();
        }
    }
}
