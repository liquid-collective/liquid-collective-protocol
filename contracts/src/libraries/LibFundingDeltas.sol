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
    /// @dev    Initial-deposit pubkeys are placed in `newPublicKeys[]`; top-up pubkeys are placed
    ///         in `topUpPublicKeys[]` with their amounts aligned 1:1 in `topUpAmounts[]`. The
    ///         registry emits the two classes via distinct events so indexers do not conflate
    ///         top-ups with newly funded validator keys.
    /// @param deposits The initial deposits to aggregate
    /// @param topUps The top-ups to aggregate
    /// @param operatorCount The current number of registered operators (upper bound exclusive)
    /// @return deltas The aggregated per-operator deltas, sorted by operatorIndex
    function build(
        IDepositDataBuffer.Deposit[] memory deposits,
        IDepositDataBuffer.TopUp[] memory topUps,
        uint256 operatorCount
    ) internal pure returns (IOperatorsRegistryV1.OperatorFundingDelta[] memory deltas) {
        uint256 depositCount = deposits.length;
        uint256 topUpCount = topUps.length;
        if (depositCount == 0 && topUpCount == 0) {
            return new IOperatorsRegistryV1.OperatorFundingDelta[](0);
        }

        // Pass 1 (over both arrays): validate operator indices and bucket-aggregate amounts and
        // per-class key counts per operator. Buckets are sized to operatorCount rather than
        // highestOpIdx+1 so the previous index-caching pass over inputs is no longer needed.
        uint256[] memory amountPerOp = new uint256[](operatorCount);
        uint256[] memory depositCountPerOp = new uint256[](operatorCount);
        uint256[] memory topUpCountPerOp = new uint256[](operatorCount);
        for (uint256 i = 0; i < depositCount; i++) {
            uint256 opIdx = deposits[i].operatorIdx;
            if (opIdx >= operatorCount) revert InvalidOperatorIndex(opIdx, operatorCount);
            amountPerOp[opIdx] += deposits[i].amount;
            depositCountPerOp[opIdx]++;
        }
        for (uint256 i = 0; i < topUpCount; i++) {
            uint256 opIdx = topUps[i].operatorIdx;
            if (opIdx >= operatorCount) revert InvalidOperatorIndex(opIdx, operatorCount);
            amountPerOp[opIdx] += topUps[i].amount;
            topUpCountPerOp[opIdx]++;
        }

        // Count populated buckets to size the deltas array. An operator is populated when it
        // received any deposit OR any top-up in this batch.
        uint256 nonEmpty = 0;
        for (uint256 j = 0; j < operatorCount; j++) {
            if (depositCountPerOp[j] + topUpCountPerOp[j] > 0) ++nonEmpty;
        }

        // Pass 2 (over buckets): allocate sparse deltas in ascending operator-index order, each
        // pre-sized for its deposit and top-up arrays.
        deltas = new IOperatorsRegistryV1.OperatorFundingDelta[](nonEmpty);
        uint256[] memory deltaIdxByOp = new uint256[](operatorCount);
        uint256[] memory depositCursors = new uint256[](operatorCount);
        uint256[] memory topUpCursors = new uint256[](operatorCount);
        uint256 di = 0;
        for (uint256 j = 0; j < operatorCount; j++) {
            if (depositCountPerOp[j] + topUpCountPerOp[j] > 0) {
                deltas[di].operatorIndex = j;
                deltas[di].fundedETH = amountPerOp[j];
                deltas[di].newPublicKeys = new bytes[](depositCountPerOp[j]);
                deltas[di].topUpPublicKeys = new bytes[](topUpCountPerOp[j]);
                deltas[di].topUpAmounts = new uint256[](topUpCountPerOp[j]);
                deltaIdxByOp[j] = di;
                ++di;
            }
        }

        // Pass 3: fill per-operator pubkeys per class, preserving input order within each class.
        for (uint256 i = 0; i < depositCount; i++) {
            uint256 opIdx = deposits[i].operatorIdx;
            uint256 d = deltaIdxByOp[opIdx];
            deltas[d].newPublicKeys[depositCursors[opIdx]++] = deposits[i].pubkey;
        }
        for (uint256 i = 0; i < topUpCount; i++) {
            uint256 opIdx = topUps[i].operatorIdx;
            uint256 d = deltaIdxByOp[opIdx];
            uint256 c = topUpCursors[opIdx]++;
            deltas[d].topUpPublicKeys[c] = topUps[i].pubkey;
            deltas[d].topUpAmounts[c] = topUps[i].amount;
        }
    }
}
