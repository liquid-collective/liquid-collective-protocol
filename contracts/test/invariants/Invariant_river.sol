pragma solidity 0.8.10;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {Base} from "./Base.sol";

contract Invariant_River is Base {
    function setUp() public override {
        super.setUp();
    }

    function invariant_test() public {
        assert(1 == 1);
    }

    function invariant_setBalanceToDeposit() public {
        uint256 balanceToDepositBefore = river.getBalanceToDeposit();
        // stakerService.action_stakeAmount(10 ether, 10);
        uint256 balanceToDepositAfter = river.getBalanceToDeposit();

        assertEq(balanceToDepositAfter, balanceToDepositBefore + 10 ether);
    }
}
