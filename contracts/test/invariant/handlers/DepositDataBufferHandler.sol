// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "forge-std/Test.sol";

import "../../../src/DepositDataBuffer.sol";
import "../../../src/interfaces/IDepositDataBuffer.sol";
import "../../shared/DepositDataBufferFixtures.sol";

/// @title DepositDataBufferHandler
/// @notice Bounded action surface for the DepositDataBuffer invariant suite. Submits fresh batches,
///         re-submits existing batches verbatim (allowed under distinct nonces), and marks batches
///         processed as the processor — tracking ghost state the invariants assert against.
contract DepositDataBufferHandler is Test, DepositDataBufferFixtures {
    DepositDataBuffer public buffer;
    address public writer;
    address public processor;

    // Ghost state
    uint256 public ghost_successfulQueues;
    bytes32[] public ghost_queuedIds;
    mapping(bytes32 => uint256) public ghost_depositCounts;
    mapping(bytes32 => bool) public ghost_processed;
    uint256 public ghost_processedCount;

    constructor(DepositDataBuffer _buffer, address _writer, address _processor) {
        buffer = _buffer;
        writer = _writer;
        processor = _processor;
    }

    function ghost_queuedIdsLength() external view returns (uint256) {
        return ghost_queuedIds.length;
    }

    function ghost_queuedIdAt(uint256 idx) external view returns (bytes32) {
        return ghost_queuedIds[idx];
    }

    // -----------------------------------------------------------------------
    // Actions
    // -----------------------------------------------------------------------

    function queueRandom(uint8 batchSize, uint256 seed) external {
        uint256 count = bound(uint256(batchSize), 1, 5);
        // Bound the seed base so `seedBase + i` in the fixture builder cannot overflow.
        seed = bound(seed, 0, type(uint256).max - 5);
        IDepositDataBuffer.DepositObject memory batch = _batch(count, seed);

        // The batch nonce (lastQueuedIdx) is folded into the id, so valid data always succeeds.
        bytes32 id = keccak256(abi.encode(batch, buffer.lastQueuedIdx()));
        vm.prank(writer);
        buffer.submitDepositData(id, batch);

        ghost_successfulQueues++;
        ghost_queuedIds.push(id);
        ghost_depositCounts[id] = count;
    }

    function requeueExisting(uint256 idx) external {
        if (ghost_queuedIds.length == 0) return;
        bytes32 existing = ghost_queuedIds[bound(idx, 0, ghost_queuedIds.length - 1)];

        (IDepositDataBuffer.DepositObject memory batch,) = buffer.getDepositData(existing);

        // Re-submitting byte-identical data succeeds under a fresh, distinct id (nonce folding).
        bytes32 newId = keccak256(abi.encode(batch, buffer.lastQueuedIdx()));
        vm.prank(writer);
        buffer.submitDepositData(newId, batch);

        ghost_successfulQueues++;
        ghost_queuedIds.push(newId);
        ghost_depositCounts[newId] = batch.deposits.length;
    }

    function markProcessed(uint256 idx) external {
        if (ghost_queuedIds.length == 0) return;
        bytes32 id = ghost_queuedIds[bound(idx, 0, ghost_queuedIds.length - 1)];

        // Only the processor may mark processed; re-marking an already-processed batch reverts.
        vm.prank(processor);
        try buffer.markDepositDataProcessed(id) {
            if (!ghost_processed[id]) {
                ghost_processed[id] = true;
                ghost_processedCount++;
            }
        } catch {
            // Expected when the batch was already processed.
        }
    }
}
