//SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.10;

import "forge-std/Test.sol";

import "../src/TUPProxy.sol";

contract DummyCounter {
    error BigError(uint256);
    error CallWentIn();

    uint256 public i;

    function inc() external {
        ++i;
    }

    function fail() external view {
        revert BigError(i);
    }

    function isPaused() external pure {
        revert CallWentIn();
    }
}

contract DummyCounterEvolved is DummyCounter {
    bool internal init;

    function superInc() external {
        ++i;
        ++i;
    }

    function superI() external view returns (uint256) {
        return i * i;
    }

    function initEvolved(uint256 _i) external {
        require(init == false, "already initialised");
        i = _i;
        init = true;
    }
}

contract TUPProxyTest is Test {
    DummyCounter internal implem;
    DummyCounterEvolved internal implemEvolved;
    TUPProxy internal proxy;

    address internal admin = address(1);

    event Pause();
    event Unpause();

    function setUp() public {
        implem = new DummyCounter();
        implemEvolved = new DummyCounterEvolved();
        proxy = new TUPProxy(address(implem), admin, "");
    }

    function testViewFunc() public view {
        assert(DummyCounter(address(proxy)).i() == 0);
    }

    function testFunc() public {
        assert(DummyCounter(address(proxy)).i() == 0);
        DummyCounter(address(proxy)).inc();
        assert(DummyCounter(address(proxy)).i() == 1);
    }

    function testAdminFuncAsLambda() public {
        vm.expectRevert(abi.encodeWithSignature("CallWentIn()"));
        proxy.isPaused();
    }

    function testFuncAsAdmin() public {
        assert(DummyCounter(address(proxy)).i() == 0);
        vm.startPrank(admin);
        vm.expectRevert("TransparentUpgradeableProxy: admin cannot fallback to proxy target");
        DummyCounter(address(proxy)).inc();
    }

    function testRevert() public {
        vm.expectRevert(abi.encodeWithSignature("BigError(uint256)", 0));
        DummyCounter(address(proxy)).fail();
        DummyCounter(address(proxy)).inc();
        vm.expectRevert(abi.encodeWithSignature("BigError(uint256)", 1));
        DummyCounter(address(proxy)).fail();
    }

    function testUpgradeToAndCall() public {
        assert(DummyCounter(address(proxy)).i() == 0);
        vm.startPrank(admin);
        proxy.upgradeToAndCall(address(implemEvolved), abi.encodeWithSignature("initEvolved(uint256)", 5));
        vm.stopPrank();
        assert(DummyCounterEvolved(address(proxy)).i() == 5);
        DummyCounterEvolved(address(proxy)).superInc();
        assert(DummyCounterEvolved(address(proxy)).i() == 7);
        assert(DummyCounterEvolved(address(proxy)).superI() == 49);
    }

    function testPause() public {
        assert(DummyCounter(address(proxy)).i() == 0);
        DummyCounter(address(proxy)).inc();
        assert(DummyCounter(address(proxy)).i() == 1);
        vm.startPrank(admin);
        vm.expectEmit(true, true, true, true);
        emit Pause();
        proxy.pause();
        vm.stopPrank();
        vm.expectRevert(abi.encodeWithSignature("CallWhenPaused()"));
        DummyCounter(address(proxy)).inc();
    }

    function testUnPause() public {
        assert(DummyCounter(address(proxy)).i() == 0);
        DummyCounter(address(proxy)).inc();
        assert(DummyCounter(address(proxy)).i() == 1);
        vm.startPrank(admin);
        proxy.pause();
        assert(proxy.isPaused() == true);
        vm.stopPrank();
        vm.expectRevert(abi.encodeWithSignature("CallWhenPaused()"));
        DummyCounter(address(proxy)).inc();
        vm.startPrank(admin);
        vm.expectEmit(true, true, true, true);
        emit Unpause();
        proxy.unpause();
        assert(proxy.isPaused() == false);
        vm.stopPrank();
        DummyCounter(address(proxy)).inc();
        assert(DummyCounter(address(proxy)).i() == 2);
    }

    function testPauseAddressZeroFallback() public {
        assert(DummyCounter(address(proxy)).i() == 0);
        DummyCounter(address(proxy)).inc();
        assert(DummyCounter(address(proxy)).i() == 1);
        vm.startPrank(admin);
        proxy.pause();
        vm.stopPrank();

        vm.startPrank(address(0));
        assert(DummyCounter(address(proxy)).i() == 1);
        vm.stopPrank();
    }
}
