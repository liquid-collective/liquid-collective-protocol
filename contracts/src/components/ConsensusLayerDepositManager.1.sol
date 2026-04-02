//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../interfaces/components/IConsensusLayerDepositManager.1.sol";
import "../interfaces/IOperatorRegistry.1.sol";
import "../interfaces/IDepositContract.sol";

import "../libraries/LibBytes.sol";
import "../libraries/LibUint256.sol";

import "../state/river/DepositContractAddress.sol";
import "../state/river/WithdrawalCredentials.sol";
import "../state/river/BalanceToDeposit.sol";
import "../state/river/CommittedBalance.sol";
import "../state/river/KeeperAddress.sol";
import "../state/river/TotalDepositedETH.sol";
import "../state/river/InFlightDeposit.sol";

/// @title Consensus Layer Deposit Manager (v1)
/// @author Alluvial Finance Inc.
/// @notice This contract handles the interactions with the official deposit contract, funding all validators.
abstract contract ConsensusLayerDepositManagerV1 is IConsensusLayerDepositManagerV1 {
    /// @notice Size of a BLS Public key in bytes
    uint256 public constant PUBLIC_KEY_LENGTH = 48;
    /// @notice Size of a BLS Signature in bytes
    uint256 public constant SIGNATURE_LENGTH = 96;
    /// @notice Size of a deposit in ETH
    uint256 public constant DEPOSIT_SIZE = 32 ether;

    /// @notice Handler called to retrieve the internal River admin address
    /// @dev Must be Overridden
    function _getRiverAdmin() internal view virtual returns (address);

    /// @notice Handler called to increment the funded ETH for the operators
    /// @param _fundedETH The array of funded ETH amounts
    function _incrementFundedETH(uint256[] memory _fundedETH) internal virtual;

    /// @notice Handler called to change the committed balance to deposit
    /// @param newCommittedBalance The new committed balance value
    function _setCommittedBalance(uint256 newCommittedBalance) internal virtual;

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
        }
        uint256[] memory fundedETH = new uint256[](_allocations[_allocations.length - 1].operatorIndex + 1);

        // Check if the total requested exceeds the committed balance
        if (totalDeposits > committedBalance) {
            revert ValidatorDepositsExceedCommittedBalance();
        }

        bytes32 withdrawalCredentials = WithdrawalCredentials.get();

        if (withdrawalCredentials == 0) {
            revert InvalidWithdrawalCredentials();
        }

        address depositContract = DepositContractAddress.get();
        for (uint256 idx = 0; idx < _allocations.length; ++idx) {
            _depositValidator(
                _allocations[idx].pubkey,
                _allocations[idx].signature,
                _allocations[idx].depositAmount,
                withdrawalCredentials,
                depositContract
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
    }

    /// @notice Deposits 32 ETH to the official Deposit contract
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
        if (_depositAmount < 1 ether || _depositAmount > 2048 ether) {
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
