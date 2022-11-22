//SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import "../src/TLC.1.sol";
import "forge-std/Test.sol";

contract TLCTests is Test {
    TLCV1 internal tlc;

    address internal escrowImplem;
    address internal initAccount;
    address internal bob;
    address internal joe;

    function setUp() public {
        initAccount = makeAddr("init");
        bob = makeAddr("bob");
        joe = makeAddr("joe");

        tlc = new TLCV1();
        tlc.initTLCV1(initAccount);
        tlc.migrateVestingSchedules();
    }

    function testName() public view {
        assert(keccak256(bytes(tlc.name())) == keccak256("Liquid Collective"));
    }

    function testSymbol() public view {
        assert(keccak256(bytes(tlc.symbol())) == keccak256("TLC"));
    }

    function testInitialSupplyAndBalance() public view {
        assert(tlc.totalSupply() == 1_000_000_000e18);
        assert(tlc.balanceOf(initAccount) == tlc.totalSupply());
    }
}
