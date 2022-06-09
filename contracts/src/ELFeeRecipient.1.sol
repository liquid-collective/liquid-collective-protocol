//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "./Initializable.sol";
import "./libraries/Errors.sol";
import "./libraries/LibOwnable.sol";
import "./interfaces/IRiverDonationInput.sol";

import "./state/shared/RiverAddress.sol";

/// @title Execution Layer Fee Recipient
/// @author Kiln
/// @notice This contract receives all the execution layer fees from the proposed blocks + bribes
contract ELFeeRecipientV1 is Initializable {
    error InvalidCall();

    /// @notice Initialize the fee recipient with the required arguments
    /// @param _riverAddress Address of River
    function initELFeeRecipientV1(address _riverAddress) external init(0) {
        RiverAddress.set(_riverAddress);
    }

    /// @notice Counpounds all the current balance inside river
    function compound() external {
        IRiverDonationInput river = IRiverDonationInput(RiverAddress.get());
        river.donate{value: address(this).balance}();
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
