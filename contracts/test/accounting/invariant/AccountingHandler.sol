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

    function deposit(uint256 opSeed, uint256 nSeed) external {
        uint256 opIdx = (opSeed % 2 == 0) ? _opOne : _opTwo;
        uint256 n = bound(nSeed, 1, 4);
        _test.handler_deposit(opIdx, n);
        ghost_depositCount += n;
        calls_deposit++;
    }

    function activateValidators(uint256 nSeed) external {
        uint256 pending = _test.handler_pendingCount();
        if (pending == 0) return;
        uint256 n = bound(nSeed, 1, pending);
        _test.handler_activateValidators(n);
        calls_activate++;
    }

    function advanceEpoch(uint256 rewardSeed) external {
        uint256 reward = bound(rewardSeed, 0, 0.008 ether);
        _test.handler_advanceEpoch(reward);
        calls_advanceEpoch++;
    }

    function requestExit(uint256 opSeed, uint256 nSeed) external {
        uint256 opIdx = (opSeed % 2 == 0) ? _opOne : _opTwo;
        uint256 active = _test.handler_activeCount(opIdx);
        if (active == 0) return;
        uint256 n = bound(nSeed, 1, active);
        uint256 ethAmount = n * 32 ether;
        _test.handler_requestExit(opIdx, ethAmount);
        calls_requestExit++;
    }

    function completeExit(uint256 opSeed, uint256 nSeed, uint256 penaltySeed) external {
        uint256 opIdx = (opSeed % 2 == 0) ? _opOne : _opTwo;
        uint256 exiting = _test.handler_exitingCount(opIdx);
        if (exiting == 0) return;
        uint256 n = bound(nSeed, 1, exiting);
        uint256 ethAmount = n * 32 ether;
        uint256 penalty = bound(penaltySeed, 0, 2 ether);
        _test.handler_completeExit(opIdx, ethAmount, penalty);
        calls_completeExit++;
    }

    function slash(uint256 opSeed, uint256 penaltySeed) external {
        uint256 opIdx = (opSeed % 2 == 0) ? _opOne : _opTwo;
        uint256 active = _test.handler_activeCount(opIdx);
        if (active == 0) return;
        uint256 penalty = bound(penaltySeed, 0.01 ether, 16 ether);
        _test.handler_slash(opIdx, penalty);
        ghost_slashOccurred = true;
        calls_slash++;
    }

    function oracleReport(uint256 modeSeed) external {
        if (ghost_depositCount == 0) return;
        bool rebalance = (modeSeed % 4 == 0);
        bool slashingContainment = ghost_slashOccurred;
        _test.handler_oracleReport(rebalance, slashingContainment);
        ghost_slashOccurred = false;
        ghost_reportCount++;
        calls_oracleReport++;
    }
}
