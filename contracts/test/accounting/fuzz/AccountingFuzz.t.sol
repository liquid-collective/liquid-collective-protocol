// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../AccountingInvariants.sol";

contract AccountingFuzzTest is AccountingInvariants {
    uint256 private constant MAX_VALIDATORS = 8;
    uint256 private constant MAX_REWARD = 0.008 ether; // stay within APR bounds

    function testFuzz_depositActivateReport(uint8 n1, uint8 n2) public {
        n1 = uint8(bound(n1, 1, MAX_VALIDATORS));
        n2 = uint8(bound(n2, 1, MAX_VALIDATORS));
        sim_deposit(operatorOneIndex, n1);
        sim_deposit(operatorTwoIndex, n2);
        sim_activateValidators(n1 + n2);
        sim_oracleReport();
    }

    function testFuzz_rewardsAccrual(uint8 n, uint64 rewardWei) public {
        n = uint8(bound(n, 1, MAX_VALIDATORS));
        rewardWei = uint64(bound(rewardWei, 0, MAX_REWARD));
        sim_deposit(operatorOneIndex, n);
        sim_activateValidators(n);
        sim_oracleReport();
        sim_advanceEpoch(rewardWei);
        sim_oracleReport();
    }

    function testFuzz_exitFlow(uint8 nDeposit, uint8 nExit) public {
        nDeposit = uint8(bound(nDeposit, 2, MAX_VALIDATORS));
        nExit = uint8(bound(nExit, 1, nDeposit));
        sim_deposit(operatorOneIndex, nDeposit);
        sim_activateValidators(nDeposit);
        sim_oracleReport();
        sim_requestExit(operatorOneIndex, uint256(nExit) * DEPOSIT_SIZE);
        sim_completeExit(operatorOneIndex, uint256(nExit) * DEPOSIT_SIZE, 0);
        sim_oracleReport();
    }

    function testFuzz_randomSequence(uint256 seed) public {
        uint256 s = seed;
        uint256 n1 = bound(s, 1, 4);
        s = _h(s);
        uint256 n2 = bound(s, 1, 4);
        s = _h(s);
        sim_deposit(operatorOneIndex, n1);
        sim_deposit(operatorTwoIndex, n2);
        sim_activateValidators(n1 + n2);
        sim_oracleReport();

        if (s % 2 == 0) {
            uint256 reward = bound(s, 0, MAX_REWARD);
            s = _h(s);
            sim_advanceEpoch(reward);
            sim_oracleReport();
        }
        s = _h(s);

        uint256 exitN = bound(s, 0, n1);
        s = _h(s);
        if (exitN > 0) {
            sim_requestExit(operatorOneIndex, exitN * DEPOSIT_SIZE);
            sim_completeExit(operatorOneIndex, exitN * DEPOSIT_SIZE, 0);
            sim_oracleReport();
        }
    }

    function _h(uint256 s) internal pure returns (uint256) {
        return uint256(keccak256(abi.encode(s)));
    }
}
