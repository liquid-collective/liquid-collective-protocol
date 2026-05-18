// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../../contracts/src/River.1.sol";

/// @title RiverHarness
/// @notice Harness for RiverV1 — exposes internal state for formal verification.
///         River is concrete through multiple inheritance but we need getters for
///         unstructured storage slots that have no public accessors.
contract RiverHarness is RiverV1 {

    /// @notice Expose total supply (Shares.get())
    function getTotalSupply() external view returns (uint256) {
        return Shares.get();
    }

    /// @notice Expose shares for a specific owner
    function getSharesPerOwner(address _owner) external view returns (uint256) {
        return SharesPerOwner.get(_owner);
    }

    /// @notice Expose CommittedBalance
    function getCommittedBalanceHarness() external view returns (uint256) {
        return CommittedBalance.get();
    }

    /// @notice Expose BalanceToDeposit
    function getBalanceToDepositHarness() external view returns (uint256) {
        return BalanceToDeposit.get();
    }

    /// @notice Expose BalanceToRedeem
    function getBalanceToRedeemHarness() external view returns (uint256) {
        return BalanceToRedeem.get();
    }

    /// @notice Expose DepositedValidatorCount
    function getDepositedValidatorCountHarness() external view returns (uint256) {
        return DepositedValidatorCount.get();
    }

    /// @notice Expose _assetBalance
    function getAssetBalance() external view returns (uint256) {
        return _assetBalance();
    }

    /// @notice Expose the slashing containment mode
    function getSlashingContainmentModeHarness() external view returns (bool) {
        return _getSlashingContainmentMode();
    }

    /// @notice Expose the keeper address
    function getKeeperHarness() external view returns (address) {
        return KeeperAddress.get();
    }

    /// @notice Expose the allowlist address
    function getAllowlistAddress() external view returns (address) {
        return AllowlistAddress.get();
    }

    /// @notice Expose the ELFeeRecipient address
    function getELFeeRecipientAddress() external view returns (address) {
        return ELFeeRecipientAddress.get();
    }

    /// @notice Expose WithdrawalCredentials address
    function getWithdrawalCredentialsAddress() external view returns (address) {
        return WithdrawalCredentials.getAddress();
    }

    /// @notice Expose CoverageFundAddress
    function getCoverageFundAddressHarness() external view returns (address) {
        return CoverageFundAddress.get();
    }

    /// @notice Expose RedeemManagerAddress
    function getRedeemManagerAddressHarness() external view returns (address) {
        return RedeemManagerAddress.get();
    }

    /// @notice Expose admin
    function getAdminHarness() external view returns (address) {
        return _getAdmin();
    }

    /// @notice Expose GlobalFee
    function getGlobalFeeHarness() external view returns (uint256) {
        return GlobalFee.get();
    }

    /// @notice Expose validatorsBalance from last report
    function getValidatorsBalance() external view returns (uint256) {
        return LastConsensusLayerReport.get().validatorsBalance;
    }

    /// @notice Expose validatorsCount from last report
    function getValidatorsCount() external view returns (uint32) {
        return LastConsensusLayerReport.get().validatorsCount;
    }

    /// @notice Expose OracleAddress
    function getOracleAddressHarness() external view returns (address) {
        return OracleAddress.get();
    }

    /// @notice Expose CollectorAddress
    function getCollectorAddressHarness() external view returns (address) {
        return CollectorAddress.get();
    }

    /// @notice Expose OperatorsRegistryAddress
    function getOperatorsRegistryAddressHarness() external view returns (address) {
        return OperatorsRegistryAddress.get();
    }
}
