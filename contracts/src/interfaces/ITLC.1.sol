//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "openzeppelin-contracts-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";
import "openzeppelin-contracts-upgradeable/contracts/governance/utils/IVotesUpgradeable.sol";

import "./components/IERC20VestableVotesUpgradeable.1.sol";

/// @title TLC Interface (v1)
/// @author Alluvial Finance Inc.
/// @notice TLC token interface
/// @dev The v1.0 initializer and the vesting-schedule migration are intentionally absent: the deployed
///      proxy already sits at OpenZeppelin `_initialized == 2`, so neither can be re-run. Their bodies
///      are preserved for test bootstrapping in contracts/test/utils/LegacyInit.sol.
interface ITLCV1 is IERC20Upgradeable, IVotesUpgradeable, IERC20VestableVotesUpgradeableV1 {}
