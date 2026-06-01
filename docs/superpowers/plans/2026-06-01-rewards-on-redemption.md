# Rewards on Redemption Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement inactive-ETH rate locking for redemption claims so redeemers earn rewards until matched ETH stops earning, while claims still require actual withdrawal ETH.

**Architecture:** Add a FIFO rate-lock stack and rate-lock demand accounting to `RedeemManager`. Extend oracle reports with cumulative inactive-ETH fields, have `River` report inactive coverage to `RedeemManager`, and keep `claimRedeemRequests` calldata unchanged by resolving rate-lock events internally from each request's stored rate-lock pointer.

**Tech Stack:** Solidity 0.8.34, Foundry tests, Hardhat compile, existing Liquid Collective unstructured storage libraries.

---

## File Structure

- Create `contracts/src/state/redeemManager/RateLockStack.sol`: FIFO rate-lock event storage.
- Create `contracts/src/state/redeemManager/RateLockDemand.sol`: total LsETH demand still waiting for inactive-rate coverage.
- Create `contracts/src/state/redeemManager/RateLockHeightForRequest.sol`: mapping from redeem request ID to the current rate-lock stack height.
- Modify `contracts/src/interfaces/IRedeemManager.1.sol`: expose rate-lock event type, report API, resolver V2, view methods, events, and errors.
- Modify `contracts/src/RedeemManager.1.sol`: rate-lock reporting, rate-lock resolution, and claim matching using both stacks.
- Modify `contracts/src/interfaces/components/IOracleManager.1.sol`: append two cumulative inactive fields and `lastSharePrice` to the report structs; add monotonicity errors.
- Modify `contracts/src/components/OracleManager.1.sol`: compute inactive deltas, pull partial exits to redeem, report inactive coverage, and store the next share price.
- Modify `contracts/src/River.1.sol`: implement the new OracleManager hooks by calling `RedeemManager.reportInactiveEth`, returning total share supply, and routing partial exits.
- Modify `contracts/src/Oracle.1.sol`: no logic change expected beyond struct checksum using the extended struct.
- Modify `contracts/test/RedeemManager.1.t.sol`: rate-lock unit tests and updates for claim tests that now need both coverage streams.
- Modify `contracts/test/River.1.t.sol`: oracle report tests for partial exits, stopped-earning locks, and previous-report share price.
- Modify `contracts/test/components/OracleManager.1.t.sol`: expose and assert new OracleManager hooks.
- Modify `contracts/test/Oracle.1.t.sol` and `contracts/test/mocks/RiverMock.sol`: initialize extended report arrays/fields for checksum/vote tests.
- Modify `contracts/test/accounting/BeaconChainSimulator.sol`, `contracts/test/accounting/AccountingInvariants.sol`, and `contracts/test/accounting/invariant/AccountingInvariantTest.t.sol`: separate partial-exit and full-exit accumulators and assert new monotonic stored fields.
- Modify `certora/harness/RiverV1Harness.sol`, `certora/conf/RiverV1.conf`, `certora/conf/RiverV1DivideByConstant.conf`, and `certora/conf/RiverV1Tadeas.conf`: keep harness signatures and report tuple comments in sync.

## Task 1: RedeemManager Rate-Lock Storage And Reporting

**Files:**
- Create: `contracts/src/state/redeemManager/RateLockStack.sol`
- Create: `contracts/src/state/redeemManager/RateLockDemand.sol`
- Create: `contracts/src/state/redeemManager/RateLockHeightForRequest.sol`
- Modify: `contracts/src/interfaces/IRedeemManager.1.sol`
- Modify: `contracts/src/RedeemManager.1.sol`
- Modify: `contracts/test/RedeemManager.1.t.sol`

- [ ] **Step 1: Write failing tests for rate-lock reporting**

Add imports in `contracts/test/RedeemManager.1.t.sol`:

```solidity
import "../src/state/redeemManager/RateLockStack.sol";
import "../src/state/redeemManager/RateLockDemand.sol";
```

Add events beside the existing redeem manager test events:

```solidity
event ReportedInactiveEth(uint256 height, uint256 amount, uint256 ethAmount, uint32 id);
event SetRateLockDemand(uint256 oldRateLockDemand, uint256 newRateLockDemand);
```

Add these tests to `RedeemManagerTest`:

```solidity
function testRequestRedeemIncrementsRateLockDemand(uint256 _salt) external {
    address user = _generateAllowlistedUser(_salt);
    uint128 amount = uint128(bound(_salt, 1, type(uint128).max));

    river.sudoDeal(user, amount);

    vm.prank(user);
    river.approve(address(redeemManager), amount);

    vm.expectEmit(true, true, true, true);
    emit SetRateLockDemand(0, amount);
    vm.prank(user);
    redeemManager.requestRedeem(amount, user);

    assertEq(redeemManager.getRateLockDemand(), amount);
    assertEq(redeemManager.getRateLockEventCount(), 0);
}

function testReportInactiveEthCreatesRateLockEvent(uint256 _salt) external {
    address user = _generateAllowlistedUser(_salt);
    uint128 amount = uint128(bound(_salt, 1 ether, 1000 ether));
    uint256 lockedEth = uint256(amount) * 2;

    river.sudoDeal(user, amount);

    vm.prank(user);
    river.approve(address(redeemManager), amount);

    vm.prank(user);
    redeemManager.requestRedeem(amount, user);

    vm.expectEmit(true, true, true, true);
    emit ReportedInactiveEth(0, amount, lockedEth, 0);
    vm.prank(address(river));
    redeemManager.reportInactiveEth(amount, lockedEth);

    assertEq(redeemManager.getRateLockDemand(), 0);
    assertEq(redeemManager.getRateLockEventCount(), 1);

    RateLockStack.RateLockEvent memory event0 = redeemManager.getRateLockEventDetails(0);
    assertEq(event0.height, 0);
    assertEq(event0.amount, amount);
    assertEq(event0.ethAmount, lockedEth);
}

function testReportInactiveEthCapsToRateLockDemand(uint256 _salt) external {
    address user = _generateAllowlistedUser(_salt);
    uint128 amount = uint128(bound(_salt, 1 ether, 1000 ether));
    uint256 reportedLsEth = uint256(amount) * 2;
    uint256 reportedEth = uint256(amount) * 6;

    river.sudoDeal(user, amount);

    vm.prank(user);
    river.approve(address(redeemManager), amount);

    vm.prank(user);
    redeemManager.requestRedeem(amount, user);

    vm.prank(address(river));
    redeemManager.reportInactiveEth(reportedLsEth, reportedEth);

    RateLockStack.RateLockEvent memory event0 = redeemManager.getRateLockEventDetails(0);
    assertEq(event0.amount, amount);
    assertEq(event0.ethAmount, reportedEth * amount / reportedLsEth);
    assertEq(redeemManager.getRateLockDemand(), 0);
}

function testReportInactiveEthDoesNothingWithoutDemand(uint256 amount, uint256 ethAmount) external {
    amount = bound(amount, 1, type(uint128).max);
    ethAmount = bound(ethAmount, 1, type(uint128).max);

    vm.prank(address(river));
    redeemManager.reportInactiveEth(amount, ethAmount);

    assertEq(redeemManager.getRateLockDemand(), 0);
    assertEq(redeemManager.getRateLockEventCount(), 0);
}

function testReportInactiveEthOnlyRiver(uint256 amount, uint256 ethAmount) external {
    vm.expectRevert(abi.encodeWithSignature("Unauthorized(address)", address(this)));
    redeemManager.reportInactiveEth(amount, ethAmount);
}
```

- [ ] **Step 2: Run tests to verify failure**

Run:

```bash
forge test --match-path contracts/test/RedeemManager.1.t.sol --match-test 'test(RequestRedeemIncrementsRateLockDemand|ReportInactiveEth)' -vvv
```

Expected: FAIL with missing `RateLockStack`, `getRateLockDemand`, `getRateLockEventCount`, `getRateLockEventDetails`, or `reportInactiveEth`.

- [ ] **Step 3: Add rate-lock storage libraries**

Create `contracts/src/state/redeemManager/RateLockStack.sol`:

```solidity
//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

/// @title Redeem Manager Rate Lock Stack storage
/// @notice FIFO stack of inactive ETH rate-lock events in redeem-request LsETH height space
library RateLockStack {
    bytes32 internal constant RATE_LOCK_STACK_ID_SLOT = bytes32(uint256(keccak256("river.state.rateLockStack")) - 1);

    struct RateLockEvent {
        uint256 amount;
        uint256 ethAmount;
        uint256 height;
    }

    function get() internal pure returns (RateLockEvent[] storage data) {
        bytes32 position = RATE_LOCK_STACK_ID_SLOT;
        assembly {
            data.slot := position
        }
    }
}
```

Create `contracts/src/state/redeemManager/RateLockDemand.sol`:

```solidity
//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../../libraries/LibUnstructuredStorage.sol";

/// @title Redeem Manager Rate Lock Demand storage
/// @notice LsETH amount still waiting for inactive-rate coverage
library RateLockDemand {
    bytes32 internal constant RATE_LOCK_DEMAND_SLOT =
        bytes32(uint256(keccak256("river.state.rateLockDemand")) - 1);

    function get() internal view returns (uint256) {
        return LibUnstructuredStorage.getStorageUint256(RATE_LOCK_DEMAND_SLOT);
    }

    function set(uint256 newValue) internal {
        LibUnstructuredStorage.setStorageUint256(RATE_LOCK_DEMAND_SLOT, newValue);
    }
}
```

Create `contracts/src/state/redeemManager/RateLockHeightForRequest.sol`:

```solidity
//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

/// @title Redeem Manager Rate Lock Height storage
/// @notice Current rate-lock stack height per redeem request id
library RateLockHeightForRequest {
    bytes32 internal constant RATE_LOCK_HEIGHT_FOR_REQUEST_SLOT =
        bytes32(uint256(keccak256("river.state.rateLockHeightForRequest")) - 1);

    struct Slot {
        mapping(uint32 => uint256) value;
    }

    function get(uint32 requestId) internal view returns (uint256) {
        bytes32 position = RATE_LOCK_HEIGHT_FOR_REQUEST_SLOT;
        Slot storage slot;
        assembly {
            slot.slot := position
        }
        return slot.value[requestId];
    }

    function set(uint32 requestId, uint256 newValue) internal {
        bytes32 position = RATE_LOCK_HEIGHT_FOR_REQUEST_SLOT;
        Slot storage slot;
        assembly {
            slot.slot := position
        }
        slot.value[requestId] = newValue;
    }
}
```

- [ ] **Step 4: Extend the redeem manager interface**

In `contracts/src/interfaces/IRedeemManager.1.sol`, add:

```solidity
import "../state/redeemManager/RateLockStack.sol";
```

Add events after `ReportedWithdrawal`:

```solidity
event ReportedInactiveEth(uint256 height, uint256 amount, uint256 ethAmount, uint32 id);
event SetRateLockDemand(uint256 oldRateLockDemand, uint256 newRateLockDemand);
```

Add view and report functions:

```solidity
function getRateLockEventCount() external view returns (uint256);

function getRateLockEventDetails(uint32 _rateLockEventId)
    external
    view
    returns (RateLockStack.RateLockEvent memory);

function getRateLockDemand() external view returns (uint256);

function reportInactiveEth(uint256 _lsETHAmount, uint256 _ethAmount) external;
```

- [ ] **Step 5: Implement reporting in RedeemManager**

In `contracts/src/RedeemManager.1.sol`, add imports:

```solidity
import "./state/redeemManager/RateLockStack.sol";
import "./state/redeemManager/RateLockDemand.sol";
import "./state/redeemManager/RateLockHeightForRequest.sol";
```

Add public views near `getRedeemDemand()`:

```solidity
function getRateLockEventCount() external view returns (uint256) {
    return RateLockStack.get().length;
}

function getRateLockEventDetails(uint32 _rateLockEventId)
    external
    view
    returns (RateLockStack.RateLockEvent memory)
{
    return RateLockStack.get()[_rateLockEventId];
}

function getRateLockDemand() external view returns (uint256) {
    return RateLockDemand.get();
}
```

Add demand setter near `_setRedeemDemand()`:

```solidity
function _setRateLockDemand(uint256 _newValue) internal {
    emit SetRateLockDemand(RateLockDemand.get(), _newValue);
    RateLockDemand.set(_newValue);
}
```

In `_requestRedeem`, after `_setRedeemDemand(...)`, set the rate-lock pointer and demand:

```solidity
RateLockHeightForRequest.set(redeemRequestId, height);
_setRateLockDemand(RateLockDemand.get() + _lsETHAmount);
```

Add `reportInactiveEth` after `reportWithdraw`:

```solidity
function reportInactiveEth(uint256 _lsETHAmount, uint256 _ethAmount) external onlyRiver {
    if (_lsETHAmount == 0) {
        return;
    }

    uint256 rateLockDemand = RateLockDemand.get();
    uint256 effectiveLsETHAmount = LibUint256.min(_lsETHAmount, rateLockDemand);
    if (effectiveLsETHAmount == 0) {
        return;
    }

    uint256 effectiveEthAmount = (_ethAmount * effectiveLsETHAmount) / _lsETHAmount;
    RateLockStack.RateLockEvent[] storage rateLockEvents = RateLockStack.get();
    uint32 rateLockEventId = uint32(rateLockEvents.length);
    uint256 height = 0;
    if (rateLockEventId != 0) {
        RateLockStack.RateLockEvent memory previousRateLockEvent = rateLockEvents[rateLockEventId - 1];
        height = previousRateLockEvent.height + previousRateLockEvent.amount;
    }

    rateLockEvents.push(
        RateLockStack.RateLockEvent({height: height, amount: effectiveLsETHAmount, ethAmount: effectiveEthAmount})
    );
    unchecked {
        _setRateLockDemand(rateLockDemand - effectiveLsETHAmount);
    }
    emit ReportedInactiveEth(height, effectiveLsETHAmount, effectiveEthAmount, rateLockEventId);
}
```

- [ ] **Step 6: Run tests to verify pass**

Run:

```bash
forge test --match-path contracts/test/RedeemManager.1.t.sol --match-test 'test(RequestRedeemIncrementsRateLockDemand|ReportInactiveEth)' -vvv
```

Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add contracts/src/state/redeemManager/RateLockStack.sol contracts/src/state/redeemManager/RateLockDemand.sol contracts/src/state/redeemManager/RateLockHeightForRequest.sol contracts/src/interfaces/IRedeemManager.1.sol contracts/src/RedeemManager.1.sol contracts/test/RedeemManager.1.t.sol
git commit -m "feat: add redeem rate lock reporting"
```

## Task 2: Rate-Lock Resolution APIs

**Files:**
- Modify: `contracts/src/interfaces/IRedeemManager.1.sol`
- Modify: `contracts/src/RedeemManager.1.sol`
- Modify: `contracts/test/RedeemManager.1.t.sol`

- [ ] **Step 1: Write failing resolver tests**

Add these tests to `RedeemManagerTest`:

```solidity
function testResolveRedeemRequestsV2RequiresBothStacks(uint256 _salt) external {
    address user = _generateAllowlistedUser(_salt);
    uint128 amount = uint128(bound(_salt, 1 ether, 1000 ether));

    river.sudoDeal(user, amount);
    vm.prank(user);
    river.approve(address(redeemManager), amount);
    vm.prank(user);
    redeemManager.requestRedeem(amount, user);

    uint32[] memory ids = new uint32[](1);
    ids[0] = 0;

    (int64[] memory rateLockIds, int64[] memory withdrawalIds) = redeemManager.resolveRedeemRequestsV2(ids);
    assertEq(rateLockIds[0], -1);
    assertEq(withdrawalIds[0], -1);

    vm.prank(address(river));
    redeemManager.reportInactiveEth(amount, amount);

    (rateLockIds, withdrawalIds) = redeemManager.resolveRedeemRequestsV2(ids);
    assertEq(rateLockIds[0], 0);
    assertEq(withdrawalIds[0], -1);

    vm.deal(address(this), amount);
    river.sudoReportWithdraw{value: amount}(address(redeemManager), amount);

    (rateLockIds, withdrawalIds) = redeemManager.resolveRedeemRequestsV2(ids);
    assertEq(rateLockIds[0], 0);
    assertEq(withdrawalIds[0], 0);
}

function testResolveRedeemRequestsV2OutOfBounds() external {
    uint32[] memory ids = new uint32[](1);
    ids[0] = 0;

    (int64[] memory rateLockIds, int64[] memory withdrawalIds) = redeemManager.resolveRedeemRequestsV2(ids);
    assertEq(rateLockIds[0], -2);
    assertEq(withdrawalIds[0], -2);
}
```

- [ ] **Step 2: Run resolver tests to verify failure**

Run:

```bash
forge test --match-path contracts/test/RedeemManager.1.t.sol --match-test 'testResolveRedeemRequestsV2' -vvv
```

Expected: FAIL with missing `resolveRedeemRequestsV2`.

- [ ] **Step 3: Add resolver signature**

In `contracts/src/interfaces/IRedeemManager.1.sol`, add:

```solidity
function resolveRedeemRequestsV2(uint32[] calldata _redeemRequestIds)
    external
    view
    returns (int64[] memory rateLockEventIds, int64[] memory withdrawalEventIds);
```

- [ ] **Step 4: Implement rate-lock matching helpers**

In `contracts/src/RedeemManager.1.sol`, add:

```solidity
function _isRateLockMatch(
    uint256 _rateLockHeight,
    RateLockStack.RateLockEvent memory _rateLockEvent
) internal pure returns (bool) {
    return (_rateLockHeight < _rateLockEvent.height + _rateLockEvent.amount
            && _rateLockHeight >= _rateLockEvent.height);
}

function _performRateLockDichotomicResolution(uint256 _rateLockHeight) internal view returns (int64) {
    RateLockStack.RateLockEvent[] storage rateLockEvents = RateLockStack.get();
    int64 max = int64(int256(rateLockEvents.length - 1));

    if (_isRateLockMatch(_rateLockHeight, rateLockEvents[uint64(max)])) {
        return max;
    }

    int64 min = 0;
    if (_isRateLockMatch(_rateLockHeight, rateLockEvents[uint64(min)])) {
        return min;
    }

    while (min != max) {
        int64 mid = (min + max) / 2;
        RateLockStack.RateLockEvent memory midRateLockEvent = rateLockEvents[uint64(mid)];
        if (_isRateLockMatch(_rateLockHeight, midRateLockEvent)) {
            return mid;
        }
        if (_rateLockHeight < midRateLockEvent.height) {
            max = mid;
        } else {
            min = mid;
        }
    }
    return min;
}

function _resolveRateLockEventId(uint32 _redeemRequestId) internal view returns (int64 rateLockEventId) {
    RedeemQueueV2.RedeemRequest[] storage redeemRequests = RedeemQueueV2.get();
    if (_redeemRequestId >= redeemRequests.length) {
        return RESOLVE_OUT_OF_BOUNDS;
    }
    RedeemQueueV2.RedeemRequest memory redeemRequest = redeemRequests[_redeemRequestId];
    if (redeemRequest.amount == 0) {
        return RESOLVE_FULLY_CLAIMED;
    }
    RateLockStack.RateLockEvent[] storage rateLockEvents = RateLockStack.get();
    if (rateLockEvents.length == 0) {
        return RESOLVE_UNSATISFIED;
    }
    RateLockStack.RateLockEvent memory lastRateLockEvent = rateLockEvents[rateLockEvents.length - 1];
    uint256 rateLockHeight = RateLockHeightForRequest.get(_redeemRequestId);
    if (lastRateLockEvent.height + lastRateLockEvent.amount <= rateLockHeight) {
        return RESOLVE_UNSATISFIED;
    }
    return _performRateLockDichotomicResolution(rateLockHeight);
}
```

Add external resolver:

```solidity
function resolveRedeemRequestsV2(uint32[] calldata _redeemRequestIds)
    external
    view
    returns (int64[] memory rateLockEventIds, int64[] memory withdrawalEventIds)
{
    rateLockEventIds = new int64[](_redeemRequestIds.length);
    withdrawalEventIds = new int64[](_redeemRequestIds.length);

    WithdrawalStack.WithdrawalEvent memory lastWithdrawalEvent;
    WithdrawalStack.WithdrawalEvent[] storage withdrawalEvents = WithdrawalStack.get();
    if (withdrawalEvents.length > 0) {
        lastWithdrawalEvent = withdrawalEvents[withdrawalEvents.length - 1];
    }

    for (uint256 idx = 0; idx < _redeemRequestIds.length; ++idx) {
        rateLockEventIds[idx] = _resolveRateLockEventId(_redeemRequestIds[idx]);
        withdrawalEventIds[idx] = _resolveRedeemRequestId(_redeemRequestIds[idx], lastWithdrawalEvent);
    }
}
```

- [ ] **Step 5: Run resolver tests to verify pass**

Run:

```bash
forge test --match-path contracts/test/RedeemManager.1.t.sol --match-test 'testResolveRedeemRequestsV2' -vvv
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add contracts/src/interfaces/IRedeemManager.1.sol contracts/src/RedeemManager.1.sol contracts/test/RedeemManager.1.t.sol
git commit -m "feat: resolve redeem rate locks"
```

## Task 3: Claim Matching With Internal Rate-Lock Resolution

**Files:**
- Modify: `contracts/src/interfaces/IRedeemManager.1.sol`
- Modify: `contracts/src/RedeemManager.1.sol`
- Modify: `contracts/test/RedeemManager.1.t.sol`

- [ ] **Step 1: Add focused claim tests**

Add helper functions to `RedeemManagerTest`:

```solidity
function _requestRedeem(address user, uint256 amount) internal returns (uint32) {
    river.sudoDeal(user, amount);
    vm.prank(user);
    river.approve(address(redeemManager), amount);
    vm.prank(user);
    return redeemManager.requestRedeem(amount, user);
}

function _reportInactive(uint256 lsEthAmount, uint256 ethAmount) internal {
    vm.prank(address(river));
    redeemManager.reportInactiveEth(lsEthAmount, ethAmount);
}

function _reportWithdraw(uint256 lsEthAmount, uint256 ethAmount) internal {
    vm.deal(address(this), ethAmount);
    river.sudoReportWithdraw{value: ethAmount}(address(redeemManager), lsEthAmount);
}
```

Add tests:

```solidity
function testClaimRequiresRateLockCoverage(uint256 _salt) external {
    address user = _generateAllowlistedUser(_salt);
    uint128 amount = uint128(bound(_salt, 1 ether, 1000 ether));
    _requestRedeem(user, amount);
    _reportWithdraw(amount, amount);

    uint32[] memory requestIds = new uint32[](1);
    uint32[] memory withdrawalIds = new uint32[](1);
    requestIds[0] = 0;
    withdrawalIds[0] = 0;

    vm.expectRevert(abi.encodeWithSignature("UnsatisfiedRateLock(uint256)", 0));
    redeemManager.claimRedeemRequests(requestIds, withdrawalIds);
}

function testClaimUsesLowerLockedRate(uint256 _salt) external {
    address user = _generateAllowlistedUser(_salt);
    uint128 amount = uint128(bound(_salt, 1 ether, 1000 ether));
    _requestRedeem(user, amount);
    _reportInactive(amount, amount);
    _reportWithdraw(amount, uint256(amount) * 2);

    uint32[] memory requestIds = new uint32[](1);
    uint32[] memory withdrawalIds = new uint32[](1);
    requestIds[0] = 0;
    withdrawalIds[0] = 0;

    redeemManager.claimRedeemRequests(requestIds, withdrawalIds);

    assertEq(user.balance, amount);
    assertEq(redeemManager.getBufferedExceedingEth(), amount);
}

function testClaimUsesLowerWithdrawalRateAfterSlashing(uint256 _salt) external {
    address user = _generateAllowlistedUser(_salt);
    uint128 amount = uint128(bound(_salt, 2 ether, 1000 ether));
    uint256 withdrawnEth = uint256(amount) / 2;
    _requestRedeem(user, amount);
    _reportInactive(amount, amount);
    _reportWithdraw(amount, withdrawnEth);

    uint32[] memory requestIds = new uint32[](1);
    uint32[] memory withdrawalIds = new uint32[](1);
    requestIds[0] = 0;
    withdrawalIds[0] = 0;

    redeemManager.claimRedeemRequests(requestIds, withdrawalIds);

    assertEq(user.balance, withdrawnEth);
    assertEq(redeemManager.getBufferedExceedingEth(), 0);
}

function testClaimDoesNotNeedRateLockEventIdsInCalldata(uint256 _salt) external {
    address user = _generateAllowlistedUser(_salt);
    uint128 amount = uint128(bound(_salt, 1 ether, 1000 ether));
    _requestRedeem(user, amount);
    _reportInactive(amount, amount);
    _reportWithdraw(amount, amount);

    uint32[] memory requestIds = new uint32[](1);
    uint32[] memory withdrawalIds = new uint32[](1);
    requestIds[0] = 0;
    withdrawalIds[0] = 0;

    uint8[] memory statuses = redeemManager.claimRedeemRequests(requestIds, withdrawalIds);
    assertEq(statuses[0], 0);
    assertEq(user.balance, amount);
}
```

- [ ] **Step 2: Add claim-boundary split test**

Add:

```solidity
function testClaimSplitsAcrossRateLockAndWithdrawalBoundaries() external {
    address user = _generateAllowlistedUser(123);
    _requestRedeem(user, 100 ether);

    _reportInactive(40 ether, 40 ether);
    _reportInactive(60 ether, 120 ether);

    _reportWithdraw(25 ether, 25 ether);
    _reportWithdraw(75 ether, 75 ether);

    uint32[] memory requestIds = new uint32[](1);
    uint32[] memory withdrawalIds = new uint32[](1);
    requestIds[0] = 0;
    withdrawalIds[0] = 0;

    redeemManager.claimRedeemRequests(requestIds, withdrawalIds, true, type(uint16).max);

    assertEq(user.balance, 100 ether);
    assertEq(redeemManager.getBufferedExceedingEth(), 0);
}
```

- [ ] **Step 3: Run claim tests to verify failure**

Run:

```bash
forge test --match-path contracts/test/RedeemManager.1.t.sol --match-test 'testClaim(RequiresRateLockCoverage|UsesLower|DoesNotNeedRateLock|Splits)' -vvv
```

Expected: FAIL because current claim logic ignores `RateLockStack`.

- [ ] **Step 4: Add error and parameters for rate-lock claim logic**

In `IRedeemManager.1.sol`, add:

```solidity
error UnsatisfiedRateLock(uint256 redeemRequestId);
```

In `RedeemManager.1.sol`, extend `ClaimRedeemRequestParameters`:

```solidity
RateLockStack.RateLockEvent rateLockEvent;
uint32 rateLockEventId;
uint32 rateLockEventCount;
uint256 rateLockHeight;
```

Extend `ClaimRedeemRequestInternalVariables`:

```solidity
uint256 lockedEthAmount;
uint256 withdrawalEthAmount;
```

- [ ] **Step 5: Update save logic for request and rate-lock height**

Replace `_saveRedeemRequest` with:

```solidity
function _saveRedeemRequest(ClaimRedeemRequestParameters memory _params) internal {
    RedeemQueueV2.RedeemRequest[] storage redeemRequests = RedeemQueueV2.get();
    redeemRequests[_params.redeemRequestId].height = _params.redeemRequest.height;
    redeemRequests[_params.redeemRequestId].amount = _params.redeemRequest.amount;
    redeemRequests[_params.redeemRequestId].maxRedeemableEth = _params.redeemRequest.maxRedeemableEth;
    RateLockHeightForRequest.set(_params.redeemRequestId, _params.rateLockHeight);
}
```

- [ ] **Step 6: Rewrite segment calculation in `_claimRedeemRequest`**

Inside `_claimRedeemRequest`, replace the current matching and cap block with:

```solidity
uint256 withdrawalEventEndPosition = _params.withdrawalEvent.height + _params.withdrawalEvent.amount;
uint256 rateLockEventEndPosition = _params.rateLockEvent.height + _params.rateLockEvent.amount;

uint256 withdrawalMatched =
    LibUint256.min(_params.redeemRequest.amount, withdrawalEventEndPosition - _params.redeemRequest.height);
uint256 rateLockMatched =
    LibUint256.min(_params.redeemRequest.amount, rateLockEventEndPosition - _params.rateLockHeight);
vars.matchingAmount = LibUint256.min(withdrawalMatched, rateLockMatched);

vars.withdrawalEthAmount =
    (vars.matchingAmount * _params.withdrawalEvent.withdrawnEth) / _params.withdrawalEvent.amount;
vars.lockedEthAmount =
    (vars.matchingAmount * _params.rateLockEvent.ethAmount) / _params.rateLockEvent.amount;

vars.ethAmount = LibUint256.min(vars.withdrawalEthAmount, vars.lockedEthAmount);
if (vars.withdrawalEthAmount > vars.ethAmount) {
    vars.exceedingEthAmount = vars.withdrawalEthAmount - vars.ethAmount;
    BufferedExceedingEth.set(BufferedExceedingEth.get() + vars.exceedingEthAmount);
}

_params.redeemRequest.height += vars.matchingAmount;
_params.rateLockHeight += vars.matchingAmount;
_params.redeemRequest.amount -= vars.matchingAmount;
```

Remove the request-time `maxRedeemableEth` payout cap from new-flow claim logic. Keep the field assignment in `_requestRedeem` and storage save for ABI compatibility.

- [ ] **Step 7: Advance either stack internally**

Replace the recursive continuation condition with this exact branching:

```solidity
bool hasMoreWithdrawalEvents =
    _params.redeemRequest.amount > 0 && _params.withdrawalEventId + 1 < _params.withdrawalEventCount;
bool hasMoreRateLockEvents =
    _params.redeemRequest.amount > 0 && _params.rateLockEventId + 1 < _params.rateLockEventCount;
bool exhaustedWithdrawalEvent =
    _params.redeemRequest.height == _params.withdrawalEvent.height + _params.withdrawalEvent.amount;
bool exhaustedRateLockEvent =
    _params.rateLockHeight == _params.rateLockEvent.height + _params.rateLockEvent.amount;

if (_params.redeemRequest.amount > 0 && _params.depth > 0 && (hasMoreWithdrawalEvents || hasMoreRateLockEvents)) {
    if (exhaustedWithdrawalEvent && hasMoreWithdrawalEvents) {
        WithdrawalStack.WithdrawalEvent[] storage withdrawalEvents = WithdrawalStack.get();
        ++_params.withdrawalEventId;
        _params.withdrawalEvent = withdrawalEvents[_params.withdrawalEventId];
    }
    if (exhaustedRateLockEvent && hasMoreRateLockEvents) {
        RateLockStack.RateLockEvent[] storage rateLockEvents = RateLockStack.get();
        ++_params.rateLockEventId;
        _params.rateLockEvent = rateLockEvents[_params.rateLockEventId];
    }
    --_params.depth;
    _claimRedeemRequest(_params);
} else {
    _saveRedeemRequest(_params);
}
```

- [ ] **Step 8: Resolve rate-lock event before claiming**

In `_claimRedeemRequests`, after loading `params.withdrawalEvent`, add:

```solidity
int64 rateLockEventId = _resolveRateLockEventId(params.redeemRequestId);
if (rateLockEventId < 0) {
    revert UnsatisfiedRateLock(params.redeemRequestId);
}

RateLockStack.RateLockEvent[] storage rateLockEvents = RateLockStack.get();
params.rateLockEventCount = uint32(rateLockEvents.length);
params.rateLockEventId = uint32(uint64(rateLockEventId));
params.rateLockEvent = rateLockEvents[params.rateLockEventId];
params.rateLockHeight = RateLockHeightForRequest.get(params.redeemRequestId);
```

Keep the existing caller-supplied withdrawal event validation unchanged.

- [ ] **Step 9: Run focused claim tests to verify pass**

Run:

```bash
forge test --match-path contracts/test/RedeemManager.1.t.sol --match-test 'testClaim(RequiresRateLockCoverage|UsesLower|DoesNotNeedRateLock|Splits)' -vvv
```

Expected: PASS.

- [ ] **Step 10: Update older claim tests to create lock coverage**

For existing claim tests in `contracts/test/RedeemManager.1.t.sol` that call `river.sudoReportWithdraw` before claiming, add `_reportInactive(lsEthAmount, lockedEthAmount)` before the withdrawal report. For tests that specifically validate `reportWithdraw`, do not add rate-lock coverage unless the test claims.

Run:

```bash
forge test --match-path contracts/test/RedeemManager.1.t.sol -vvv
```

Expected: PASS.

- [ ] **Step 11: Commit**

```bash
git add contracts/src/interfaces/IRedeemManager.1.sol contracts/src/RedeemManager.1.sol contracts/test/RedeemManager.1.t.sol
git commit -m "feat: claim redemptions with rate locks"
```

## Task 4: Oracle Report Struct Fields And Share Price Hook

**Files:**
- Modify: `contracts/src/interfaces/components/IOracleManager.1.sol`
- Modify: `contracts/src/components/OracleManager.1.sol`
- Modify: `contracts/src/River.1.sol`
- Modify: `contracts/test/components/OracleManager.1.t.sol`
- Modify: `contracts/test/River.1.t.sol`
- Modify: `contracts/test/Oracle.1.t.sol`
- Modify: `contracts/test/mocks/RiverMock.sol`

- [ ] **Step 1: Write failing component tests for new report fields**

In `contracts/test/components/OracleManager.1.t.sol`, extend `OracleManagerV1ExposeInitializer` with:

```solidity
uint256 public totalSupplyForOracle = 1e18;
uint256 public reportedInactiveLsEth;
uint256 public reportedInactiveEth;

function sudoSetTotalSupplyForOracle(uint256 newValue) external {
    totalSupplyForOracle = newValue;
}

event Internal_ReportInactiveEthToRedeemManager(uint256 lsEthAmount, uint256 ethAmount);

function _totalSupplyForOracle() internal view override returns (uint256) {
    return totalSupplyForOracle;
}

function _reportInactiveEthToRedeemManager(uint256 lsEthAmount, uint256 ethAmount) internal override {
    reportedInactiveLsEth = lsEthAmount;
    reportedInactiveEth = ethAmount;
    emit Internal_ReportInactiveEthToRedeemManager(lsEthAmount, ethAmount);
}
```

Add tests:

```solidity
function testReportingError_InvalidDecreasingPartialExitWithdrawnBalance() public {
    IOracleManagerV1.ConsensusLayerReport memory clr;
    clr.epoch = epochsPerFrame;
    clr.validatorsPartialExitWithdrawnBalance = 10 ether;
    clr.totalDepositedActivatedETH = 0;

    vm.warp((clr.epoch + epochsToAssumedFinality) * slotsPerEpoch * secondsPerSlot);
    vm.prank(oracle);
    oracleManager.setConsensusLayerData(clr);

    clr.epoch += epochsPerFrame;
    clr.validatorsPartialExitWithdrawnBalance = 9 ether;
    vm.warp((clr.epoch + epochsToAssumedFinality) * slotsPerEpoch * secondsPerSlot);

    vm.prank(oracle);
    vm.expectRevert(
        abi.encodeWithSignature("InvalidDecreasingValidatorsPartialExitWithdrawnBalance(uint256,uint256)", 10 ether, 9 ether)
    );
    oracleManager.setConsensusLayerData(clr);
}

function testReportingError_InvalidDecreasingStoppedEarningBalance() public {
    IOracleManagerV1.ConsensusLayerReport memory clr;
    clr.epoch = epochsPerFrame;
    clr.validatorsStoppedEarningBalance = 10 ether;
    clr.totalDepositedActivatedETH = 0;

    vm.warp((clr.epoch + epochsToAssumedFinality) * slotsPerEpoch * secondsPerSlot);
    vm.prank(oracle);
    oracleManager.setConsensusLayerData(clr);

    clr.epoch += epochsPerFrame;
    clr.validatorsStoppedEarningBalance = 9 ether;
    vm.warp((clr.epoch + epochsToAssumedFinality) * slotsPerEpoch * secondsPerSlot);

    vm.prank(oracle);
    vm.expectRevert(
        abi.encodeWithSignature("InvalidDecreasingValidatorsStoppedEarningBalance(uint256,uint256)", 10 ether, 9 ether)
    );
    oracleManager.setConsensusLayerData(clr);
}
```

- [ ] **Step 2: Run component tests to verify failure**

Run:

```bash
forge test --match-path contracts/test/components/OracleManager.1.t.sol --match-test 'testReportingError_InvalidDecreasing(PartialExit|StoppedEarning)' -vvv
```

Expected: FAIL with missing fields, errors, or abstract hook implementations.

- [ ] **Step 3: Extend oracle report structs and errors**

In `contracts/src/interfaces/components/IOracleManager.1.sol`, add errors:

```solidity
error InvalidDecreasingValidatorsPartialExitWithdrawnBalance(
    uint256 currentValidatorsPartialExitWithdrawnBalance,
    uint256 newValidatorsPartialExitWithdrawnBalance
);

error InvalidDecreasingValidatorsStoppedEarningBalance(
    uint256 currentValidatorsStoppedEarningBalance,
    uint256 newValidatorsStoppedEarningBalance
);
```

Append these fields at the end of both `ConsensusLayerReport` and `StoredConsensusLayerReport`:

```solidity
uint256 validatorsPartialExitWithdrawnBalance;
uint256 validatorsStoppedEarningBalance;
uint256 lastSharePrice;
```

The fields are appended to preserve existing storage offsets for `StoredConsensusLayerReport.totalDepositedActivatedETH`.

- [ ] **Step 4: Add OracleManager hooks and variables**

In `contracts/src/components/OracleManager.1.sol`, add abstract hooks:

```solidity
function _totalSupplyForOracle() internal view virtual returns (uint256);

function _reportInactiveEthToRedeemManager(uint256 _lsETHAmount, uint256 _ethAmount) internal virtual;
```

Extend `ConsensusLayerDataReportingVariables`:

```solidity
uint256 lastReportPartialExitWithdrawnBalance;
uint256 lastReportStoppedEarningBalance;
uint256 partialExitWithdrawnAmountIncrease;
uint256 stoppedEarningAmountIncrease;
uint256 previousSharePrice;
```

Add helper:

```solidity
function _currentSharePrice() internal view returns (uint256) {
    uint256 totalSupply = _totalSupplyForOracle();
    if (totalSupply == 0) {
        return 0;
    }
    return (_assetBalance() * 1e18) / totalSupply;
}
```

- [ ] **Step 5: Validate new monotonic fields**

Inside `setConsensusLayerData`, in the block that reads `lastStoredReport`, add:

```solidity
vars.lastReportPartialExitWithdrawnBalance = lastStoredReport.validatorsPartialExitWithdrawnBalance;
if (_report.validatorsPartialExitWithdrawnBalance < vars.lastReportPartialExitWithdrawnBalance) {
    revert InvalidDecreasingValidatorsPartialExitWithdrawnBalance(
        vars.lastReportPartialExitWithdrawnBalance, _report.validatorsPartialExitWithdrawnBalance
    );
}
vars.partialExitWithdrawnAmountIncrease =
    _report.validatorsPartialExitWithdrawnBalance - vars.lastReportPartialExitWithdrawnBalance;

vars.lastReportStoppedEarningBalance = lastStoredReport.validatorsStoppedEarningBalance;
if (_report.validatorsStoppedEarningBalance < vars.lastReportStoppedEarningBalance) {
    revert InvalidDecreasingValidatorsStoppedEarningBalance(
        vars.lastReportStoppedEarningBalance, _report.validatorsStoppedEarningBalance
    );
}
vars.stoppedEarningAmountIncrease =
    _report.validatorsStoppedEarningBalance - vars.lastReportStoppedEarningBalance;
vars.previousSharePrice = lastStoredReport.lastSharePrice;
```

- [ ] **Step 6: Store new fields and next share price**

When building `storedReport`, set:

```solidity
storedReport.validatorsPartialExitWithdrawnBalance = _report.validatorsPartialExitWithdrawnBalance;
storedReport.validatorsStoppedEarningBalance = _report.validatorsStoppedEarningBalance;
storedReport.lastSharePrice = _report.lastSharePrice;
```

At the end of `setConsensusLayerData`, after `_commitBalanceToDeposit(...)` and before `emit ProcessedConsensusLayerReport(...)`, store the next share price:

```solidity
LastConsensusLayerReport.get().lastSharePrice = _currentSharePrice();
```

Do not trust `_report.lastSharePrice` as oracle input. It exists only so the stored report getter and event type stay aligned; the contract overwrites storage with `_currentSharePrice()`.

- [ ] **Step 7: Implement River hooks**

In `contracts/src/River.1.sol`, add:

```solidity
function _totalSupplyForOracle() internal view override returns (uint256) {
    return _totalSupply();
}

function _reportInactiveEthToRedeemManager(uint256 _lsETHAmount, uint256 _ethAmount) internal override {
    if (_lsETHAmount > 0) {
        IRedeemManagerV1(RedeemManagerAddress.get()).reportInactiveEth(_lsETHAmount, _ethAmount);
    }
}
```

- [ ] **Step 8: Update report builders and mocks for appended fields**

In `contracts/test/Oracle.1.t.sol`, update `_generateEmptyReport`:

```solidity
clr.exitedETHPerOperator = new uint256[](stoppedValidatorsCountElements);
clr.activeCLETHPerOperator = new uint256[](stoppedValidatorsCountElements > 0 ? stoppedValidatorsCountElements - 1 : 0);
```

In `contracts/test/mocks/RiverMock.sol`, no manual struct construction is required; keep emitting `DebugReceivedReport(report)`.

In `contracts/test/River.1.t.sol`, leave `_fillReport` offset for `totalDepositedActivatedETH` at `lastReportBase + 6` because new stored fields are appended.

- [ ] **Step 9: Run compile and focused tests**

Run:

```bash
forge test --match-path contracts/test/components/OracleManager.1.t.sol --match-test 'testReportingError_InvalidDecreasing(PartialExit|StoppedEarning)' -vvv
forge test --match-path contracts/test/Oracle.1.t.sol --match-test testValidReport -vvv
```

Expected: PASS.

- [ ] **Step 10: Commit**

```bash
git add contracts/src/interfaces/components/IOracleManager.1.sol contracts/src/components/OracleManager.1.sol contracts/src/River.1.sol contracts/test/components/OracleManager.1.t.sol contracts/test/River.1.t.sol contracts/test/Oracle.1.t.sol contracts/test/mocks/RiverMock.sol
git commit -m "feat: extend oracle report with inactive balances"
```

## Task 5: Partial Exit Routing And Inactive Lock Reporting From River

**Files:**
- Modify: `contracts/src/components/OracleManager.1.sol`
- Modify: `contracts/src/River.1.sol`
- Modify: `contracts/test/components/OracleManager.1.t.sol`
- Modify: `contracts/test/River.1.t.sol`
- Modify: `contracts/test/RedeemManager.1.t.sol`

- [ ] **Step 1: Write tests for routing and lock reporting**

In `contracts/test/components/OracleManager.1.t.sol`, update the exposed hook event:

```solidity
event Internal_PullCLFunds(uint256 skimmedEthAmount, uint256 exitedEthAmount, uint256 partialExitEthAmount);
```

Replace the exposed `_pullCLFunds` override with:

```solidity
function _pullCLFunds(uint256 skimmedEthAmount, uint256 exitedEthAmount, uint256 partialExitEthAmount)
    internal
    override
{
    amountToDeposit += skimmedEthAmount;
    amountToRedeem += exitedEthAmount + partialExitEthAmount;
    emit Internal_PullCLFunds(skimmedEthAmount, exitedEthAmount, partialExitEthAmount);
}
```

Add test:

```solidity
function testReportingRoutesPartialExitToRedeemAndReportsInactiveLock() public {
    IOracleManagerV1.ConsensusLayerReport memory clr;
    oracleManager.sudoSetTotalSupplyForOracle(100 ether);

    clr.epoch = epochsPerFrame;
    clr.validatorsBalance = 100 ether;
    clr.totalDepositedActivatedETH = 0;
    vm.warp((clr.epoch + epochsToAssumedFinality) * slotsPerEpoch * secondsPerSlot);

    vm.prank(oracle);
    oracleManager.setConsensusLayerData(clr);

    clr.epoch += epochsPerFrame;
    clr.validatorsPartialExitWithdrawnBalance = 10 ether;
    clr.validatorsBalance = 90 ether;
    vm.warp((clr.epoch + epochsToAssumedFinality) * slotsPerEpoch * secondsPerSlot);

    vm.expectEmit(true, true, true, true);
    emit OracleManagerV1ExposeInitializer.Internal_PullCLFunds(0, 0, 10 ether);
    vm.expectEmit(true, true, true, true);
    emit OracleManagerV1ExposeInitializer.Internal_ReportInactiveEthToRedeemManager(10 ether, 10 ether);
    vm.prank(oracle);
    oracleManager.setConsensusLayerData(clr);
}
```

- [ ] **Step 2: Run routing test to verify failure**

Run:

```bash
forge test --match-path contracts/test/components/OracleManager.1.t.sol --match-test testReportingRoutesPartialExitToRedeemAndReportsInactiveLock -vvv
```

Expected: FAIL because `_pullCLFunds` accepts only two arguments and no inactive report is emitted.

- [ ] **Step 3: Update `_pullCLFunds` signature**

In `contracts/src/components/OracleManager.1.sol`, change abstract hook:

```solidity
function _pullCLFunds(uint256 _skimmedEthAmount, uint256 _exitedEthAmount, uint256 _partialExitEthAmount)
    internal
    virtual;
```

Change the call:

```solidity
if (vars.exitedAmountIncrease + vars.skimmedAmountIncrease + vars.partialExitWithdrawnAmountIncrease > 0) {
    _pullCLFunds(vars.skimmedAmountIncrease, vars.exitedAmountIncrease, vars.partialExitWithdrawnAmountIncrease);
}
```

In `contracts/src/River.1.sol`, replace `_pullCLFunds` with:

```solidity
function _pullCLFunds(uint256 _skimmedEthAmount, uint256 _exitedEthAmount, uint256 _partialExitEthAmount)
    internal
    override
{
    uint256 currentBalance = address(this).balance;
    uint256 totalAmountToPull = _skimmedEthAmount + _exitedEthAmount + _partialExitEthAmount;
    IWithdrawV1(WithdrawalCredentials.getAddress()).pullEth(totalAmountToPull);
    uint256 collectedCLFunds = address(this).balance - currentBalance;
    if (collectedCLFunds != totalAmountToPull) {
        revert InvalidPulledClFundsAmount(totalAmountToPull, collectedCLFunds);
    }
    if (_skimmedEthAmount > 0) {
        _setBalanceToDeposit(BalanceToDeposit.get() + _skimmedEthAmount);
    }
    uint256 redeemEthAmount = _exitedEthAmount + _partialExitEthAmount;
    if (redeemEthAmount > 0) {
        _setBalanceToRedeem(BalanceToRedeem.get() + redeemEthAmount);
    }
    emit PulledCLFunds(_skimmedEthAmount, _exitedEthAmount + _partialExitEthAmount);
}
```

- [ ] **Step 4: Report inactive ETH after CL funds are accounted**

In `OracleManagerV1.setConsensusLayerData`, after `storedReport` is set and before `_reportCLETH`, add:

```solidity
uint256 inactiveEthAmount = vars.partialExitWithdrawnAmountIncrease + vars.stoppedEarningAmountIncrease;
if (inactiveEthAmount > 0 && vars.previousSharePrice > 0) {
    uint256 inactiveLsEthAmount = (inactiveEthAmount * 1e18) / vars.previousSharePrice;
    _reportInactiveEthToRedeemManager(inactiveLsEthAmount, inactiveEthAmount);
}
```

- [ ] **Step 5: Update all `_pullCLFunds` overrides**

Update `contracts/test/components/OracleManager.1.t.sol` and `certora/harness/RiverV1Harness.sol` to use the three-argument signature. In the Certora harness, preserve the existing helper split but pass the partial exit amount through to redeem balance exactly as `RiverV1` does.

- [ ] **Step 6: Add River integration test**

In `contracts/test/River.1.t.sol`, add:

```solidity
function testReportingPartialExitRoutesToRedeemManagerAndLocksRate() external {
    RedeemManagerV1 redeemManager_ = new RedeemManagerV1();
    LibImplementationUnbricker.unbrick(vm, address(redeemManager_));
    redeemManager_.initializeRedeemManagerV1(address(river));
    river.initRiverV1_1(
        address(redeemManager_),
        epochsPerFrame,
        slotsPerEpoch,
        secondsPerSlot,
        0,
        epochsUntilFinal,
        1000,
        500,
        maxDailyNetCommittableAmount,
        maxDailyRelativeCommittableAmount
    );

    _allow(bob);
    vm.deal(bob, 100 ether);
    vm.prank(bob);
    river.deposit{value: 100 ether}();
    vm.prank(bob);
    river.requestRedeem(10 ether, bob);

    IOracleManagerV1.ConsensusLayerReport memory clr = _generateEmptyReport();
    clr.epoch = epochsPerFrame;
    clr.validatorsBalance = 100 ether;
    clr.totalDepositedActivatedETH = 0;
    vm.warp((clr.epoch + epochsUntilFinal) * (secondsPerSlot * slotsPerEpoch));
    vm.prank(address(oracle));
    _fillReport(clr);
    river.setConsensusLayerData(clr);

    clr.epoch += epochsPerFrame;
    clr.validatorsBalance = 90 ether;
    clr.validatorsPartialExitWithdrawnBalance = 10 ether;
    vm.deal(address(withdraw), 10 ether);
    vm.warp((clr.epoch + epochsUntilFinal) * (secondsPerSlot * slotsPerEpoch));
    vm.prank(address(oracle));
    _fillReport(clr);
    river.setConsensusLayerData(clr);

    assertEq(redeemManager_.getRateLockEventCount(), 1);
    assertEq(redeemManager_.getWithdrawalEventCount(), 1);
}
```

- [ ] **Step 7: Run focused tests**

Run:

```bash
forge test --match-path contracts/test/components/OracleManager.1.t.sol --match-test testReportingRoutesPartialExitToRedeemAndReportsInactiveLock -vvv
forge test --match-path contracts/test/River.1.t.sol --match-test testReportingPartialExitRoutesToRedeemManagerAndLocksRate -vvv
```

Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add contracts/src/components/OracleManager.1.sol contracts/src/River.1.sol contracts/test/components/OracleManager.1.t.sol contracts/test/River.1.t.sol certora/harness/RiverV1Harness.sol
git commit -m "feat: route inactive exits through redemption"
```

## Task 6: Previous-Report Share Price Behavior

**Files:**
- Modify: `contracts/src/components/OracleManager.1.sol`
- Modify: `contracts/test/River.1.t.sol`
- Modify: `contracts/test/components/OracleManager.1.t.sol`

- [ ] **Step 1: Write share-price regression test**

In `contracts/test/River.1.t.sol`, add:

```solidity
function testInactiveLockUsesPreviousReportSharePrice() external {
    RedeemManagerV1 redeemManager_ = new RedeemManagerV1();
    LibImplementationUnbricker.unbrick(vm, address(redeemManager_));
    redeemManager_.initializeRedeemManagerV1(address(river));
    river.initRiverV1_1(
        address(redeemManager_),
        epochsPerFrame,
        slotsPerEpoch,
        secondsPerSlot,
        0,
        epochsUntilFinal,
        1000,
        500,
        maxDailyNetCommittableAmount,
        maxDailyRelativeCommittableAmount
    );

    _allow(bob);
    vm.deal(bob, 100 ether);
    vm.prank(bob);
    river.deposit{value: 100 ether}();
    vm.prank(bob);
    river.requestRedeem(20 ether, bob);

    IOracleManagerV1.ConsensusLayerReport memory first = _generateEmptyReport();
    first.epoch = epochsPerFrame;
    first.validatorsBalance = 100 ether;
    first.totalDepositedActivatedETH = 0;
    vm.warp((first.epoch + epochsUntilFinal) * (secondsPerSlot * slotsPerEpoch));
    vm.prank(address(oracle));
    _fillReport(first);
    river.setConsensusLayerData(first);

    uint256 previousSharePrice = river.getLastConsensusLayerReport().lastSharePrice;
    assertEq(previousSharePrice, 1e18);

    IOracleManagerV1.ConsensusLayerReport memory second = _generateEmptyReport();
    second.epoch = first.epoch + epochsPerFrame;
    second.validatorsBalance = 100 ether;
    second.validatorsStoppedEarningBalance = 10 ether;
    vm.warp((second.epoch + epochsUntilFinal) * (secondsPerSlot * slotsPerEpoch));
    vm.prank(address(oracle));
    _fillReport(second);
    river.setConsensusLayerData(second);

    RateLockStack.RateLockEvent memory lockEvent = redeemManager_.getRateLockEventDetails(0);
    assertEq(lockEvent.amount, 10 ether);
    assertEq(lockEvent.ethAmount, 10 ether);
}
```

- [ ] **Step 2: Run share-price test to verify failure or pass**

Run:

```bash
forge test --match-path contracts/test/River.1.t.sol --match-test testInactiveLockUsesPreviousReportSharePrice -vvv
```

Expected: PASS if Task 5 already stores and uses `lastSharePrice`; otherwise FAIL with zero lock event or wrong lock amount.

- [ ] **Step 3: Verify and correct `lastSharePrice` ordering**

Inspect `contracts/src/components/OracleManager.1.sol` and confirm this block executes before `LastConsensusLayerReport.get().lastSharePrice = _currentSharePrice();`:

```solidity
uint256 inactiveEthAmount = vars.partialExitWithdrawnAmountIncrease + vars.stoppedEarningAmountIncrease;
if (inactiveEthAmount > 0 && vars.previousSharePrice > 0) {
    uint256 inactiveLsEthAmount = (inactiveEthAmount * 1e18) / vars.previousSharePrice;
    _reportInactiveEthToRedeemManager(inactiveLsEthAmount, inactiveEthAmount);
}
```

If it executes after the assignment, move it before the assignment.

- [ ] **Step 4: Run share-price and OracleManager tests**

Run:

```bash
forge test --match-path contracts/test/River.1.t.sol --match-test testInactiveLockUsesPreviousReportSharePrice -vvv
forge test --match-path contracts/test/components/OracleManager.1.t.sol -vvv
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add contracts/src/components/OracleManager.1.sol contracts/test/River.1.t.sol contracts/test/components/OracleManager.1.t.sol
git commit -m "test: cover previous report rate locks"
```

## Task 7: Accounting Simulator And Existing Test Suite Alignment

**Files:**
- Modify: `contracts/test/accounting/BeaconChainSimulator.sol`
- Modify: `contracts/test/accounting/AccountingInvariants.sol`
- Modify: `contracts/test/accounting/invariant/AccountingInvariantTest.t.sol`
- Modify: `contracts/test/River.1.t.sol`
- Modify: `contracts/test/Oracle.1.t.sol`
- Modify: `contracts/test/components/OracleManager.1.t.sol`
- Modify: `certora/harness/RiverV1Harness.sol`
- Modify: `certora/conf/RiverV1.conf`
- Modify: `certora/conf/RiverV1DivideByConstant.conf`
- Modify: `certora/conf/RiverV1Tadeas.conf`

- [ ] **Step 1: Update accounting simulator accumulators**

In `contracts/test/accounting/BeaconChainSimulator.sol`, add fields:

```solidity
uint256 internal _simCumulativePartialExitWithdrawn;
uint256 internal _simCumulativeStoppedEarning;
```

In `sim_requestExit`, when a validator becomes fully exiting, increment stopped earning once:

```solidity
if (v.exitingETH == v.currentBalance) {
    v.state = ValidatorState.Exiting;
    _simCumulativeStoppedEarning += v.currentBalance;
}
```

In `sim_completeExit`, replace the single `_simCumulativeExited += actualExited;` with:

```solidity
if (v.state == ValidatorState.Active) {
    _simCumulativePartialExitWithdrawn += actualExited;
} else {
    _simCumulativeExited += actualExited;
}
```

In `_buildReport`, set:

```solidity
report.validatorsPartialExitWithdrawnBalance = _simCumulativePartialExitWithdrawn;
report.validatorsStoppedEarningBalance = _simCumulativeStoppedEarning;
```

- [ ] **Step 2: Update invariant snapshots for new monotonic fields**

In `contracts/test/accounting/invariant/AccountingInvariantTest.t.sol`, add ghost fields:

```solidity
uint256 public ghost_lastPartialExitWithdrawnBalance;
uint256 public ghost_lastStoppedEarningBalance;
```

Where `ghost_lastSkimmedBalance` and `ghost_lastExitedBalance` are updated, also update:

```solidity
ghost_lastPartialExitWithdrawnBalance = report.validatorsPartialExitWithdrawnBalance;
ghost_lastStoppedEarningBalance = report.validatorsStoppedEarningBalance;
```

Add invariant functions:

```solidity
function invariant_I18_partialExitWithdrawnNeverDecreases() public view {
    IOracleManagerV1.StoredConsensusLayerReport memory report = river.getLastConsensusLayerReport();
    assertGe(
        report.validatorsPartialExitWithdrawnBalance,
        ghost_lastPartialExitWithdrawnBalance,
        "I18: partial exit withdrawn decreased"
    );
}

function invariant_I19_stoppedEarningNeverDecreases() public view {
    IOracleManagerV1.StoredConsensusLayerReport memory report = river.getLastConsensusLayerReport();
    assertGe(
        report.validatorsStoppedEarningBalance,
        ghost_lastStoppedEarningBalance,
        "I19: stopped earning decreased"
    );
}
```

- [ ] **Step 3: Update report tuple comments in Certora configs**

Replace commented method tuple examples in `certora/conf/RiverV1.conf`, `certora/conf/RiverV1DivideByConstant.conf`, and `certora/conf/RiverV1Tadeas.conf` with:

```text
// "method": "setConsensusLayerData((uint256,uint256,uint256,uint256,uint256,uint256,uint32,uint256[],uint256[],bool,bool,uint256,uint256,uint256))"
```

- [ ] **Step 4: Run compile and affected suites**

Run:

```bash
forge test --match-path contracts/test/accounting/**/*.sol -vvv
forge test --match-path contracts/test/River.1.t.sol -vvv
forge test --match-path contracts/test/Oracle.1.t.sol -vvv
forge test --match-path contracts/test/components/OracleManager.1.t.sol -vvv
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add contracts/test/accounting contracts/test/River.1.t.sol contracts/test/Oracle.1.t.sol contracts/test/components/OracleManager.1.t.sol certora/harness/RiverV1Harness.sol certora/conf/RiverV1.conf certora/conf/RiverV1DivideByConstant.conf certora/conf/RiverV1Tadeas.conf
git commit -m "test: align reporting suites with inactive exits"
```

## Task 8: Full Verification And Cleanup

**Files:**
- Modify only files required by failures found in this task.

- [ ] **Step 1: Run focused contract tests**

Run:

```bash
forge test --match-path contracts/test/RedeemManager.1.t.sol -vvv
forge test --match-path contracts/test/River.1.t.sol -vvv
forge test --match-path contracts/test/Oracle.1.t.sol -vvv
forge test --match-path contracts/test/components/OracleManager.1.t.sol -vvv
```

Expected: PASS.

- [ ] **Step 2: Run accounting tests**

Run:

```bash
forge test --match-path contracts/test/accounting/**/*.sol -vvv
```

Expected: PASS.

- [ ] **Step 3: Run project compile**

Run:

```bash
yarn compile
```

Expected: PASS with Solidity compilation completing successfully.

- [ ] **Step 4: Run full test command**

Run:

```bash
yarn test
```

Expected: PASS. If the full gas-report suite is too slow for the local environment, run `forge test -vvv` and record the exact command and result in the final response.

- [ ] **Step 5: Run format check**

Run:

```bash
yarn format:check
```

Expected: PASS.

- [ ] **Step 6: Commit final fixes**

If Step 1 through Step 5 required code or formatting fixes, commit them:

```bash
git add contracts certora
git commit -m "chore: verify rewards on redemption"
```

If no files changed, do not create an empty commit.

## Plan Self-Review Notes

Spec coverage:

- Separate FIFO rate-lock stack: Task 1.
- Rate-lock demand and no revert on unsolicited inactive ETH: Task 1.
- Claims require both rate lock and withdrawal coverage with no rate-lock IDs in calldata: Tasks 2 and 3.
- Lower of locked rate and realized withdrawal rate: Task 3.
- Oracle cumulative partial-exit and stopped-earning fields: Task 4.
- Partial exits routed to `BalanceToRedeem`: Task 5.
- Stopped-earning full exits lock before sweep without pulling ETH: Tasks 5 and 6.
- Previous completed report share price: Task 6.
- Existing test/accounting/harness alignment: Task 7.
- Full verification: Task 8.

Type consistency:

- Rate-lock event type is `RateLockStack.RateLockEvent`.
- Rate-lock demand state library is `RateLockDemand`.
- Per-request pointer state library is `RateLockHeightForRequest`.
- Public report function is `reportInactiveEth(uint256,uint256)`.
- Public resolver is `resolveRedeemRequestsV2(uint32[])`.

Scope boundary:

- No migration strategy for already-pending legacy redeem requests is included.
- The plan preserves the existing claim calldata shape and does not add `rateLockEventIds` to claim inputs.
