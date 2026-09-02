//SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.34;

import "forge-std/Test.sol";

import "./utils/UserFactory.sol";
import "./utils/LibImplementationUnbricker.sol";

import "../src/CoverageFund.1.sol";
import "../src/Allowlist.1.sol";

import "./utils/LegacyInit.sol";

contract RiverMock {
    event BalanceUpdated(uint256 amount);

    address internal allowlist;

    constructor(address _allowlist) {
        allowlist = _allowlist;
    }

    function sendCoverageFunds() external payable {
        emit BalanceUpdated(address(this).balance);
    }

    function pullCoverageFunds(address coverageFund, uint256 maxAmount) external {
        ICoverageFundV1(payable(coverageFund)).pullCoverageFunds(maxAmount);
    }

    function getAllowlist() external view returns (address) {
        return allowlist;
    }
}

abstract contract CoverageFundV1TestBase is Test {
    CoverageFundV1WithLegacyInit internal coverageFund;

    AllowlistV1WithLegacyInit internal allowlist;
    RiverMock internal river;
    UserFactory internal uf = new UserFactory();
    address internal admin;

    event BalanceUpdated(uint256 amount);
    event SetRiver(address indexed river);
    event Donate(address indexed donator, uint256 amount);
}

contract CoverageFundV1InitializationTests is CoverageFundV1TestBase {
    function setUp() public {
        admin = makeAddr("admin");
        allowlist = new AllowlistV1WithLegacyInit();
        LibImplementationUnbricker.unbrick(vm, address(allowlist));
        allowlist.initAllowlistV1(admin, admin);
        river = new RiverMock(address(allowlist));
        coverageFund = new CoverageFundV1WithLegacyInit();
        LibImplementationUnbricker.unbrick(vm, address(coverageFund));
    }

    function testInitialization() external {
        vm.expectEmit(true, true, true, true);
        emit SetRiver(address(river));
        coverageFund.initCoverageFundV1(address(river));
    }
}

contract CoverageFundTestV1 is CoverageFundV1TestBase {
    function setUp() public {
        admin = makeAddr("admin");
        allowlist = new AllowlistV1WithLegacyInit();
        LibImplementationUnbricker.unbrick(vm, address(allowlist));
        allowlist.initAllowlistV1(admin, admin);
        allowlist.initAllowlistV1_1(admin);
        river = new RiverMock(address(allowlist));
        coverageFund = new CoverageFundV1WithLegacyInit();
        LibImplementationUnbricker.unbrick(vm, address(coverageFund));
        vm.expectEmit(true, true, true, true);
        emit SetRiver(address(river));
        coverageFund.initCoverageFundV1(address(river));
    }

    function testTransferInvalidCall(uint256 _senderSalt, uint256 _amount) external {
        vm.assume(_amount > 0);
        address sender = uf._new(_senderSalt);
        vm.deal(sender, _amount);

        vm.startPrank(sender);
        vm.expectRevert(abi.encodeWithSignature("InvalidCall()"));
        payable(address(coverageFund)).transfer(_amount);
        vm.stopPrank();
    }

    function testSendInvalidCall(uint256 _senderSalt, uint256 _amount) external {
        vm.assume(_amount > 0);
        address sender = uf._new(_senderSalt);
        vm.deal(sender, _amount);

        vm.startPrank(sender);
        vm.expectRevert(abi.encodeWithSignature("InvalidCall()"));
        assert(payable(address(coverageFund)).send(_amount) == true);
        vm.stopPrank();
    }

    function testCallInvalidCall(uint256 _senderSalt, uint256 _amount) external {
        vm.assume(_amount > 0);
        address sender = uf._new(_senderSalt);
        vm.deal(sender, _amount);

        vm.startPrank(sender);
        (bool ok, bytes memory rdata) = payable(address(coverageFund)).call{value: _amount}("");
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
        permissions[0] = LibAllowlistMasks.DONATE_MASK;
        allowlist.setAllowPermissions(accounts, permissions);

        vm.startPrank(sender);
        vm.expectEmit(true, true, true, true);
        emit Donate(sender, _amount);
        coverageFund.donate{value: _amount}();
        vm.stopPrank();

        if (_amount > 0) {
            vm.expectEmit(true, true, true, true);
            emit BalanceUpdated(_amount);
        }
        river.pullCoverageFunds(address(coverageFund), address(coverageFund).balance);
    }

    function testPullHalfFundsFromDonate(uint256 _senderSalt, uint256 _amount) external {
        vm.assume(_amount > 0);
        address sender = uf._new(_senderSalt);
        vm.deal(sender, _amount);

        vm.prank(admin);
        address[] memory accounts = new address[](1);
        accounts[0] = sender;
        uint256[] memory permissions = new uint256[](1);
        permissions[0] = LibAllowlistMasks.DONATE_MASK;
        allowlist.setAllowPermissions(accounts, permissions);

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
        vm.assume(_amount > 0);
        address sender = uf._new(_senderSalt);
        vm.deal(sender, _amount);

        vm.startPrank(sender);
        vm.expectRevert(abi.encodeWithSignature("Unauthorized(address)", sender));
        coverageFund.donate{value: _amount}();
        vm.stopPrank();
    }

    // ---- CEI-ordering regression guards --------------------------------------------------------
    // donate() runs the allowlist check before writing BalanceForCoverage. These assert that a
    // donate() rejected by access control never mutates the stored coverage balance — the guarantee
    // that would break if the state write were ever (re)ordered ahead of the check, or the check were
    // made non-reverting. We seed a prior authorized donation so "unchanged" is a non-trivial value.

    bytes32 internal constant BALANCE_FOR_COVERAGE_SLOT =
        bytes32(uint256(keccak256("river.state.balanceForCoverage")) - 1);

    function _storedCoverageBalance() internal view returns (uint256) {
        return uint256(vm.load(address(coverageFund), BALANCE_FOR_COVERAGE_SLOT));
    }

    function _allow(address _account, uint256 _mask) internal {
        address[] memory accounts = new address[](1);
        accounts[0] = _account;
        uint256[] memory permissions = new uint256[](1);
        permissions[0] = _mask;
        vm.prank(admin);
        allowlist.setAllowPermissions(accounts, permissions);
    }

    function _deny(address _account) internal {
        address[] memory accounts = new address[](1);
        accounts[0] = _account;
        uint256[] memory permissions = new uint256[](1);
        permissions[0] = LibAllowlistMasks.DENY_MASK;
        vm.prank(admin);
        allowlist.setDenyPermissions(accounts, permissions);
    }

    function testDonateRejectedDoesNotMutateBalance(uint256 _seedSalt, uint256 _amount) external {
        _amount = bound(_amount, 1, 1e24);

        // Seed a prior authorized donation so the stored balance is non-zero.
        address donor = uf._new(_seedSalt);
        vm.deal(donor, _amount);
        _allow(donor, LibAllowlistMasks.DONATE_MASK);
        vm.prank(donor);
        coverageFund.donate{value: _amount}();
        uint256 balanceBefore = _storedCoverageBalance();
        assertEq(balanceBefore, _amount, "seed donation should be stored");

        // (a) Unknown caller (no permissions) -> Unauthorized; stored balance untouched.
        address stranger = makeAddr("stranger");
        vm.deal(stranger, _amount);
        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSignature("Unauthorized(address)", stranger));
        coverageFund.donate{value: _amount}();
        assertEq(_storedCoverageBalance(), balanceBefore, "unknown-caller revert must not mutate balance");

        // (b) Known but lacks DONATE_MASK (allowlisted for DEPOSIT only) -> Unauthorized; untouched.
        address wrongMask = makeAddr("wrongMask");
        vm.deal(wrongMask, _amount);
        _allow(wrongMask, LibAllowlistMasks.DEPOSIT_MASK);
        vm.prank(wrongMask);
        vm.expectRevert(abi.encodeWithSignature("Unauthorized(address)", wrongMask));
        coverageFund.donate{value: _amount}();
        assertEq(_storedCoverageBalance(), balanceBefore, "wrong-mask revert must not mutate balance");

        // (c) Denylisted caller -> Denied; stored balance untouched.
        address denied = makeAddr("denied");
        vm.deal(denied, _amount);
        _deny(denied);
        vm.prank(denied);
        vm.expectRevert(abi.encodeWithSignature("Denied(address)", denied));
        coverageFund.donate{value: _amount}();
        assertEq(_storedCoverageBalance(), balanceBefore, "denylisted revert must not mutate balance");
    }

    function testDonateZero(uint256 _senderSalt) external {
        address sender = uf._new(_senderSalt);

        vm.prank(admin);
        address[] memory accounts = new address[](1);
        accounts[0] = sender;
        uint256[] memory permissions = new uint256[](1);
        permissions[0] = LibAllowlistMasks.DONATE_MASK;
        allowlist.setAllowPermissions(accounts, permissions);

        vm.startPrank(sender);
        vm.expectRevert(abi.encodeWithSignature("EmptyDonation()"));
        coverageFund.donate{value: 0}();
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
        permissions[0] = LibAllowlistMasks.DONATE_MASK;
        allowlist.setAllowPermissions(accounts, permissions);

        vm.startPrank(sender);
        coverageFund.donate{value: _amount}();
        vm.stopPrank();

        vm.startPrank(sender);
        vm.expectRevert(abi.encodeWithSignature("Unauthorized(address)", sender));
        coverageFund.pullCoverageFunds(address(coverageFund).balance);
        vm.stopPrank();
    }

    function testFallbackFail() external {
        address sender = uf._new(1);
        vm.deal(sender, 1e18);

        vm.startPrank(sender);
        vm.expectRevert(abi.encodeWithSignature("InvalidCall()"));
        address(coverageFund).call{value: 1e18}(abi.encodeWithSignature("Hello()"));
        vm.stopPrank();
    }

    function testNoFundPulled() external {
        river.pullCoverageFunds(address(coverageFund), 0);
        assertEq(0, address(river).balance);
    }

    function testVersion() external {
        assertEq(coverageFund.version(), "1.3.0");
    }
}
