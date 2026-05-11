//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../interfaces/components/IOracleManager.1.sol";
import "../state/river/AttestationVerifierAddress.sol";
import "../state/river/DepositContractAddress.sol";
import "../state/river/DepositedValidatorCount.sol";
import "../state/river/InFlightDeposit.sol";
import "../state/river/LastConsensusLayerReport.sol";
import "../state/river/TotalDepositedETH.sol";
import "../state/river/WithdrawalCredentials.sol";

/// @title LibRiverV1_3InitMigration
/// @author Alluvial Finance Inc.
/// @notice External library that holds the body of `RiverV1.initRiverV1_3`.
///         Extracted out of River to reclaim the upgrade-init bytecode (this
///         code only runs once at upgrade time but otherwise lives in River's
///         deployed bytecode forever, contributing ~600 B that is the diff
///         between fitting under EIP-170 and not).
/// @dev    Functions are `external` so Solidity emits a DELEGATECALL at the call
///         site; the library is deployed once and Foundry links its address into
///         the consumer's bytecode automatically. State writes target the caller's
///         (River's) storage because of DELEGATECALL. Event topics are identical
///         regardless of the emitting contract, so indexers see emissions from
///         River's address as if River had emitted them directly.
library LibRiverV1_3InitMigration {
    // Match the event signatures used elsewhere so topic0 is unchanged.
    event SetDepositContractAddress(address indexed depositContract);
    event SetWithdrawalCredentials(bytes32 withdrawalCredentials);
    event SetAttestationVerifier(address indexed attestationVerifier);

    /// @notice Run the full v1.3 init: reset deposit contract + withdrawal credentials
    ///         (carried over from the prior init flow), wire the AttestationVerifier
    ///         sibling, and run the 0x01 → 0x02 accounting migration that rebuilds
    ///         `LastConsensusLayerReport` with the new `totalDepositedActivatedETH`
    ///         field and seeds `TotalDepositedETH` and `InFlightDeposit`.
    /// @param  _withdrawalCredentials The withdrawal credentials to apply to all deposits
    /// @param  _attestationVerifier  The pre-initialized AttestationVerifier
    /// @param  _depositSize           Wei per validator (River's DEPOSIT_SIZE constant)
    function runInitV1_3(bytes32 _withdrawalCredentials, address _attestationVerifier, uint256 _depositSize) external {
        // Re-emit deposit-contract address (carry-over from prior initConsensusLayerDepositManagerV1_2 call)
        address depositContract = DepositContractAddress.get();
        DepositContractAddress.set(depositContract);
        emit SetDepositContractAddress(depositContract);

        WithdrawalCredentials.set(_withdrawalCredentials);
        emit SetWithdrawalCredentials(_withdrawalCredentials);

        AttestationVerifierAddress.set(_attestationVerifier);
        emit SetAttestationVerifier(_attestationVerifier);

        IOracleManagerV1.StoredConsensusLayerReport storage lastReport = LastConsensusLayerReport.get();
        uint32 clValidatorCount = lastReport.validatorsCount;
        uint256 depositedValidatorCount = DepositedValidatorCount.get();
        TotalDepositedETH.set(depositedValidatorCount * _depositSize);
        if (clValidatorCount < depositedValidatorCount) {
            InFlightDeposit.set((depositedValidatorCount - clValidatorCount) * _depositSize);
        } else {
            // explicit zero so a re-run on dirty storage cannot leak a stale value into
            // the totalDepositedActivatedETH calculation below
            InFlightDeposit.set(0);
        }

        IOracleManagerV1.StoredConsensusLayerReport memory storedReport;
        storedReport.epoch = lastReport.epoch;
        storedReport.validatorsBalance = lastReport.validatorsBalance;
        storedReport.validatorsSkimmedBalance = lastReport.validatorsSkimmedBalance;
        storedReport.validatorsExitedBalance = lastReport.validatorsExitedBalance;
        storedReport.validatorsExitingBalance = lastReport.validatorsExitingBalance;
        storedReport.validatorsCount = clValidatorCount;
        storedReport.rebalanceDepositToRedeemMode = lastReport.rebalanceDepositToRedeemMode;
        storedReport.slashingContainmentMode = lastReport.slashingContainmentMode;
        // subtract the in flight ETH to get the total deposited activated ETH
        storedReport.totalDepositedActivatedETH = depositedValidatorCount * _depositSize - InFlightDeposit.get();
        LastConsensusLayerReport.set(storedReport);
    }
}
