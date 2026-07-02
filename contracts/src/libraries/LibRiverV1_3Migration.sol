//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../interfaces/IRiver.1.sol";
import "../interfaces/IAttestationVerifier.1.sol";
import "../interfaces/components/IConsensusLayerDepositManager.1.sol";
import "../interfaces/components/IOracleManager.1.sol";

import "../state/river/InFlightDeposit.sol";
import "../state/river/TotalDepositedETH.sol";
import "../state/river/WithdrawalCredentials.sol";
import "../state/river/DepositContractAddress.sol";
import "../state/river/DepositedValidatorCount.sol";
import "../state/river/LastConsensusLayerReport.sol";
import "../state/river/ConsolidationCoverageFundAddress.sol";
import "../state/shared/AttestationVerifierAddress.sol";

/// @title Lib River V1.3 Migration
/// @author Alluvial Finance Inc.
/// @notice External library holding the one-shot `initRiverV1_3` migration body. Deployed as a
/// @notice separate contract and invoked via DELEGATECALL under River's `init(3)` modifier, so it
/// @notice reads and writes RiverV1's unstructured storage slots directly and its events surface
/// @notice from River's address. Extracting the initializer keeps RiverV1 under the EIP-170
/// @notice deployed-bytecode limit without putting any runtime logic behind a delegatecall.
library LibRiverV1_3Migration {
    /// @notice The size of a deposit to the consensus layer, mirroring ConsensusLayerDepositManagerV1.DEPOSIT_SIZE
    uint256 internal constant DEPOSIT_SIZE = 32 ether;

    /// @notice Performs the v1.3 migration: re-anchors the withdrawal credentials, wires the
    ///         AttestationVerifier and consolidation coverage fund, and migrates the accounting
    ///         from 0x01 to 0x02 semantics (TotalDepositedETH / InFlightDeposit / report fields).
    /// @dev DELEGATECALL target: `address(this)` is RiverV1.
    /// @param _withdrawalCredentials The withdrawal credentials to apply to all deposits
    /// @param _consolidationCoverageFund The address of the consolidation coverage fund
    /// @param _attestationVerifier The pre-initialized AttestationVerifier contract address
    function run(bytes32 _withdrawalCredentials, address _consolidationCoverageFund, address _attestationVerifier)
        external
    {
        if (_withdrawalCredentials == bytes32(0)) {
            revert IConsensusLayerDepositManagerV1.InvalidWithdrawalCredentials();
        }
        // Also rejects address(0) and codeless addresses: the staticcall to a target without code
        // returns empty returndata, which fails ABI decoding and reverts.
        if (IAttestationVerifierV1(_attestationVerifier).getRiver() != address(this)) {
            revert IRiverV1.InvalidAttestationVerifier();
        }

        // Mirrors ConsensusLayerDepositManagerV1.initConsensusLayerDepositManagerV1, re-run with
        // the already-stored deposit contract address (carry-over from initConsensusLayerDepositManagerV1_2)
        address depositContract = DepositContractAddress.get();
        DepositContractAddress.set(depositContract);
        emit IConsensusLayerDepositManagerV1.SetDepositContractAddress(depositContract);

        if (bytes1(_withdrawalCredentials) != 0x02) {
            revert IConsensusLayerDepositManagerV1.InvalidWithdrawalCredentialsPrefix();
        }
        WithdrawalCredentials.set(_withdrawalCredentials);
        emit IConsensusLayerDepositManagerV1.SetWithdrawalCredentials(_withdrawalCredentials);

        AttestationVerifierAddress.set(_attestationVerifier);
        emit IConsensusLayerDepositManagerV1.SetAttestationVerifier(_attestationVerifier);

        // accounting changes to move from 0x01 to 0x02 accounting

        ConsolidationCoverageFundAddress.set(_consolidationCoverageFund);
        emit IRiverV1.SetConsolidationCoverageFund(_consolidationCoverageFund);

        IOracleManagerV1.StoredConsensusLayerReport storage lastReport = LastConsensusLayerReport.get();
        uint32 clValidatorCount = lastReport.validatorsCount;
        uint256 depositedValidatorCount = DepositedValidatorCount.get();
        TotalDepositedETH.set(depositedValidatorCount * DEPOSIT_SIZE);
        if (clValidatorCount < depositedValidatorCount) {
            InFlightDeposit.set((depositedValidatorCount - clValidatorCount) * DEPOSIT_SIZE);
        } else {
            // explicit zero so a re-run on dirty storage cannot leak a stale value into
            // the totalDepositedActivatedETH calculation below
            InFlightDeposit.set(0);
        }

        // Update the two Pectra-era report fields in place; every other field keeps its stored value.
        lastReport.totalDepositedActivatedETH = depositedValidatorCount * DEPOSIT_SIZE - InFlightDeposit.get();
        // Explicit zero so a re-run on dirty storage cannot leak a stale value; consolidations
        // were not enabled before this version, so the correct starting value is 0.
        lastReport.totalExternalConsolidationsAmountReported = 0;
    }
}
