// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "forge-std/StdUtils.sol";

/// @dev Interface exposing the test contract's external wrappers and state readers.
interface IAccountingActions {
    function handler_deposit(uint256 opIdx, uint256 n) external;
    function handler_activateValidators(uint256 n) external;
    function handler_advanceEpoch(uint256 rewardsPerValidator) external;
    function handler_requestExit(uint256 opIdx, uint256 ethAmount) external;
    function handler_completeExit(uint256 opIdx, uint256 ethAmount, uint256 penalty) external;
    function handler_slash(uint256 opIdx, uint256 penalty) external;
    function handler_oracleReport(bool rebalance, bool slashingContainment) external;

    function handler_pendingCount() external view returns (uint256);
    function handler_activeCount(uint256 opIdx) external view returns (uint256);
    function handler_exitingCount(uint256 opIdx) external view returns (uint256);
    function handler_operatorIndex(uint256 which) external view returns (uint256);
}

/// @title AccountingHandler
/// @notice Foundry invariant-test handler that bounds fuzzed inputs and delegates to sim_* step functions
///         on the test contract. Each public function is a target for Foundry's stateful fuzzer.
contract AccountingHandler is StdUtils {
    IAccountingActions private _test;

    uint256 private _opOne;
    uint256 private _opTwo;

    // ─── ghost variables ────────────────────────────────────────────────────────

    uint256 public ghost_depositCount;
    uint256 public ghost_reportCount;
    bool public ghost_slashOccurred;

    // ─── call counters (debugging) ──────────────────────────────────────────────

    uint256 public calls_deposit;
    uint256 public calls_activate;
    uint256 public calls_advanceEpoch;
    uint256 public calls_requestExit;
    uint256 public calls_completeExit;
    uint256 public calls_slash;
    uint256 public calls_oracleReport;

    constructor(IAccountingActions test_) {
        _test = test_;
        _opOne = test_.handler_operatorIndex(0);
        _opTwo = test_.handler_operatorIndex(1);
    }

    // ─── bounded handler functions ──────────────────────────────────────────────

    /// @notice Fuzzer entry point: deposits 1–4 validators for a pseudo-randomly selected operator.
    ///         Updates `ghost_depositCount` so that `oracleReport` knows at least one deposit exists.
    /// @param opSeed   Seed used to select the target operator (even → operator one, odd → operator two).
    /// @param nSeed    Seed used to derive the number of validators to deposit, bounded to [1, 4].
    function deposit(uint256 opSeed, uint256 nSeed) external {
        // Step 1: Select operator and bound the validator count to a safe range.
        uint256 opIdx = (opSeed % 2 == 0) ? _opOne : _opTwo;
        uint256 n = bound(nSeed, 1, 4);
        // Step 2: Delegate the deposit to the test contract and update ghost/call counters.
        _test.handler_deposit(opIdx, n);
        ghost_depositCount += n;
        calls_deposit++;
    }

    /// @notice Fuzzer entry point: activates 1–N pending validators where N is the current
    ///         pending count. Skips silently if no validators are pending.
    /// @param nSeed  Seed used to derive the number of validators to activate, bounded to [1, pending].
    function activateValidators(uint256 nSeed) external {
        // Step 1: Guard — skip if there are no pending validators to activate.
        uint256 pending = _test.handler_pendingCount();
        if (pending == 0) return;
        // Step 2: Bound the activation count and delegate to the test contract.
        uint256 n = bound(nSeed, 1, pending);
        _test.handler_activateValidators(n);
        calls_activate++;
    }

    /// @notice Fuzzer entry point: advances a single epoch with a per-validator reward bounded
    ///         to [0, 0.008 ETH] to stay within realistic APR limits.
    /// @param rewardSeed  Seed used to derive the per-validator reward amount in wei.
    function advanceEpoch(uint256 rewardSeed) external {
        // Step 1: Bound the reward to the maximum allowed per-validator amount.
        uint256 reward = bound(rewardSeed, 0, 0.008 ether);
        // Step 2: Delegate the epoch advance to the test contract.
        _test.handler_advanceEpoch(reward);
        calls_advanceEpoch++;
    }

    /// @notice Fuzzer entry point: requests the exit of 1–N active validators for a
    ///         pseudo-randomly selected operator. Skips silently if none are active.
    /// @param opSeed  Seed used to select the target operator.
    /// @param nSeed   Seed used to derive the number of validators to exit, bounded to [1, active].
    function requestExit(uint256 opSeed, uint256 nSeed) external {
        // Step 1: Select operator and guard — skip if no active validators exist.
        uint256 opIdx = (opSeed % 2 == 0) ? _opOne : _opTwo;
        uint256 active = _test.handler_activeCount(opIdx);
        if (active == 0) return;
        // Step 2: Bound the exit count and compute the corresponding ETH amount.
        uint256 n = bound(nSeed, 1, active);
        uint256 ethAmount = n * 32 ether;
        // Step 3: Delegate the exit request to the test contract.
        _test.handler_requestExit(opIdx, ethAmount);
        calls_requestExit++;
    }

    /// @notice Fuzzer entry point: completes the exit of 1–N exiting validators for a
    ///         pseudo-randomly selected operator with a random penalty up to 2 ETH.
    ///         Skips silently if no validators are in the Exiting state.
    /// @param opSeed      Seed used to select the target operator.
    /// @param nSeed       Seed used to derive the number of validators to complete, bounded to [1, exiting].
    /// @param penaltySeed Seed used to derive the exit penalty, bounded to [0, 2 ETH].
    function completeExit(uint256 opSeed, uint256 nSeed, uint256 penaltySeed) external {
        // Step 1: Select operator and guard — skip if no validators are currently exiting.
        uint256 opIdx = (opSeed % 2 == 0) ? _opOne : _opTwo;
        uint256 exiting = _test.handler_exitingCount(opIdx);
        if (exiting == 0) return;
        // Step 2: Bound the count and penalty, then compute the ETH amount.
        uint256 n = bound(nSeed, 1, exiting);
        uint256 ethAmount = n * 32 ether;
        uint256 penalty = bound(penaltySeed, 0, 2 ether);
        // Step 3: Delegate the exit completion to the test contract.
        _test.handler_completeExit(opIdx, ethAmount, penalty);
        calls_completeExit++;
    }

    /// @notice Fuzzer entry point: applies a slash penalty of 0.01–16 ETH to a pseudo-randomly
    ///         selected operator's first active validator. Skips silently if none are active.
    ///         Sets `ghost_slashOccurred` so the next `oracleReport` uses slashing-containment mode.
    /// @param opSeed      Seed used to select the target operator.
    /// @param penaltySeed Seed used to derive the slash penalty, bounded to [0.01 ETH, 16 ETH].
    function slash(uint256 opSeed, uint256 penaltySeed) external {
        // Step 1: Select operator and guard — skip if no active validators exist.
        uint256 opIdx = (opSeed % 2 == 0) ? _opOne : _opTwo;
        uint256 active = _test.handler_activeCount(opIdx);
        if (active == 0) return;
        // Step 2: Bound the penalty and delegate the slash to the test contract.
        uint256 penalty = bound(penaltySeed, 0.01 ether, 16 ether);
        _test.handler_slash(opIdx, penalty);
        // Step 3: Record that a slash occurred so the next oracle report uses containment mode.
        ghost_slashOccurred = true;
        calls_slash++;
    }

    /// @notice Fuzzer entry point: submits an oracle report. Skips silently if no deposits have
    ///         been made yet. Activates rebalancing mode ~25% of the time (modeSeed % 4 == 0)
    ///         and slashing-containment mode whenever a slash has occurred since the last report.
    /// @param modeSeed  Seed used to decide whether to submit in rebalancing mode.
    function oracleReport(uint256 modeSeed) external {
        // Step 1: Guard — no-op if no validators have been deposited yet.
        if (ghost_depositCount == 0) return;
        // Step 2: Derive report mode flags and delegate the report to the test contract.
        bool rebalance = (modeSeed % 4 == 0);
        bool slashingContainment = ghost_slashOccurred;
        _test.handler_oracleReport(rebalance, slashingContainment);
        // Step 3: Reset the slash flag and update ghost/call counters.
        ghost_slashOccurred = false;
        ghost_reportCount++;
        calls_oracleReport++;
    }
}
