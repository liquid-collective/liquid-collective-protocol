//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "../libraries/Errors.sol";

/// @title Transfer Manager (v1)
/// @author Iulian Rotaru
/// @notice This contract handles the inbound transfers cases or the explicit submissions
abstract contract TransferManagerV1 {
    event UserDeposit(address indexed user, address indexed referral, uint256 amount);

    error EmptyDeposit();

    /// @notice Handler called whenever a user has sent funds to the contract
    /// @dev Must be overriden
    /// @param _depositor Address that made the deposit
    /// @param _amount Amount deposited
    function _onDeposit(address _depositor, uint256 _amount) internal virtual;

    /// @notice Internal utility calling the deposit handler and emitting the deposit details and the referral address
    /// @param _referral Referral address, address(0) if none
    function _deposit(address _referral) internal {
        if (msg.value == 0) {
            revert EmptyDeposit();
        }

        _onDeposit(msg.sender, msg.value);

        emit UserDeposit(msg.sender, _referral, msg.value);
    }

    /// @notice Explicit deposit method
    /// @param _referral Referral address, address(0) if none
    function deposit(address _referral) external payable {
        _deposit(_referral);
    }

    /// @notice Implicit deposit method, when the user performs a regular transfer to the contract
    receive() external payable {
        _deposit(address(0));
    }

    /// @notice Invalid call, when the user sends a transaction with a data payload but no method matched
    fallback() external payable {
        revert Errors.InvalidCall();
    }
}
