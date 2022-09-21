//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "openzeppelin-contracts-upgradeable/contracts/token/ERC20/extensions/ERC20VotesUpgradeable.sol";

contract TLC is ERC20VotesUpgradeable {
    // Token information
    string internal constant NAME = "Liquid Collective";
    string internal constant SYMBOL = "TLC";

    // Initial supply of token minted
    uint256 internal constant INITIAL_SUPPLY = 1_000_000_000e18; // 1 billion TLC

    /// @notice Initializes the TLC Token
    /// * @param account_ The initial account to grant all the minted tokens
    function initTLCV1(address account_) external initializer {
        __ERC20Permit_init(NAME);
        __ERC20_init(NAME, SYMBOL);
        _mint(account_, INITIAL_SUPPLY);
    }
}
