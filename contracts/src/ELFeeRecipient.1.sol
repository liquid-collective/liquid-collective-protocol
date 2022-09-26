//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "./Initializable.sol";
import "./libraries/LibErrors.sol";
import "./libraries/LibUint256.sol";
import "./interfaces/IRiver.1.sol";
import "./interfaces/IELFeeRecipient.1.sol";
import "./state/shared/RiverAddress.sol";

/// @title Execution Layer Fee Recipient
/// @author Kiln
/// @notice This contract receives all the execution layer fees from the proposed blocks + bribes
contract ELFeeRecipientV1 is Initializable, IELFeeRecipientV1 {
    /// @notice Initialize the fee recipient with the required arguments
    /// @param _riverAddress Address of River
    function initELFeeRecipientV1(address _riverAddress) external init(0) {
        RiverAddress.set(_riverAddress);
        emit SetRiver(_riverAddress);
    }

    /// @notice Pulls all the ETH to the River contract
    /// @dev Only callable by the River contract
    /// @param _maxAmount Maximum value to extract from the recipient
    function pullELFees(uint256 _maxAmount) external {
        address river = RiverAddress.get();
        if (msg.sender != river) {
            revert LibErrors.Unauthorized(msg.sender);
        }
        uint256 amount = LibUint256.min(_maxAmount, address(this).balance);

        IRiverV1(payable(river)).sendELFees{value: amount}();
    }

    /// @notice Ether receiver
    receive() external payable {
        this;
    }

    /// @notice Invalid fallback detector
    fallback() external payable {
        revert InvalidCall();
    }
}
