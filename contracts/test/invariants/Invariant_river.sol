pragma solidity 0.8.10;

import "forge-std/Test.sol";
import {Base} from "./Base.sol";

contract Invariant_River is Base {
    Base private base;

    function invariant_test() public {
        assert(1 == 1);
    }
}
