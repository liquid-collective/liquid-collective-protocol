//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "./interfaces/IDepositDataBuffer.sol";

import "./components/DepositDataBufferBase.sol";

/// @title DepositDataBuffer (v1)
/// @author Alluvial Finance Inc.
/// @notice Non-upgradeable contract that buffers pre-committed validator deposit batches on-chain.
///         A trusted producer submits batches; off-chain daemons and the AttestationVerifier read them
///         back by id. Each submission is uniquely addressable because the batch nonce (`lastQueuedIdx`
///         at submit time) is folded into the id, so byte-identical batches submitted twice never
///         collide.
/// @dev The buffer owns the authoritative `processed` flag: only the processor may flip it via
///      `markDepositDataProcessed`, and `isDepositDataProcessed` is consulted before each deposit to
///      reject replays. Withdrawal credentials are intentionally NOT stored — the canonical withdrawal
///      credentials are supplied by the processor at deposit time and used for BLS verification and the
///      official deposit-contract call, so the buffer producer is never trusted on that field.
contract DepositDataBuffer is DepositDataBufferBase, IDepositDataBuffer {
    /// @dev depositDataBufferId => stored deposit batch.
    mapping(bytes32 => DepositObject) internal _batches;

    /// @param admin     The admin address, able to rotate the producer.
    /// @param producer  The producer address authorized to submit deposit batches.
    /// @param processor The address permitted to mark deposit data processed.
    constructor(address admin, address producer, address processor) DepositDataBufferBase(admin, producer, processor) {}

    /// @inheritdoc IDepositDataBuffer
    /// @dev The id is hashed here, over `DepositObject` itself, rather than inside
    ///      `_submitDepositData`: that is the same Solidity type the AttestationVerifier re-encodes
    ///      from the stored batch, so the two sides cannot drift apart.
    /// @dev `batch` stays `calldata` to enable the direct calldata-to-storage copy at the end;
    ///      switching it to `memory` only compiles under via-ir, which breaks coverage.
    function submitDepositData(bytes32 depositDataBufferId, DepositObject calldata batch) external onlyProducer {
        uint256 topUpCount = batch.topUps.length;

        // Submission-time validation is stateless — no BLS signature is verified here — so the
        // withdrawal credentials play no part and are passed as zero. The canonical credentials are
        // supplied by the processor at deposit time and never stored by the buffer.
        _verifyInitialDeposits(standardizeDeposits(batch.deposits, bytes32(0)));
        for (uint256 i; i < topUpCount; ++i) {
            _verifyTopUp(i, batch.topUps[i].pubkey, batch.topUps[i].amount);
        }

        _submitDepositData(
            depositDataBufferId,
            keccak256(abi.encode(batch, lastQueuedIdx)),
            batch.deposits.length,
            topUpCount
        );

        _batches[depositDataBufferId] = batch;
    }

    /// @inheritdoc IDepositDataBuffer
    function getDepositData(bytes32 depositDataBufferId)
        external
        view
        returns (DepositObject memory batch, uint256 nonce)
    {
        if (!_exists[depositDataBufferId]) revert DepositDataBufferIdNotFound(depositDataBufferId);
        return (_batches[depositDataBufferId], _nonce[depositDataBufferId]);
    }
}
