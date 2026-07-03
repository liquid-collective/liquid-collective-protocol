//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

/// @title External Consolidation Recipient Mapping Interface (v1)
/// @author Alluvial Finance Inc.
/// @notice Maps withdrawal credential addresses to recipient addresses for external consolidation minting
interface IExternalConsolidationRecipientMappingV1 {
    /// @notice The stored River address has changed
    /// @param river The new River address
    event SetRiver(address indexed river);

    /// @notice The recipient for a withdrawal credential address has changed
    /// @param withdrawalCredentialAddress The address component of the validator withdrawal credentials
    /// @param recipient The recipient address
    event SetRecipient(address indexed withdrawalCredentialAddress, address indexed recipient);

    /// @notice The requested recipient is denied on the allowlist
    error RecipientIsDenied();

    /// @notice Initialize the mapping contract with the required arguments
    /// @param _riverAddress Address of River
    function initExternalConsolidationRecipientMappingV1(address _riverAddress) external;

    /// @notice Sets the recipient address for the caller.
    /// @dev The caller is the committee-attested withdrawal credential address.
    /// @param _recipient The address to receive minted LsETH
    function setRecipient(address _recipient) external;

    /// @notice Retrieves the raw recipient address mapped to a withdrawal credential address
    /// @param _withdrawalCredentialAddress The withdrawal credential address to query
    /// @return The mapped recipient address
    function getRecipient(address _withdrawalCredentialAddress) external view returns (address);

    /// @notice Resolves the mint recipient for a withdrawal credential address
    /// @dev Returns the mapped recipient when set, otherwise falls back to the withdrawal credential address.
    /// @dev Does not perform any validation on the recipient address.
    /// @param _withdrawalCredentialAddress The withdrawal credential address to resolve
    /// @return The recipient address to receive minted LsETH
    function resolveRecipient(address _withdrawalCredentialAddress) external view returns (address);
}
