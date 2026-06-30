//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../state/river/DailyCommittableLimits.sol";
import "./IWithdraw.1.sol";

/// @title River Config Manager Interface (v1)
/// @author Alluvial Finance Inc.
/// @notice Surface of the RiverConfigManager sibling contract. River holds a thin stub per function
///         that forwards raw calldata via DELEGATECALL to the manager, which carries the full body.
///         Because it is delegatecall, the manager executes in River's storage context — every
///         function reads/writes River's existing unstructured-storage slots. The manager's functions
///         are intentionally permissionless: they are only meaningful when delegatecalled by River
///         (which enforces access control in its stub); a direct call to the standalone manager only
///         touches the manager's own unused storage.
interface IRiverConfigManagerV1 {
    /// @notice Sets the global fee
    /// @param _newFee The new global fee
    function setGlobalFee(uint256 _newFee) external;

    /// @notice Sets the allowlist address
    /// @param _newAllowlist The new allowlist address
    function setAllowlist(address _newAllowlist) external;

    /// @notice Sets the collector address
    /// @param _newCollector The new collector address
    function setCollector(address _newCollector) external;

    /// @notice Sets the execution layer fee recipient address
    /// @param _newELFeeRecipient The new execution layer fee recipient address
    function setELFeeRecipient(address _newELFeeRecipient) external;

    /// @notice Sets the coverage fund address
    /// @param _newCoverageFund The new coverage fund address
    function setCoverageFund(address _newCoverageFund) external;

    /// @notice Sets the consolidation coverage fund address
    /// @param _newConsolidationCoverageFund The new consolidation coverage fund address
    function setConsolidationCoverageFund(address _newConsolidationCoverageFund) external;

    /// @notice Sets the metadata URI
    /// @param _metadataURI The new metadata URI
    function setMetadataURI(string memory _metadataURI) external;

    /// @notice Sets the consolidator address
    /// @param _newConsolidator The new consolidator address
    function setConsolidator(address _newConsolidator) external;

    /// @notice Sets the daily committable limits
    /// @param _dcl The new daily committable limits
    function setDailyCommittableLimits(DailyCommittableLimits.DailyCommittableLimitsStruct memory _dcl) external;

    /// @notice Sets the keeper address
    /// @param _keeper The new keeper address
    function setKeeper(address _keeper) external;

    /// @notice Requests Pectra self-consolidations of the protocol's own validators
    /// @param pubkeys The 48-byte BLS pubkeys to consolidate
    /// @param maxFeePerConsolidation Maximum fee per consolidation
    function selfConsolidation(bytes[] calldata pubkeys, uint256 maxFeePerConsolidation) external payable;

    /// @notice Forwards pre-built Pectra consolidation requests to the Withdraw contract
    /// @param requests The consolidation requests
    /// @param maxFeePerConsolidation Maximum fee per consolidation
    function consolidate(IWithdrawV1.ConsolidationRequest[] calldata requests, uint256 maxFeePerConsolidation)
        external
        payable;

    /// @notice Requests a redeem against the redeem manager, moving the caller's LsETH to River
    /// @param _lsETHAmount The amount of LsETH to redeem
    /// @param _recipient The address that will own the redeem request
    /// @return _redeemRequestId The id of the created redeem request
    function requestRedeem(uint256 _lsETHAmount, address _recipient) external returns (uint32 _redeemRequestId);

    /// @notice Claims redeem requests against the redeem manager
    /// @param _redeemRequestIds The redeem request ids
    /// @param _withdrawalEventIds The withdrawal event ids
    /// @return claimStatuses The per-request claim statuses
    function claimRedeemRequests(uint32[] calldata _redeemRequestIds, uint32[] calldata _withdrawalEventIds)
        external
        returns (uint8[] memory claimStatuses);

    /// @notice Performs the V3 accounting migration (Pectra 0x01→0x02). Idempotent storage rebuild from
    ///         the last stored report and deposited-validator count; invoked once via delegatecall from
    ///         River's initRiverV1_3.
    function migrateV3Accounting() external;
}
