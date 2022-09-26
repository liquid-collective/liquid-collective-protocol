//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

interface IELFeeRecipientV1 {
    /// @notice The storage river address has changed
    /// @param river The new river address
    event SetRiver(address indexed river);

    /// @notice The fallback has been triggered with calldata
    error InvalidCall();

    /// @notice Initialize the fee recipient with the required arguments
    /// @param _riverAddress Address of River
    function initELFeeRecipientV1(address _riverAddress) external;

    /// @notice Pulls all the ETH to the River contract
    /// @dev Only callable by the River contract
    /// @param _maxAmount The maximum amount to pull into the system
    function pullELFees(uint256 _maxAmount) external;

    /// @notice Ether receiver
    receive() external payable;

    /// @notice Invalid fallback detector
    fallback() external payable;
}
