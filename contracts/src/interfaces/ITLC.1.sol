//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "openzeppelin-contracts-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";
import "openzeppelin-contracts-upgradeable/contracts/governance/utils/IVotesUpgradeable.sol";

import "./components/IERC20VestableVotesUpgradeable.1.sol";

/// @title TLC Interface (v1)
/// @author Alluvial Finance Inc.
/// @notice TLC token interface
/// @dev This interface is deliberately empty. It used to declare `initTLCV1(address)` (OZ
///      `initializer`) and `migrateVestingSchedules()` (OZ `reinitializer(2)`); both were removed
///      because the deployed proxy already sits at `_initialized == 2`. See the note on TLCV1 in
///      contracts/src/TLC.1.sol for the full record.
interface ITLCV1 is IERC20Upgradeable, IVotesUpgradeable, IERC20VestableVotesUpgradeableV1 {}
