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
    /// @dev    Top-up pubkeys ARE included in the returned `newPublicKeys[]` so the registry
    ///         can emit a complete `FundedValidatorKeys` event for the batch.
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
        // key counts per operator. Buckets are sized to operatorCount rather than highestOpIdx+1
        // so the previous index-caching pass over inputs is no longer needed.
        uint256[] memory amountPerOp = new uint256[](operatorCount);
        uint256[] memory keyCountPerOp = new uint256[](operatorCount);
        for (uint256 i = 0; i < depositCount; i++) {
            uint256 opIdx = deposits[i].operatorIdx;
            if (opIdx >= operatorCount) revert InvalidOperatorIndex(opIdx, operatorCount);
            amountPerOp[opIdx] += deposits[i].amount;
            keyCountPerOp[opIdx]++;
        }
        for (uint256 i = 0; i < topUpCount; i++) {
            uint256 opIdx = topUps[i].operatorIdx;
            if (opIdx >= operatorCount) revert InvalidOperatorIndex(opIdx, operatorCount);
            amountPerOp[opIdx] += topUps[i].amount;
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

        // Pass 3 (over both arrays): fill per-operator pubkeys. Deposits come first, then top-ups,
        // preserving within-class ordering. Cross-class ordering matches the deposit-execution
        // order in ConsensusLayerDepositManager (deposits before top-ups).
        for (uint256 i = 0; i < depositCount; i++) {
            uint256 opIdx = deposits[i].operatorIdx;
            uint256 d = deltaIdxByOp[opIdx];
            deltas[d].newPublicKeys[keyCursors[opIdx]++] = deposits[i].pubkey;
        }
        for (uint256 i = 0; i < topUpCount; i++) {
            uint256 opIdx = topUps[i].operatorIdx;
            uint256 d = deltaIdxByOp[opIdx];
            deltas[d].newPublicKeys[keyCursors[opIdx]++] = topUps[i].pubkey;
        }
    }
}
