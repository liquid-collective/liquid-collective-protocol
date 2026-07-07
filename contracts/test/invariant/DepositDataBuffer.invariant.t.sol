// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "forge-std/Test.sol";

import "../../src/DepositDataBuffer.sol";
import "../../src/interfaces/IDepositDataBuffer.sol";
import "./handlers/DepositDataBufferHandler.sol";

/// @title DepositDataBufferInvariantTest
/// @notice Invariants for the DepositDataBuffer, ported from the frontrun-mitigation suite and
///         adapted to the `deposits[]/topUps[]` shape.
contract DepositDataBufferInvariantTest is Test {
    DepositDataBuffer internal buffer;
    DepositDataBufferHandler internal handler;

    address internal writer = makeAddr("writer");
    address internal processor = makeAddr("processor");

    function setUp() public {
        buffer = new DepositDataBuffer(makeAddr("admin"), writer, processor);
        handler = new DepositDataBufferHandler(buffer, writer, processor);

        targetContract(address(handler));

        bytes4[] memory selectors = new bytes4[](3);
        selectors[0] = DepositDataBufferHandler.queueRandom.selector;
        selectors[1] = DepositDataBufferHandler.requeueExisting.selector;
        selectors[2] = DepositDataBufferHandler.markProcessed.selector;
        targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));
    }

    /// @notice B1: lastQueuedIdx strictly tracks the number of successful submissions.
    function invariant_indexEqualsSuccessfulQueues() public {
        assertEq(buffer.lastQueuedIdx(), handler.ghost_successfulQueues(), "B1: lastQueuedIdx != successful queues");
    }

    /// @notice B2/B4: every submitted id stays retrievable with valid field lengths, and the stored
    ///         (batch, nonce) always hashes back to its id — the verifier's tamper-check property.
    function invariant_allIdsRetrievableAndBindToId() public {
        uint256 len = handler.ghost_queuedIdsLength();
        for (uint256 i = 0; i < len; i++) {
            bytes32 id = handler.ghost_queuedIdAt(i);
            (IDepositDataBuffer.DepositObject memory batch, uint256 nonce) = buffer.getDepositData(id);

            assertGt(batch.deposits.length, 0, "B2: submitted id returned empty data");
            assertEq(batch.deposits.length, handler.ghost_depositCounts(id), "B2: deposit count mismatch");

            for (uint256 j = 0; j < batch.deposits.length; j++) {
                assertEq(batch.deposits[j].pubkey.length, 48, "B4: invalid pubkey length");
                assertEq(batch.deposits[j].signature.length, 96, "B4: invalid signature length");
                assertGt(batch.deposits[j].amount, 0, "B4: zero amount");
            }

            assertEq(keccak256(abi.encode(batch, nonce)), id, "B3: stored batch+nonce must reproduce id");
        }
    }

    /// @notice B6: the per-batch processed flag matches the handler's ghost record.
    function invariant_processedIsConsistentPerBatch() public {
        uint256 len = handler.ghost_queuedIdsLength();
        for (uint256 i = 0; i < len; i++) {
            bytes32 id = handler.ghost_queuedIdAt(i);
            assertEq(buffer.isDepositDataProcessed(id), handler.ghost_processed(id), "B6: processed flag diverges");
        }
    }
}
