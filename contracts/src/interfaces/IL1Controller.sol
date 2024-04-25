//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.20;

interface IL1Controller {
    /// @notice Used to mint LsETH equivalent to ETH being supplied
    function mint() external payable;

    /// @notice Used to mint & bridge the LsETH
    function mintAndBridge() external payable;

    /// @notice Used to mint & bridge the LsETH
    /// @param _recipient Address which will receive the bridged LsETH
    function mintAndBridgeTo(address _recipient) external payable;

    /// @notice Used to bridge LsETH present in the contract
    /// @param _amount Amount of LsETH to be bridged
    function bridgeAmount(uint256 _amount) external;

    /// @notice Performs a redeem request on the redeem manager
    /// @param _lsETHAmount The amount of LsETH to redeem
    /// @param _recipient The address that will own the redeem request
    /// @return redeemRequestId The ID of the newly created redeem request
    function requestRedeem(uint256 _lsETHAmount, address _recipient) external returns (uint32 redeemRequestId);

    /// @notice Claims several redeem requests
    /// @param _redeemRequestIds The list of redeem requests to claim
    /// @param _withdrawalEventIds The list of resolved withdrawal event ids
    /// @return claimStatuses The operation status results
    function claimRedeemRequests(uint32[] calldata _redeemRequestIds, uint32[] calldata _withdrawalEventIds)
        external
        returns (uint8[] memory claimStatuses);

    /// @notice Used to withdraw ETH present in the contract
    /// @param _amount Amount of ETH to be withdrawn
    function withdrawETH(uint256 _amount) external;
}
