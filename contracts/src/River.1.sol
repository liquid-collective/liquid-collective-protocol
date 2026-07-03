//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "./interfaces/IRiver.1.sol";
import "./interfaces/IWithdraw.1.sol";
import "./interfaces/IAllowlist.1.sol";
import "./interfaces/IProtocolVersion.sol";
import "./interfaces/IOperatorRegistry.1.sol";
import "./interfaces/IAttestationVerifier.1.sol";
import "./interfaces/IAttestationVerifierPectraMigration.1.sol";
import "./interfaces/IExternalConsolidationRecipientMapping.1.sol";

import "./components/SharesManager.1.sol";
import "./components/OracleManager.1.sol";
import "./components/UserDepositManager.1.sol";
import "./components/ConsensusLayerDepositManager.1.sol";

import "./Initializable.sol";
import "./Administrable.sol";

import "./libraries/LibErrors.sol";
import "./libraries/LibFundingDeltas.sol";
import "./libraries/LibAllowlistMasks.sol";
import "./interfaces/IDepositDataBuffer.sol";

import "./state/river/GlobalFee.sol";
import "./state/river/MetadataURI.sol";
import "./state/river/BalanceToRedeem.sol";
import "./state/river/AllowlistAddress.sol";
import "./state/river/CollectorAddress.sol";
import "./state/river/TotalDepositedETH.sol";
import "./state/river/ConsolidatorAddress.sol";
import "./state/river/CoverageFundAddress.sol";
import "./state/river/ConsolidationCoverageFundAddress.sol";
import "./state/river/RedeemManagerAddress.sol";
import "./state/river/ELFeeRecipientAddress.sol";
import "./state/river/DepositedValidatorCount.sol";
import "./state/river/LastConsensusLayerReport.sol";
import "./state/river/ConsolidationCoverageFundAddress.sol";
import "./state/river/ExternalConsolidationRecipientMappingAddress.sol";
import "./state/shared/OperatorsRegistryAddress.sol";
import "./state/shared/AttestationVerifierAddress.sol";

/// @title River (v1)
/// @author Alluvial Finance Inc.
/// @notice This contract merges all the manager contracts and implements all the virtual methods stitching all components together
contract RiverV1 is
    ConsensusLayerDepositManagerV1,
    UserDepositManagerV1,
    SharesManagerV1,
    OracleManagerV1,
    Initializable,
    Administrable,
    IProtocolVersion,
    IRiverV1
{
    /// @notice Modifier to check if the caller is the consolidator
    modifier onlyConsolidator() {
        if (msg.sender != ConsolidatorAddress.get()) {
            revert OnlyConsolidator();
        }
        _;
    }

    /// @inheritdoc IRiverV1
    function initRiverV1_3(
        bytes32 _withdrawalCredentials,
        address _consolidationCoverageFund,
        address _attestationVerifier,
        address _externalConsolidationRecipientMapping,
        address _consolidator
    ) external init(3) {
        if (_withdrawalCredentials == bytes32(0)) {
            revert InvalidWithdrawalCredentials();
        }
        if (_attestationVerifier == address(0) || _attestationVerifier.code.length == 0) {
            revert InvalidAttestationVerifier();
        }
        if (IAttestationVerifierV1(_attestationVerifier).getRiver() != address(this)) {
            revert InvalidAttestationVerifier();
        }

        // Re-emit deposit-contract address (carry-over from prior initConsensusLayerDepositManagerV1_2 call)
        address depositContract = DepositContractAddress.get();
        DepositContractAddress.set(depositContract);
        emit SetDepositContractAddress(depositContract);

        ConsensusLayerDepositManagerV1.initConsensusLayerDepositManagerV1(
            DepositContractAddress.get(), _withdrawalCredentials
        );

        AttestationVerifierAddress.set(_attestationVerifier);
        emit SetAttestationVerifier(_attestationVerifier);

        ExternalConsolidationRecipientMappingAddress.set(_externalConsolidationRecipientMapping);
        emit SetExternalConsolidationRecipientMapping(_externalConsolidationRecipientMapping);

        // accounting changes to move from 0x01 to 0x02 accounting

        ConsolidationCoverageFundAddress.set(_consolidationCoverageFund);
        emit SetConsolidationCoverageFund(_consolidationCoverageFund);

        _setConsolidator(_consolidator);

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

    /// @inheritdoc IRiverV1
    function getGlobalFee() external view returns (uint256) {
        return GlobalFee.get();
    }

    /// @inheritdoc IRiverV1
    function getAllowlist() external view returns (address) {
        return AllowlistAddress.get();
    }

    /// @inheritdoc IRiverV1
    function getCollector() external view returns (address) {
        return CollectorAddress.get();
    }

    /// @inheritdoc IRiverV1
    function getELFeeRecipient() external view returns (address) {
        return ELFeeRecipientAddress.get();
    }

    /// @inheritdoc IRiverV1
    function getCoverageFund() external view returns (address) {
        return CoverageFundAddress.get();
    }

    /// @inheritdoc IRiverV1
    function getConsolidationCoverageFund() external view returns (address) {
        return ConsolidationCoverageFundAddress.get();
    }

    /// @inheritdoc IRiverV1
    function getRedeemManager() external view returns (address) {
        return RedeemManagerAddress.get();
    }

    /// @inheritdoc IRiverV1
    function getConsolidator() external view returns (address) {
        return ConsolidatorAddress.get();
    }

    /// @inheritdoc IRiverV1
    function getMetadataURI() external view returns (string memory) {
        return MetadataURI.get();
    }

    /// @inheritdoc IRiverV1
    function getDailyCommittableLimits()
        external
        view
        returns (DailyCommittableLimits.DailyCommittableLimitsStruct memory)
    {
        return DailyCommittableLimits.get();
    }

    /// @inheritdoc IRiverV1
    function setDailyCommittableLimits(DailyCommittableLimits.DailyCommittableLimitsStruct memory _dcl)
        external
        onlyAdmin
    {
        _setDailyCommittableLimits(_dcl);
    }

    function setKeeper(address _keeper) external onlyAdmin {
        _setKeeper(_keeper);
    }

    /// @inheritdoc IRiverV1
    function getBalanceToRedeem() external view returns (uint256) {
        return BalanceToRedeem.get();
    }

    /// @inheritdoc IRiverV1
    function getBalanceToConsolidate() external view returns (uint256) {
        return ConsolidationBuffer.get();
    }

    /// @inheritdoc IRiverV1
    function mintLsETHForConsolidation(IAttestationVerifierV1.ConsolidationObject calldata consolidation)
        external
        onlyConsolidator
    {
        // we check the allowlist first to fail fast if the withdrawalAddress/recipient is denied
        IAllowlistV1 allowlist = IAllowlistV1(AllowlistAddress.get());
        allowlist.onlyAllowed(consolidation.withdrawalAddress, LibAllowlistMasks.CONSOLIDATE_MASK);

        address recipient = IExternalConsolidationRecipientMappingV1(ExternalConsolidationRecipientMappingAddress.get())
            .resolveRecipient(consolidation.withdrawalAddress);

        if (recipient != consolidation.withdrawalAddress && allowlist.isDenied(recipient)) {
            revert Denied(recipient);
        }

        IAttestationVerifierV1 verifier = IAttestationVerifierV1(AttestationVerifierAddress.get());
        // Since the verifier validates the consolidation object, we do not validate it here
        // this reverts if the consolidation is invalid
        verifier.validateConsolidation(consolidation);

        uint256 oldConsolidationBuffer = ConsolidationBuffer.get();
        _setConsolidationBuffer(oldConsolidationBuffer, oldConsolidationBuffer + consolidation.totalAmount);
        uint256 sharesMinted = _mintShares(recipient, consolidation.totalAmount);
        emit LsETHMintedForConsolidation(recipient, consolidation.totalAmount, sharesMinted);
    }

    /// @inheritdoc IRiverV1
    function resolveRedeemRequests(uint32[] calldata _redeemRequestIds)
        external
        view
        returns (int64[] memory withdrawalEventIds)
    {
        return IRedeemManagerV1(RedeemManagerAddress.get()).resolveRedeemRequests(_redeemRequestIds);
    }

    /// @inheritdoc IRiverV1
    function requestRedeem(uint256 _lsETHAmount, address _recipient)
        external
        whenNotSlashingContainmentMode
        returns (uint32 _redeemRequestId)
    {
        IAllowlistV1(AllowlistAddress.get()).onlyAllowed(msg.sender, LibAllowlistMasks.REDEEM_MASK);
        if (IAllowlistV1(AllowlistAddress.get()).isDenied(_recipient)) {
            revert IRedeemManagerV1.RecipientIsDenied();
        }
        _transfer(msg.sender, address(this), _lsETHAmount);
        return IRedeemManagerV1(RedeemManagerAddress.get()).requestRedeem(_lsETHAmount, _recipient, msg.sender);
    }

    /// @inheritdoc IRiverV1
    function claimRedeemRequests(uint32[] calldata _redeemRequestIds, uint32[] calldata _withdrawalEventIds)
        external
        returns (uint8[] memory claimStatuses)
    {
        return IRedeemManagerV1(RedeemManagerAddress.get())
            .claimRedeemRequests(_redeemRequestIds, _withdrawalEventIds, true, type(uint16).max);
    }

    /// @inheritdoc IRiverV1
    function setGlobalFee(uint256 _newFee) external onlyAdmin {
        GlobalFee.set(_newFee);
        emit SetGlobalFee(_newFee);
    }

    /// @inheritdoc IRiverV1
    function setAllowlist(address _newAllowlist) external onlyAdmin {
        AllowlistAddress.set(_newAllowlist);
        emit SetAllowlist(_newAllowlist);
    }

    /// @inheritdoc IRiverV1
    function setCollector(address _newCollector) external onlyAdmin {
        CollectorAddress.set(_newCollector);
        emit SetCollector(_newCollector);
    }

    /// @inheritdoc IRiverV1
    function setELFeeRecipient(address _newELFeeRecipient) external onlyAdmin {
        ELFeeRecipientAddress.set(_newELFeeRecipient);
        emit SetELFeeRecipient(_newELFeeRecipient);
    }

    /// @inheritdoc IRiverV1
    function setCoverageFund(address _newCoverageFund) external onlyAdmin {
        CoverageFundAddress.set(_newCoverageFund);
        emit SetCoverageFund(_newCoverageFund);
    }

    /// @inheritdoc IRiverV1
    function setConsolidationCoverageFund(address _newConsolidationCoverageFund) external onlyAdmin {
        ConsolidationCoverageFundAddress.set(_newConsolidationCoverageFund);
        emit SetConsolidationCoverageFund(_newConsolidationCoverageFund);
    }

    /// @inheritdoc IRiverV1
    function setMetadataURI(string memory _metadataURI) external onlyAdmin {
        LibSanitize._notEmptyString(_metadataURI);
        MetadataURI.set(_metadataURI);
        emit SetMetadataURI(_metadataURI);
    }

    /// @inheritdoc IRiverV1
    function setConsolidator(address _newConsolidator) external onlyAdmin {
        _setConsolidator(_newConsolidator);
    }

    /// @notice Internal utility to set the consolidator address
    /// @param _newConsolidator The new consolidator address
    function _setConsolidator(address _newConsolidator) internal {
        ConsolidatorAddress.set(_newConsolidator);
        emit SetConsolidator(_newConsolidator);
    }

    /// @inheritdoc IRiverV1
    function getOperatorsRegistry() external view returns (address) {
        return OperatorsRegistryAddress.get();
    }

    /// @inheritdoc IRiverV1
    function sendELFees() external payable {
        if (msg.sender != ELFeeRecipientAddress.get()) {
            revert LibErrors.Unauthorized(msg.sender);
        }
    }

    /// @inheritdoc IRiverV1
    function sendCLFunds() external payable {
        if (msg.sender != WithdrawalCredentials.getAddress()) {
            revert LibErrors.Unauthorized(msg.sender);
        }
    }

    /// @inheritdoc IRiverV1
    function sendCoverageFunds() external payable {
        if (msg.sender != CoverageFundAddress.get()) {
            revert LibErrors.Unauthorized(msg.sender);
        }
    }

    /// @inheritdoc IRiverV1
    function sendConsolidationCoverageFunds() external payable {
        if (msg.sender != ConsolidationCoverageFundAddress.get()) {
            revert LibErrors.Unauthorized(msg.sender);
        }
    }

    /// @inheritdoc IRiverV1
    function sendRedeemManagerExceedingFunds() external payable {
        if (msg.sender != RedeemManagerAddress.get()) {
            revert LibErrors.Unauthorized(msg.sender);
        }
    }

    /// @inheritdoc IRiverV1
    function selfConsolidation(bytes[] calldata pubkeys, uint256 maxFeePerConsolidation)
        external
        payable
        onlyConsolidator
    {
        IWithdrawV1.ConsolidationRequest[] memory requests = IAttestationVerifierPectraMigrationV1(
                AttestationVerifierAddress.get()
            ).validateSelfConsolidation(pubkeys);
        address excessFeeRecipient = msg.sender;
        IWithdrawV1(payable(WithdrawalCredentials.getAddress())).consolidate{value: msg.value}(
            requests, maxFeePerConsolidation, excessFeeRecipient
        );
        emit PectraConsolidationRequested(requests, maxFeePerConsolidation, excessFeeRecipient, msg.value);
    }

    /// @inheritdoc IRiverV1
    function consolidate(IWithdrawV1.ConsolidationRequest[] calldata requests, uint256 maxFeePerConsolidation)
        external
        payable
        onlyConsolidator
    {
        address excessFeeRecipient = msg.sender;
        IWithdrawV1(payable(WithdrawalCredentials.getAddress())).consolidate{value: msg.value}(
            requests, maxFeePerConsolidation, excessFeeRecipient
        );
        emit PectraConsolidationRequested(requests, maxFeePerConsolidation, excessFeeRecipient, msg.value);
    }

    /// @notice Overridden handler to pass the system admin inside components
    /// @return The address of the admin
    function _getRiverAdmin()
        internal
        view
        override(OracleManagerV1, ConsensusLayerDepositManagerV1)
        returns (address)
    {
        return Administrable._getAdmin();
    }

    /// @notice Overridden handler to increment the funded ETH for the operators
    /// @param _deltas The per-operator funding deltas (sorted by operatorIndex)
    function _incrementFundedETH(IOperatorsRegistryV1.OperatorFundingDelta[] memory _deltas) internal override {
        IOperatorsRegistryV1(OperatorsRegistryAddress.get()).incrementFundedETH(_deltas);
    }

    /// @notice Overridden handler to update operator funded ETH accounting for attestation-based deposits.
    ///         Delegates bucketing/aggregation to LibFundingDeltas so the production path and the
    ///         attestation test harness share the same code, then forwards to _incrementFundedETH.
    /// @param deposits Initial deposits from the buffer
    /// @param topUps Top-ups from the buffer
    function _updateFundedETHFromBuffer(
        IDepositDataBuffer.Deposit[] memory deposits,
        IDepositDataBuffer.TopUp[] memory topUps
    ) internal override {
        if (deposits.length == 0 && topUps.length == 0) return;
        uint256 operatorCount = IOperatorsRegistryV1(OperatorsRegistryAddress.get()).getOperatorCount();
        _incrementFundedETH(LibFundingDeltas.build(deposits, topUps, operatorCount));
    }

    /// @notice Overridden handler called whenever a token transfer is triggered
    /// @param _from Token sender
    /// @param _to Token receiver
    function _onTransfer(address _from, address _to) internal view override {
        IAllowlistV1 allowlist = IAllowlistV1(AllowlistAddress.get());
        if (allowlist.isDenied(_from)) {
            revert Denied(_from);
        }
        if (allowlist.isDenied(_to)) {
            revert Denied(_to);
        }
    }

    /// @notice Overridden handler called whenever a user deposits ETH to the system. Mints the adequate amount of shares.
    /// @param _depositor User address that made the deposit
    /// @param _amount Amount of ETH deposited
    function _onDeposit(address _depositor, address _recipient, uint256 _amount) internal override {
        uint256 mintedShares = SharesManagerV1._mintShares(_depositor, _amount);
        IAllowlistV1 allowlist = IAllowlistV1(AllowlistAddress.get());
        allowlist.onlyAllowed(_depositor, LibAllowlistMasks.DEPOSIT_MASK); // this call reverts if unauthorized or denied
        if (_depositor != _recipient) {
            if (allowlist.isDenied(_recipient)) {
                revert Denied(_recipient);
            }
            _transfer(_depositor, _recipient, mintedShares);
        }
    }

    /// @notice Overridden handler called whenever the total balance of ETH is requested
    /// @return The current total asset balance managed by River
    function _assetBalance() internal view override(SharesManagerV1, OracleManagerV1) returns (uint256) {
        IOracleManagerV1.StoredConsensusLayerReport storage storedReport = LastConsensusLayerReport.get();
        return storedReport.validatorsBalance + BalanceToDeposit.get() + CommittedBalance.get() + BalanceToRedeem.get()
            + InFlightDeposit.get() + ConsolidationBuffer.get();
    }

    /// @notice Internal utility to set the daily committable limits
    /// @param _dcl The new daily committable limits
    function _setDailyCommittableLimits(DailyCommittableLimits.DailyCommittableLimitsStruct memory _dcl) internal {
        DailyCommittableLimits.set(_dcl);
        emit SetMaxDailyCommittableAmounts(_dcl.minDailyNetCommittableAmount, _dcl.maxDailyRelativeCommittableAmount);
    }

    /// @notice Sets the balance to deposit, but not yet committed
    /// @param _newBalanceToDeposit The new balance to deposit value
    function _setBalanceToDeposit(uint256 _newBalanceToDeposit) internal override(UserDepositManagerV1) {
        emit SetBalanceToDeposit(BalanceToDeposit.get(), _newBalanceToDeposit);
        BalanceToDeposit.set(_newBalanceToDeposit);
    }

    /// @notice Returns whether slashing containment mode is currently active
    function _getSlashingContainmentMode() internal view override(ConsensusLayerDepositManagerV1) returns (bool) {
        return LastConsensusLayerReport.get().slashingContainmentMode;
    }

    /// @inheritdoc IRiverV1
    function getSlashingContainmentMode() external view returns (bool) {
        return _getSlashingContainmentMode();
    }

    /// @notice Reverts if slashing containment mode is currently active.
    /// @dev Slashing containment is designed to pause new validator funding and shareholder churn
    /// @dev (deposits, redeems, exit requests, balance-to-deposit commitment) to limit protocol
    /// @dev exposure during a slashing event. The reward-pull pipeline (EL fees, CL skimming,
    /// @dev coverage funds) continues to operate normally, as those flows reduce — not increase — risk.
    modifier whenNotSlashingContainmentMode() {
        if (_getSlashingContainmentMode()) {
            revert SlashingContainmentModeEnabled();
        }
        _;
    }

    /// @notice Override to block user deposits when slashing containment mode is active
    function _deposit(address _recipient) internal override whenNotSlashingContainmentMode {
        super._deposit(_recipient);
    }

    /// @notice Sets the committed balance, ready to be deposited to the consensus layer
    /// @param _newCommittedBalance The new committed balance value
    function _setCommittedBalance(uint256 _newCommittedBalance) internal override(ConsensusLayerDepositManagerV1) {
        emit SetBalanceCommittedToDeposit(CommittedBalance.get(), _newCommittedBalance);
        CommittedBalance.set(_newCommittedBalance);
    }

    /// @notice Sets the consolidation buffer
    /// @param _oldConsolidationBuffer The old consolidation buffer value
    /// @param _newConsolidationBuffer The new consolidation buffer value
    function _setConsolidationBuffer(uint256 _oldConsolidationBuffer, uint256 _newConsolidationBuffer)
        internal
        override(OracleManagerV1)
    {
        emit SetConsolidationBuffer(_oldConsolidationBuffer, _newConsolidationBuffer);
        ConsolidationBuffer.set(_newConsolidationBuffer);
    }

    function version() external pure returns (string memory) {
        return "1.3.0";
    }
}
