//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "./IAttestationVerifier.1.sol";
import "./IWithdraw.1.sol";

/// @title Consolidation Manager Interface (v1)
/// @author Alluvial Finance Inc.
/// @notice Coordinates Pectra consolidation requests and external consolidation minting.
interface IConsolidationManagerV1 {
    /// @notice The stored River address has changed
    /// @param river The new River address
    event SetRiver(address indexed river);

    /// @notice The stored external consolidation recipient mapping has changed
    /// @param externalConsolidationRecipientMapping The new mapping contract address
    event SetExternalConsolidationRecipientMapping(address indexed externalConsolidationRecipientMapping);

    /// @notice The stored consolidator has changed
    /// @param consolidator The new consolidator address
    event SetConsolidator(address indexed consolidator);

    /// @notice Emitted when LsETH is minted for consolidation
    /// @param recipient The address that received the minted LsETH
    /// @param amountEth The amount of ETH(wei) attributed to consolidation
    /// @param sharesMinted The amount of LsETH shares minted
    event LsETHMintedForConsolidation(address indexed recipient, uint256 amountEth, uint256 sharesMinted);

    /// @notice Emitted when a Pectra consolidation request is forwarded to the Withdraw contract
    /// @param requests Consolidation requests
    /// @param maxFeePerConsolidation Maximum fee per consolidation
    /// @param excessFeeRecipient Address to receive any excess msg.value
    /// @param valueSent ETH sent with the call for fees
    event PectraConsolidationRequested(
        IWithdrawV1.ConsolidationRequest[] requests,
        uint256 maxFeePerConsolidation,
        address excessFeeRecipient,
        uint256 valueSent
    );

    /// @notice Thrown when the consolidator address is not authorized
    error OnlyConsolidator();

    /// @notice Initialize the manager with River and consolidation dependencies
    /// @param _riverAddress Address of River
    /// @param _externalConsolidationRecipientMapping The recipient mapping contract
    /// @param _consolidator The authorized consolidator
    function initConsolidationManagerV1(
        address _riverAddress,
        address _externalConsolidationRecipientMapping,
        address _consolidator
    ) external;

    /// @notice Retrieve the configured consolidator address
    /// @return The consolidator address
    function getConsolidator() external view returns (address);

    /// @notice Retrieve the external consolidation recipient mapping address
    /// @return The mapping contract address
    function getExternalConsolidationRecipientMapping() external view returns (address);

    /// @notice Changes the consolidator address
    /// @param _newConsolidator New consolidator address
    function setConsolidator(address _newConsolidator) external;

    /// @notice Mints LsETH to a recipient for consolidated ETH
    /// @param consolidation The consolidation object
    function mintLsETHForConsolidation(IAttestationVerifierV1.ConsolidationObject calldata consolidation) external;

    /// @notice Request self consolidation of pre-Pectra validator pubkeys
    /// @param pubkeys The 48-byte BLS pubkeys to consolidate
    /// @param maxFeePerConsolidation The maximum fee per consolidation to accept
    function selfConsolidation(bytes[] calldata pubkeys, uint256 maxFeePerConsolidation) external payable;

    /// @notice Request Pectra consolidations via the Withdraw contract
    /// @param requests Consolidation requests
    /// @param maxFeePerConsolidation Maximum fee per consolidation to accept
    function consolidate(IWithdrawV1.ConsolidationRequest[] calldata requests, uint256 maxFeePerConsolidation)
        external
        payable;
}
