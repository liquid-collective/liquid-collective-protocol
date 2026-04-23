// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "forge-std/Test.sol";

import "../utils/BytesGenerator.sol";
import "../utils/LibImplementationUnbricker.sol";
import "../mocks/DepositContractMock.sol";

import "../../src/River.1.sol";
import "../../src/Oracle.1.sol";
import "../../src/OperatorsRegistry.1.sol";
import "../../src/Allowlist.1.sol";
import "../../src/ELFeeRecipient.1.sol";
import "../../src/CoverageFund.1.sol";
import "../../src/RedeemManager.1.sol";
import "../../src/Withdraw.1.sol";

import "../../src/interfaces/IOperatorRegistry.1.sol";
import "../../src/interfaces/components/IOracleManager.1.sol";
import "../../src/libraries/LibAllowlistMasks.sol";
import "../../src/state/river/InFlightDeposit.sol";
import "../../src/state/river/CommittedBalance.sol";
import "../../src/state/river/BalanceToDeposit.sol";
import "../../src/state/operatorsRegistry/Operators.3.sol";

/// @dev Test-only OperatorsRegistry subclass exposing raw exited ETH initialization.
contract AccountingTestOperatorsRegistry is OperatorsRegistryV1 {
    function sudoSetRawExitedETH(uint256[] memory value) external {
        OperatorsV3.setRawExitedETH(value);
    }
}

/// @dev Test-only River subclass exposing InFlightDeposit and debug helpers.
contract AccountingRiverV1 is RiverV1 {
    function getInFlightDeposit() external view returns (uint256) {
        return InFlightDeposit.get();
    }

    function debug_moveDepositToCommitted() external {
        _setCommittedBalance(CommittedBalance.get() + BalanceToDeposit.get());
        _setBalanceToDeposit(0);
    }
}

abstract contract AccountingHarnessBase is Test, BytesGenerator {
    // ─── protocol constants ───────────────────────────────────────────────────
    uint64 internal constant EPOCHS_PER_FRAME = 225;
    uint64 internal constant SLOTS_PER_EPOCH = 32;
    uint64 internal constant SECONDS_PER_SLOT = 12;
    uint64 internal constant EPOCHS_UNTIL_FINAL = 4;
    uint256 internal constant DEPOSIT_SIZE = 32 ether;
    uint128 internal constant MAX_DAILY_NET = 3200 ether;
    uint128 internal constant MAX_DAILY_REL = 2000;

    // ─── contracts ────────────────────────────────────────────────────────────
    AccountingRiverV1 internal river;
    OracleV1 internal oracle;
    AccountingTestOperatorsRegistry internal operatorsRegistry;
    AllowlistV1 internal allowlist;
    ELFeeRecipientV1 internal elFeeRecipient;
    CoverageFundV1 internal coverageFund;
    RedeemManagerV1 internal redeemManager;
    WithdrawV1 internal withdraw;
    IDepositContract internal depositContract;

    // ─── actors ───────────────────────────────────────────────────────────────
    address internal admin;
    address internal allower;
    address internal keeper;
    address internal oracleMember;
    address internal operatorOneAddr;
    address internal operatorTwoAddr;

    uint256 internal operatorOneIndex;
    uint256 internal operatorTwoIndex;

    // ─── test helpers ─────────────────────────────────────────────────────────
    uint256 private _fundUserCounter;
    /// @dev Tracks total ETH deposited by users into the river (independent of contract storage).
    uint256 internal _simTotalUserDeposited;

    // ─── setUp ────────────────────────────────────────────────────────────────
    function setUp() public virtual {
        admin = makeAddr("admin");
        allower = makeAddr("allower");
        keeper = makeAddr("keeper");
        oracleMember = makeAddr("oracleMember");
        operatorOneAddr = makeAddr("operatorOne");
        operatorTwoAddr = makeAddr("operatorTwo");

        vm.warp(1_000_000);

        depositContract = new DepositContractMock();
        withdraw = new WithdrawV1();
        oracle = new OracleV1();
        allowlist = new AllowlistV1();
        redeemManager = new RedeemManagerV1();
        elFeeRecipient = new ELFeeRecipientV1();
        coverageFund = new CoverageFundV1();
        river = new AccountingRiverV1();
        operatorsRegistry = new AccountingTestOperatorsRegistry();

        LibImplementationUnbricker.unbrick(vm, address(withdraw));
        LibImplementationUnbricker.unbrick(vm, address(oracle));
        LibImplementationUnbricker.unbrick(vm, address(allowlist));
        LibImplementationUnbricker.unbrick(vm, address(redeemManager));
        LibImplementationUnbricker.unbrick(vm, address(elFeeRecipient));
        LibImplementationUnbricker.unbrick(vm, address(coverageFund));
        LibImplementationUnbricker.unbrick(vm, address(river));
        LibImplementationUnbricker.unbrick(vm, address(operatorsRegistry));

        allowlist.initAllowlistV1(admin, allower);
        allowlist.initAllowlistV1_1(makeAddr("denier"));

        operatorsRegistry.initOperatorsRegistryV1(admin, address(river));

        redeemManager.initializeRedeemManagerV1(address(river));

        river.initRiverV1(
            address(depositContract),
            address(elFeeRecipient),
            withdraw.getCredentials(),
            address(oracle),
            admin,
            address(allowlist),
            address(operatorsRegistry),
            makeAddr("collector"),
            500
        );
        river.initRiverV1_1(
            address(redeemManager),
            EPOCHS_PER_FRAME,
            SLOTS_PER_EPOCH,
            SECONDS_PER_SLOT,
            0,
            EPOCHS_UNTIL_FINAL,
            1000,
            500,
            MAX_DAILY_NET,
            MAX_DAILY_REL
        );
        river.initRiverV1_2();
        address[] memory _initAttesters = new address[](1);
        _initAttesters[0] = makeAddr("attester");
        vm.prank(admin);
        river.initRiverV1_3(makeAddr("depositBuffer"), _initAttesters, 1, bytes4(0));

        withdraw.initializeWithdrawV1(address(river));
        elFeeRecipient.initELFeeRecipientV1(address(river));
        coverageFund.initCoverageFundV1(address(river));

        oracle.initOracleV1(address(river), admin, EPOCHS_PER_FRAME, SLOTS_PER_EPOCH, SECONDS_PER_SLOT, 0, 1000, 500);

        vm.startPrank(admin);
        river.setCoverageFund(address(coverageFund));
        river.setKeeper(keeper);
        oracle.addMember(oracleMember, 1);
        operatorOneIndex = operatorsRegistry.addOperator("OperatorOne", operatorOneAddr);
        operatorTwoIndex = operatorsRegistry.addOperator("OperatorTwo", operatorTwoAddr);
        vm.stopPrank();

        // Initialize the exited ETH array to zeros (opCount + 1 elements: [total, op0, op1, ...]).
        // Required because _setExitedETH accesses currentExitedETH[idx] without a bounds check,
        // so the array must be pre-populated before the first oracle report.
        uint256 opCount = operatorsRegistry.getOperatorCount();
        operatorsRegistry.sudoSetRawExitedETH(new uint256[](opCount + 1));
    }

    // ─── helpers ──────────────────────────────────────────────────────────────

    function _fundRiver(uint256 ethAmount) internal {
        require(ethAmount > 0, "fundRiver: zero amount");
        _simTotalUserDeposited += ethAmount;
        address user = makeAddr(string(abi.encode("fundUser", _fundUserCounter++)));
        _allowUser(user);
        vm.deal(user, ethAmount);
        vm.prank(user);
        river.deposit{value: ethAmount}();
        river.debug_moveDepositToCommitted();
    }

    function _allowUser(address user) internal {
        address[] memory addrs = new address[](1);
        addrs[0] = user;
        uint256[] memory masks = new uint256[](1);
        masks[0] = LibAllowlistMasks.DEPOSIT_MASK | LibAllowlistMasks.REDEEM_MASK;
        vm.prank(allower);
        allowlist.setAllowPermissions(addrs, masks);
    }

    function _makeDeposits(uint256 opIdx, uint256[] memory amounts)
        internal
        returns (IOperatorsRegistryV1.ValidatorDeposit[] memory allocs)
    {
        allocs = new IOperatorsRegistryV1.ValidatorDeposit[](amounts.length);
        for (uint256 i = 0; i < amounts.length; i++) {
            allocs[i] = IOperatorsRegistryV1.ValidatorDeposit({
                operatorIndex: opIdx, pubkey: genBytes(48), signature: genBytes(96), depositAmount: amounts[i]
            });
        }
        return allocs;
    }

    /// @dev Convenience: create an array of `n` identical deposit amounts.
    function _amounts(uint256 n, uint256 amountEach) internal pure returns (uint256[] memory amounts) {
        amounts = new uint256[](n);
        for (uint256 i = 0; i < n; i++) {
            amounts[i] = amountEach;
        }
    }
}
