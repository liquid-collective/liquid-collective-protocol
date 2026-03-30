//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";

import "./Initializable.sol";
import "./interfaces/IRiver.1.sol";
import "./interfaces/IWithdraw.1.sol";
import "./interfaces/IProtocolVersion.sol";
import "./libraries/LibErrors.sol";
import "./libraries/LibUint256.sol";

import "./state/shared/RiverAddress.sol";
import "./state/shared/WithdrawalContractAddress.sol";
import "./state/shared/ConsolidationContractAddress.sol";

/// @title Withdraw (v1)
/// @author Alluvial Finance Inc.
/// @notice This contract is in charge of holding the exit and skimming funds and allow river to pull these funds
contract WithdrawV1 is IWithdrawV1, Initializable, ReentrancyGuard, IProtocolVersion {
    modifier onlyRiver() {
        if (msg.sender != RiverAddress.get()) {
            revert LibErrors.Unauthorized(msg.sender);
        }
        _;
    }

    /// @inheritdoc IWithdrawV1
    function initializeWithdrawV1(address _river) external init(0) {
        _setRiver(_river);
    }

    /// @inheritdoc IWithdrawV1
    function initWithdrawV1_1(address _withdrawalContractAddress, address _consolidationContractAddress) external init(1) {
        WithdrawalContractAddress.set(_withdrawalContractAddress);
        ConsolidationContractAddress.set(_consolidationContractAddress);
    }

    /// @inheritdoc IWithdrawV1
    function getCredentials() external view returns (bytes32) {
        return
            bytes32(
                uint256(uint160(address(this))) + 0x0100000000000000000000000000000000000000000000000000000000000000
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
    ) external payable onlyRiver nonReentrant {
        if (pubkeys.length != amount.length) {
            revert LengthMismatch(pubkeys.length, amount.length);
        }

        uint256 maxFeePayable = maxFeePerWithdrawal * pubkeys.length;
        _validateSufficientValueForFee(msg.value, maxFeePayable);

        address withdrawalContract = WithdrawalContractAddress.get();
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
        address consolidationContract = ConsolidationContractAddress.get();
        uint256 fee = _validateAndReturnFee(consolidationContract, maxFeePerConsolidation);

        uint256 totalNumOfConsolidationOperations = 0;
        for (uint256 i = 0; i < requests.length; i++) {
            totalNumOfConsolidationOperations += requests[i].srcPubkeys.length;
        }
        uint256 totalFeeRequired = fee * totalNumOfConsolidationOperations;
        _validateSufficientValueForFee(msg.value, totalFeeRequired);

        for (uint256 i = 0; i < requests.length; i++) {
            _validatePubkeyLength(requests[i].targetPubkey);

            for (uint256 j = 0; j < requests[i].srcPubkeys.length; j++) {
                _validatePubkeyLength(requests[i].srcPubkeys[j]);

                bytes memory callData = bytes.concat(requests[i].srcPubkeys[j], requests[i].targetPubkey);
                (bool writeOK,) = consolidationContract.call{value: fee}(callData);
                if (!writeOK) {
                    revert RequestFailed();
                }
                emit ConsolidationRequested(requests[i].srcPubkeys[j], requests[i].targetPubkey, fee);
            }
        }

        _refundExcessFee(msg.value, totalFeeRequired, excessFeeRecipient);
    }

    /// @notice Internal utility to set the river address
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
        _fee = uint256(bytes32(feeData));

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

    /// @notice Internal: refund excess fee to recipient; emit on send failure instead of reverting
    function _refundExcessFee(uint256 _totalValueReceived, uint256 _totalFeePaid, address _excessFeeRecipient) internal {
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
