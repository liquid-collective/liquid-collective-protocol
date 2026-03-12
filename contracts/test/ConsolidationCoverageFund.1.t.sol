//SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.34;

import "forge-std/Test.sol";

import "./utils/UserFactory.sol";
import "./utils/LibImplementationUnbricker.sol";

import "../src/ConsolidationCoverageFund.1.sol";
import "../src/interfaces/IConsolidationCoverageFund.1.sol";
import "../src/Allowlist.1.sol";

contract RiverMock {
    event BalanceUpdated(uint256 amount);

    address internal allowlist;

    constructor(address _allowlist) {
        allowlist = _allowlist;
    }

    function sendCoverageFunds() external payable {
        emit BalanceUpdated(address(this).balance);
    }

    function sendConsolidationCoverageFunds() external payable {
        emit BalanceUpdated(address(this).balance);
    }

    function pullCoverageFunds(address consolidationCoverageFund, uint256 maxAmount) external {
        IConsolidationCoverageFundV1(payable(consolidationCoverageFund)).pullCoverageFunds(maxAmount);
    }

    function getAllowlist() external view returns (address) {
        return allowlist;
    }
}

abstract contract ConsolidationCoverageFundV1TestBase is Test {
    ConsolidationCoverageFundV1 internal consolidationCoverageFund;

    AllowlistV1 internal allowlist;
    RiverMock internal river;
    UserFactory internal uf = new UserFactory();
    address internal admin;

    event BalanceUpdated(uint256 amount);
    event SetRiver(address indexed river);
    event Donate(address indexed donator, uint256 amount);
}

contract ConsolidationCoverageFundV1InitializationTests is ConsolidationCoverageFundV1TestBase {
    function setUp() public {
        admin = makeAddr("admin");
        allowlist = new AllowlistV1();
        LibImplementationUnbricker.unbrick(vm, address(allowlist));
        allowlist.initAllowlistV1(admin, admin);
        river = new RiverMock(address(allowlist));
        consolidationCoverageFund = new ConsolidationCoverageFundV1();
        LibImplementationUnbricker.unbrick(vm, address(consolidationCoverageFund));
    }

    function testInitialization() external {
        vm.expectEmit(true, true, true, true);
        emit SetRiver(address(river));
        consolidationCoverageFund.initConsolidationCoverageFundV1(address(river));
    }
}

contract ConsolidationCoverageFundTestV1 is ConsolidationCoverageFundV1TestBase {
    function setUp() public {
        admin = makeAddr("admin");
        allowlist = new AllowlistV1();
        LibImplementationUnbricker.unbrick(vm, address(allowlist));
        allowlist.initAllowlistV1(admin, admin);
        allowlist.initAllowlistV1_1(admin);
        river = new RiverMock(address(allowlist));
        consolidationCoverageFund = new ConsolidationCoverageFundV1();
        LibImplementationUnbricker.unbrick(vm, address(consolidationCoverageFund));
        vm.expectEmit(true, true, true, true);
        emit SetRiver(address(river));
        consolidationCoverageFund.initConsolidationCoverageFundV1(address(river));
    }

    function testTransferInvalidCall(uint256 _senderSalt, uint256 _amount) external {
        vm.assume(_amount > 0);
        address sender = uf._new(_senderSalt);
        vm.deal(sender, _amount);

        vm.startPrank(sender);
        vm.expectRevert(abi.encodeWithSignature("InvalidCall()"));
        payable(address(consolidationCoverageFund)).transfer(_amount);
        vm.stopPrank();
    }

    function testSendInvalidCall(uint256 _senderSalt, uint256 _amount) external {
        vm.assume(_amount > 0);
        address sender = uf._new(_senderSalt);
        vm.deal(sender, _amount);

        vm.startPrank(sender);
        vm.expectRevert(abi.encodeWithSignature("InvalidCall()"));
        assert(payable(address(consolidationCoverageFund)).send(_amount) == true);
        vm.stopPrank();
    }

    function testCallInvalidCall(uint256 _senderSalt, uint256 _amount) external {
        vm.assume(_amount > 0);
        address sender = uf._new(_senderSalt);
        vm.deal(sender, _amount);

        vm.startPrank(sender);
        (bool ok, bytes memory rdata) = payable(address(consolidationCoverageFund)).call{value: _amount}("");
        assert(ok == false);
        assertEq(rdata, abi.encodeWithSignature("InvalidCall()"));
        vm.stopPrank();
    }

    function testPullFundsFromDonate(uint256 _senderSalt, uint256 _amount) external {
        vm.assume(_amount > 0);
        address sender = uf._new(_senderSalt);
        vm.deal(sender, _amount);

        vm.prank(admin);
        address[] memory accounts = new address[](1);
        accounts[0] = sender;
        uint256[] memory permissions = new uint256[](1);
        permissions[0] = LibAllowlistMasks.DONATE_CONSOLIDATION_MASK;
        allowlist.setAllowPermissions(accounts, permissions);

        vm.startPrank(sender);
        vm.expectEmit(true, true, true, true);
        emit Donate(sender, _amount);
        consolidationCoverageFund.donate{value: _amount}();
        vm.stopPrank();

        if (_amount > 0) {
            vm.expectEmit(true, true, true, true);
            emit BalanceUpdated(_amount);
        }
        river.pullCoverageFunds(address(consolidationCoverageFund), address(consolidationCoverageFund).balance);
    }

    function testPullHalfFundsFromDonate(uint256 _senderSalt, uint256 _amount) external {
        vm.assume(_amount > 0);
        address sender = uf._new(_senderSalt);
        vm.deal(sender, _amount);

        vm.prank(admin);
        address[] memory accounts = new address[](1);
        accounts[0] = sender;
        uint256[] memory permissions = new uint256[](1);
        permissions[0] = LibAllowlistMasks.DONATE_CONSOLIDATION_MASK;
        allowlist.setAllowPermissions(accounts, permissions);

        vm.startPrank(sender);
        consolidationCoverageFund.donate{value: _amount}();
        vm.stopPrank();

        if (_amount > 1) {
            vm.expectEmit(true, true, true, true);
            emit BalanceUpdated(_amount / 2);
        }
        river.pullCoverageFunds(address(consolidationCoverageFund), address(consolidationCoverageFund).balance / 2);
    }

    function testDonateUnauthorized(uint256 _senderSalt, uint256 _amount) external {
        vm.assume(_amount > 0);
        address sender = uf._new(_senderSalt);
        vm.deal(sender, _amount);

        vm.startPrank(sender);
        vm.expectRevert(abi.encodeWithSignature("Unauthorized(address)", sender));
        consolidationCoverageFund.donate{value: _amount}();
        vm.stopPrank();
    }

    function testDonateZero(uint256 _senderSalt) external {
        address sender = uf._new(_senderSalt);

        vm.prank(admin);
        address[] memory accounts = new address[](1);
        accounts[0] = sender;
        uint256[] memory permissions = new uint256[](1);
        permissions[0] = LibAllowlistMasks.DONATE_CONSOLIDATION_MASK;
        allowlist.setAllowPermissions(accounts, permissions);

        vm.startPrank(sender);
        vm.expectRevert(abi.encodeWithSignature("EmptyDonation()"));
        consolidationCoverageFund.donate{value: 0}();
        vm.stopPrank();
    }

    function testPullFundsUnauthorized(uint256 _senderSalt, uint256 _amount) external {
        vm.assume(_amount > 0);
        address sender = uf._new(_senderSalt);
        vm.deal(sender, _amount);

        vm.prank(admin);
        address[] memory accounts = new address[](1);
        accounts[0] = sender;
        uint256[] memory permissions = new uint256[](1);
        permissions[0] = LibAllowlistMasks.DONATE_CONSOLIDATION_MASK;
        allowlist.setAllowPermissions(accounts, permissions);

        vm.startPrank(sender);
        consolidationCoverageFund.donate{value: _amount}();
        vm.stopPrank();

        vm.startPrank(sender);
        vm.expectRevert(abi.encodeWithSignature("Unauthorized(address)", sender));
        consolidationCoverageFund.pullCoverageFunds(address(consolidationCoverageFund).balance);
        vm.stopPrank();
    }

    function testFallbackFail() external {
        address sender = uf._new(1);
        vm.deal(sender, 1e18);

        vm.startPrank(sender);
        vm.expectRevert(abi.encodeWithSignature("InvalidCall()"));
        address(consolidationCoverageFund).call{value: 1e18}(abi.encodeWithSignature("Hello()"));
        vm.stopPrank();
    }

    function testNoFundPulled() external {
        river.pullCoverageFunds(address(consolidationCoverageFund), 0);
        assertEq(0, address(river).balance);
    }

    function testVersion() external {
        assertEq(consolidationCoverageFund.version(), "1.0.0");
    }
}
