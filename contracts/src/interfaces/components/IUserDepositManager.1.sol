//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

/// @title User Deposit Manager (v1)
/// @author Kiln
/// @notice This interface exposes methods to handle the inbound transfers cases or the explicit submissions
interface IUserDepositManagerV1 {
    /// @notice User deposited ETH in the system
    /// @param depositor Address performing the deposit
    /// @param recipient Address receiving the minted shares
    /// @param amount Amount in ETH deposited
    event UserDeposit(address indexed depositor, address indexed recipient, uint256 amount);

    /// @notice User donated ETH to the system
    /// @param donator Address performing the donation
    /// @param amount Amount in ETH donated
    event UserDonation(address indexed donator, uint256 amount);

    /// @notice An empty deposit attempt was made
    error EmptyDeposit();

    /// @notice An empty donation attempt was made
    error EmptyDonation();

    /// @notice Explicit deposit method to mint on msg.sender
    function deposit() external payable;

    /// @notice Explicit deposit method to mint on msg.sender and transfer to _recipient
    /// @param _recipient Address receiving the minted LsETH
    function depositAndTransfer(address _recipient) external payable;

    /// @notice Explicit donation method, to add ETH into the system without creating new shares
    function donate() external payable;

    /// @notice Implicit deposit method, when the user performs a regular transfer to the contract
    receive() external payable;

    /// @notice Invalid call, when the user sends a transaction with a data payload but no method matched
    fallback() external payable;
}
