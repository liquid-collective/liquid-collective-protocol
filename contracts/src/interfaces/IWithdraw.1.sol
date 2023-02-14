//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

/// @title Withdraw Interface (V1)
/// @author Kiln
/// @notice This contract is in charge of holding the exit and skimming funds and allow river to pull these funds
interface IWithdrawV1 {
    /// @notice Emitted when the linked River address is changed
    /// @param river The new River address
    event SetRiver(address river);

    /// @notice Thrown when the requested pulled amount is too high
    /// @param requestedAmount The amount that was requested by River
    /// @param availableAmount The current balance available
    error PulledAmountTooHigh(uint256 requestedAmount, uint256 availableAmount);

    /// @param river The address of the River contract
    function initializeWithdrawV1(address river) external;

    /// @notice Retrieve the withdrawal credentials to use
    /// @return The withdrawal credentials
    function getCredentials() external view returns (bytes32);

    /// @notice Retrieve the linked River address
    /// @return The River address
    function getRiver() external view returns (address);

    /// @notice Callable by River, sends the specified amount of ETH to River
    /// @param amount The amount to pull
    function pullEth(uint256 amount) external;

    /// @notice Fallback for payments (transfer, send, call without data)
    receive() external payable;

    /// @notice Fallback for calls with data
    fallback() external payable;
}
