//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "./interfaces/IAttestationVerifier.1.sol";
import "./interfaces/IRiver.1.sol";
import "./interfaces/IRiverV1_3Migration.1.sol";
import "./interfaces/components/IConsensusLayerDepositManager.1.sol";
import "./interfaces/components/IOracleManager.1.sol";

import "./state/river/ConsolidationCoverageFundAddress.sol";
import "./state/river/ConsolidationManagerAddress.sol";
import "./state/river/DepositContractAddress.sol";
import "./state/river/DepositExecutorAddress.sol";
import "./state/river/DepositedValidatorCount.sol";
import "./state/river/FundingDeltasBuilderAddress.sol";
import "./state/river/InFlightDeposit.sol";
import "./state/river/LastConsensusLayerReport.sol";
import "./state/river/TotalDepositedETH.sol";
import "./state/river/WithdrawalCredentials.sol";
import "./state/shared/AttestationVerifierAddress.sol";

/// @title River V1.3 Migration Helper
/// @author Alluvial Finance Inc.
/// @notice One-time delegatecall target used by RiverV1.initRiverV1_3.
contract RiverV1_3Migration is IRiverV1_3Migration {
    uint256 internal constant DEPOSIT_SIZE = 32 ether;

    /// @inheritdoc IRiverV1_3Migration
    function migrate(
        bytes32 _withdrawalCredentials,
        address _consolidationCoverageFund,
        address _attestationVerifier,
        address _consolidationManager,
        address _fundingDeltasBuilder,
        address _depositExecutor
    ) external {
        if (_withdrawalCredentials == bytes32(0)) {
            revert IConsensusLayerDepositManagerV1.InvalidWithdrawalCredentials();
        }
        if (bytes1(_withdrawalCredentials) != 0x02) {
            revert IConsensusLayerDepositManagerV1.InvalidWithdrawalCredentialsPrefix();
        }
        if (_attestationVerifier == address(0) || _attestationVerifier.code.length == 0) {
            revert IRiverV1.InvalidAttestationVerifier();
        }
        if (IAttestationVerifierV1(_attestationVerifier).getRiver() != address(this)) {
            revert IRiverV1.InvalidAttestationVerifier();
        }

        address depositContract = DepositContractAddress.get();
        DepositContractAddress.set(depositContract);
        emit IConsensusLayerDepositManagerV1.SetDepositContractAddress(depositContract);

        WithdrawalCredentials.set(_withdrawalCredentials);
        emit IConsensusLayerDepositManagerV1.SetWithdrawalCredentials(_withdrawalCredentials);

        AttestationVerifierAddress.set(_attestationVerifier);
        emit IConsensusLayerDepositManagerV1.SetAttestationVerifier(_attestationVerifier);

        ConsolidationCoverageFundAddress.set(_consolidationCoverageFund);
        emit IRiverV1.SetConsolidationCoverageFund(_consolidationCoverageFund);

        ConsolidationManagerAddress.set(_consolidationManager);
        emit IRiverV1.SetConsolidationManager(_consolidationManager);

        FundingDeltasBuilderAddress.set(_fundingDeltasBuilder);
        DepositExecutorAddress.set(_depositExecutor);

        IOracleManagerV1.StoredConsensusLayerReport storage lastReport = LastConsensusLayerReport.get();
        uint32 clValidatorCount = lastReport.validatorsCount;
        uint256 depositedValidatorCount = DepositedValidatorCount.get();
        uint256 totalDepositedETH = depositedValidatorCount * DEPOSIT_SIZE;
        TotalDepositedETH.set(totalDepositedETH);

        uint256 inFlightDeposit = 0;
        if (clValidatorCount < depositedValidatorCount) {
            inFlightDeposit = (depositedValidatorCount - clValidatorCount) * DEPOSIT_SIZE;
        }
        InFlightDeposit.set(inFlightDeposit);

        IOracleManagerV1.StoredConsensusLayerReport memory storedReport;
        storedReport.epoch = lastReport.epoch;
        storedReport.validatorsBalance = lastReport.validatorsBalance;
        storedReport.validatorsSkimmedBalance = lastReport.validatorsSkimmedBalance;
        storedReport.validatorsExitedBalance = lastReport.validatorsExitedBalance;
        storedReport.validatorsExitingBalance = lastReport.validatorsExitingBalance;
        storedReport.validatorsCount = clValidatorCount;
        storedReport.rebalanceDepositToRedeemMode = lastReport.rebalanceDepositToRedeemMode;
        storedReport.slashingContainmentMode = lastReport.slashingContainmentMode;
        storedReport.totalDepositedActivatedETH = totalDepositedETH - inFlightDeposit;
        LastConsensusLayerReport.set(storedReport);
    }
}
