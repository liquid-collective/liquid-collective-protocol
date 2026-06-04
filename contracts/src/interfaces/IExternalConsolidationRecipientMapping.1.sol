//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

/// @title External Consolidation Recipient Mapping Interface (v1)
/// @author Alluvial Finance Inc.
/// @notice Maps callers' withdrawal credential addresses to recipient addresses for external consolidation minting
interface IExternalConsolidationRecipientMappingV1 {
    /// @notice The stored River address has changed
    /// @param river The new River address
    event SetRiver(address indexed river);

    /// @notice The recipient for a withdrawal credential address has changed
    /// @param withdrawalCredential The withdrawal credential address
    /// @param account The account that set the recipient
    /// @param recipient The recipient address
    event SetRecipient(address indexed withdrawalCredential, address indexed account, address indexed recipient);

    /// @notice The requested recipient is denied on the allowlist
    error RecipientIsDenied();

    /// @notice Initialize the mapping contract with the required arguments
    /// @param _riverAddress Address of River
    function initExternalConsolidationRecipientMappingV1(address _riverAddress) external;

    /// @notice Sets the recipient address for the caller's withdrawal credential address
    /// @param _withdrawalCredential The caller's withdrawal credential address to map
    /// @param _recipient The address to receive minted LsETH
    function setRecipient(address _withdrawalCredential, address _recipient) external;

    /// @notice Retrieves the recipient address mapped to a withdrawal credential address
    /// @param _withdrawalCredential The withdrawal credential address to query
    /// @return The mapped recipient address
    function getRecipient(address _withdrawalCredential) external view returns (address);
}
