// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../AccountingInvariants.sol";

contract AccountingFuzzTest is AccountingInvariants {
    uint256 private constant MAX_VALIDATORS = 8;
    uint256 private constant MAX_REWARD = 0.008 ether; // stay within APR bounds

    /// @notice Fuzz test covering the deposit-activate-report lifecycle for two operators.
    ///         Verifies that all accounting invariants hold for any combination of validator
    ///         counts `n1` (operator one) and `n2` (operator two), each bounded to [1, 8].
    /// @param n1 Number of validators to deposit for operator one (fuzzed, bounded to [1, 8]).
    /// @param n2 Number of validators to deposit for operator two (fuzzed, bounded to [1, 8]).
    function testFuzz_depositActivateReport(uint8 n1, uint8 n2) public {
        // Step 1: Bound inputs to a safe range and deposit validators for both operators.
        n1 = uint8(bound(n1, 1, MAX_VALIDATORS));
        n2 = uint8(bound(n2, 1, MAX_VALIDATORS));
        sim_deposit(operatorOneIndex, n1);
        sim_deposit(operatorTwoIndex, n2);
        // Step 2: Activate all deposited validators and submit an oracle report.
        //         Invariant checks inside sim_oracleReport act as the assertion oracle.
        sim_activateValidators(n1 + n2);
        sim_oracleReport();
    }

    /// @notice Fuzz test verifying that reward accrual via epoch advancement is correctly
    ///         reflected in `totalUnderlyingSupply` for any combination of validator count
    ///         and per-validator reward amount within the expected APR bounds.
    /// @param n          Number of validators to deposit (fuzzed, bounded to [1, 8]).
    /// @param rewardWei  Per-validator reward in wei for the advanced epoch (fuzzed, bounded to [0, 0.008 ETH]).
    function testFuzz_rewardsAccrual(uint8 n, uint64 rewardWei) public {
        // Step 1: Bound inputs and deposit validators for operator one.
        n = uint8(bound(n, 1, MAX_VALIDATORS));
        rewardWei = uint64(bound(rewardWei, 0, MAX_REWARD));
        sim_deposit(operatorOneIndex, n);
        // Step 2: Activate all validators and submit the initial oracle report.
        sim_activateValidators(n);
        sim_oracleReport();
        // Step 3: Advance one epoch with the fuzzed per-validator reward and report again.
        sim_advanceEpoch(rewardWei);
        sim_oracleReport();
    }

    /// @notice Fuzz test covering the full deposit → activate → report → exit → report flow
    ///         for operator one. Verifies that all accounting invariants hold for any number
    ///         of deposited validators and any partial exit count within that range.
    /// @param nDeposit  Total validators to deposit (fuzzed, bounded to [2, 8]).
    /// @param nExit     Number of validators to exit (fuzzed, bounded to [1, nDeposit]).
    function testFuzz_exitFlow(uint8 nDeposit, uint8 nExit) public {
        // Step 1: Bound inputs — at least 2 deposits so at least 1 exit is possible.
        nDeposit = uint8(bound(nDeposit, 2, MAX_VALIDATORS));
        nExit = uint8(bound(nExit, 1, nDeposit));
        // Step 2: Deposit and activate all validators, then submit the initial oracle report.
        sim_deposit(operatorOneIndex, nDeposit);
        sim_activateValidators(nDeposit);
        sim_oracleReport();
        // Step 3: Request and complete exits for `nExit` validators with no penalty.
        sim_requestExit(operatorOneIndex, uint256(nExit) * DEPOSIT_SIZE);
        sim_completeExit(operatorOneIndex, uint256(nExit) * DEPOSIT_SIZE, 0);
        // Step 4: Submit the final oracle report confirming the exits.
        sim_oracleReport();
    }

    /// @notice Fuzz test exercising a pseudo-random sequence of accounting operations derived
    ///         from a single seed. The sequence covers deposits for two operators, conditional
    ///         epoch advancement with rewards, and a conditional partial exit for operator one.
    ///         Verifies that all accounting invariants hold throughout the entire sequence.
    /// @param seed  Seed used to derive all fuzzed parameters via sequential keccak256 hashing.
    function testFuzz_randomSequence(uint256 seed) public {
        // Step 1: Derive operator deposit counts from the seed.
        uint256 s = seed;
        uint256 n1 = bound(s, 1, 4);
        s = _h(s);
        uint256 n2 = bound(s, 1, 4);
        s = _h(s);
        // Step 2: Deposit for both operators, activate all validators, and report.
        sim_deposit(operatorOneIndex, n1);
        sim_deposit(operatorTwoIndex, n2);
        sim_activateValidators(n1 + n2);
        sim_oracleReport();

        // Step 3: Conditionally advance an epoch with rewards (50% probability from seed parity).
        if (s % 2 == 0) {
            uint256 reward = bound(s, 0, MAX_REWARD);
            s = _h(s);
            sim_advanceEpoch(reward);
            sim_oracleReport();
        }
        s = _h(s);

        // Step 4: Conditionally exit a subset of operator one's validators.
        uint256 exitN = bound(s, 0, n1);
        s = _h(s);
        if (exitN > 0) {
            sim_requestExit(operatorOneIndex, exitN * DEPOSIT_SIZE);
            sim_completeExit(operatorOneIndex, exitN * DEPOSIT_SIZE, 0);
            sim_oracleReport();
        }
    }

    /// @dev Derives the next pseudo-random value from `s` by hashing it with keccak256.
    ///      Used to create a deterministic sequence of fuzz inputs from a single seed.
    function _h(uint256 s) internal pure returns (uint256) {
        return uint256(keccak256(abi.encode(s)));
    }
}
