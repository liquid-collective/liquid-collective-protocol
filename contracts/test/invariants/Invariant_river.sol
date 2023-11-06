pragma solidity 0.8.10;

import "forge-std/Test.sol";
import {Base} from "./Base.sol";

contract Invariant is Base {
    Base private base;

    function setUp() public override {
        super.setUp();
        addTargetSelectors();
    }

    function addTargetSelectors() internal {
        targetSelector(stakerService.getTargetSelectors());
    }
    function invariant_test() public {
        assert(1==1);
    }
}
