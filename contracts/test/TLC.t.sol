//SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import "../src/TLC.sol";
import "forge-std/Test.sol";

contract TLCTestTests is Test {
    TLC internal tlc;

    address internal initAccount;
    address internal bob;
    address internal joe;

    function setUp() public {
        initAccount = makeAddr("init");
        bob = makeAddr("bob");
        joe = makeAddr("joe");

        tlc = new TLC();
        tlc.initTLCV1(initAccount);
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

    function testTransfer() public {
        vm.startPrank(initAccount);
        tlc.transfer(joe, 5_000e18);
        vm.stopPrank();

        assert(tlc.balanceOf(joe) == 5_000e18);
        assert(tlc.balanceOf(initAccount) == 999_995_000e18);
    }

    function testDelegate() public {
        vm.startPrank(initAccount);
        tlc.transfer(joe, 5_000e18);
        vm.stopPrank();
        assert(tlc.balanceOf(joe) == 5_000e18);

        // before self delegating voting power is zero (this is an implementation choice from
        // open zeppelin to optimize gas)
        assert(tlc.getVotes(joe) == 0);

        vm.startPrank(joe);
        tlc.delegate(joe);
        vm.stopPrank();

        assert(tlc.balanceOf(joe) == 5_000e18);
        assert(tlc.getVotes(joe) == 5_000e18);
    }

    function testCheckpoints() public {
        vm.roll(1000);

        vm.startPrank(initAccount);
        tlc.transfer(joe, 5_000e18);
        vm.stopPrank();

        vm.startPrank(joe);
        tlc.delegate(joe);
        vm.stopPrank();

        assert(tlc.balanceOf(joe) == 5_000e18);
        assert(tlc.getVotes(joe) == 5_000e18);

        vm.roll(1010);
        assert(tlc.getPastVotes(joe, 999) == 0);
        assert(tlc.getPastVotes(joe, 1005) == 5_000e18);

        vm.startPrank(joe);
        tlc.transfer(bob, 2_500e18);
        vm.stopPrank();

        vm.startPrank(bob);
        tlc.delegate(bob);
        vm.stopPrank();

        vm.roll(1020);
        assert(tlc.getPastVotes(joe, 999) == 0);
        assert(tlc.getPastVotes(joe, 1005) == 5_000e18);
        assert(tlc.getPastVotes(joe, 1010) == 2_500e18);
        assert(tlc.getPastVotes(bob, 1005) == 0);
        assert(tlc.getPastVotes(bob, 1010) == 2_500e18);
    }

    function testDelegateAndTransfer() public {
        vm.startPrank(initAccount);
        tlc.transfer(joe, 5_000e18);
        vm.stopPrank();
        assert(tlc.balanceOf(joe) == 5_000e18);

        // before self delegating voting power is zero
        // (this is an implementation choice from open zeppelin to optimize gas)
        assert(tlc.getVotes(joe) == 0);

        vm.startPrank(joe);
        tlc.delegate(joe);
        vm.stopPrank();

        assert(tlc.balanceOf(joe) == 5_000e18);
        assert(tlc.getVotes(joe) == 5_000e18);

        vm.startPrank(joe);
        tlc.transfer(bob, 2_500e18);
        vm.stopPrank();

        assert(tlc.balanceOf(joe) == 2_500e18);
        assert(tlc.balanceOf(bob) == 2_500e18);
        assert(tlc.getVotes(joe) == 2_500e18);

        // before self delegating voting power is zero
        assert(tlc.getVotes(bob) == 0);

        vm.startPrank(bob);
        tlc.delegate(bob);
        vm.stopPrank();

        assert(tlc.balanceOf(joe) == 2_500e18);
        assert(tlc.balanceOf(bob) == 2_500e18);
        assert(tlc.getVotes(joe) == 2_500e18);
        assert(tlc.getVotes(bob) == 2_500e18);

        vm.startPrank(joe);
        tlc.transfer(bob, 1_000e18);
        vm.stopPrank();

        assert(tlc.balanceOf(joe) == 1_500e18);
        assert(tlc.balanceOf(bob) == 3_500e18);
        assert(tlc.getVotes(joe) == 1_500e18);
        assert(tlc.getVotes(bob) == 3_500e18);
    }
}
