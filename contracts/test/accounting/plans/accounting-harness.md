# Accounting Test Harness Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a step-function `BeaconChainSimulator` harness in `contracts/test/accounting/` that emulates beacon chain state, drives the real protocol contracts through scenario tests, and asserts 6 ETH-accounting invariants after every state transition.

**Architecture:** Three-layer design — `AccountingHarnessBase` deploys the full protocol stack (including V1_3 migration), `BeaconChainSimulator` models beacon state and exposes named step functions, `AccountingInvariants` asserts invariants post-report. Concrete scenario contracts inherit all three and write linear test scripts.

**Tech Stack:** Solidity 0.8.34, Foundry (forge-std Test), existing protocol contracts: `RiverV1`, `OracleV1`, `OperatorsRegistryV1`, `RedeemManagerV1`, `AllowlistV1`, `ELFeeRecipientV1`, `CoverageFundV1`, `WithdrawV1`. Test utilities: `BytesGenerator`, `LibImplementationUnbricker`.

---

## Task 1: AccountingHarnessBase — protocol stack setup

**Files:**
- Create: `contracts/test/accounting/AccountingHarnessBase.sol`

This deploys every protocol contract, runs the complete init chain (including V1_3), registers two operators, and exposes common helpers.

**Step 1: Create the file**

```solidity
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

/// @dev Test-only River subclass that exposes InFlightDeposit and debug helpers.
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
    uint64 internal constant EPOCHS_PER_FRAME    = 225;
    uint64 internal constant SLOTS_PER_EPOCH     = 32;
    uint64 internal constant SECONDS_PER_SLOT    = 12;
    uint64 internal constant EPOCHS_UNTIL_FINAL  = 4;
    uint256 internal constant DEPOSIT_SIZE       = 32 ether;
    uint128 internal constant MAX_DAILY_NET      = 3200 ether;
    uint128 internal constant MAX_DAILY_REL      = 2000;

    // ─── contracts ────────────────────────────────────────────────────────────
    AccountingRiverV1             internal river;
    OracleV1                      internal oracle;
    OperatorsRegistryV1           internal operatorsRegistry;
    AllowlistV1                   internal allowlist;
    ELFeeRecipientV1              internal elFeeRecipient;
    CoverageFundV1                internal coverageFund;
    RedeemManagerV1               internal redeemManager;
    WithdrawV1                    internal withdraw;
    IDepositContract              internal depositContract;

    // ─── actors ───────────────────────────────────────────────────────────────
    address internal admin;
    address internal allower;
    address internal keeper;
    address internal oracleMember;
    address internal operatorOneAddr;
    address internal operatorTwoAddr;

    uint256 internal operatorOneIndex;
    uint256 internal operatorTwoIndex;

    // ─── setUp ────────────────────────────────────────────────────────────────
    function setUp() public virtual {
        admin          = makeAddr("admin");
        allower        = makeAddr("allower");
        keeper         = makeAddr("keeper");
        oracleMember   = makeAddr("oracleMember");
        operatorOneAddr = makeAddr("operatorOne");
        operatorTwoAddr = makeAddr("operatorTwo");

        vm.warp(1_000_000); // deterministic start time

        // Deploy contracts
        depositContract  = new DepositContractMock();
        withdraw         = new WithdrawV1();
        oracle           = new OracleV1();
        allowlist        = new AllowlistV1();
        redeemManager    = new RedeemManagerV1();
        elFeeRecipient   = new ELFeeRecipientV1();
        coverageFund     = new CoverageFundV1();
        river            = new AccountingRiverV1();
        operatorsRegistry = new OperatorsRegistryV1();

        // Unbrick upgradeable proxies
        LibImplementationUnbricker.unbrick(vm, address(withdraw));
        LibImplementationUnbricker.unbrick(vm, address(oracle));
        LibImplementationUnbricker.unbrick(vm, address(allowlist));
        LibImplementationUnbricker.unbrick(vm, address(redeemManager));
        LibImplementationUnbricker.unbrick(vm, address(elFeeRecipient));
        LibImplementationUnbricker.unbrick(vm, address(coverageFund));
        LibImplementationUnbricker.unbrick(vm, address(river));
        LibImplementationUnbricker.unbrick(vm, address(operatorsRegistry));

        // Initialize Allowlist
        allowlist.initAllowlistV1(admin, allower);
        allowlist.initAllowlistV1_1(makeAddr("denier"));

        // Initialize OperatorsRegistry (V1 only; V1_1 and V1_2 are migration no-ops on fresh state)
        operatorsRegistry.initOperatorsRegistryV1(admin, address(river));

        // Initialize RedeemManager
        redeemManager.initializeRedeemManagerV1(address(river));

        // Initialize River (full chain)
        river.initRiverV1(
            address(depositContract),
            address(elFeeRecipient),
            withdraw.getCredentials(),
            address(oracle),
            admin,
            address(allowlist),
            address(operatorsRegistry),
            makeAddr("collector"),
            500 // 5% global fee
        );
        river.initRiverV1_1(
            address(redeemManager),
            EPOCHS_PER_FRAME,
            SLOTS_PER_EPOCH,
            SECONDS_PER_SLOT,
            0, // genesisTime
            EPOCHS_UNTIL_FINAL,
            1000, // annualAprUpperBound (10%)
            500   // relativeLowerBound  (5%)
            , MAX_DAILY_NET,
            MAX_DAILY_REL
        );
        river.initRiverV1_2();
        river.initRiverV1_3();

        // Initialize Withdraw, ELFeeRecipient, CoverageFund
        withdraw.initializeWithdrawV1(address(river));
        elFeeRecipient.initELFeeRecipientV1(address(river));
        coverageFund.initCoverageFundV1(address(river));

        // Initialize Oracle
        oracle.initOracleV1(address(river), admin, EPOCHS_PER_FRAME, SLOTS_PER_EPOCH, SECONDS_PER_SLOT, 0, 1000, 500);

        // Admin setup
        vm.startPrank(admin);
        river.setCoverageFund(address(coverageFund));
        river.setKeeper(keeper);
        oracle.addMember(oracleMember, 1);
        operatorOneIndex = operatorsRegistry.addOperator("OperatorOne", operatorOneAddr);
        operatorTwoIndex = operatorsRegistry.addOperator("OperatorTwo", operatorTwoAddr);
        vm.stopPrank();
    }

    // ─── helpers ──────────────────────────────────────────────────────────────

    /// @dev Allowlist + deposit ETH into River for a user, then move to committed.
    function _fundRiver(uint256 ethAmount) internal {
        address user = makeAddr(string(abi.encode(ethAmount, block.timestamp)));
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

    /// @dev Build a ValidatorDeposit array for `n` deposits to `opIdx`.
    function _makeDeposits(uint256 opIdx, uint256 n)
        internal
        returns (IOperatorsRegistryV1.ValidatorDeposit[] memory allocs)
    {
        allocs = new IOperatorsRegistryV1.ValidatorDeposit[](n);
        for (uint256 i = 0; i < n; i++) {
            allocs[i] = IOperatorsRegistryV1.ValidatorDeposit({
                operatorIndex: opIdx,
                pubkey: genBytes(48),
                signature: genBytes(96),
                depositAmount: DEPOSIT_SIZE
            });
        }
    }
}
```

**Step 2: Verify it compiles**

```bash
cd contracts && forge build --match-path "test/accounting/AccountingHarnessBase.sol"
```
Expected: `Compiler run successful`

**Step 3: Commit**

```bash
git add contracts/test/accounting/AccountingHarnessBase.sol
git commit -m "test: add AccountingHarnessBase protocol stack setup"
```

---

## Task 2: BeaconChainSimulator — state model + step function shells

**Files:**
- Create: `contracts/test/accounting/BeaconChainSimulator.sol`

**Step 1: Create the file with state structs and UNIMPLEMENTED step function shells**

Each step function body should `revert("not implemented")` so that any test calling them fails clearly until Task 5.

```solidity
// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "./AccountingHarnessBase.sol";

abstract contract BeaconChainSimulator is AccountingHarnessBase {
    // ─── beacon state ─────────────────────────────────────────────────────────
    enum ValidatorState { Pending, Active, Exiting, Exited }

    struct SimValidator {
        uint256 operatorIndex;
        uint256 depositedETH;      // always 32 ether currently
        uint256 currentBalance;    // 32 ether + accrued rewards
        ValidatorState state;
        uint256 exitedETH;         // actual ETH returned: depositedETH minus slash penalty
    }

    SimValidator[] internal _simValidators;

    /// @dev Cumulative skimmed balance. Monotonically increasing. Reported as
    ///      validatorsSkimmedBalance in oracle reports.
    uint256 internal _simCumulativeSkimmed;

    /// @dev Cumulative exited ETH. Monotonically increasing. Reported as
    ///      validatorsExitedBalance in oracle reports.
    uint256 internal _simCumulativeExited;

    /// @dev Values as reported in the last oracle report (used to fund Withdraw).
    uint256 internal _lastReportedSkimmed;
    uint256 internal _lastReportedExited;

    /// @dev Epoch of the last oracle report.
    uint256 internal _lastReportEpoch;

    // ─── step functions ───────────────────────────────────────────────────────

    /// @notice Deposit `n` validators for operator `opIdx` to the beacon chain.
    /// Ensures River has enough committed balance, builds ValidatorDeposit[], calls the real
    /// depositToConsensusLayerWithDepositRoot, and records pending validators in sim state.
    function sim_deposit(uint256 opIdx, uint256 n) internal {
        revert("sim_deposit: not implemented");
    }

    /// @notice Transition `n` pending validators to Active.
    /// Increments `_simTotalDepositedActivatedETH` by `n * DEPOSIT_SIZE`. The increase
    /// is reported as `totalDepositedActivatedETH` in the next oracle report, causing
    /// `InFlightDeposit` to decrease by the same amount.
    function sim_activateValidators(uint256 n) internal {
        revert("sim_activateValidators: not implemented");
    }

    /// @notice Accrue `rewardsPerValidator` to each Active validator and advance
    /// the simulated epoch by 1. Rewards increase cumulativeSkimmed.
    function sim_advanceEpoch(uint256 rewardsPerValidator) internal {
        revert("sim_advanceEpoch: not implemented");
    }

    /// @notice Mark `ethAmount` worth of validators for `opIdx` as Exiting.
    /// `ethAmount` must be a multiple of DEPOSIT_SIZE.
    function sim_requestExit(uint256 opIdx, uint256 ethAmount) internal {
        revert("sim_requestExit: not implemented");
    }

    /// @notice Complete the exit of `ethAmount` worth of validators for `opIdx`.
    /// `penalty` is the slash penalty in wei (0 for clean exits).
    /// Funds the Withdraw contract with the exited ETH.
    function sim_completeExit(uint256 opIdx, uint256 ethAmount, uint256 penalty) internal {
        revert("sim_completeExit: not implemented");
    }

    /// @notice Apply a slash `penalty` to one Active validator of `opIdx`.
    function sim_slash(uint256 opIdx, uint256 penalty) internal {
        revert("sim_slash: not implemented");
    }

    /// @notice Build a ConsensusLayerReport from current sim state, submit it
    /// through the real Oracle, and then run all accounting invariants.
    function sim_oracleReport() internal {
        sim_oracleReport(false, false);
    }

    /// @notice Same as sim_oracleReport() but with explicit mode flags.
    function sim_oracleReport(bool rebalance, bool slashingContainment) internal {
        revert("sim_oracleReport: not implemented");
    }

    // ─── internal helpers (implemented in Task 5) ─────────────────────────────

    function _buildReport(bool rebalance, bool slashingContainment)
        internal
        view
        returns (IOracleManagerV1.ConsensusLayerReport memory report)
    {
        revert("_buildReport: not implemented");
    }

    function _pendingETH() internal view returns (uint256 total) {
        for (uint256 i = 0; i < _simValidators.length; i++) {
            if (_simValidators[i].state == ValidatorState.Pending) {
                total += _simValidators[i].depositedETH;
            }
        }
    }

    function _simActivatedCount() internal view returns (uint32 count) {
        for (uint256 i = 0; i < _simValidators.length; i++) {
            if (_simValidators[i].state != ValidatorState.Pending) {
                count++;
            }
        }
    }
}
```

**Step 2: Verify it compiles**

```bash
cd contracts && forge build --match-path "test/accounting/BeaconChainSimulator.sol"
```
Expected: `Compiler run successful`

**Step 3: Commit**

```bash
git add contracts/test/accounting/BeaconChainSimulator.sol
git commit -m "test: add BeaconChainSimulator state model and step function shells"
```

---

## Task 3: AccountingInvariants — invariant assertion mixin

**Files:**
- Create: `contracts/test/accounting/AccountingInvariants.sol`

**Step 1: Create the file**

```solidity
// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "./BeaconChainSimulator.sol";

/// @dev Mixin that snapshots pre-report state and asserts all 6 accounting
///      invariants after every sim_oracleReport call.
abstract contract AccountingInvariants is BeaconChainSimulator {
    uint256 private _snapTotalUnderlying;
    uint256 private _snapTotalShares;
    uint256 private _snapTotalDepositedETH;
    bool    private _allowSharePriceDecrease; // set true in slashing scenarios

    // ─── snapshot ─────────────────────────────────────────────────────────────

    function _snapshotPreReport() internal {
        // I3 (pre-report): InFlightDeposit must match sim's independently-tracked in-flight value.
        // Checked here (before the oracle report) because post-report it would be a tautology —
        // the oracle itself sets InFlightDeposit = pendingETH after confirming activated validators.
        assertEq(
            river.getInFlightDeposit(), _simInFlightDeposit,
            "I3 (pre-report): InFlightDeposit != sim in-flight deposit"
        );
        _snapTotalUnderlying   = river.totalUnderlyingSupply();
        _snapTotalShares       = river.totalSupply();
        _snapTotalDepositedETH = river.getTotalDepositedETH();
    }

    function _setAllowSharePriceDecrease(bool allow) internal {
        _allowSharePriceDecrease = allow;
    }

    // ─── top-level assert (called by sim_oracleReport after each report) ──────

    function _assertAllInvariants() internal {
        _assertI1_SharePriceNonDecrease();
        _assertI2_ETHConservation();
        _assertI3_InFlightConsistency();
        _assertI4_PerOperatorETH();
        _assertI5_TotalDepositedETHMonotonic();
        _assertI6_ExitedETHAggregate();
    }

    // ─── I1: share price non-decrease ─────────────────────────────────────────

    function _assertI1_SharePriceNonDecrease() internal view {
        if (_allowSharePriceDecrease) return;
        uint256 sharesTotalNow = river.totalSupply();
        if (sharesTotalNow == 0 || _snapTotalShares == 0) return;
        // price_before = snapUnderlying / snapShares
        // price_after  = underlying_now / shares_now
        // price_after >= price_before  iff
        //   underlying_now * snapShares >= snapUnderlying * shares_now
        uint256 lhs = river.totalUnderlyingSupply() * _snapTotalShares;
        uint256 rhs = _snapTotalUnderlying * sharesTotalNow;
        assertGe(lhs, rhs, "I1: share price decreased unexpectedly");
    }

    // ─── I2: ETH conservation (upper bound check against externally tracked values) ───

    function _assertI2_ETHConservation() internal {
        // Upper bound: underlying can never exceed total user deposits + cumulative skimmed rewards.
        // Both values are tracked independently of contract storage, making this non-tautological.
        uint256 upperBound = _simTotalUserDeposited + _simCumulativeSkimmed;
        assertLe(river.totalUnderlyingSupply(), upperBound, "I2: total underlying exceeds deposited + rewards");
        if (_simTotalUserDeposited > 0) {
            assertGt(river.totalUnderlyingSupply(), 0, "I2: total underlying is zero after deposits");
        }
    }

    // ─── I3: InFlightDeposit consistency (checked pre-report in _snapshotPreReport) ────

    function _assertI3_InFlightConsistency() internal pure {
        // The substantive I3 check is performed in _snapshotPreReport() before the oracle report,
        // where it is non-tautological. Post-report the oracle already decremented InFlightDeposit
        // by the totalDepositedActivatedETH increase, so checking here would be a tautology.
    }

    // ─── I4: per-operator funded and exited ETH matches sim ───────────────────

    function _assertI4_PerOperatorETH() internal view {
        uint256 opCount = operatorsRegistry.getOperatorCount();
        uint256[] memory exitedPerOp = operatorsRegistry.getExitedETHPerOperator();

        for (uint256 i = 0; i < opCount; i++) {
            OperatorsV3.Operator memory op = operatorsRegistry.getOperator(i);

            // compute sim totals for operator i
            uint256 simFunded = 0;
            uint256 simExited = 0;
            for (uint256 j = 0; j < _simValidators.length; j++) {
                if (_simValidators[j].operatorIndex == i) {
                    simFunded += _simValidators[j].depositedETH;
                    if (_simValidators[j].state == ValidatorState.Exited) {
                        simExited += _simValidators[j].exitedETH;
                    }
                }
            }

            assertEq(op.funded, simFunded,
                string(abi.encodePacked("I4: operator ", vm.toString(i), " funded mismatch")));
            assertLe(exitedPerOp.length > i ? exitedPerOp[i] : 0, op.funded,
                string(abi.encodePacked("I4: operator ", vm.toString(i), " exited > funded")));
            assertEq(exitedPerOp.length > i ? exitedPerOp[i] : 0, simExited,
                string(abi.encodePacked("I4: operator ", vm.toString(i), " exited mismatch")));
        }
    }

    // ─── I5: TotalDepositedETH is monotonically increasing ────────────────────

    function _assertI5_TotalDepositedETHMonotonic() internal view {
        assertGe(river.getTotalDepositedETH(), _snapTotalDepositedETH,
            "I5: TotalDepositedETH decreased");
    }

    // ─── I6: exitedETHPerOperator[0] == sum of [1..n] ─────────────────────────

    function _assertI6_ExitedETHAggregate() internal view {
        // getExitedETHPerOperator() strips the aggregate slot, so we call the raw
        // getExitedETHAndRequestedExitAmounts for the total.
        (uint256 totalExited,) = operatorsRegistry.getExitedETHAndRequestedExitAmounts();
        uint256[] memory perOp = operatorsRegistry.getExitedETHPerOperator();
        uint256 sum = 0;
        for (uint256 i = 0; i < perOp.length; i++) {
            sum += perOp[i];
        }
        assertEq(totalExited, sum, "I6: exitedETHPerOperator[0] != sum of individual slots");
    }
}
```

**Step 2: Verify it compiles**

```bash
cd contracts && forge build --match-path "test/accounting/AccountingInvariants.sol"
```
Expected: `Compiler run successful`

Note: This will fail if `OperatorsV3` is not imported. Add the import:
```solidity
import "../../src/state/operatorsRegistry/Operators.3.sol";
```

**Step 3: Commit**

```bash
git add contracts/test/accounting/AccountingInvariants.sol
git commit -m "test: add AccountingInvariants assertion mixin"
```

---

## Task 4: HappyPath.t.sol — write the first failing test

**Files:**
- Create: `contracts/test/accounting/scenarios/HappyPath.t.sol`

This is the first concrete test. It calls `sim_deposit` and `sim_oracleReport`, which both revert with "not implemented", so the test will fail until Task 5.

**Step 1: Create the file**

```solidity
// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../AccountingInvariants.sol";

contract HappyPathTest is AccountingInvariants {
    /// @dev Single operator deposits 3 validators, activates them, and submits an oracle report.
    function testDepositActivateReport() public {
        _fundRiver(3 * DEPOSIT_SIZE);

        sim_deposit(operatorOneIndex, 3);
        // validators are pending, InFlightDeposit = 96 ether
        assertEq(river.getInFlightDeposit(), 96 ether);

        sim_activateValidators(3);
        // still pending in storage until next report

        sim_oracleReport();
        // After report: inFlightDeposit reduced, invariants checked inside sim_oracleReport
        assertEq(river.getInFlightDeposit(), 0);
    }

    /// @dev Two operators, multiple epochs with reward accrual.
    function testMultiOperatorWithRewards() public {
        _fundRiver(10 * DEPOSIT_SIZE);

        sim_deposit(operatorOneIndex, 6);
        sim_deposit(operatorTwoIndex, 4);
        sim_activateValidators(10);

        sim_oracleReport();

        sim_advanceEpoch(0.01 ether); // 0.01 ETH reward per validator
        sim_oracleReport();

        sim_advanceEpoch(0.01 ether);
        sim_oracleReport();

        // After 2 epochs of rewards: 10 * 0.01 * 2 = 0.2 ETH skimmed
        // share price should have increased
        assertGt(river.totalUnderlyingSupply(), 10 * DEPOSIT_SIZE);
    }

    /// @dev Depositing in batches — inFlightDeposit grows and shrinks correctly.
    function testIncrementalDeposits() public {
        _fundRiver(5 * DEPOSIT_SIZE);

        sim_deposit(operatorOneIndex, 2);
        assertEq(river.getInFlightDeposit(), 64 ether, "after first batch");

        sim_deposit(operatorOneIndex, 3);
        assertEq(river.getInFlightDeposit(), 160 ether, "after second batch");

        sim_activateValidators(5);
        sim_oracleReport();
        assertEq(river.getInFlightDeposit(), 0, "after report");
    }
}
```

**Step 2: Run the test — expect failure**

```bash
cd contracts && forge test --match-path "test/accounting/scenarios/HappyPath.t.sol" -v
```
Expected: All tests FAIL with `"sim_deposit: not implemented"` (or similar revert).

**Step 3: Commit the failing tests**

```bash
git add contracts/test/accounting/scenarios/HappyPath.t.sol
git commit -m "test: add HappyPath accounting scenario tests (failing)"
```

---

## Task 5: Implement core step functions — sim_deposit, sim_activateValidators, sim_oracleReport

**Files:**
- Modify: `contracts/test/accounting/BeaconChainSimulator.sol`

Replace the `revert("not implemented")` bodies in `sim_deposit`, `sim_activateValidators`, `sim_oracleReport`, and `_buildReport`.

**Step 1: Replace sim_deposit**

```solidity
function sim_deposit(uint256 opIdx, uint256 n) internal {
    uint256 needed = n * DEPOSIT_SIZE;
    // ensure River has enough committed balance
    if (river.getCommittedBalance() < needed) {
        _fundRiver(needed - river.getCommittedBalance());
    }

    uint256 prevInFlight = river.getInFlightDeposit();
    IOperatorsRegistryV1.ValidatorDeposit[] memory allocs = _makeDeposits(opIdx, n);

    vm.prank(keeper);
    river.depositToConsensusLayerWithDepositRoot(allocs, bytes32(0));

    for (uint256 i = 0; i < n; i++) {
        _simValidators.push(SimValidator({
            operatorIndex: opIdx,
            depositedETH: DEPOSIT_SIZE,
            currentBalance: DEPOSIT_SIZE,
            state: ValidatorState.Pending,
            exitedETH: 0
        }));
    }

    assertEq(
        river.getInFlightDeposit(), prevInFlight + needed,
        "sim_deposit: InFlightDeposit did not increase"
    );
}
```

**Step 2: Replace sim_activateValidators**

```solidity
function sim_activateValidators(uint256 n) internal {
    uint256 activated = 0;
    for (uint256 i = 0; i < _simValidators.length && activated < n; i++) {
        if (_simValidators[i].state == ValidatorState.Pending) {
            _simValidators[i].state = ValidatorState.Active;
            activated++;
        }
    }
    assertEq(activated, n, "sim_activateValidators: not enough pending validators");
    _simTotalDepositedActivatedETH += n * DEPOSIT_SIZE;
}
```

**Step 3: Replace _buildReport**

```solidity
function _buildReport(bool rebalance, bool slashingContainment)
    internal
    view
    returns (IOracleManagerV1.ConsensusLayerReport memory report)
{
    uint256 validatorsBalance    = 0;
    uint256 validatorsExiting    = 0;
    uint32  activatedCount       = 0;

    uint256 opCount = operatorsRegistry.getOperatorCount();
    // exitedETHPerOperator format: [totalSum, op0, op1, ...]
    uint256[] memory exitedArr = new uint256[](opCount + 1);
    uint256 cumulativeExited   = 0;

    for (uint256 i = 0; i < _simValidators.length; i++) {
        SimValidator memory v = _simValidators[i];
        if (v.state == ValidatorState.Pending) {
            // pending validators tracked via _simInFlightDeposit; not included in report
        } else if (v.state == ValidatorState.Active) {
            validatorsBalance += v.currentBalance;
            activatedCount++;
        } else if (v.state == ValidatorState.Exiting) {
            validatorsBalance += v.currentBalance;
            validatorsExiting += v.currentBalance;
            activatedCount++;
        } else if (v.state == ValidatorState.Exited) {
            activatedCount++;
            exitedArr[v.operatorIndex + 1] += v.exitedETH;
            cumulativeExited += v.exitedETH;
        }
    }
    exitedArr[0] = cumulativeExited;

    report.validatorsBalance            = validatorsBalance;
    report.validatorsSkimmedBalance     = _simCumulativeSkimmed;
    report.validatorsExitedBalance      = _simCumulativeExited;
    report.validatorsExitingBalance     = validatorsExiting;
    report.totalDepositedActivatedETH   = _simTotalDepositedActivatedETH;
    report.validatorsCount              = activatedCount;
    report.exitedETHPerOperator         = exitedArr;
    report.rebalanceDepositToRedeemMode = rebalance;
    report.slashingContainmentMode      = slashingContainment;
}
```

**Step 4: Replace sim_oracleReport(bool, bool)**

```solidity
function sim_oracleReport(bool rebalance, bool slashingContainment) internal {
    // Determine the next valid report epoch
    uint256 reportEpoch = river.getExpectedEpochId();

    // Warp time past finality for this epoch
    uint256 targetTime = (SECONDS_PER_SLOT * SLOTS_PER_EPOCH) * (reportEpoch + EPOCHS_UNTIL_FINAL) + 1;
    if (block.timestamp < targetTime) {
        vm.warp(targetTime);
    }

    // Fund Withdraw contract with newly skimmed + newly exited ETH
    uint256 newSkimmed = _simCumulativeSkimmed - _lastReportedSkimmed;
    uint256 newExited  = _simCumulativeExited  - _lastReportedExited;
    if (newSkimmed + newExited > 0) {
        vm.deal(address(withdraw), address(withdraw).balance + newSkimmed + newExited);
    }

    IOracleManagerV1.ConsensusLayerReport memory report = _buildReport(rebalance, slashingContainment);
    report.epoch = reportEpoch;

    _snapshotPreReport();

    vm.prank(oracleMember);
    oracle.reportConsensusLayerData(report);

    // Update tracking
    _lastReportedSkimmed = _simCumulativeSkimmed;
    _lastReportedExited  = _simCumulativeExited;
    _lastReportEpoch     = reportEpoch;
    // Sync sim in-flight to what the oracle just confirmed: oracle sets InFlightDeposit = _pendingETH().
    _simInFlightDeposit = _pendingETH();

    _assertAllInvariants();
}
```

**Step 5: Run HappyPath tests — expect pass**

```bash
cd contracts && forge test --match-path "test/accounting/scenarios/HappyPath.t.sol" -v
```
Expected: All 3 tests PASS.

**Step 6: Commit**

```bash
git add contracts/test/accounting/BeaconChainSimulator.sol
git commit -m "test: implement sim_deposit, sim_activateValidators, sim_oracleReport"
```

---

## Task 6: Implement remaining step functions

**Files:**
- Modify: `contracts/test/accounting/BeaconChainSimulator.sol`

Replace the remaining `revert("not implemented")` bodies.

**Step 1: Replace sim_advanceEpoch**

```solidity
function sim_advanceEpoch(uint256 rewardsPerValidator) internal {
    for (uint256 i = 0; i < _simValidators.length; i++) {
        if (_simValidators[i].state == ValidatorState.Active) {
            _simValidators[i].currentBalance += rewardsPerValidator;
            _simCumulativeSkimmed += rewardsPerValidator;
        }
    }
}
```

**Step 2: Replace sim_requestExit**

```solidity
function sim_requestExit(uint256 opIdx, uint256 ethAmount) internal {
    require(ethAmount % DEPOSIT_SIZE == 0, "sim_requestExit: ethAmount must be multiple of 32 ether");
    uint256 remaining = ethAmount;
    for (uint256 i = 0; i < _simValidators.length && remaining > 0; i++) {
        SimValidator storage v = _simValidators[i];
        if (v.operatorIndex == opIdx && v.state == ValidatorState.Active) {
            v.state = ValidatorState.Exiting;
            remaining -= DEPOSIT_SIZE;
        }
    }
    assertEq(remaining, 0, "sim_requestExit: not enough active validators for opIdx");
}
```

**Step 3: Replace sim_completeExit**

```solidity
function sim_completeExit(uint256 opIdx, uint256 ethAmount, uint256 penalty) internal {
    require(ethAmount % DEPOSIT_SIZE == 0, "sim_completeExit: ethAmount must be multiple of DEPOSIT_SIZE");
    uint256 validatorsToExit = ethAmount / DEPOSIT_SIZE;
    uint256 exited = 0;
    for (uint256 i = 0; i < _simValidators.length && exited < validatorsToExit; i++) {
        SimValidator storage v = _simValidators[i];
        if (v.operatorIndex == opIdx && v.state == ValidatorState.Exiting) {
            // distribute penalty proportionally; for simplicity apply penalty to first validator
            uint256 thisPenalty = (exited == 0) ? penalty : 0;
            v.exitedETH = v.depositedETH - thisPenalty;
            v.currentBalance = 0;
            v.state = ValidatorState.Exited;
            _simCumulativeExited += v.exitedETH;
            exited++;
        }
    }
    assertEq(exited, validatorsToExit, "sim_completeExit: not enough exiting validators for opIdx");
    // Pre-fund Withdraw so it can pay out; the delta will be sent in sim_oracleReport
}
```

**Step 4: Replace sim_slash**

```solidity
function sim_slash(uint256 opIdx, uint256 penalty) internal {
    for (uint256 i = 0; i < _simValidators.length; i++) {
        SimValidator storage v = _simValidators[i];
        if (v.operatorIndex == opIdx && v.state == ValidatorState.Active) {
            require(penalty <= v.currentBalance, "sim_slash: penalty > balance");
            v.currentBalance -= penalty;
            return;
        }
    }
    revert("sim_slash: no active validator found for opIdx");
}
```

**Step 5: Run all current tests to confirm nothing is broken**

```bash
cd contracts && forge test --match-path "test/accounting/**" -v
```
Expected: All tests PASS.

**Step 6: Commit**

```bash
git add contracts/test/accounting/BeaconChainSimulator.sol
git commit -m "test: implement sim_advanceEpoch, sim_requestExit, sim_completeExit, sim_slash"
```

---

## Task 7: InFlightETH.t.sol — InFlightDeposit edge cases

**Files:**
- Create: `contracts/test/accounting/scenarios/InFlightETH.t.sol`

**Step 1: Create the file**

```solidity
// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../AccountingInvariants.sol";

contract InFlightETHTest is AccountingInvariants {
    /// @dev Oracle report before any activation: inFlightDeposit must be preserved.
    function testReportWithPendingValidators() public {
        _fundRiver(3 * DEPOSIT_SIZE);
        sim_deposit(operatorOneIndex, 3);

        // Do NOT call sim_activateValidators — all 3 are still Pending.
        sim_oracleReport();
        // After report: inFlightETH in report was 96 ether; stored correctly.
        assertEq(river.getInFlightDeposit(), 96 ether, "inFlightDeposit after report with pending");
    }

    /// @dev Partial activation: 2 activated, 1 still pending after report.
    function testPartialActivation() public {
        _fundRiver(3 * DEPOSIT_SIZE);
        sim_deposit(operatorOneIndex, 3);
        sim_activateValidators(2); // 1 still pending

        sim_oracleReport();
        assertEq(river.getInFlightDeposit(), DEPOSIT_SIZE, "1 validator still pending");

        sim_activateValidators(1);
        sim_oracleReport();
        assertEq(river.getInFlightDeposit(), 0, "all activated");
    }

    /// @dev Depositing more validators between reports increments inFlightDeposit.
    function testIncrementalDepositsBetweenReports() public {
        _fundRiver(5 * DEPOSIT_SIZE);
        sim_deposit(operatorOneIndex, 2);
        sim_activateValidators(2);
        sim_oracleReport();
        assertEq(river.getInFlightDeposit(), 0);

        sim_deposit(operatorOneIndex, 3);
        assertEq(river.getInFlightDeposit(), 3 * DEPOSIT_SIZE, "inFlight after second deposit");
        sim_activateValidators(3);
        sim_oracleReport();
        assertEq(river.getInFlightDeposit(), 0);
    }

    /// @dev Reporting inFlightETH > current stored value must revert.
    function testReportInFlightETHIncreaseReverts() public {
        _fundRiver(2 * DEPOSIT_SIZE);
        sim_deposit(operatorOneIndex, 2);
        sim_activateValidators(2);
        sim_oracleReport();
        // Now inFlightDeposit == 0.

        // Manually craft a report with inFlightETH = 1 ether > 0 (invalid increase)
        uint256 reportEpoch = river.getExpectedEpochId();
        vm.warp((SECONDS_PER_SLOT * SLOTS_PER_EPOCH) * (reportEpoch + EPOCHS_UNTIL_FINAL) + 1);

        IOracleManagerV1.ConsensusLayerReport memory bad = _buildReport(false, false);
        bad.epoch = reportEpoch;
        // Decrease totalDepositedActivatedETH — invalid since it must be non-decreasing.
        // This would imply InFlightDeposit increased, which is forbidden.
        bad.totalDepositedActivatedETH = bad.totalDepositedActivatedETH - 1 ether;

        vm.prank(oracleMember);
        vm.expectRevert(); // InvalidTotalDepositedActivatedETHIncrease
        oracle.reportConsensusLayerData(bad);
    }
}
```

**Step 2: Run the tests**

```bash
cd contracts && forge test --match-path "test/accounting/scenarios/InFlightETH.t.sol" -v
```
Expected: All 4 tests PASS.

**Step 3: Commit**

```bash
git add contracts/test/accounting/scenarios/InFlightETH.t.sol
git commit -m "test: add InFlightETH edge case scenario tests"
```

---

## Task 8: ExitAccounting.t.sol — per-operator exit ETH tracking

**Files:**
- Create: `contracts/test/accounting/scenarios/ExitAccounting.t.sol`

**Step 1: Create the file**

```solidity
// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../AccountingInvariants.sol";

contract ExitAccountingTest is AccountingInvariants {
    /// @dev Clean exit for one operator: fundedETH and exitedETH reconcile.
    function testCleanExit() public {
        _fundRiver(4 * DEPOSIT_SIZE);
        sim_deposit(operatorOneIndex, 4);
        sim_activateValidators(4);
        sim_oracleReport();

        sim_requestExit(operatorOneIndex, 2 * DEPOSIT_SIZE);
        sim_completeExit(operatorOneIndex, 2 * DEPOSIT_SIZE, 0);
        sim_oracleReport();

        OperatorsV3.Operator memory op = operatorsRegistry.getOperator(operatorOneIndex);
        assertEq(op.funded, 4 * DEPOSIT_SIZE, "funded ETH");
        uint256[] memory exitedPerOp = operatorsRegistry.getExitedETHPerOperator();
        assertEq(exitedPerOp[operatorOneIndex], 2 * DEPOSIT_SIZE, "exited ETH for op1");
    }

    /// @dev Two operators exit independently; per-operator accounting stays isolated.
    function testTwoOperatorExits() public {
        _fundRiver(6 * DEPOSIT_SIZE);
        sim_deposit(operatorOneIndex, 3);
        sim_deposit(operatorTwoIndex, 3);
        sim_activateValidators(6);
        sim_oracleReport();

        sim_requestExit(operatorOneIndex, DEPOSIT_SIZE);
        sim_requestExit(operatorTwoIndex, 2 * DEPOSIT_SIZE);
        sim_completeExit(operatorOneIndex, DEPOSIT_SIZE, 0);
        sim_completeExit(operatorTwoIndex, 2 * DEPOSIT_SIZE, 0);
        sim_oracleReport();

        uint256[] memory exitedPerOp = operatorsRegistry.getExitedETHPerOperator();
        assertEq(exitedPerOp[operatorOneIndex], DEPOSIT_SIZE,     "op1 exited");
        assertEq(exitedPerOp[operatorTwoIndex], 2 * DEPOSIT_SIZE, "op2 exited");

        (uint256 totalExited,) = operatorsRegistry.getExitedETHAndRequestedExitAmounts();
        assertEq(totalExited, 3 * DEPOSIT_SIZE, "total exited");
    }

    /// @dev Slashed exit: exitedETH < depositedETH (penalty applied).
    function testSlashedExit() public {
        _fundRiver(2 * DEPOSIT_SIZE);
        sim_deposit(operatorOneIndex, 2);
        sim_activateValidators(2);
        sim_oracleReport();

        uint256 penalty = 1 ether;
        sim_requestExit(operatorOneIndex, DEPOSIT_SIZE);
        sim_completeExit(operatorOneIndex, DEPOSIT_SIZE, penalty);
        sim_oracleReport();

        uint256[] memory exitedPerOp = operatorsRegistry.getExitedETHPerOperator();
        assertEq(exitedPerOp[operatorOneIndex], DEPOSIT_SIZE - penalty, "slashed exit");
    }

    /// @dev TotalDepositedETH never decreases across exits.
    function testTotalDepositedETHMonotonicAcrossExits() public {
        _fundRiver(3 * DEPOSIT_SIZE);
        sim_deposit(operatorOneIndex, 3);
        uint256 totalAfterDeposit = river.getTotalDepositedETH();

        sim_activateValidators(3);
        sim_oracleReport();
        assertEq(river.getTotalDepositedETH(), totalAfterDeposit, "no change after report");

        sim_requestExit(operatorOneIndex, 3 * DEPOSIT_SIZE);
        sim_completeExit(operatorOneIndex, 3 * DEPOSIT_SIZE, 0);
        sim_oracleReport();
        assertEq(river.getTotalDepositedETH(), totalAfterDeposit, "no change after exit");
    }
}
```

**Step 2: Run the tests**

```bash
cd contracts && forge test --match-path "test/accounting/scenarios/ExitAccounting.t.sol" -v
```
Expected: All 4 tests PASS.

**Step 3: Commit**

```bash
git add contracts/test/accounting/scenarios/ExitAccounting.t.sol
git commit -m "test: add ExitAccounting per-operator ETH scenario tests"
```

---

## Task 9: SlashingContainment.t.sol — slashing mode scenarios

**Files:**
- Create: `contracts/test/accounting/scenarios/SlashingContainment.t.sol`

**Step 1: Create the file**

```solidity
// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../AccountingInvariants.sol";

contract SlashingContainmentTest is AccountingInvariants {
    /// @dev When slashingContainmentMode = true, share price may decrease; invariants still hold.
    function testSlashingContainmentModeActive() public {
        _fundRiver(4 * DEPOSIT_SIZE);
        sim_deposit(operatorOneIndex, 4);
        sim_activateValidators(4);
        sim_oracleReport();

        // Apply a slash penalty to one validator
        uint256 penalty = 4 ether;
        sim_slash(operatorOneIndex, penalty);

        // Allow share price to decrease in this report
        _setAllowSharePriceDecrease(true);
        sim_oracleReport(false, true); // slashingContainmentMode = true
        _setAllowSharePriceDecrease(false);

        // Total underlying should have decreased by the slash amount (no fees taken on loss)
        // This is a sanity check, not exact because fee logic may vary
        assertLt(river.totalUnderlyingSupply(), 4 * DEPOSIT_SIZE, "underlying reduced by slash");
    }

    /// @dev Slashing containment prevents new exit requests being triggered.
    function testNoExitRequestsDuringContainment() public {
        _fundRiver(4 * DEPOSIT_SIZE);
        sim_deposit(operatorOneIndex, 4);
        sim_activateValidators(4);
        sim_oracleReport();

        uint256 exitsBefore = operatorsRegistry.getTotalETHExitsRequested();

        sim_slash(operatorOneIndex, 4 ether);
        _setAllowSharePriceDecrease(true);
        // Large redeem demand would normally trigger exits, but containment mode suppresses them
        sim_oracleReport(false, true);
        _setAllowSharePriceDecrease(false);

        // Exits requested must not increase during slashing containment
        uint256 exitsAfter = operatorsRegistry.getTotalETHExitsRequested();
        assertEq(exitsBefore, exitsAfter, "no exits during slashing containment");
    }

    /// @dev After containment ends, accounting invariants remain valid.
    function testContainmentEndAndResume() public {
        _fundRiver(4 * DEPOSIT_SIZE);
        sim_deposit(operatorOneIndex, 4);
        sim_activateValidators(4);
        sim_oracleReport();

        sim_slash(operatorOneIndex, 2 ether);
        _setAllowSharePriceDecrease(true);
        sim_oracleReport(false, true); // containment on
        _setAllowSharePriceDecrease(false);

        // Resume normal reporting — containment off
        sim_oracleReport(false, false); // invariants checked inside
    }
}
```

**Step 2: Run the tests**

```bash
cd contracts && forge test --match-path "test/accounting/scenarios/SlashingContainment.t.sol" -v
```
Expected: All 3 tests PASS.

**Step 3: Commit**

```bash
git add contracts/test/accounting/scenarios/SlashingContainment.t.sol
git commit -m "test: add SlashingContainment scenario tests"
```

---

## Task 10: RebalancingMode.t.sol — deposit-to-redeem rebalancing

**Files:**
- Create: `contracts/test/accounting/scenarios/RebalancingMode.t.sol`

**Step 1: Create the file**

```solidity
// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../AccountingInvariants.sol";

contract RebalancingModeTest is AccountingInvariants {
    /// @dev Rebalancing mode set in report: ETH conservation still holds.
    function testRebalancingModePreservesConservation() public {
        _fundRiver(6 * DEPOSIT_SIZE);
        sim_deposit(operatorOneIndex, 3);
        sim_activateValidators(3);
        sim_oracleReport();

        // Submit a report with rebalanceDepositToRedeemMode = true
        sim_oracleReport(true, false);
        // I2 (ETH conservation) is checked inside sim_oracleReport
    }

    /// @dev Normal report after a rebalancing report still passes all invariants.
    function testResumeAfterRebalancing() public {
        _fundRiver(4 * DEPOSIT_SIZE);
        sim_deposit(operatorOneIndex, 4);
        sim_activateValidators(4);
        sim_oracleReport();
        sim_oracleReport(true, false);
        sim_oracleReport(false, false);
    }
}
```

**Step 2: Run the tests**

```bash
cd contracts && forge test --match-path "test/accounting/scenarios/RebalancingMode.t.sol" -v
```
Expected: All 2 tests PASS.

**Step 3: Commit**

```bash
git add contracts/test/accounting/scenarios/RebalancingMode.t.sol
git commit -m "test: add RebalancingMode scenario tests"
```

---

## Task 11: Migration.t.sol — V2→V3 migration correctness

**Files:**
- Create: `contracts/test/accounting/scenarios/Migration.t.sol`

This test sets up pre-migration V2 state (using a storage-manipulation helper), runs the migration, and verifies the V3 state is correctly scaled.

**Step 1: Create the file**

```solidity
// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../AccountingHarnessBase.sol";
import "../../utils/LibImplementationUnbricker.sol";
import "../../../src/OperatorsRegistry.1.sol";
import "../../../src/state/operatorsRegistry/Operators.2.sol";
import "../../../src/state/operatorsRegistry/TotalValidatorExitsRequested.sol";
import "../../../src/state/operatorsRegistry/CurrentValidatorExitsDemand.sol";
import "../../../src/state/river/DepositedValidatorCount.sol";

/// @dev Exposes internals needed to set up pre-migration V2 state.
contract MigrationOperatorsRegistry is OperatorsRegistryV1 {
    /// @dev Directly push a V2-format operator (for migration testing only).
    function sudoPushV2Operator(
        string memory name,
        address addr,
        uint32 funded,
        uint32 stopped
    ) external {
        OperatorsV2.push(
            OperatorsV2.Operator({
                limit: funded,
                funded: funded,
                requestedExits: 0,
                keys: funded,
                latestKeysEditBlockNumber: 0,
                active: true,
                name: name,
                operator: addr
            })
        );
        // update stopped validators storage
        uint32[] memory stoppedCounts = OperatorsV2.getStoppedValidators();
        uint256 opIdx = OperatorsV2.getCount() - 1;
        // extend array and set stopped count for this operator
        uint256[] memory raw = new uint256[](opIdx + 2);
        for (uint256 i = 0; i < stoppedCounts.length; i++) raw[i + 1] = stoppedCounts[i];
        raw[opIdx + 1] = stopped;
        raw[0] += stopped;
    }

    function sudoSetTotalValidatorExitsRequested(uint256 v) external {
        TotalValidatorExitsRequested.set(v);
    }

    function sudoSetCurrentValidatorExitsDemand(uint256 v) external {
        CurrentValidatorExitsDemand.set(v);
    }
}

contract MigrationTest is Test {
    using LibImplementationUnbricker for Vm;

    MigrationOperatorsRegistry internal reg;
    address internal admin = makeAddr("migAdmin");

    function setUp() public {
        reg = new MigrationOperatorsRegistry();
        LibImplementationUnbricker.unbrick(vm, address(reg));
        reg.initOperatorsRegistryV1(admin, makeAddr("river"));
    }

    /// @dev V2 operators with funded/stopped counts migrate to correct ETH values.
    function testMigrateV2ToV3ETHScaling() public {
        // Set up V2 state: 2 operators, op0 has 5 funded / 2 stopped, op1 has 3 funded / 1 stopped
        vm.startPrank(admin);
        reg.sudoPushV2Operator("op0", makeAddr("op0"), 5, 2);
        reg.sudoPushV2Operator("op1", makeAddr("op1"), 3, 1);
        reg.sudoSetTotalValidatorExitsRequested(3);
        reg.sudoSetCurrentValidatorExitsDemand(1);
        vm.stopPrank();

        // Migrate V1→V2 (no-op since we wrote directly to V2 slot, but must call for version check)
        reg.initOperatorsRegistryV1_1();

        // Migrate V2→V3
        reg.initOperatorsRegistryV1_2();

        // Assert V3 state: funded and exited are ETH-scaled
        OperatorsV3.Operator memory op0 = reg.getOperator(0);
        OperatorsV3.Operator memory op1 = reg.getOperator(1);

        assertEq(op0.funded, 5 * 32 ether, "op0 funded ETH");
        assertEq(op1.funded, 3 * 32 ether, "op1 funded ETH");

        uint256[] memory exitedPerOp = reg.getExitedETHPerOperator();
        assertEq(exitedPerOp[0], 2 * 32 ether, "op0 exited ETH");
        assertEq(exitedPerOp[1], 1 * 32 ether, "op1 exited ETH");

        assertEq(reg.getTotalETHExitsRequested(), 3 * 32 ether, "total exits requested ETH");
        assertEq(reg.getCurrentETHExitsDemand(), 1 * 32 ether, "current exit demand ETH");
    }

    /// @dev Empty registry migration is a clean no-op.
    function testMigrateEmptyRegistry() public {
        reg.initOperatorsRegistryV1_1();
        reg.initOperatorsRegistryV1_2();
        assertEq(reg.getOperatorCount(), 0);
    }
}
```

**Step 2: Run the tests**

```bash
cd contracts && forge test --match-path "test/accounting/scenarios/Migration.t.sol" -v
```
Expected: Both tests PASS.

**Step 3: Commit**

```bash
git add contracts/test/accounting/scenarios/Migration.t.sol
git commit -m "test: add Migration V2→V3 ETH-scaling correctness tests"
```

---

## Task 12: AccountingFuzz.t.sol — random action sequences (Approach B layer)

**Files:**
- Create: `contracts/test/accounting/fuzz/AccountingFuzz.t.sol`

**Step 1: Create the file**

```solidity
// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../AccountingInvariants.sol";

/// @dev Fuzz layer: drives random sequences of sim_* step functions.
/// Every action is followed by a sim_oracleReport that asserts all 6 invariants.
/// Deposit amounts and validator counts are bounded to keep tests tractable.
contract AccountingFuzzTest is AccountingInvariants {
    uint256 private constant MAX_VALIDATORS_PER_OP = 10;
    uint256 private constant MAX_REWARD_PER_VAL    = 0.05 ether;

    function testFuzz_depositActivateReport(uint8 n1, uint8 n2) public {
        n1 = uint8(bound(n1, 1, MAX_VALIDATORS_PER_OP));
        n2 = uint8(bound(n2, 1, MAX_VALIDATORS_PER_OP));

        sim_deposit(operatorOneIndex, n1);
        sim_deposit(operatorTwoIndex, n2);
        sim_activateValidators(n1 + n2);
        sim_oracleReport(); // invariants checked inside
    }

    function testFuzz_rewardsAccrual(uint8 n, uint80 rewardWei) public {
        n = uint8(bound(n, 1, MAX_VALIDATORS_PER_OP));
        rewardWei = uint80(bound(rewardWei, 0, MAX_REWARD_PER_VAL));

        sim_deposit(operatorOneIndex, n);
        sim_activateValidators(n);
        sim_oracleReport();

        sim_advanceEpoch(rewardWei);
        sim_oracleReport();

        sim_advanceEpoch(rewardWei);
        sim_oracleReport();
    }

    function testFuzz_exitFlow(uint8 nDeposit, uint8 nExit) public {
        nDeposit = uint8(bound(nDeposit, 2, MAX_VALIDATORS_PER_OP));
        nExit    = uint8(bound(nExit, 1, nDeposit));

        sim_deposit(operatorOneIndex, nDeposit);
        sim_activateValidators(nDeposit);
        sim_oracleReport();

        sim_requestExit(operatorOneIndex, uint256(nExit) * DEPOSIT_SIZE);
        sim_completeExit(operatorOneIndex, uint256(nExit) * DEPOSIT_SIZE, 0);
        sim_oracleReport(); // I4, I5, I6 checked
    }

    function testFuzz_slashThenExit(uint8 n, uint64 penaltyWei) public {
        n = uint8(bound(n, 2, MAX_VALIDATORS_PER_OP));
        penaltyWei = uint64(bound(penaltyWei, 0, 8 ether));

        sim_deposit(operatorOneIndex, n);
        sim_activateValidators(n);
        sim_oracleReport();

        sim_slash(operatorOneIndex, penaltyWei);
        _setAllowSharePriceDecrease(penaltyWei > 0);
        sim_oracleReport(false, penaltyWei > 2 ether);
        _setAllowSharePriceDecrease(false);

        sim_requestExit(operatorOneIndex, DEPOSIT_SIZE);
        sim_completeExit(operatorOneIndex, DEPOSIT_SIZE, penaltyWei);
        sim_oracleReport();
    }

    function testFuzz_randomSequence(uint256 seed) public {
        uint256 s = seed;

        // Phase 1: deposits across both operators
        uint256 n1 = bound(s, 1, 5); s = _next(s);
        uint256 n2 = bound(s, 1, 5); s = _next(s);
        sim_deposit(operatorOneIndex, n1);
        sim_deposit(operatorTwoIndex, n2);
        sim_activateValidators(n1 + n2);
        sim_oracleReport();

        // Phase 2: optional reward epoch
        if (s % 2 == 0) {
            uint256 reward = bound(s, 0, MAX_REWARD_PER_VAL); s = _next(s);
            sim_advanceEpoch(reward);
            sim_oracleReport();
        }
        s = _next(s);

        // Phase 3: optional exit from op1
        uint256 exitN = bound(s, 0, n1); s = _next(s);
        if (exitN > 0) {
            sim_requestExit(operatorOneIndex, exitN * DEPOSIT_SIZE);
            sim_completeExit(operatorOneIndex, exitN * DEPOSIT_SIZE, 0);
            sim_oracleReport();
        }

        // Phase 4: optional slash op2 + report
        if (s % 3 == 0 && n2 > 0) {
            uint256 penalty = bound(s, 0, 1 ether); s = _next(s);
            if (penalty > 0) {
                sim_slash(operatorTwoIndex, penalty);
                _setAllowSharePriceDecrease(true);
                sim_oracleReport(false, true);
                _setAllowSharePriceDecrease(false);
            }
        }
    }

    function _next(uint256 s) internal pure returns (uint256) {
        return uint256(keccak256(abi.encode(s)));
    }
}
```

**Step 2: Run the fuzz tests**

```bash
cd contracts && forge test --match-path "test/accounting/fuzz/AccountingFuzz.t.sol" -v --fuzz-runs 500
```
Expected: All fuzz tests PASS (or reveal genuine accounting bugs).

**Step 3: Run the full accounting suite**

```bash
cd contracts && forge test --match-path "test/accounting/**" -v
```
Expected: All tests PASS.

**Step 4: Commit**

```bash
git add contracts/test/accounting/fuzz/AccountingFuzz.t.sol
git commit -m "test: add AccountingFuzz random action sequence tests"
```

---

## Final verification

Run the full existing test suite to confirm nothing regressed:

```bash
cd contracts && forge test -v
```
Expected: All tests PASS (no regressions in existing tests).
