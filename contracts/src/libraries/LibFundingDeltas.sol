//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../interfaces/IDepositDataBuffer.sol";
import "../interfaces/IOperatorRegistry.1.sol";

/// @title Funding Delta builder
/// @author Alluvial Finance Inc.
/// @notice Pure aggregation of `Deposit[]` + `TopUp[]` into a sparse, ascending-by-operatorIndex
///         OperatorFundingDelta[].
library LibFundingDeltas {
    /// @notice Thrown when an entry references an operatorIdx outside the registered range.
    /// @param operatorIndex The offending operator index
    /// @param operatorCount The current number of registered operators (upper bound exclusive)
    error InvalidOperatorIndex(uint256 operatorIndex, uint256 operatorCount);

    /// @notice Aggregate initial deposits + top-ups into a sparse, ascending-by-operatorIndex
    ///         OperatorFundingDelta[]. Reverts InvalidOperatorIndex when any operatorIdx is
    ///         outside the registered range — both to honour the registry's contract and to
    ///         bound the memory allocated by the bucketing passes (a crafted operatorIdx could
    ///         otherwise OOG-DoS the batch via an oversized allocation).
    /// @dev    Pure aggregation only. Operator-status invariants (`active`, `requestedExits`
    ///         vs `exitedETH`) are NOT checked here; they are enforced by
    ///         `OperatorsRegistryV1.incrementFundedETH`.
    /// @dev    Initial-deposit pubkeys are placed in `newPubkeys[]` with their amounts aligned
    ///         1:1 in `depositAmounts[]`; top-up pubkeys are placed in `topUpPubkeys[]` with
    ///         their amounts aligned 1:1 in `topUpAmounts[]`. The registry emits the two classes
    ///         via distinct events so indexers do not conflate top-ups with newly funded
    ///         validator keys.
    /// @param deposits The initial deposits to aggregate
    /// @param topUps The top-ups to aggregate
    /// @param operatorCount The current number of registered operators (upper bound exclusive)
    /// @return deltas The aggregated per-operator deltas, sorted by operatorIndex
    function build(
        IDepositDataBuffer.Deposit[] memory deposits,
        IDepositDataBuffer.TopUp[] memory topUps,
        uint256 operatorCount
    ) internal pure returns (IOperatorsRegistryV1.OperatorFundingDelta[] memory deltas) {
        if (deposits.length == 0 && topUps.length == 0) {
            return new IOperatorsRegistryV1.OperatorFundingDelta[](0);
        }

        // Pass 1: validate operator indices and bucket-aggregate amounts and per-class key counts.
        // Buckets are sized to operatorCount rather than highestOpIdx+1 so the previous
        // index-caching pass over inputs is no longer needed.
        (uint256[] memory amountPerOp, uint256[] memory depositCountPerOp, uint256[] memory topUpCountPerOp) =
            _bucketCounts(deposits, topUps, operatorCount);

        // Pass 2: allocate sparse deltas in ascending operator-index order, each pre-sized for
        // its deposit and top-up arrays. Returns deltaIdxByOp to map operatorIdx -> deltas index.
        uint256[] memory deltaIdxByOp;
        (deltas, deltaIdxByOp) = _allocateDeltas(operatorCount, amountPerOp, depositCountPerOp, topUpCountPerOp);

        // Pass 3: fill per-operator pubkeys + amounts per class, preserving input order.
        _fillDeposits(deposits, deltas, deltaIdxByOp, operatorCount);
        _fillTopUps(topUps, deltas, deltaIdxByOp, operatorCount);
    }

    /// @dev Pass 1 helper: split into its own frame to keep `build`'s stack shallow enough for
    ///      coverage builds (viaIR disabled).
    function _bucketCounts(
        IDepositDataBuffer.Deposit[] memory deposits,
        IDepositDataBuffer.TopUp[] memory topUps,
        uint256 operatorCount
    )
        private
        pure
        returns (uint256[] memory amountPerOp, uint256[] memory depositCountPerOp, uint256[] memory topUpCountPerOp)
    {
        amountPerOp = new uint256[](operatorCount);
        depositCountPerOp = new uint256[](operatorCount);
        topUpCountPerOp = new uint256[](operatorCount);

        uint256 depositCount = deposits.length;
        for (uint256 i = 0; i < depositCount; i++) {
            uint256 opIdx = deposits[i].operatorIdx;
            if (opIdx >= operatorCount) revert InvalidOperatorIndex(opIdx, operatorCount);
            amountPerOp[opIdx] += deposits[i].amount;
            depositCountPerOp[opIdx]++;
        }

        uint256 topUpCount = topUps.length;
        for (uint256 i = 0; i < topUpCount; i++) {
            uint256 opIdx = topUps[i].operatorIdx;
            if (opIdx >= operatorCount) revert InvalidOperatorIndex(opIdx, operatorCount);
            amountPerOp[opIdx] += topUps[i].amount;
            topUpCountPerOp[opIdx]++;
        }
    }

    /// @dev Pass 2 helper: counts populated buckets, allocates the sparse deltas array, and
    ///      pre-sizes per-class pubkey / amount arrays.
    function _allocateDeltas(
        uint256 operatorCount,
        uint256[] memory amountPerOp,
        uint256[] memory depositCountPerOp,
        uint256[] memory topUpCountPerOp
    ) private pure returns (IOperatorsRegistryV1.OperatorFundingDelta[] memory deltas, uint256[] memory deltaIdxByOp) {
        uint256 nonEmpty = 0;
        for (uint256 j = 0; j < operatorCount; j++) {
            if (depositCountPerOp[j] + topUpCountPerOp[j] > 0) ++nonEmpty;
        }

        deltas = new IOperatorsRegistryV1.OperatorFundingDelta[](nonEmpty);
        deltaIdxByOp = new uint256[](operatorCount);

        uint256 di = 0;
        for (uint256 j = 0; j < operatorCount; j++) {
            uint256 dc = depositCountPerOp[j];
            uint256 tc = topUpCountPerOp[j];
            if (dc + tc > 0) {
                deltas[di].operatorIndex = j;
                deltas[di].fundedETH = amountPerOp[j];
                deltas[di].newPubkeys = new bytes[](dc);
                deltas[di].depositAmounts = new uint256[](dc);
                deltas[di].topUpPubkeys = new bytes[](tc);
                deltas[di].topUpAmounts = new uint256[](tc);
                deltaIdxByOp[j] = di;
                ++di;
            }
        }
    }

    /// @dev Pass 3 helper for initial deposits.
    function _fillDeposits(
        IDepositDataBuffer.Deposit[] memory deposits,
        IOperatorsRegistryV1.OperatorFundingDelta[] memory deltas,
        uint256[] memory deltaIdxByOp,
        uint256 operatorCount
    ) private pure {
        uint256[] memory cursors = new uint256[](operatorCount);
        uint256 n = deposits.length;
        for (uint256 i = 0; i < n; i++) {
            uint256 opIdx = deposits[i].operatorIdx;
            uint256 d = deltaIdxByOp[opIdx];
            uint256 c = cursors[opIdx]++;
            deltas[d].newPubkeys[c] = deposits[i].pubkey;
            deltas[d].depositAmounts[c] = deposits[i].amount;
        }
    }

    /// @dev Pass 3 helper for top-ups.
    function _fillTopUps(
        IDepositDataBuffer.TopUp[] memory topUps,
        IOperatorsRegistryV1.OperatorFundingDelta[] memory deltas,
        uint256[] memory deltaIdxByOp,
        uint256 operatorCount
    ) private pure {
        uint256[] memory cursors = new uint256[](operatorCount);
        uint256 n = topUps.length;
        for (uint256 i = 0; i < n; i++) {
            uint256 opIdx = topUps[i].operatorIdx;
            uint256 d = deltaIdxByOp[opIdx];
            uint256 c = cursors[opIdx]++;
            deltas[d].topUpPubkeys[c] = topUps[i].pubkey;
            deltas[d].topUpAmounts[c] = topUps[i].amount;
        }
    }
}
