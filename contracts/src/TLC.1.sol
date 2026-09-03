//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "./components/ERC20VestableVotesUpgradeable.1.sol";
import "./interfaces/ITLC.1.sol";

/// @title TLC (v1)
/// @author Alluvial Finance Inc.
/// @notice The TLC token has a max supply of 1,000,000,000 and 18 decimal places.
/// @notice Upon deployment, all minted tokens are send to account provided at construction, in charge of creating the vesting schedules
/// @notice The contract is based on ERC20Votes by OpenZeppelin. Users need to delegate their voting power to someone or themselves to be able to vote.
/// @notice The contract contains vesting logics allowing vested users to still be able to delegate their voting power while their tokens are held in an escrow
/// @dev REMOVED INITIALIZERS. TLC uses OpenZeppelin's `Initializable`, not the protocol's `init(N)`
///      counter, and the deployed proxy already sits at `_initialized == 2`, so neither of these can
///      run again; they were deleted to reclaim bytecode. Recorded here so the initialization history
///      stays readable, and so nobody reuses one of these OZ versions:
///        initializer      initTLCV1(address)            -- _account, minted INITIAL_SUPPLY to it
///        reinitializer(2) migrateVestingSchedules()     -- ran migrateVestingSchedulesFromV1ToV2
///                                                          (VestingSchedulesV1 -> V2)
///      Bodies preserved verbatim in contracts/test/utils/TLCV1WithLegacyInit.sol, which is why the
///      token constants below are still declared here.
contract TLCV1 is ITLCV1, ERC20VestableVotesUpgradeableV1 {
    // Token information
    string internal constant NAME = "Liquid Collective";
    string internal constant SYMBOL = "TLC";

    // Initial supply of token minted
    uint256 internal constant INITIAL_SUPPLY = 1_000_000_000e18; // 1 billion TLC

    /// @notice Disables implementation initialization
    constructor() {
        _disableInitializers();
    }
}
