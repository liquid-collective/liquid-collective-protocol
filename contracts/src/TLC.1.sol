//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "./abstracts/ERC20VestableVotesUpgradeable.1.sol";

contract TLCV1 is ERC20VestableVotesUpgradeableV1 {
    // Token information
    string internal constant NAME = "Liquid Collective";
    string internal constant SYMBOL = "TLC";

    // Initial supply of token minted
    uint256 internal constant INITIAL_SUPPLY = 1_000_000_000e18; // 1 billion TLC

    /// @notice Initializes the TLC Token
    /// @param _account The initial account to grant all the minted tokens
    function initTLCV1(address _account) external initializer {
        LibSanitize._notZeroAddress(_account);
        __ERC20Permit_init(NAME);
        __ERC20_init(NAME, SYMBOL);
        _mint(_account, INITIAL_SUPPLY);
    }
}
