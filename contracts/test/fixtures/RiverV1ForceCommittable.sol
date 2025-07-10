// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.13;

import "../../src/River.1.sol";

contract RiverV1ForceCommittable is RiverV1 {
    function debug_moveDepositToCommitted() external {
        _setCommittedBalance(CommittedBalance.get() + BalanceToDeposit.get());
        _setBalanceToDeposit(0);
    }
}
