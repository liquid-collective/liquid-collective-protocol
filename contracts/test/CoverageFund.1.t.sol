//SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import "forge-std/Test.sol";

import "./utils/UserFactory.sol";

import "../src/CoverageFund.1.sol";
import "../src/Allowlist.1.sol";

contract RiverMock {
    event BalanceUpdated(uint256 amount);

    address internal allowlist;

    constructor(address _allowlist) {
        allowlist = _allowlist;
    }

    function sendELFees() external payable {
        emit BalanceUpdated(address(this).balance);
    }

    function pullCoverageFunds(address coverageFund, uint256 maxAmount) external {
        ICoverageFundV1(payable(coverageFund)).pullCoverageFunds(maxAmount);
    }

    function getAllowlist() external view returns (address) {
        return allowlist;
    }
}

contract CoverageFundTestV1 is Test {
    CoverageFundV1 internal coverageFund;

    AllowlistV1 internal allowlist;
    RiverMock internal river;
    UserFactory internal uf = new UserFactory();
    address internal admin;

    event BalanceUpdated(uint256 amount);
    event SetRiver(address indexed river);

    function setUp() public {
        admin = makeAddr("admin");
        allowlist = new AllowlistV1();
        allowlist.initAllowlistV1(admin, admin);
        river = new RiverMock(address(allowlist));
        coverageFund = new CoverageFundV1();
        vm.expectEmit(true, true, true, true);
        emit SetRiver(address(river));
        coverageFund.initCoverageFundV1(address(river));
    }

    function testTransferInvalidCall(uint256 _senderSalt, uint256 _amount) external {
        address sender = uf._new(_senderSalt);
        vm.deal(sender, _amount);

        vm.startPrank(sender);
        vm.expectRevert(abi.encodeWithSignature("InvalidCall()"));
        payable(address(coverageFund)).transfer(_amount);
        vm.stopPrank();
    }

    function testSendInvalidCall(uint256 _senderSalt, uint256 _amount) external {
        address sender = uf._new(_senderSalt);
        vm.deal(sender, _amount);

        vm.startPrank(sender);
        vm.expectRevert(abi.encodeWithSignature("InvalidCall()"));
        assert(payable(address(coverageFund)).send(_amount) == true);
        vm.stopPrank();
    }

    function testCallInvalidCall(uint256 _senderSalt, uint256 _amount) external {
        address sender = uf._new(_senderSalt);
        vm.deal(sender, _amount);

        vm.startPrank(sender);
        (bool ok, bytes memory rdata) = payable(address(coverageFund)).call{value: _amount}("");
        assert(ok == false);
        assertEq(rdata, abi.encodeWithSignature("InvalidCall()"));
        vm.stopPrank();
    }

    function testPullFundsFromDonate(uint256 _senderSalt, uint256 _amount) external {
        address sender = uf._new(_senderSalt);
        vm.deal(sender, _amount);

        vm.prank(admin);
        address[] memory accounts = new address[](1);
        accounts[0] = sender;
        uint256[] memory permissions = new uint256[](1);
        permissions[0] = LibAllowlistMasks.DONATE_MASK;
        allowlist.allow(accounts, permissions);

        vm.startPrank(sender);
        coverageFund.donate{value: _amount}();
        vm.stopPrank();

        if (_amount > 0) {
            vm.expectEmit(true, true, true, true);
            emit BalanceUpdated(_amount);
        }
        river.pullCoverageFunds(address(coverageFund), address(coverageFund).balance);
    }

    function testPullHalfFundsFromDonate(uint256 _senderSalt, uint256 _amount) external {
        address sender = uf._new(_senderSalt);
        vm.deal(sender, _amount);

        vm.prank(admin);
        address[] memory accounts = new address[](1);
        accounts[0] = sender;
        uint256[] memory permissions = new uint256[](1);
        permissions[0] = LibAllowlistMasks.DONATE_MASK;
        allowlist.allow(accounts, permissions);

        vm.startPrank(sender);
        coverageFund.donate{value: _amount}();
        vm.stopPrank();

        if (_amount > 1) {
            vm.expectEmit(true, true, true, true);
            emit BalanceUpdated(_amount / 2);
        }
        river.pullCoverageFunds(address(coverageFund), address(coverageFund).balance / 2);
    }

    function testDonateUnauthorized(uint256 _senderSalt, uint256 _amount) external {
        address sender = uf._new(_senderSalt);
        vm.deal(sender, _amount);

        vm.startPrank(sender);
        vm.expectRevert(abi.encodeWithSignature("Unauthorized(address)", sender));
        coverageFund.donate{value: _amount}();
        vm.stopPrank();
    }

    function testPullFundsUnauthorized(uint256 _senderSalt, uint256 _amount) external {
        address sender = uf._new(_senderSalt);
        vm.deal(sender, _amount);

        vm.prank(admin);
        address[] memory accounts = new address[](1);
        accounts[0] = sender;
        uint256[] memory permissions = new uint256[](1);
        permissions[0] = LibAllowlistMasks.DONATE_MASK;
        allowlist.allow(accounts, permissions);

        vm.startPrank(sender);
        coverageFund.donate{value: _amount}();
        vm.stopPrank();

        vm.startPrank(sender);
        vm.expectRevert(abi.encodeWithSignature("Unauthorized(address)", sender));
        coverageFund.pullCoverageFunds(address(coverageFund).balance);
        vm.stopPrank();
    }
}
