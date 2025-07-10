// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20Upgradeable} from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";

interface IBurnMintERC20 is IERC20Upgradeable {
    /// @notice Mints new tokens for a given address.
    /// @param account The address to mint the new tokens to.
    /// @param amount The number of tokens to be minted.
    /// @dev this function increases the total supply.
    function mint(address account, uint256 amount) external;

    /// @notice Burns tokens from the sender.
    /// @param amount The number of tokens to be burned.
    /// @dev this function decreases the total supply.
    function burn(uint256 amount) external;

    /// @notice Burns tokens from a given address..
    /// @param account The address to burn tokens from.
    /// @param amount The number of tokens to be burned.
    /// @dev this function decreases the total supply.
    function burn(address account, uint256 amount) external;

    /// @notice Burns tokens from a given address..
    /// @param account The address to burn tokens from.
    /// @param amount The number of tokens to be burned.
    /// @dev this function decreases the total supply.
    function burnFrom(address account, uint256 amount) external;
}
