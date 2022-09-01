//SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import "../src/TLC.sol";
import "forge-std/Test.sol";

contract TLCTestTests is Test {
    TLC internal tlc;

    address internal owner;
    address internal initAccount;

    address internal bob;
    address internal joe;

    function setUp() public {
        owner = makeAddr("owner");
        initAccount = makeAddr("init");
        bob = makeAddr("bob");
        joe = makeAddr("joe");

        tlc = new TLC(owner, initAccount, block.timestamp + 1 days * 366);
    }

    function testName() public view {
        assert(keccak256(bytes(tlc.name())) == keccak256("Liquid Collective Token"));
    }

    function testSymbol() public view {
        assert(keccak256(bytes(tlc.symbol())) == keccak256("TLC"));
    }

    function testOwner() public view {
        assert(tlc.owner() == owner);
    }

    function testInitialSupplyAndBalance() public view {
        assert(tlc.totalSupply() == 1_000_000_000e18);
        assert(tlc.balanceOf(initAccount) == tlc.totalSupply());
    }

    function testTransferOwnership() public {
        vm.startPrank(owner);
        tlc.transferOwnership(joe);
        vm.stopPrank();

        assert(tlc.owner() == joe);
    }

    function testTransfer() public {
        vm.startPrank(initAccount);
        tlc.transfer(joe, 5_000e18);
        vm.stopPrank();

        assert(tlc.balanceOf(joe) == 5_000e18);
        assert(tlc.balanceOf(initAccount) == 999_995_000e18);
    }

    function testTransferFrom() public {
        vm.startPrank(initAccount);
        tlc.transfer(joe, 5_000e18);
        vm.stopPrank();

        assert(tlc.balanceOf(joe) == 5_000e18);

        vm.startPrank(joe);
        tlc.increaseAllowance(bob, 1_000e18);
        vm.stopPrank();

        vm.startPrank(bob);
        tlc.transferFrom(joe, bob, 1_000e18);
        vm.stopPrank();

        assert(tlc.balanceOf(joe) == 4_000e18);
        assert(tlc.balanceOf(bob) == 1_000e18);
        assert(tlc.allowance(joe, bob) == 0);
    }

    function testTransferFromAsOwner() public {
        vm.startPrank(initAccount);
        tlc.transfer(joe, 5_000e18);
        vm.stopPrank();

        assert(tlc.balanceOf(joe) == 5_000e18);

        vm.startPrank(owner);
        tlc.transferFrom(joe, bob, 1_000e18);
        vm.stopPrank();

        assert(tlc.balanceOf(joe) == 4_000e18);
        assert(tlc.balanceOf(bob) == 1_000e18);
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

    function pause() public {
        vm.startPrank(owner);
        tlc.pause();
        vm.stopPrank();
    }

    function testPauseAsOwner() public {
        pause();
        assert(tlc.paused());
    }

    function testUnpauseAsOwner() public {
        pause();

        vm.startPrank(owner);
        tlc.unpause();
        vm.stopPrank();

        assert(!tlc.paused());
    }

    function testPauseAsNonOwner() public {
        vm.startPrank(joe);
        vm.expectRevert("Ownable: caller is not the owner");
        tlc.pause();
        vm.stopPrank();
    }

    function testUnpauseAsNonOwner() public {
        pause();

        vm.startPrank(joe);
        vm.expectRevert("Ownable: caller is not the owner");
        tlc.unpause();
        vm.stopPrank();
    }

    function testTransferFromAsOwnerWhenPaused() public {
        pause();

        vm.startPrank(owner);
        tlc.transferFrom(initAccount, joe, 5_000e18);
        vm.stopPrank();
        assert(tlc.balanceOf(joe) == 5_000e18);
    }

    function testTransferAsNonOwnerWhenPaused() public {
        pause();
        vm.startPrank(initAccount);
        vm.expectRevert("TLC: transfer while paused");
        tlc.transfer(joe, 5_000e18);
        vm.stopPrank();
    }

    function testDelegateWhenPaused() public {
        pause();

        vm.startPrank(initAccount);
        vm.expectRevert("TLC: delegate while paused");
        tlc.delegate(initAccount);
        vm.stopPrank();
    }

    function testMintBeforeNoMintDateAsOwner() public {
        vm.warp(block.timestamp + 1 days * 365);
        vm.startPrank(owner);
        vm.expectRevert("TLC: minting is not allowed yet");
        tlc.mint(joe, 1_000e18);
        vm.stopPrank();
    }

    function testMintAfterMintDateAsOwner() public {
        vm.warp(block.timestamp + 1 days * 367);
        vm.startPrank(owner);
        tlc.mint(joe, 1_000e18);
        vm.stopPrank();

        assert(tlc.balanceOf(joe) == 1_000e18);
    }

    function testMintAfterMintDateAsNonOwner() public {
        vm.warp(block.timestamp + 1 days * 367);
        vm.startPrank(joe);
        vm.expectRevert("TLC: only owner can mint");
        tlc.mint(joe, 1_000e18);
        vm.stopPrank();
    }

    function testDoubleMintAsOwner() public {
        vm.warp(block.timestamp + 1 days * 367);
        vm.startPrank(owner);
        tlc.mint(joe, 1_000e18);
        vm.stopPrank();

        vm.warp(block.timestamp + 1 days * 10);

        vm.startPrank(owner);
        vm.expectRevert("TLC: minting is not allowed yet");
        tlc.mint(joe, 1_000e18);
        vm.stopPrank();
    }
}
