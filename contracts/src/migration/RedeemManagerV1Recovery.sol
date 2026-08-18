//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../RedeemManager.1.sol";
import "../libraries/LibErrors.sol";
import "../state/redeemManager/RedeemQueueRepaired.sol";

/// @title Redeem Manager Recovery (BS-4878)
/// @author Alluvial Finance Inc.
/// @notice One-shot recovery implementation that rewrites a redeem queue corrupted by a replayed
///         `initializeRedeemManagerV1_2`.
/// @dev The v1.3.0 upgrade script calls `initializeRedeemManagerV1_2` through `upgradeToAndCall`. On a
///      deployment created fresh from v1.2.1 sources the queue is already in RedeemQueueV2 layout while
///      Version is still 1, so the `init(1)` guard passes and the V1 -> V2 migration is replayed. It reads
///      5 word records at a 4 word stride, so every record past index 0 is reassembled from fragments of
///      its neighbours.
///
///      Recovery sequence, all steps driven from the proxy admin (the RedeemManagerProxyFirewall):
///        1. Rebuild the correct queue off chain, from archive state at the pre-upgrade block, cross
///           checked against a replay of `RequestedRedeem` / `ClaimedRedeemRequest`.
///        2. `upgradeToAndCall(recovery, repairRedeemQueue(requests, queueHash))` - this contract.
///        3. `upgradeTo(RedeemManagerV1)` - drop the recovery surface again.
///
///      No pause is needed. The queue hash is verified on chain, so a claim landing between building
///      the payload and sending it makes the repair revert rather than silently replay stale amounts.
///
///      Step 2 is deliberately a single atomic call: a partially repaired queue is harder to reason
///      about than a failed transaction, and the proxy's transparent dispatch means only
///      `upgradeToAndCall` can reach an implementation function from the admin anyway.

contract RedeemManagerV1Recovery is RedeemManagerV1 {
    /// @notice EIP-1967 admin slot, read to confirm the caller is the proxy admin
    bytes32 private constant EIP1967_ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

    /// @notice The repair has already been performed on this deployment
    error RedeemQueueAlreadyRepaired();

    /// @notice The queue changed between building the payload and sending it
    /// @param found The hash of the queue as it stands now
    /// @param expected The hash the payload was built against
    error RepairQueueChanged(bytes32 found, bytes32 expected);

    /// @notice The supplied queue does not have the same length as the stored one
    /// @param provided The number of requests supplied
    /// @param expected The number of requests currently stored
    error RepairLengthMismatch(uint256 provided, uint256 expected);

    /// @notice The supplied request has a zero recipient
    /// @param index The index of the offending request
    error RepairInvalidRecipient(uint256 index);

    /// @notice The supplied request has a zero initiator
    /// @param index The index of the offending request
    error RepairInvalidInitiator(uint256 index);

    /// @notice The supplied request starts before the end position of the preceding one
    /// @param index The index of the offending request
    /// @param height The height of the offending request
    /// @param previousEnd The end position of the preceding request
    error RepairOverlappingRequest(uint256 index, uint256 height, uint256 previousEnd);

    /// @notice The supplied request has an end position at or below the preceding one, implying a zero size
    /// @param index The index of the offending request
    error RepairEmptyRequest(uint256 index);

    /// @notice The rebuilt queue ends below the withdrawal stack coverage, which `reportWithdraw` forbids
    /// @param queueEnd The end position of the rebuilt queue
    /// @param coverage The end position of the withdrawal stack
    error RepairQueueBelowCoverage(uint256 queueEnd, uint256 coverage);

    /// @notice The rebuilt queue is inconsistent with the untouched redeem demand counter
    /// @param implied The demand implied by the rebuilt queue
    /// @param expected The redeem demand currently stored
    error RepairDemandMismatch(uint256 implied, uint256 expected);

    /// @notice Emitted for every request rewritten by the repair
    /// @param redeemRequestId The id of the repaired request
    /// @param amount The restored amount of LsETH remaining
    /// @param maxRedeemableEth The restored maximum amount of ETH redeemable
    /// @param recipient The restored recipient
    /// @param height The restored height
    /// @param initiator The restored initiator
    event RedeemRequestRepaired(
        uint32 indexed redeemRequestId,
        uint256 amount,
        uint256 maxRedeemableEth,
        address recipient,
        uint256 height,
        address initiator
    );

    /// @notice Emitted once the whole queue has been rewritten and the invariants verified
    /// @param count The number of requests rewritten
    /// @param queueEndPosition The end position of the rebuilt queue
    /// @param redeemDemand The redeem demand the rebuilt queue was checked against
    event RedeemQueueRepairPerformed(uint256 count, uint256 queueEndPosition, uint256 redeemDemand);

    /// @notice Rewrite the redeem queue with externally reconstructed values
    /// @dev Restricted to the proxy admin and guarded by a dedicated one-off flag rather than `init`,
    ///      so Version stays at 2 and matches the other deployments. Values are supplied as calldata and
    ///      never derived from the corrupted storage - deriving in place is what caused the incident.
    ///
    ///      The checks below make the calldata self validating. The decisive one is the demand check:
    ///      `_requestRedeem` adds every request's size to RedeemDemand and anchors each request at the
    ///      preceding one's end position, while `reportWithdraw` subtracts each withdrawal event's size and
    ///      anchors it at the preceding event's end position. So the end of the queue minus the end of the
    ///      withdrawal stack is identically RedeemDemand. RedeemDemand lives in its own slot and was never
    ///      written by the faulty migration, which makes it an independent witness that the supplied queue
    ///      geometry is the correct one.
    /// @param _requests The full queue, index aligned, exactly as it should read after the repair
    /// @param _expectedQueueHash Hash of the queue as it stood when the payload was built
    function repairRedeemQueue(RedeemQueueV2.RedeemRequest[] calldata _requests, bytes32 _expectedQueueHash) external {
        // Access control, not decoration: recipients are written verbatim from calldata and only checked
        // for being non zero, so an unauthorised caller could pass a queue that satisfies every geometry
        // check while pointing all the payouts at themselves. A transparent proxy never delegates calls
        // from its admin, so requiring the admin here means this is reachable only through
        // upgradeToAndCall, which preserves msg.sender across the inner delegatecall.
        if (msg.sender != _proxyAdmin()) {
            revert LibErrors.Unauthorized(msg.sender);
        }
        // One-off, tracked in its own slot rather than through `init` so that Version stays at 2 and
        // matches the other deployments.
        if (RedeemQueueRepaired.get()) {
            revert RedeemQueueAlreadyRepaired();
        }
        RedeemQueueRepaired.set(true);

        // The payload was built against a specific queue. If anything moved since - a claim, a new
        // request - those values are stale and writing them would revert real activity: replaying a
        // claimed request's old amount would let it be claimed a second time. None of the checks below
        // would notice, because claiming moves neither the end positions, the coverage nor the demand.
        // Comparing the whole queue makes that impossible to miss, and removes any need to pause first.
        bytes32 currentHash = _currentQueueHash();
        if (currentHash != _expectedQueueHash) {
            revert RepairQueueChanged(currentHash, _expectedQueueHash);
        }

        RedeemQueueV2.RedeemRequest[] storage queue = RedeemQueueV2.get();
        uint256 count = queue.length;
        if (_requests.length != count) {
            revert RepairLengthMismatch(_requests.length, count);
        }

        uint256 previousEnd = 0;
        for (uint256 i = 0; i < count; ++i) {
            RedeemQueueV2.RedeemRequest calldata request = _requests[i];

            if (request.recipient == address(0)) {
                revert RepairInvalidRecipient(i);
            }
            if (request.initiator == address(0)) {
                revert RepairInvalidInitiator(i);
            }
            // The unclaimed remainder of a request never starts before the previous request's end position,
            // because claiming only ever moves height forward while holding height + amount constant.
            if (request.height < previousEnd) {
                revert RepairOverlappingRequest(i, request.height, previousEnd);
            }
            uint256 end = request.height + request.amount;
            // Every request was created with a non zero size, so end positions strictly increase.
            if (i != 0 && end <= previousEnd) {
                revert RepairEmptyRequest(i);
            }
            previousEnd = end;

            queue[i] = request;

            emit RedeemRequestRepaired(
                uint32(i),
                request.amount,
                request.maxRedeemableEth,
                request.recipient,
                request.height,
                request.initiator
            );
        }

        uint256 coverage = _withdrawalStackEndPosition();
        if (previousEnd < coverage) {
            revert RepairQueueBelowCoverage(previousEnd, coverage);
        }
        uint256 impliedDemand = previousEnd - coverage;
        uint256 redeemDemand = RedeemDemand.get();
        if (impliedDemand != redeemDemand) {
            revert RepairDemandMismatch(impliedDemand, redeemDemand);
        }

        emit RedeemQueueRepairPerformed(count, previousEnd, redeemDemand);
    }

    /// @notice Hash the redeem queue as it currently stands
    /// @dev Rolling hash so the whole queue is covered without materialising it in memory. Must match
    ///      the off chain computation in redeem_queue_repair.ts exactly, field order included.
    /// @return The hash of every stored redeem request, in order
    function _currentQueueHash() internal view returns (bytes32) {
        RedeemQueueV2.RedeemRequest[] storage queue = RedeemQueueV2.get();
        uint256 length = queue.length;
        bytes32 acc;
        for (uint256 i = 0; i < length; ++i) {
            RedeemQueueV2.RedeemRequest storage request = queue[i];
            acc = keccak256(
                abi.encodePacked(
                    acc, request.amount, request.maxRedeemableEth, request.recipient, request.height, request.initiator
                )
            );
        }
        return acc;
    }

    /// @notice Retrieve the proxy admin from the EIP-1967 slot
    /// @return admin The address allowed to upgrade this proxy
    function _proxyAdmin() internal view returns (address admin) {
        bytes32 slot = EIP1967_ADMIN_SLOT;
        assembly {
            admin := sload(slot)
        }
    }

    /// @notice Retrieve the end position of the withdrawal stack, in the same cumulative LsETH space as the queue
    /// @return The end position of the last withdrawal event, or zero if the stack is empty
    function _withdrawalStackEndPosition() internal view returns (uint256) {
        WithdrawalStack.WithdrawalEvent[] storage withdrawalEvents = WithdrawalStack.get();
        uint256 length = withdrawalEvents.length;
        if (length == 0) {
            return 0;
        }
        WithdrawalStack.WithdrawalEvent memory last = withdrawalEvents[length - 1];
        return last.height + last.amount;
    }
}
