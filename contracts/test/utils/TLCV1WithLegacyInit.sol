// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../../src/TLC.1.sol";

/// @title TLCV1WithLegacyInit (test-only)
/// @author Alluvial Finance Inc.
/// @notice Test subclass that adds back the v1.0 initializer and the vesting-schedule migration.
/// @dev The deployed TLC proxy already sits at OpenZeppelin `_initialized == 2`, so neither function
///      can be re-run onchain; production TLCV1 therefore no longer ships them. The bodies below are
///      byte-for-byte copies of what previously lived in contracts/src/TLC.1.sol, kept so tests can
///      still mint a fresh TLC and so the mainnet fork test can replay the V1 -> V2 vesting migration.
/// @dev Lives in its own file because TLC.1.sol pulls in OpenZeppelin's `Initializable`, which clashes
///      with the protocol's own `Initializable` imported by the harnesses in LegacyInit.sol.
contract TLCV1WithLegacyInit is TLCV1 {
    function initTLCV1(address _account) external initializer {
        LibSanitize._notZeroAddress(_account);
        __ERC20Permit_init(NAME);
        __ERC20_init(NAME, SYMBOL);
        _mint(_account, INITIAL_SUPPLY);
    }

    function migrateVestingSchedules() external reinitializer(2) {
        ERC20VestableVotesUpgradeableV1.migrateVestingSchedulesFromV1ToV2();
    }
}
