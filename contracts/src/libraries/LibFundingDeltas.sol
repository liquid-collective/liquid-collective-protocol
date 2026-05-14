//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../interfaces/IDepositDataBuffer.sol";
import "../interfaces/IOperatorRegistry.1.sol";

/// @title Funding Delta builder
/// @author Alluvial Finance Inc.
/// @notice Pure aggregation of a flat DepositObject[] into a sparse, ascending-by-operatorIndex
///         OperatorFundingDelta[].
library LibFundingDeltas {
    /// @notice Thrown when a deposit references an operatorIdx outside the registered range.
    /// @param operatorIndex The offending operator index
    /// @param operatorCount The current number of registered operators (upper bound exclusive)
    error InvalidOperatorIndex(uint256 operatorIndex, uint256 operatorCount);

    /// @notice Aggregate a flat list of DepositObjects into a sparse, ascending-by-operatorIndex
    ///         OperatorFundingDelta[]. Reverts InvalidOperatorIndex when any operatorIdx is
    ///         outside the registered range — both to honour the registry's contract and to
    ///         bound the memory allocated by the bucketing passes (a crafted operatorIdx could
    ///         otherwise OOG-DoS the batch via an oversized allocation).
    /// @param deposits The deposit objects to aggregate
    /// @param operatorCount The current number of registered operators (upper bound exclusive)
    /// @return deltas The aggregated per-operator deltas, sorted by operatorIndex
    function build(IDepositDataBuffer.DepositObject[] memory deposits, uint256 operatorCount)
        internal
        pure
        returns (IOperatorsRegistryV1.OperatorFundingDelta[] memory deltas)
    {
        uint256 len = deposits.length;
        if (len == 0) {
            return new IOperatorsRegistryV1.OperatorFundingDelta[](0);
        }

        // Pass 1: cache operator indices, validate them, find highestOpIdx.
        uint256[] memory opIndices = new uint256[](len);
        uint256 highestOpIdx = 0;
        for (uint256 i = 0; i < len; i++) {
            uint256 opIdx = deposits[i].operatorIdx;
            if (opIdx >= operatorCount) revert InvalidOperatorIndex(opIdx, operatorCount);
            opIndices[i] = opIdx;
            if (opIdx > highestOpIdx) highestOpIdx = opIdx;
        }

        // Pass 2: bucket-aggregate amounts and key counts per operator.
        uint256 buckets = highestOpIdx + 1;
        uint256[] memory amountPerOp = new uint256[](buckets);
        uint256[] memory keyCountPerOp = new uint256[](buckets);
        for (uint256 i = 0; i < len; i++) {
            uint256 opIdx = opIndices[i];
            amountPerOp[opIdx] += deposits[i].amount;
            keyCountPerOp[opIdx]++;
        }

        // Count populated buckets to size the deltas array.
        uint256 nonEmpty = 0;
        for (uint256 j = 0; j < buckets; j++) {
            if (keyCountPerOp[j] > 0) ++nonEmpty;
        }

        // Pass 3: allocate sparse deltas in ascending operator-index order.
        deltas = new IOperatorsRegistryV1.OperatorFundingDelta[](nonEmpty);
        uint256[] memory deltaIdxByOp = new uint256[](buckets);
        uint256[] memory keyCursors = new uint256[](buckets);
        uint256 di = 0;
        for (uint256 j = 0; j < buckets; j++) {
            if (keyCountPerOp[j] > 0) {
                deltas[di].operatorIndex = j;
                deltas[di].fundedETH = amountPerOp[j];
                deltas[di].newPublicKeys = new bytes[](keyCountPerOp[j]);
                deltaIdxByOp[j] = di;
                ++di;
            }
        }

        // Pass 4: fill per-operator pubkeys in deposit order.
        for (uint256 i = 0; i < len; i++) {
            uint256 opIdx = opIndices[i];
            uint256 d = deltaIdxByOp[opIdx];
            deltas[d].newPublicKeys[keyCursors[opIdx]++] = deposits[i].pubkey;
        }
    }
}
