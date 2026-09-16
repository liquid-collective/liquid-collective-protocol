//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "./interfaces/IRiver.1.sol";
import "./interfaces/IELFeeRecipient.1.sol";
import "./interfaces/IProtocolVersion.sol";

import "./libraries/LibUint256.sol";

import "./Initializable.sol";

import "./state/shared/RiverAddress.sol";

/// @title Execution Layer Fee Recipient (v1)
/// @author Alluvial Finance Inc.
/// @notice This contract receives all the execution layer fees from the proposed blocks + bribes
/// @dev REMOVED INITIALIZERS. Every deployed proxy is at `Version == 1`, so the `init(N)` guard on
///      this can never pass again; it was deleted to reclaim bytecode. Recorded here so the version
///      counter's history stays readable, and so nobody reuses this slot:
///        init(0)  initELFeeRecipientV1(address)         -- _riverAddress
///      Body preserved verbatim in contracts/test/utils/LegacyInit.sol
///      (ELFeeRecipientV1WithLegacyInit).
contract ELFeeRecipientV1 is Initializable, IELFeeRecipientV1, IProtocolVersion {
    /// @inheritdoc IELFeeRecipientV1
    function pullELFees(uint256 _maxAmount) external {
        address river = RiverAddress.get();
        if (msg.sender != river) {
            revert LibErrors.Unauthorized(msg.sender);
        }
        uint256 amount = LibUint256.min(_maxAmount, address(this).balance);

        if (amount > 0) {
            IRiverV1(payable(river)).sendELFees{value: amount}();
        }
    }

    /// @inheritdoc IELFeeRecipientV1
    receive() external payable {
        this;
    }

    /// @inheritdoc IELFeeRecipientV1
    fallback() external payable {
        revert InvalidCall();
    }

    function version() external pure returns (string memory) {
        return "1.3.0";
    }
}
