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

        // Pass 1 (over deposits): validate operator indices and bucket-aggregate amounts and key
        // counts per operator. Buckets are sized to operatorCount rather than highestOpIdx+1 so
        // the previous index-caching pass over `deposits` is no longer needed.
        uint256[] memory amountPerOp = new uint256[](operatorCount);
        uint256[] memory keyCountPerOp = new uint256[](operatorCount);
        for (uint256 i = 0; i < len; i++) {
            uint256 opIdx = deposits[i].operatorIdx;
            if (opIdx >= operatorCount) revert InvalidOperatorIndex(opIdx, operatorCount);
            amountPerOp[opIdx] += deposits[i].amount;
            keyCountPerOp[opIdx]++;
        }

        // Count populated buckets to size the deltas array.
        uint256 nonEmpty = 0;
        for (uint256 j = 0; j < operatorCount; j++) {
            if (keyCountPerOp[j] > 0) ++nonEmpty;
        }

        // Pass 2 (over buckets): allocate sparse deltas in ascending operator-index order.
        deltas = new IOperatorsRegistryV1.OperatorFundingDelta[](nonEmpty);
        uint256[] memory deltaIdxByOp = new uint256[](operatorCount);
        uint256[] memory keyCursors = new uint256[](operatorCount);
        uint256 di = 0;
        for (uint256 j = 0; j < operatorCount; j++) {
            if (keyCountPerOp[j] > 0) {
                deltas[di].operatorIndex = j;
                deltas[di].fundedETH = amountPerOp[j];
                deltas[di].newPublicKeys = new bytes[](keyCountPerOp[j]);
                deltaIdxByOp[j] = di;
                ++di;
            }
        }

        // Pass 3 (over deposits): fill per-operator pubkeys in deposit order.
        for (uint256 i = 0; i < len; i++) {
            uint256 opIdx = deposits[i].operatorIdx;
            uint256 d = deltaIdxByOp[opIdx];
            deltas[d].newPublicKeys[keyCursors[opIdx]++] = deposits[i].pubkey;
        }
    }
}
