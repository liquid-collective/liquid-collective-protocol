//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Votes.sol";

contract TLC is ERC20Votes {
    // Token information
    string internal constant NAME = "Liquid Collective Token";
    string internal constant SYMBOL = "TLC";

    // Initial supply of token minted
    uint256 internal constant INITIAL_SUPPLY = 1_000_000_000e18; // 1 billion TLC

    /**
     * @notice Construct a new TLC token
     * @param account_ The initial account to grant all the tokens
     */
    constructor(address account_) ERC20Permit(NAME) ERC20(NAME, SYMBOL) {
        _mint(account_, INITIAL_SUPPLY);
    }
}