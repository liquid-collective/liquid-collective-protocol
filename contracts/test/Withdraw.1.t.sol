//SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.34;

import "forge-std/Test.sol";
import "./utils/UserFactory.sol";
import "./utils/LibImplementationUnbricker.sol";

import "../src/interfaces/IWithdraw.1.sol";
import "../src/Withdraw.1.sol";
import "../src/OperatorsRegistry.1.sol";

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

/// @notice Mock that reverts on receive (for UnsentExcessFee tests)
contract MockBeneficiaryContract {
    receive() external payable {
        revert();
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

/// @notice Mock consolidation that reverts on call with value (for RequestFailed tests)
contract MockELConsolidationFails {
    uint256 public fee = 1 gwei;

    function setFee(uint256 _fee) external {
        fee = _fee;
    }

    fallback(bytes calldata) external payable returns (bytes memory) {
        if (msg.value > 0) revert("mock fail");
        return abi.encode(fee);
    }
}

/// @notice Mock consolidation that reverts on fee read (staticcall)
contract MockELConsolidationFeeReadFails {
    fallback(bytes calldata) external payable returns (bytes memory) {
        revert();
    }
}

/// @notice Mock withdrawal that reverts on fee read (staticcall)
contract MockELWithdrawalFeeReadFails {
    fallback(bytes calldata) external payable returns (bytes memory) {
        revert();
    }
}

abstract contract WithdrawV1TestBase is Test {
    WithdrawV1 internal withdraw;
    RiverMock internal river;
    UserFactory internal uf = new UserFactory();
    OperatorsRegistryV1 internal operatorsRegistry;

    event DebugReceivedCLFunds(uint256 amount);

    function setUp() public virtual {
        river = new RiverMock();
        operatorsRegistry = new OperatorsRegistryV1();
        LibImplementationUnbricker.unbrick(vm, address(operatorsRegistry));
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
                uint256(uint160(address(withdraw))) + 0x0200000000000000000000000000000000000000000000000000000000000000
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
    bytes internal constant VALID_PUBKEY_48 =
        hex"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef";

    // Events for expectEmit (must match IWithdrawV1)
    event ConsolidationRequested(bytes srcPubkey, bytes targetPubkey, uint256 fee);
    event WithdrawalRequested(bytes pubkey, uint64 amount, uint256 fee);
    event UnsentExcessFee(address recipient, uint256 amount);

    function setUp() public override {
        super.setUp();
        withdraw.initializeWithdrawV1(address(river));
        mockWithdrawal = new MockELWithdrawal();
        mockConsolidation = new MockELConsolidation();
        excessFeeRecipient = makeAddr("excessFeeRecipient");
        withdraw.initWithdrawV1_1(address(mockWithdrawal), address(mockConsolidation), address(operatorsRegistry));
    }

    function testInitWithdrawV1_1SetsAddresses() external {
        WithdrawV1 w = new WithdrawV1();
        LibImplementationUnbricker.unbrick(vm, address(w));
        w.initializeWithdrawV1(address(river));
        assertEq(w.getRiver(), address(river));

        w.initWithdrawV1_1(address(mockWithdrawal), address(mockConsolidation), address(operatorsRegistry));
        // Unstructured storage slots match WithdrawalContractAddress, ConsolidationContractAddress,
        // OperatorsRegistryAddress (see ../src/state/shared/*.sol)
        assertEq(
            vm.load(address(w), bytes32(uint256(keccak256("withdraw.state.withdrawalContractAddress")) - 1)),
            bytes32(uint256(uint160(address(mockWithdrawal))))
        );
        assertEq(
            vm.load(address(w), bytes32(uint256(keccak256("withdraw.state.consolidationContractAddress")) - 1)),
            bytes32(uint256(uint160(address(mockConsolidation))))
        );
        assertEq(
            vm.load(address(w), bytes32(uint256(keccak256("river.state.operatorsRegistryAddress")) - 1)),
            bytes32(uint256(uint160(address(operatorsRegistry))))
        );
    }

    function testReinitWithdrawV1_1Reverts() external {
        vm.expectRevert(abi.encodeWithSignature("InvalidInitialization(uint256,uint256)", 1, 2));
        withdraw.initWithdrawV1_1(address(mockWithdrawal), address(mockConsolidation), address(operatorsRegistry));
    }

    function testWithdrawOnlyCallableByOperatorsRegistry() external {
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

    function testWithdrawRevertsIfCalledByRiver() external {
        bytes[] memory pubkeys = new bytes[](1);
        pubkeys[0] = VALID_PUBKEY_48;
        uint64[] memory amounts = new uint64[](1);
        amounts[0] = 1 gwei;
        vm.deal(address(river), 10 gwei);
        vm.prank(address(river));
        vm.expectRevert(abi.encodeWithSignature("Unauthorized(address)", address(river)));
        withdraw.withdraw{value: 1 gwei}(pubkeys, amounts, 1 gwei, excessFeeRecipient);
    }

    function testConsolidateOnlyCallableByRiver() external {
        bytes[] memory srcPubkeys = new bytes[](1);
        srcPubkeys[0] = VALID_PUBKEY_48;
        IWithdrawV1.ConsolidationRequest[] memory requests = new IWithdrawV1.ConsolidationRequest[](1);
        requests[0] = IWithdrawV1.ConsolidationRequest({srcPubkeys: srcPubkeys, targetPubkey: VALID_PUBKEY_48});
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
        vm.deal(address(operatorsRegistry), 2 gwei);
        vm.prank(address(operatorsRegistry));
        vm.expectRevert(abi.encodeWithSelector(IWithdrawV1.LengthMismatch.selector, uint256(2), uint256(1)));
        withdraw.withdraw{value: 2 gwei}(pubkeys, amounts, 1 gwei, excessFeeRecipient);
    }

    function testWithdrawInsufficientValueReverts() external {
        bytes[] memory pubkeys = new bytes[](1);
        pubkeys[0] = VALID_PUBKEY_48;
        uint64[] memory amounts = new uint64[](1);
        amounts[0] = 1 gwei;
        vm.prank(address(operatorsRegistry));
        vm.expectRevert(abi.encodeWithSignature("InsufficientValueForFee(uint256,uint256)", 0, 1 gwei));
        withdraw.withdraw{value: 0}(pubkeys, amounts, 1 gwei, excessFeeRecipient);
    }

    function testWithdrawFeeTooHighReverts() external {
        mockWithdrawal.setFee(2 gwei);
        bytes[] memory pubkeys = new bytes[](1);
        pubkeys[0] = VALID_PUBKEY_48;
        uint64[] memory amounts = new uint64[](1);
        amounts[0] = 1 gwei;
        vm.deal(address(operatorsRegistry), 2 gwei);
        vm.prank(address(operatorsRegistry));
        vm.expectRevert(abi.encodeWithSelector(IWithdrawV1.FeeTooHigh.selector, uint256(2 gwei), uint256(1 gwei)));
        withdraw.withdraw{value: 2 gwei}(pubkeys, amounts, 1 gwei, excessFeeRecipient);
    }

    function testWithdrawInvalidPubkeyLengthReverts() external {
        bytes[] memory pubkeys = new bytes[](1);
        pubkeys[0] = hex"ab"; // 1 byte
        uint64[] memory amounts = new uint64[](1);
        amounts[0] = 1 gwei;
        vm.deal(address(operatorsRegistry), 1 gwei);
        vm.prank(address(operatorsRegistry));
        vm.expectRevert(abi.encodeWithSelector(IWithdrawV1.InvalidPubkeyLength.selector, uint256(1)));
        withdraw.withdraw{value: 1 gwei}(pubkeys, amounts, 1 gwei, excessFeeRecipient);
    }

    function testWithdrawSuccessAndRefund() external {
        bytes[] memory pubkeys = new bytes[](1);
        pubkeys[0] = VALID_PUBKEY_48;
        uint64[] memory amounts = new uint64[](1);
        amounts[0] = 1 gwei;
        uint256 valueSent = 5 gwei;
        vm.deal(address(operatorsRegistry), valueSent);
        vm.prank(address(operatorsRegistry));
        withdraw.withdraw{value: valueSent}(pubkeys, amounts, 1 gwei, excessFeeRecipient);

        assertEq(address(mockWithdrawal).balance, 1 gwei);
        assertEq(excessFeeRecipient.balance, valueSent - 1 gwei);
    }

    function testConsolidateSuccessAndRefund() external {
        bytes[] memory srcPubkeys = new bytes[](1);
        srcPubkeys[0] = VALID_PUBKEY_48;
        IWithdrawV1.ConsolidationRequest[] memory requests = new IWithdrawV1.ConsolidationRequest[](1);
        requests[0] = IWithdrawV1.ConsolidationRequest({srcPubkeys: srcPubkeys, targetPubkey: VALID_PUBKEY_48});
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
        w.initWithdrawV1_1(address(mockFail), address(mockConsolidation), address(operatorsRegistry));

        bytes[] memory pubkeys = new bytes[](1);
        pubkeys[0] = VALID_PUBKEY_48;
        uint64[] memory amounts = new uint64[](1);
        amounts[0] = 1 gwei;
        vm.deal(address(operatorsRegistry), 1 gwei);
        vm.prank(address(operatorsRegistry));
        vm.expectRevert(abi.encodeWithSignature("RequestFailed()"));
        w.withdraw{value: 1 gwei}(pubkeys, amounts, 1 gwei, excessFeeRecipient);
    }

    // --- Consolidation tests (from plan) ---

    /// @notice Tests that consolidate reverts when fee read (staticcall) fails.
    function testConsolidateFailsIfNoValueSent() public {
        MockELConsolidationFeeReadFails mockConsolidationFeeReadFails = new MockELConsolidationFeeReadFails();
        WithdrawV1 w = new WithdrawV1();
        LibImplementationUnbricker.unbrick(vm, address(w));
        w.initializeWithdrawV1(address(river));
        w.initWithdrawV1_1(address(mockWithdrawal), address(mockConsolidationFeeReadFails), address(operatorsRegistry));

        bytes[] memory srcPubkeys = new bytes[](1);
        srcPubkeys[0] = VALID_PUBKEY_48;
        bytes memory targetPubkey = VALID_PUBKEY_48;
        IWithdrawV1.ConsolidationRequest[] memory requests = new IWithdrawV1.ConsolidationRequest[](1);
        requests[0] = IWithdrawV1.ConsolidationRequest(srcPubkeys, targetPubkey);

        vm.prank(address(river));
        vm.expectRevert(abi.encodeWithSelector(IWithdrawV1.FeeReadFailed.selector));
        w.consolidate(requests, 0.1 ether, excessFeeRecipient);
    }

    /// @notice Tests that consolidate refunds the sender (river) any excess funds after actual fee deduction.
    function testConsolidateRefundsSenderAnyExcessFund() public {
        bytes[] memory srcPubkeys = new bytes[](1);
        srcPubkeys[0] = VALID_PUBKEY_48;
        bytes memory targetPubkey = VALID_PUBKEY_48;
        IWithdrawV1.ConsolidationRequest[] memory requests = new IWithdrawV1.ConsolidationRequest[](1);
        requests[0] = IWithdrawV1.ConsolidationRequest(srcPubkeys, targetPubkey);

        uint256 maxFeePerConsolidation = 1.5 ether;
        uint256 fee = maxFeePerConsolidation - 1;
        mockConsolidation.setFee(fee);
        vm.deal(address(river), maxFeePerConsolidation);

        uint256 recipientBalBefore = excessFeeRecipient.balance;
        vm.prank(address(river));
        withdraw.consolidate{value: maxFeePerConsolidation}(requests, maxFeePerConsolidation, excessFeeRecipient);
        uint256 recipientBalAfter = excessFeeRecipient.balance;
        assertEq(
            recipientBalAfter,
            recipientBalBefore + (maxFeePerConsolidation - fee),
            "Recipient should be refunded any excess funds after actual fee deduction."
        );
    }

    /// @notice Tests that consolidate emits UnsentExcessFee when excess refund fails.
    function testConsolidateEmitsEventWhenExcessRefundsFail() public {
        bytes[] memory srcPubkeys = new bytes[](1);
        srcPubkeys[0] = VALID_PUBKEY_48;
        bytes memory targetPubkey = VALID_PUBKEY_48;
        IWithdrawV1.ConsolidationRequest[] memory requests = new IWithdrawV1.ConsolidationRequest[](1);
        requests[0] = IWithdrawV1.ConsolidationRequest(srcPubkeys, targetPubkey);

        uint256 maxFeePerConsolidation = 1.5 ether;
        uint256 fee = maxFeePerConsolidation - 1;
        mockConsolidation.setFee(fee);
        vm.deal(address(river), maxFeePerConsolidation);

        address excessFeeRecipientAddr = address(new MockBeneficiaryContract());
        uint256 totalValueReceived = maxFeePerConsolidation;
        uint256 excessFee = totalValueReceived - fee;

        vm.expectEmit(true, true, true, true);
        emit UnsentExcessFee(excessFeeRecipientAddr, excessFee);

        vm.prank(address(river));
        withdraw.consolidate{value: maxFeePerConsolidation}(requests, maxFeePerConsolidation, excessFeeRecipientAddr);
    }

    /// @notice Tests that consolidate reverts when the fee exceeds the max fee.
    function testConsolidateFailsIfFeeExceedsMax() public {
        bytes[] memory srcPubkeys = new bytes[](1);
        srcPubkeys[0] = VALID_PUBKEY_48;
        bytes memory targetPubkey = VALID_PUBKEY_48;
        IWithdrawV1.ConsolidationRequest[] memory requests = new IWithdrawV1.ConsolidationRequest[](1);
        requests[0] = IWithdrawV1.ConsolidationRequest(srcPubkeys, targetPubkey);

        uint256 maxFeePerConsolidation = 0.1 ether;
        uint256 fee = maxFeePerConsolidation + 1;
        mockConsolidation.setFee(fee);
        vm.deal(address(river), fee);

        vm.prank(address(river));
        vm.expectRevert(abi.encodeWithSelector(IWithdrawV1.FeeTooHigh.selector, fee, maxFeePerConsolidation));
        withdraw.consolidate{value: fee}(requests, maxFeePerConsolidation, excessFeeRecipient);
    }

    /// @notice Tests that consolidate reverts when the fee exceeds the value sent (msg.value).
    function testConsolidateFailsIfFeeExceedsValue() public {
        bytes[] memory srcPubkeys = new bytes[](1);
        srcPubkeys[0] = VALID_PUBKEY_48;
        bytes memory targetPubkey = VALID_PUBKEY_48;
        IWithdrawV1.ConsolidationRequest[] memory requests = new IWithdrawV1.ConsolidationRequest[](1);
        requests[0] = IWithdrawV1.ConsolidationRequest(srcPubkeys, targetPubkey);

        uint256 maxFeePerConsolidation = 0.1 ether;
        mockConsolidation.setFee(maxFeePerConsolidation);
        vm.deal(address(river), maxFeePerConsolidation);
        vm.deal(address(withdraw), 10 ether);

        uint256 value = maxFeePerConsolidation - 1;
        vm.prank(address(river));
        vm.expectRevert(
            abi.encodeWithSelector(IWithdrawV1.InsufficientValueForFee.selector, value, maxFeePerConsolidation)
        );
        withdraw.consolidate{value: value}(requests, maxFeePerConsolidation, excessFeeRecipient);
    }

    /// @notice Tests that consolidate reverts when value is insufficient for multiple consolidations.
    function testConsolidateFailsIfFeeExceedsValueForMultipleConsolidations() public {
        bytes[] memory srcPubkeys = new bytes[](4);
        for (uint256 i = 0; i < 4; i++) {
            srcPubkeys[i] = VALID_PUBKEY_48;
        }
        bytes memory targetPubkey = VALID_PUBKEY_48;
        bytes[] memory srcPubkeys2 = new bytes[](4);
        for (uint256 i = 0; i < 4; i++) {
            srcPubkeys2[i] = VALID_PUBKEY_48;
        }
        bytes memory targetPubkey2 = VALID_PUBKEY_48;

        IWithdrawV1.ConsolidationRequest[] memory requests = new IWithdrawV1.ConsolidationRequest[](2);
        requests[0] = IWithdrawV1.ConsolidationRequest(srcPubkeys, targetPubkey);
        requests[1] = IWithdrawV1.ConsolidationRequest(srcPubkeys2, targetPubkey2);

        uint256 maxFeePerConsolidation = 0.1 ether;
        mockConsolidation.setFee(maxFeePerConsolidation);
        vm.deal(address(river), 1 ether);
        vm.deal(address(withdraw), 10 ether);

        uint256 totalNumOfConsolidationOperations = 8;
        uint256 totalFeeRequired = maxFeePerConsolidation * totalNumOfConsolidationOperations;
        uint256 value = totalFeeRequired - 1;

        vm.prank(address(river));
        vm.expectRevert(abi.encodeWithSelector(IWithdrawV1.InsufficientValueForFee.selector, value, totalFeeRequired));
        withdraw.consolidate{value: value}(requests, maxFeePerConsolidation, excessFeeRecipient);
    }

    /// @notice Tests that consolidate reverts when the request (call to EL contract) fails.
    function testConsolidateFailsIfRequestFails() public {
        MockELConsolidationFails mockConsolidationFails = new MockELConsolidationFails();
        uint256 maxFeePerConsolidation = 0.1 ether;
        mockConsolidationFails.setFee(maxFeePerConsolidation);

        WithdrawV1 w = new WithdrawV1();
        LibImplementationUnbricker.unbrick(vm, address(w));
        w.initializeWithdrawV1(address(river));
        w.initWithdrawV1_1(address(mockWithdrawal), address(mockConsolidationFails), address(operatorsRegistry));

        bytes[] memory srcPubkeys = new bytes[](1);
        srcPubkeys[0] = VALID_PUBKEY_48;
        bytes memory targetPubkey = VALID_PUBKEY_48;
        IWithdrawV1.ConsolidationRequest[] memory requests = new IWithdrawV1.ConsolidationRequest[](1);
        requests[0] = IWithdrawV1.ConsolidationRequest(srcPubkeys, targetPubkey);

        vm.deal(address(river), maxFeePerConsolidation);
        vm.prank(address(river));
        vm.expectRevert(abi.encodeWithSignature("RequestFailed()"));
        w.consolidate{value: maxFeePerConsolidation}(requests, maxFeePerConsolidation, excessFeeRecipient);
    }

    /// @notice Tests that consolidate works when all checks pass.
    function testConsolidateWorksIfAllIsFine() public {
        bytes[] memory srcPubkeys = new bytes[](1);
        srcPubkeys[0] = VALID_PUBKEY_48;
        bytes memory targetPubkey = VALID_PUBKEY_48;
        IWithdrawV1.ConsolidationRequest[] memory requests = new IWithdrawV1.ConsolidationRequest[](1);
        requests[0] = IWithdrawV1.ConsolidationRequest(srcPubkeys, targetPubkey);

        uint256 maxFeePerConsolidation = 0.1 ether;
        mockConsolidation.setFee(maxFeePerConsolidation);
        vm.deal(address(river), maxFeePerConsolidation);

        bytes memory callData = bytes.concat(srcPubkeys[0], targetPubkey);

        vm.expectCall(address(mockConsolidation), maxFeePerConsolidation, callData);
        vm.expectEmit(true, true, true, true);
        emit ConsolidationRequested(srcPubkeys[0], targetPubkey, maxFeePerConsolidation);

        vm.prank(address(river));
        withdraw.consolidate{value: maxFeePerConsolidation}(requests, maxFeePerConsolidation, excessFeeRecipient);
    }

    /// @notice Tests that consolidate emits events for multiple consolidations.
    function testConsolidateEmitsEventsForMultipleConsolidations() public {
        bytes[] memory srcPubkeys1 = new bytes[](1);
        srcPubkeys1[0] = VALID_PUBKEY_48;
        bytes[] memory srcPubkeys2 = new bytes[](1);
        srcPubkeys2[0] = VALID_PUBKEY_48;
        bytes memory targetPubkey = VALID_PUBKEY_48;

        IWithdrawV1.ConsolidationRequest[] memory requests = new IWithdrawV1.ConsolidationRequest[](2);
        requests[0] = IWithdrawV1.ConsolidationRequest(srcPubkeys1, targetPubkey);
        requests[1] = IWithdrawV1.ConsolidationRequest(srcPubkeys2, targetPubkey);

        uint256 maxFeePerConsolidation = 0.1 ether;
        mockConsolidation.setFee(maxFeePerConsolidation);
        vm.deal(address(river), maxFeePerConsolidation * 2);

        bytes memory callData1 = bytes.concat(srcPubkeys1[0], targetPubkey);
        bytes memory callData2 = bytes.concat(srcPubkeys2[0], targetPubkey);

        vm.expectCall(address(mockConsolidation), maxFeePerConsolidation, callData1);
        vm.expectCall(address(mockConsolidation), maxFeePerConsolidation, callData2);
        vm.expectEmit(true, true, true, true);
        emit ConsolidationRequested(srcPubkeys1[0], targetPubkey, maxFeePerConsolidation);
        vm.expectEmit(true, true, true, true);
        emit ConsolidationRequested(srcPubkeys2[0], targetPubkey, maxFeePerConsolidation);

        vm.prank(address(river));
        withdraw.consolidate{value: maxFeePerConsolidation * 2}(requests, maxFeePerConsolidation, excessFeeRecipient);
    }

    /// @notice Tests that consolidate reverts when the caller is not River.
    function testConsolidateFailsIfNotOwner() public {
        bytes[] memory srcPubkeys = new bytes[](1);
        srcPubkeys[0] = VALID_PUBKEY_48;
        bytes memory targetPubkey = VALID_PUBKEY_48;
        IWithdrawV1.ConsolidationRequest[] memory requests = new IWithdrawV1.ConsolidationRequest[](1);
        requests[0] = IWithdrawV1.ConsolidationRequest(srcPubkeys, targetPubkey);

        uint256 maxFeePerConsolidation = 0.1 ether;
        address nonOwner = makeAddr("nonOwner");
        vm.deal(nonOwner, maxFeePerConsolidation);

        vm.expectRevert(abi.encodeWithSignature("Unauthorized(address)", nonOwner));
        vm.prank(nonOwner);
        withdraw.consolidate{value: maxFeePerConsolidation}(requests, maxFeePerConsolidation, excessFeeRecipient);
    }

    /// @notice Tests that consolidate reverts when a source pubkey is not 48 bytes.
    function testConsolidateFailsIfSrcPubkeyLengthInvalid() public {
        bytes[] memory srcPubkeys = new bytes[](1);
        srcPubkeys[0] =
        hex"1234567890abcdef1234567890abcde67895645f1234567890abcdef1234567890abcdef1234567890abcdef123456"; // 47 bytes
        bytes memory targetPubkey = VALID_PUBKEY_48;
        IWithdrawV1.ConsolidationRequest[] memory requests = new IWithdrawV1.ConsolidationRequest[](1);
        requests[0] = IWithdrawV1.ConsolidationRequest(srcPubkeys, targetPubkey);

        uint256 maxFeePerConsolidation = 0.1 ether;
        vm.deal(address(river), maxFeePerConsolidation);

        vm.expectRevert(abi.encodeWithSelector(IWithdrawV1.InvalidPubkeyLength.selector, 47));
        vm.prank(address(river));
        withdraw.consolidate{value: maxFeePerConsolidation}(requests, maxFeePerConsolidation, excessFeeRecipient);
    }

    /// @notice Tests that consolidate reverts when the target pubkey is not 48 bytes.
    function testConsolidateFailsIfTargetPubkeyLengthInvalid() public {
        bytes[] memory srcPubkeys = new bytes[](1);
        srcPubkeys[0] = VALID_PUBKEY_48;
        bytes memory targetPubkey =
            hex"1234567890abcdef1234567890abcde67895645f1234567890abcdef1234567890abcdef1234567890abcdef123456"; // 47 bytes
        IWithdrawV1.ConsolidationRequest[] memory requests = new IWithdrawV1.ConsolidationRequest[](1);
        requests[0] = IWithdrawV1.ConsolidationRequest(srcPubkeys, targetPubkey);

        uint256 maxFeePerConsolidation = 0.1 ether;
        vm.deal(address(river), maxFeePerConsolidation);

        vm.expectRevert(abi.encodeWithSelector(IWithdrawV1.InvalidPubkeyLength.selector, 47));
        vm.prank(address(river));
        withdraw.consolidate{value: maxFeePerConsolidation}(requests, maxFeePerConsolidation, excessFeeRecipient);
    }

    // --- Withdraw tests (from plan) ---

    /// @notice Tests that withdraw reverts when the fee read fails.
    function testWithdrawFailsIfFeeReadFails() public {
        MockELWithdrawalFeeReadFails mockWithdrawalFeeReadFails = new MockELWithdrawalFeeReadFails();
        WithdrawV1 w = new WithdrawV1();
        LibImplementationUnbricker.unbrick(vm, address(w));
        w.initializeWithdrawV1(address(river));
        w.initWithdrawV1_1(address(mockWithdrawalFeeReadFails), address(mockConsolidation), address(operatorsRegistry));

        bytes[] memory pubkeys = new bytes[](1);
        pubkeys[0] = VALID_PUBKEY_48;
        uint64[] memory amounts = new uint64[](1);
        amounts[0] = 1 ether;

        uint256 maxFeePerWithdrawal = 0.1 ether;
        vm.deal(address(operatorsRegistry), maxFeePerWithdrawal);

        vm.prank(address(operatorsRegistry));
        vm.expectRevert(abi.encodeWithSelector(IWithdrawV1.FeeReadFailed.selector));
        w.withdraw{value: maxFeePerWithdrawal}(pubkeys, amounts, maxFeePerWithdrawal, excessFeeRecipient);
    }

    /// @notice Tests that withdraw reverts when the fee exceeds the max fee.
    function testWithdrawFailsIfFeeExceedsMax() public {
        bytes[] memory pubkeys = new bytes[](1);
        pubkeys[0] = VALID_PUBKEY_48;
        uint64[] memory amounts = new uint64[](1);
        amounts[0] = 1 ether;

        uint256 maxFeePerWithdrawal = 0.1 ether;
        uint256 fee = maxFeePerWithdrawal + 1;
        mockWithdrawal.setFee(fee);
        vm.deal(address(operatorsRegistry), maxFeePerWithdrawal);

        vm.prank(address(operatorsRegistry));
        vm.expectRevert(abi.encodeWithSelector(IWithdrawV1.FeeTooHigh.selector, fee, maxFeePerWithdrawal));
        withdraw.withdraw{value: maxFeePerWithdrawal}(pubkeys, amounts, maxFeePerWithdrawal, excessFeeRecipient);
    }

    /// @notice Tests that withdraw reverts when the request fails.
    function testWithdrawFailsIfRequestFails() public {
        MockELWithdrawalFails mockWithdrawalFails = new MockELWithdrawalFails();
        WithdrawV1 w = new WithdrawV1();
        LibImplementationUnbricker.unbrick(vm, address(w));
        w.initializeWithdrawV1(address(river));
        w.initWithdrawV1_1(address(mockWithdrawalFails), address(mockConsolidation), address(operatorsRegistry));

        bytes[] memory pubkeys = new bytes[](1);
        pubkeys[0] = VALID_PUBKEY_48;
        uint64[] memory amounts = new uint64[](1);
        amounts[0] = 1 ether;

        uint256 maxFeePerWithdrawal = 0.1 ether;
        vm.deal(address(operatorsRegistry), maxFeePerWithdrawal);

        vm.prank(address(operatorsRegistry));
        vm.expectRevert(abi.encodeWithSignature("RequestFailed()"));
        w.withdraw{value: maxFeePerWithdrawal}(pubkeys, amounts, maxFeePerWithdrawal, excessFeeRecipient);
    }

    /// @notice Tests that withdraw refunds the sender (river) any excess funds after actual fee deduction.
    function testWithdrawRefundsSenderAnyExcessFund() public {
        bytes[] memory pubkeys = new bytes[](1);
        pubkeys[0] = VALID_PUBKEY_48;
        uint64[] memory amounts = new uint64[](1);
        amounts[0] = 1 ether;

        uint256 maxFeePerWithdrawal = 2 ether;
        uint256 fee = maxFeePerWithdrawal - 1 ether;
        mockWithdrawal.setFee(fee);
        vm.deal(address(operatorsRegistry), maxFeePerWithdrawal);

        uint256 recipientBalBefore = excessFeeRecipient.balance;
        vm.prank(address(operatorsRegistry));
        withdraw.withdraw{value: maxFeePerWithdrawal}(pubkeys, amounts, maxFeePerWithdrawal, excessFeeRecipient);
        uint256 recipientBalAfter = excessFeeRecipient.balance;
        assertEq(
            recipientBalAfter,
            recipientBalBefore + (maxFeePerWithdrawal - fee),
            "Recipient should be refunded any excess funds after actual fee deduction."
        );
    }

    /// @notice Tests that withdraw emits UnsentExcessFee when excess refund fails.
    function testWithdrawEmitsEventWhenExcessRefundsFail() public {
        bytes[] memory pubkeys = new bytes[](1);
        pubkeys[0] = VALID_PUBKEY_48;
        uint64[] memory amounts = new uint64[](1);
        amounts[0] = 1 ether;

        uint256 maxFeePerWithdrawal = 2 ether;
        uint256 fee = maxFeePerWithdrawal - 1 ether;
        mockWithdrawal.setFee(fee);
        vm.deal(address(operatorsRegistry), maxFeePerWithdrawal);

        address excessFeeRecipientAddr = address(new MockBeneficiaryContract());
        uint256 totalValueReceived = maxFeePerWithdrawal;
        uint256 excessFee = totalValueReceived - fee;

        vm.expectEmit(true, true, true, true);
        emit UnsentExcessFee(excessFeeRecipientAddr, excessFee);

        vm.prank(address(operatorsRegistry));
        withdraw.withdraw{value: maxFeePerWithdrawal}(pubkeys, amounts, maxFeePerWithdrawal, excessFeeRecipientAddr);
    }

    /// @notice Tests that withdraw works when all is fine.
    function testWithdrawWorksIfAllIsFine() public {
        bytes[] memory pubkeys = new bytes[](1);
        pubkeys[0] = VALID_PUBKEY_48;
        uint64[] memory amounts = new uint64[](1);
        amounts[0] = 1 ether;

        uint256 maxFeePerWithdrawal = 0.1 ether;
        mockWithdrawal.setFee(maxFeePerWithdrawal);
        vm.deal(address(operatorsRegistry), maxFeePerWithdrawal);

        bytes memory callData = abi.encodePacked(pubkeys[0], amounts[0]);

        vm.expectCall(address(mockWithdrawal), maxFeePerWithdrawal, callData);
        vm.expectEmit(true, true, true, true);
        emit WithdrawalRequested(pubkeys[0], amounts[0], maxFeePerWithdrawal);

        vm.prank(address(operatorsRegistry));
        withdraw.withdraw{value: maxFeePerWithdrawal}(pubkeys, amounts, maxFeePerWithdrawal, excessFeeRecipient);
    }

    /// @notice Tests that withdraw emits events for multiple withdrawals.
    function testWithdrawEmitsEventsForMultipleWithdrawals() public {
        bytes[] memory pubkeys = new bytes[](2);
        pubkeys[0] = VALID_PUBKEY_48;
        pubkeys[1] = VALID_PUBKEY_48;
        uint64[] memory amounts = new uint64[](2);
        amounts[0] = 1 ether;
        amounts[1] = 2 ether;

        uint256 maxFeePerWithdrawal = 0.1 ether;
        mockWithdrawal.setFee(maxFeePerWithdrawal);
        vm.deal(address(operatorsRegistry), maxFeePerWithdrawal * 2);

        bytes memory callData1 = abi.encodePacked(pubkeys[0], amounts[0]);
        bytes memory callData2 = abi.encodePacked(pubkeys[1], amounts[1]);

        vm.expectCall(address(mockWithdrawal), maxFeePerWithdrawal, callData1);
        vm.expectCall(address(mockWithdrawal), maxFeePerWithdrawal, callData2);
        vm.expectEmit(true, true, true, true);
        emit WithdrawalRequested(pubkeys[0], amounts[0], maxFeePerWithdrawal);
        vm.expectEmit(true, true, true, true);
        emit WithdrawalRequested(pubkeys[1], amounts[1], maxFeePerWithdrawal);

        vm.prank(address(operatorsRegistry));
        withdraw.withdraw{value: maxFeePerWithdrawal * 2}(pubkeys, amounts, maxFeePerWithdrawal, excessFeeRecipient);
    }

    /// @notice Tests that withdraw reverts when the caller is not River.
    function testWithdrawFailsIfNotOwner() public {
        bytes[] memory pubkeys = new bytes[](1);
        pubkeys[0] = VALID_PUBKEY_48;
        uint64[] memory amounts = new uint64[](1);
        amounts[0] = 1 ether;

        uint256 maxFeePerWithdrawal = 0.1 ether;
        address nonOwner = makeAddr("nonOwner");
        vm.deal(nonOwner, maxFeePerWithdrawal);

        vm.expectRevert(abi.encodeWithSignature("Unauthorized(address)", nonOwner));
        vm.prank(nonOwner);
        withdraw.withdraw{value: maxFeePerWithdrawal}(pubkeys, amounts, maxFeePerWithdrawal, excessFeeRecipient);
    }

    /// @notice Tests that withdraw reverts when a pubkey is not 48 bytes.
    function testWithdrawFailsIfPubkeyLengthInvalid() public {
        bytes[] memory pubkeys = new bytes[](1);
        pubkeys[0] = hex"1234567890abcdef1234567890abcde67895645f1234567890abcdef1234567890abcdef1234567890abcdef123456"; // 47 bytes
        uint64[] memory amounts = new uint64[](1);
        amounts[0] = 1 ether;

        uint256 maxFeePerWithdrawal = 0.1 ether;
        vm.deal(address(operatorsRegistry), maxFeePerWithdrawal);

        vm.expectRevert(abi.encodeWithSelector(IWithdrawV1.InvalidPubkeyLength.selector, 47));
        vm.prank(address(operatorsRegistry));
        withdraw.withdraw{value: maxFeePerWithdrawal}(pubkeys, amounts, maxFeePerWithdrawal, excessFeeRecipient);
    }

    /// @notice Tests that withdraw reverts when the fee exceeds the value sent.
    function testWithdrawFailsIfFeeExceedsValue() public {
        bytes[] memory pubkeys = new bytes[](1);
        pubkeys[0] = VALID_PUBKEY_48;
        uint64[] memory amounts = new uint64[](1);
        amounts[0] = 1 ether;

        uint256 maxFeePerWithdrawal = 0.1 ether;
        mockWithdrawal.setFee(maxFeePerWithdrawal);
        uint256 value = maxFeePerWithdrawal - 1;
        vm.deal(address(operatorsRegistry), maxFeePerWithdrawal);

        vm.expectRevert(
            abi.encodeWithSelector(IWithdrawV1.InsufficientValueForFee.selector, value, maxFeePerWithdrawal)
        );
        vm.prank(address(operatorsRegistry));
        withdraw.withdraw{value: value}(pubkeys, amounts, maxFeePerWithdrawal, excessFeeRecipient);
    }

    /// @notice Tests that withdraw reverts when pubkeys and amounts length mismatch.
    function testWithdrawFailsIfInputLengthMismatch() public {
        bytes[] memory pubkeys = new bytes[](1);
        pubkeys[0] = VALID_PUBKEY_48;
        uint64[] memory amounts = new uint64[](0);

        uint256 maxFeePerWithdrawal = 0.1 ether;
        vm.deal(address(operatorsRegistry), maxFeePerWithdrawal);

        vm.expectRevert(abi.encodeWithSelector(IWithdrawV1.LengthMismatch.selector, pubkeys.length, amounts.length));
        vm.prank(address(operatorsRegistry));
        withdraw.withdraw{value: maxFeePerWithdrawal}(pubkeys, amounts, maxFeePerWithdrawal, excessFeeRecipient);
    }

    /// @notice A ConsolidationRequest with empty srcPubkeys still validates targetPubkey length
    ///         and completes as a no-op (no EL calls, no fee spent, full refund).
    function testConsolidateWithEmptySrcPubkeys() public {
        IWithdrawV1.ConsolidationRequest[] memory requests = new IWithdrawV1.ConsolidationRequest[](1);
        requests[0] = IWithdrawV1.ConsolidationRequest({srcPubkeys: new bytes[](0), targetPubkey: VALID_PUBKEY_48});

        uint256 maxFeePerConsolidation = 1 gwei;
        uint256 valueSent = 5 gwei;
        vm.deal(address(river), valueSent);

        vm.prank(address(river));
        withdraw.consolidate{value: valueSent}(requests, maxFeePerConsolidation, excessFeeRecipient);

        assertEq(address(mockConsolidation).balance, 0, "no fee should be paid for empty srcPubkeys");
        assertEq(excessFeeRecipient.balance, valueSent, "full value should be refunded");
    }

    /// @notice A ConsolidationRequest with empty srcPubkeys but invalid targetPubkey length reverts.
    function testConsolidateWithEmptySrcPubkeysInvalidTargetReverts() public {
        bytes memory shortPubkey = hex"1234"; // 2 bytes, not 48
        IWithdrawV1.ConsolidationRequest[] memory requests = new IWithdrawV1.ConsolidationRequest[](1);
        requests[0] = IWithdrawV1.ConsolidationRequest({srcPubkeys: new bytes[](0), targetPubkey: shortPubkey});

        vm.deal(address(river), 1 gwei);
        vm.prank(address(river));
        vm.expectRevert(abi.encodeWithSelector(IWithdrawV1.InvalidPubkeyLength.selector, uint256(2)));
        withdraw.consolidate{value: 1 gwei}(requests, 1 gwei, excessFeeRecipient);
    }
}
