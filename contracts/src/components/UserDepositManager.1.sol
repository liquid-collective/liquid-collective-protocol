//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "../libraries/LibErrors.sol";
import "../libraries/LibSanitize.sol";
import "../state/river/BalanceToDeposit.sol";

import "../interfaces/components/IUserDepositManager.1.sol";

/// @title User Deposit Manager (v1)
/// @author Kiln
/// @notice This contract handles the inbound transfers cases or the explicit submissions
abstract contract UserDepositManagerV1 is IUserDepositManagerV1 {
    /// @notice Handler called whenever a user has sent funds to the contract
    /// @dev Must be overriden
    /// @param _depositor Address that made the deposit
    /// @param _recipient Address that receives the minted shares
    /// @param _amount Amount deposited
    function _onDeposit(address _depositor, address _recipient, uint256 _amount) internal virtual returns (uint256);

    /// @notice Internal utility calling the deposit handler and emitting the deposit details
    function _deposit(address _recipient) internal {
        if (msg.value == 0) {
            revert EmptyDeposit();
        }

        uint256 usedValue = _onDeposit(msg.sender, _recipient, msg.value);

        BalanceToDeposit.set(BalanceToDeposit.get() + usedValue);

        emit UserDeposit(msg.sender, _recipient, usedValue);
    }

    /// @notice Explicit deposit method to mint on msg.sender
    function deposit() external payable {
        _deposit(msg.sender);
    }

    /// @notice Explicit deposit method to mint on msg.sender and transfer to _recipient
    /// @param _recipient Address receiving the minted lsETH
    function depositAndTransfer(address _recipient) external payable {
        LibSanitize._notZeroAddress(_recipient);
        _deposit(_recipient);
    }

    /// @notice Implicit deposit method, when the user performs a regular transfer to the contract
    receive() external payable {
        _deposit(msg.sender);
    }

    /// @notice Invalid call, when the user sends a transaction with a data payload but no method matched
    fallback() external payable {
        revert LibErrors.InvalidCall();
    }
}
