//SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.13;

import "../../src/components/OracleManager.1.sol";
import "../../src/state/shared/AdministratorAddress.sol";


contract OracleManagerWithOverridesV1 is OracleManagerV1 {
    function supersedeReportedBalanceSum(uint256 amount) external {
        LastConsensusLayerReport.get().validatorsBalance = amount;
    }

    function supersedeReportedValidatorCount(uint256 amount) external {
        LastConsensusLayerReport.get().validatorsCount = uint32(amount);
    }

    function supersedeDepositedValidatorCount(uint256 amount) external {
        DepositedValidatorCount.set(amount);
    }

    function _getRiverAdmin() internal view override returns (address) {
        return AdministratorAddress.get();
    }

    constructor(
        address oracle,
        address admin,
        uint64 epochsPerFrame,
        uint64 slotsPerEpoch,
        uint64 secondsPerSlot,
        uint64 genesisTime,
        uint64 epochsToAssumedFinality,
        uint256 annualAprUpperBound,
        uint256 relativeLowerBound
    ) {
        AdministratorAddress.set(admin);
        initOracleManagerV1(oracle);
        initOracleManagerV1_1(
            epochsPerFrame,
            slotsPerEpoch,
            secondsPerSlot,
            genesisTime,
            epochsToAssumedFinality,
            annualAprUpperBound,
            relativeLowerBound
        );
    }

    // internal hooks

    uint256 amountToRedeem;
    uint256 amountToDeposit;

    event Internal_OnEarnings(uint256 amount);

    function _onEarnings(uint256 amount) internal override {
        emit Internal_OnEarnings(amount);
    }

    uint256 public elFeesAvailable;

    function sudoSetElFeesAvailable(uint256 newValue) external {
        elFeesAvailable = newValue;
    }

    event Internal_PullELFees(uint256 _max, uint256 _returned);

    function _pullELFees(uint256 _max) internal override returns (uint256 result) {
        result = LibUint256.min(elFeesAvailable, _max);
        amountToDeposit += result;
        emit Internal_PullELFees(_max, result);
    }

    uint256 public coverageFundAvailable;

    function sudoSetCoverageFundAvailable(uint256 newValue) external {
        coverageFundAvailable = newValue;
    }

    event Internal_PullCoverageFunds(uint256 _max, uint256 _returned);

    function _pullCoverageFunds(uint256 _max) internal override returns (uint256 result) {
        result = LibUint256.min(coverageFundAvailable, _max);
        amountToDeposit += result;
        emit Internal_PullCoverageFunds(_max, result);
    }

    function _assetBalance() internal view override returns (uint256 result) {
        result = (DepositedValidatorCount.get() - LastConsensusLayerReport.get().validatorsCount) * 32 ether
            + LastConsensusLayerReport.get().validatorsBalance + amountToDeposit + amountToRedeem;
    }

    function debug_getTotalUnderlyingBalance() external view returns (uint256) {
        return _assetBalance();
    }

    uint256 public redeemDemand;

    function sudoSetRedeemDemand(uint256 newValue) external {
        redeemDemand = newValue;
    }

    event Internal_ReportWithdrawToRedeemManager(uint256 currentAmountToRedeem);

    function _reportWithdrawToRedeemManager() internal override {
        emit Internal_ReportWithdrawToRedeemManager(amountToRedeem);
        uint256 amountToUse = LibUint256.min(amountToRedeem, redeemDemand);
        amountToRedeem -= amountToUse;
        redeemDemand -= amountToUse;
    }

    event Internal_PullCLFunds(uint256 skimmedEthAmount, uint256 exitedEthAmount);

    function _pullCLFunds(uint256 skimmedEthAmount, uint256 exitedEthAmount) internal override {
        amountToDeposit += skimmedEthAmount;
        amountToRedeem += exitedEthAmount;
        emit Internal_PullCLFunds(skimmedEthAmount, exitedEthAmount);
    }

    uint256 public exceedingEth;

    function sudoSetExceedingEth(uint256 newValue) external {
        exceedingEth = newValue;
    }

    event Internal_PullRedeemManagerExceedingEth(uint256 max, uint256 result);

    function _pullRedeemManagerExceedingEth(uint256 max) internal override returns (uint256 result) {
        result = LibUint256.min(max, exceedingEth);
        emit Internal_PullRedeemManagerExceedingEth(max, result);
        amountToDeposit += result;
    }

    event Internal_SetReportedStoppedValidatorCounts(uint32[] stoppedValidatorCounts);

    event Internal_RequestExitsBasedOnRedeemDemandAfterRebalancings(
        uint256 exitingBalance, bool depositToRedeemRebalancingAllowed, uint256 exitCountRequest
    );

    function _requestExitsBasedOnRedeemDemandAfterRebalancings(
        uint256 exitingBalance,
        uint32[] memory stoppedValidatorCounts,
        bool depositToRedeemRebalancingAllowed,
        bool slashingContainmentModeEnabled
    ) internal override {
        uint256 exitCount = 0;

        emit Internal_SetReportedStoppedValidatorCounts(stoppedValidatorCounts);

        if (slashingContainmentModeEnabled) {
            return;
        }

        if (redeemDemand > amountToRedeem + exitingBalance) {
            exitCount = LibUint256.ceil((redeemDemand - (amountToRedeem + exitingBalance)), 32 ether);
        }
        emit Internal_RequestExitsBasedOnRedeemDemandAfterRebalancings(
            exitingBalance, depositToRedeemRebalancingAllowed, exitCount
        );
    }

    event Internal_CommitBalanceToDeposit(uint256 period, uint256 depositBalance);

    function _commitBalanceToDeposit(uint256 period) internal override {
        emit Internal_CommitBalanceToDeposit(period, amountToDeposit);
    }

    event Internal_SkimExcessBalanceToRedeem(uint256 balanceToDeposit, uint256 balanceToRedeem);

    function _skimExcessBalanceToRedeem() internal override {
        emit Internal_SkimExcessBalanceToRedeem(amountToDeposit, amountToRedeem);
        amountToDeposit += amountToRedeem;
        amountToRedeem = 0;
    }
}