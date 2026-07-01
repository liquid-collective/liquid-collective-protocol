//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "./interfaces/IRiver.1.sol";
import "./interfaces/IRiverConfigManager.1.sol";
import "./interfaces/IWithdraw.1.sol";
import "./interfaces/IAttestationVerifierPectraMigration.1.sol";
import "./interfaces/components/IConsensusLayerDepositManager.1.sol";
import "./interfaces/components/IOracleManager.1.sol";

import "./libraries/LibSanitize.sol";

import "./state/river/GlobalFee.sol";
import "./state/river/MetadataURI.sol";
import "./state/river/AllowlistAddress.sol";
import "./state/river/CollectorAddress.sol";
import "./state/river/ConsolidatorAddress.sol";
import "./state/river/CoverageFundAddress.sol";
import "./state/river/ConsolidationCoverageFundAddress.sol";
import "./state/river/ELFeeRecipientAddress.sol";
import "./state/river/DailyCommittableLimits.sol";
import "./state/river/KeeperAddress.sol";
import "./state/river/WithdrawalCredentials.sol";
import "./state/river/LastConsensusLayerReport.sol";
import "./state/river/DepositedValidatorCount.sol";
import "./state/river/TotalDepositedETH.sol";
import "./state/river/InFlightDeposit.sol";
import "./state/shared/AttestationVerifierAddress.sol";

/// @title River Config Manager (v1)
/// @author Alluvial Finance Inc.
/// @notice Holds the bodies of self-contained, state-mutating RiverV1 functions that River reaches via
///         DELEGATECALL, extracted to keep River's deployed bytecode under EIP-170. Each function runs
///         in River's storage context, so it reads/writes River's existing unstructured-storage slots
///         through the same state libraries and emits the same events (qualified to their declaring
///         interfaces so log topics are identical).
/// @dev    Functions are intentionally permissionless: they are only meaningful when delegatecalled by
///         River, which enforces access control in its forwarding stub before delegating. A direct call
///         to this standalone contract writes only its own (unused) storage and cannot move River funds —
///         the Pectra paths additionally revert because `Withdraw.consolidate` is `onlyRiver` and the
///         AttestationVerifier address read from this contract's storage is zero.
contract RiverConfigManagerV1 is IRiverConfigManagerV1 {
    /// @notice Canonical legacy validator deposit size (32 ETH); used for the V3 accounting migration.
    uint256 internal constant DEPOSIT_SIZE = 32 ether;

    /// @inheritdoc IRiverConfigManagerV1
    function setGlobalFee(uint256 _newFee) external {
        GlobalFee.set(_newFee);
        emit IRiverV1.SetGlobalFee(_newFee);
    }

    /// @inheritdoc IRiverConfigManagerV1
    function setAllowlist(address _newAllowlist) external {
        AllowlistAddress.set(_newAllowlist);
        emit IRiverV1.SetAllowlist(_newAllowlist);
    }

    /// @inheritdoc IRiverConfigManagerV1
    function setCollector(address _newCollector) external {
        CollectorAddress.set(_newCollector);
        emit IRiverV1.SetCollector(_newCollector);
    }

    /// @inheritdoc IRiverConfigManagerV1
    function setELFeeRecipient(address _newELFeeRecipient) external {
        ELFeeRecipientAddress.set(_newELFeeRecipient);
        emit IRiverV1.SetELFeeRecipient(_newELFeeRecipient);
    }

    /// @inheritdoc IRiverConfigManagerV1
    function setCoverageFund(address _newCoverageFund) external {
        CoverageFundAddress.set(_newCoverageFund);
        emit IRiverV1.SetCoverageFund(_newCoverageFund);
    }

    /// @inheritdoc IRiverConfigManagerV1
    function setConsolidationCoverageFund(address _newConsolidationCoverageFund) external {
        ConsolidationCoverageFundAddress.set(_newConsolidationCoverageFund);
        emit IRiverV1.SetConsolidationCoverageFund(_newConsolidationCoverageFund);
    }

    /// @inheritdoc IRiverConfigManagerV1
    function setMetadataURI(string memory _metadataURI) external {
        LibSanitize._notEmptyString(_metadataURI);
        MetadataURI.set(_metadataURI);
        emit IRiverV1.SetMetadataURI(_metadataURI);
    }

    /// @inheritdoc IRiverConfigManagerV1
    function setConsolidator(address _newConsolidator) external {
        ConsolidatorAddress.set(_newConsolidator);
        emit IRiverV1.SetConsolidator(_newConsolidator);
    }

    /// @inheritdoc IRiverConfigManagerV1
    function setDailyCommittableLimits(DailyCommittableLimits.DailyCommittableLimitsStruct memory _dcl) external {
        DailyCommittableLimits.set(_dcl);
        emit IRiverV1.SetMaxDailyCommittableAmounts(
            _dcl.minDailyNetCommittableAmount, _dcl.maxDailyRelativeCommittableAmount
        );
    }

    /// @inheritdoc IRiverConfigManagerV1
    function setKeeper(address _keeper) external {
        KeeperAddress.set(_keeper);
        emit IConsensusLayerDepositManagerV1.SetKeeper(_keeper);
    }

    /// @inheritdoc IRiverConfigManagerV1
    function selfConsolidation(bytes[] calldata pubkeys, uint256 maxFeePerConsolidation) external payable {
        IWithdrawV1.ConsolidationRequest[] memory requests =
            IAttestationVerifierPectraMigrationV1(AttestationVerifierAddress.get()).validateSelfConsolidation(pubkeys);
        address excessFeeRecipient = msg.sender;
        IWithdrawV1(payable(WithdrawalCredentials.getAddress())).consolidate{value: msg.value}(
            requests, maxFeePerConsolidation, excessFeeRecipient
        );
        emit IRiverV1.PectraConsolidationRequested(requests, maxFeePerConsolidation, excessFeeRecipient, msg.value);
    }

    /// @inheritdoc IRiverConfigManagerV1
    function consolidate(IWithdrawV1.ConsolidationRequest[] calldata requests, uint256 maxFeePerConsolidation)
        external
        payable
    {
        address excessFeeRecipient = msg.sender;
        IWithdrawV1(payable(WithdrawalCredentials.getAddress())).consolidate{value: msg.value}(
            requests, maxFeePerConsolidation, excessFeeRecipient
        );
        emit IRiverV1.PectraConsolidationRequested(requests, maxFeePerConsolidation, excessFeeRecipient, msg.value);
    }

    /// @inheritdoc IRiverConfigManagerV1
    function migrateV3Accounting() external {
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

        IOracleManagerV1.StoredConsensusLayerReport memory storedReport;
        storedReport.epoch = lastReport.epoch;
        storedReport.validatorsBalance = lastReport.validatorsBalance;
        storedReport.validatorsSkimmedBalance = lastReport.validatorsSkimmedBalance;
        storedReport.validatorsExitedBalance = lastReport.validatorsExitedBalance;
        storedReport.validatorsExitingBalance = lastReport.validatorsExitingBalance;
        storedReport.validatorsCount = clValidatorCount;
        storedReport.rebalanceDepositToRedeemMode = lastReport.rebalanceDepositToRedeemMode;
        storedReport.slashingContainmentMode = lastReport.slashingContainmentMode;
        storedReport.totalDepositedActivatedETH = depositedValidatorCount * DEPOSIT_SIZE - InFlightDeposit.get();
        /// We don't set the totalExternalConsolidationsAmountReported here because consolidations were not enabled before this version.
        /// And the default value will be 0, so we don't need to set it here.
        LastConsensusLayerReport.set(storedReport);
    }
}
