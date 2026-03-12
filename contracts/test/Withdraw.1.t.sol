//SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.34;

import "forge-std/Test.sol";
import "./utils/UserFactory.sol";
import "./utils/LibImplementationUnbricker.sol";

import "../src/interfaces/IWithdraw.1.sol";
import "../src/Withdraw.1.sol";

contract RiverMock {
    event DebugReceivedCLFunds(uint256 amount);

    function sendCLFunds() external payable {
        emit DebugReceivedCLFunds(msg.value);
    }

    function debug_pullFunds(address withdrawContract, uint256 amount) external {
        IWithdrawV1(payable(withdrawContract)).pullEth(amount);
    }

    function debug_withdraw(
        address withdrawContract,
        bytes[] calldata pubkeys,
        uint64[] calldata amount,
        uint256 maxFeePerWithdrawal,
        address excessFeeRecipient
    ) external payable {
        IWithdrawV1(payable(withdrawContract)).withdraw{value: msg.value}(
            pubkeys, amount, maxFeePerWithdrawal, excessFeeRecipient
        );
    }

    function debug_consolidate(
        address withdrawContract,
        IWithdrawV1.ConsolidationRequest[] calldata requests,
        uint256 maxFeePerConsolidation,
        address excessFeeRecipient
    ) external payable {
        IWithdrawV1(payable(withdrawContract)).consolidate{value: msg.value}(
            requests, maxFeePerConsolidation, excessFeeRecipient
        );
    }
}

/// @notice Mock Pectra EL withdrawal contract: staticcall returns fee; call accepts value and succeeds
contract MockELWithdrawal {
    uint256 public fee = 1 gwei;

    function setFee(uint256 _fee) external {
        fee = _fee;
    }

    fallback(bytes calldata) external payable returns (bytes memory) {
        return abi.encode(fee);
    }
}

/// @notice Mock Pectra EL consolidation contract: staticcall returns fee; call accepts value and succeeds
contract MockELConsolidation {
    uint256 public fee = 1 gwei;

    function setFee(uint256 _fee) external {
        fee = _fee;
    }

    fallback(bytes calldata) external payable returns (bytes memory) {
        return abi.encode(fee);
    }
}

/// @notice Mock that fails on call (for RequestFailed tests)
contract MockELWithdrawalFails {
    uint256 public fee = 1 gwei;

    fallback(bytes calldata) external payable returns (bytes memory) {
        if (msg.value > 0) revert("mock fail");
        return abi.encode(fee);
    }
}

abstract contract WithdrawV1TestBase is Test {
    WithdrawV1 internal withdraw;
    RiverMock internal river;
    UserFactory internal uf = new UserFactory();

    event DebugReceivedCLFunds(uint256 amount);

    function setUp() public virtual {
        river = new RiverMock();

        withdraw = new WithdrawV1();
        LibImplementationUnbricker.unbrick(vm, address(withdraw));
    }
}

contract WithdrawV1InitializationTests is WithdrawV1TestBase {
    function testInitialization() external {
        withdraw.initializeWithdrawV1(address(river));
        assertEq(address(river), withdraw.getRiver());
    }
}

contract WithdrawV1Tests is WithdrawV1TestBase {
    function setUp() public override {
        super.setUp();
        withdraw.initializeWithdrawV1(address(river));
    }

    function testReinitialize() external {
        vm.expectRevert(abi.encodeWithSignature("InvalidInitialization(uint256,uint256)", 0, 1));
        withdraw.initializeWithdrawV1(address(river));
    }

    function testGetCredentials() external {
        assertEq(
            withdraw.getCredentials(),
            bytes32(
                uint256(uint160(address(withdraw))) + 0x0100000000000000000000000000000000000000000000000000000000000000
            )
        );
    }

    function testGetRiver() external {
        assertEq(withdraw.getRiver(), address(river));
    }

    function testPullFundsAsRiverPullAll(uint256 _amount) external {
        vm.deal(address(withdraw), _amount);

        assertEq(address(withdraw).balance, _amount);
        assertEq(address(river).balance, 0);

        if (_amount > 0) {
            vm.expectEmit(true, true, true, true);
            emit DebugReceivedCLFunds(_amount);
        }
        river.debug_pullFunds(address(withdraw), _amount);

        assertEq(address(withdraw).balance, 0);
        assertEq(address(river).balance, _amount);
    }

    function testSendingFundsReverting(uint256 _amount) external {
        address sender = uf._new(_amount);
        vm.deal(sender, _amount);

        vm.startPrank(sender);

        assertEq(sender.balance, _amount);
        assertEq(address(withdraw).balance, 0);

        assertEq(payable(address(withdraw)).send(_amount), false);

        assertEq(sender.balance, _amount);
        assertEq(address(withdraw).balance, 0);

        vm.expectRevert();
        payable(address(withdraw)).transfer(_amount);

        assertEq(sender.balance, _amount);
        assertEq(address(withdraw).balance, 0);

        (bool success,) = payable(address(withdraw)).call{value: _amount}("");
        assertEq(success, false);

        assertEq(sender.balance, _amount);
        assertEq(address(withdraw).balance, 0);

        vm.stopPrank();
    }

    function testPullFundsAsRiverPullPartial(uint256 _salt, uint256 _amount) external {
        vm.assume(_amount > 0);
        vm.deal(address(withdraw), _amount);

        assertEq(address(withdraw).balance, _amount);
        assertEq(address(river).balance, 0);

        uint256 amountToPull = bound(_salt, 1, _amount);

        vm.expectEmit(true, true, true, true);
        emit DebugReceivedCLFunds(amountToPull);
        river.debug_pullFunds(address(withdraw), amountToPull);

        assertEq(address(withdraw).balance, _amount - amountToPull);
        assertEq(address(river).balance, amountToPull);
    }

    function testPullFundsAsRandom(uint256 _salt) external {
        address random = uf._new(_salt);

        vm.deal(address(withdraw), 1 ether);

        vm.prank(random);
        vm.expectRevert(abi.encodeWithSignature("Unauthorized(address)", random));
        withdraw.pullEth(1 ether);
    }

    function testPullFundsAsRiver() external {
        vm.deal(address(withdraw), 1 ether);
        river.debug_pullFunds(address(withdraw), 1 ether);

        assertEq(1 ether, address(river).balance);
    }

    function testPullFundsAmountTooHigh(uint256 _amount) external {
        _amount = bound(_amount, 1, type(uint128).max);

        vm.deal(address(withdraw), _amount);

        assertEq(address(withdraw).balance, uint256(_amount));
        assertEq(address(river).balance, 0);

        river.debug_pullFunds(address(withdraw), _amount * 2);

        assertEq(address(withdraw).balance, 0);
        assertEq(address(river).balance, _amount);
    }

    function testNoFundPulled() external {
        river.debug_pullFunds(address(withdraw), 0);
        assertEq(0, address(river).balance);
    }

    function testVersion() external {
        assertEq(withdraw.version(), "1.3.0");
    }
}

contract WithdrawV1PectraTests is WithdrawV1TestBase {
    MockELWithdrawal internal mockWithdrawal;
    MockELConsolidation internal mockConsolidation;
    address internal excessFeeRecipient;

    /// 48 bytes = 96 hex chars
    bytes internal constant VALID_PUBKEY_48 = hex"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef";

    function setUp() public override {
        super.setUp();
        withdraw.initializeWithdrawV1(address(river));
        mockWithdrawal = new MockELWithdrawal();
        mockConsolidation = new MockELConsolidation();
        excessFeeRecipient = makeAddr("excessFeeRecipient");
        withdraw.initWithdrawV1_1(address(mockWithdrawal), address(mockConsolidation));
    }

    function testInitWithdrawV1_1SetsAddresses() external {
        WithdrawV1 w = new WithdrawV1();
        LibImplementationUnbricker.unbrick(vm, address(w));
        w.initializeWithdrawV1(address(river));
        assertEq(w.getRiver(), address(river));

        w.initWithdrawV1_1(address(mockWithdrawal), address(mockConsolidation));
        // Addresses are in storage; we verify by calling withdraw which uses them
        bytes[] memory pubkeys = new bytes[](1);
        pubkeys[0] = VALID_PUBKEY_48;
        uint64[] memory amounts = new uint64[](1);
        amounts[0] = 1 gwei;
        vm.deal(address(river), 10 gwei);
        vm.prank(address(river));
        w.withdraw{value: 10 gwei}(pubkeys, amounts, 1 gwei, excessFeeRecipient);
    }

    function testReinitWithdrawV1_1Reverts() external {
        vm.expectRevert(abi.encodeWithSignature("InvalidInitialization(uint256,uint256)", 1, 2));
        withdraw.initWithdrawV1_1(address(mockWithdrawal), address(mockConsolidation));
    }

    function testWithdrawOnlyCallableByRiver() external {
        bytes[] memory pubkeys = new bytes[](1);
        pubkeys[0] = VALID_PUBKEY_48;
        uint64[] memory amounts = new uint64[](1);
        amounts[0] = 1 gwei;
        address random = makeAddr("random");
        vm.deal(random, 10 gwei);
        vm.prank(random);
        vm.expectRevert(abi.encodeWithSignature("Unauthorized(address)", random));
        withdraw.withdraw{value: 1 gwei}(pubkeys, amounts, 1 gwei, excessFeeRecipient);
    }

    function testConsolidateOnlyCallableByRiver() external {
        bytes[] memory srcPubkeys = new bytes[](1);
        srcPubkeys[0] = VALID_PUBKEY_48;
        IWithdrawV1.ConsolidationRequest[] memory requests = new IWithdrawV1.ConsolidationRequest[](1);
        requests[0] = IWithdrawV1.ConsolidationRequest({ srcPubkeys: srcPubkeys, targetPubkey: VALID_PUBKEY_48 });
        address random = makeAddr("random");
        vm.deal(random, 10 gwei);
        vm.prank(random);
        vm.expectRevert(abi.encodeWithSignature("Unauthorized(address)", random));
        withdraw.consolidate{value: 1 gwei}(requests, 1 gwei, excessFeeRecipient);
    }

    function testWithdrawLengthMismatchReverts() external {
        bytes[] memory pubkeys = new bytes[](2);
        pubkeys[0] = VALID_PUBKEY_48;
        pubkeys[1] = VALID_PUBKEY_48;
        uint64[] memory amounts = new uint64[](1);
        amounts[0] = 1 gwei;
        vm.deal(address(river), 2 gwei);
        vm.prank(address(river));
        vm.expectRevert(abi.encodeWithSelector(IWithdrawV1.LengthMismatch.selector, uint256(2), uint256(1)));
        withdraw.withdraw{value: 2 gwei}(pubkeys, amounts, 1 gwei, excessFeeRecipient);
    }

    function testWithdrawInsufficientValueReverts() external {
        bytes[] memory pubkeys = new bytes[](1);
        pubkeys[0] = VALID_PUBKEY_48;
        uint64[] memory amounts = new uint64[](1);
        amounts[0] = 1 gwei;
        vm.prank(address(river));
        vm.expectRevert(abi.encodeWithSignature("InsufficientValueForFee(uint256,uint256)", 0, 1 gwei));
        withdraw.withdraw{value: 0}(pubkeys, amounts, 1 gwei, excessFeeRecipient);
    }

    function testWithdrawFeeTooHighReverts() external {
        mockWithdrawal.setFee(2 gwei);
        bytes[] memory pubkeys = new bytes[](1);
        pubkeys[0] = VALID_PUBKEY_48;
        uint64[] memory amounts = new uint64[](1);
        amounts[0] = 1 gwei;
        vm.deal(address(river), 2 gwei);
        vm.prank(address(river));
        vm.expectRevert(abi.encodeWithSelector(IWithdrawV1.FeeTooHigh.selector, uint256(2 gwei), uint256(1 gwei)));
        withdraw.withdraw{value: 2 gwei}(pubkeys, amounts, 1 gwei, excessFeeRecipient);
    }

    function testWithdrawInvalidPubkeyLengthReverts() external {
        bytes[] memory pubkeys = new bytes[](1);
        pubkeys[0] = hex"ab"; // 1 byte
        uint64[] memory amounts = new uint64[](1);
        amounts[0] = 1 gwei;
        vm.deal(address(river), 1 gwei);
        vm.prank(address(river));
        vm.expectRevert(abi.encodeWithSelector(IWithdrawV1.InvalidPubkeyLength.selector, uint256(1)));
        withdraw.withdraw{value: 1 gwei}(pubkeys, amounts, 1 gwei, excessFeeRecipient);
    }

    function testWithdrawSuccessAndRefund() external {
        bytes[] memory pubkeys = new bytes[](1);
        pubkeys[0] = VALID_PUBKEY_48;
        uint64[] memory amounts = new uint64[](1);
        amounts[0] = 1 gwei;
        uint256 valueSent = 5 gwei;
        vm.deal(address(river), valueSent);
        vm.prank(address(river));
        withdraw.withdraw{value: valueSent}(pubkeys, amounts, 1 gwei, excessFeeRecipient);

        assertEq(address(mockWithdrawal).balance, 1 gwei);
        assertEq(excessFeeRecipient.balance, valueSent - 1 gwei);
    }

    function testConsolidateSuccessAndRefund() external {
        bytes[] memory srcPubkeys = new bytes[](1);
        srcPubkeys[0] = VALID_PUBKEY_48;
        IWithdrawV1.ConsolidationRequest[] memory requests = new IWithdrawV1.ConsolidationRequest[](1);
        requests[0] = IWithdrawV1.ConsolidationRequest({ srcPubkeys: srcPubkeys, targetPubkey: VALID_PUBKEY_48 });
        uint256 valueSent = 5 gwei;
        vm.deal(address(river), valueSent);
        vm.prank(address(river));
        withdraw.consolidate{value: valueSent}(requests, 1 gwei, excessFeeRecipient);

        assertEq(address(mockConsolidation).balance, 1 gwei);
        assertEq(excessFeeRecipient.balance, valueSent - 1 gwei);
    }

    function testWithdrawRequestFailedReverts() external {
        MockELWithdrawalFails mockFail = new MockELWithdrawalFails();
        WithdrawV1 w = new WithdrawV1();
        LibImplementationUnbricker.unbrick(vm, address(w));
        w.initializeWithdrawV1(address(river));
        w.initWithdrawV1_1(address(mockFail), address(mockConsolidation));

        bytes[] memory pubkeys = new bytes[](1);
        pubkeys[0] = VALID_PUBKEY_48;
        uint64[] memory amounts = new uint64[](1);
        amounts[0] = 1 gwei;
        vm.deal(address(river), 1 gwei);
        vm.prank(address(river));
        vm.expectRevert(abi.encodeWithSignature("RequestFailed()"));
        w.withdraw{value: 1 gwei}(pubkeys, amounts, 1 gwei, excessFeeRecipient);
    }
}
