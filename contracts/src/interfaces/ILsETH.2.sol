//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.20;

interface ILsETH2 {
    // Token Functionality
    /// @notice Allow user to deposit ETH and get equivalent LsETH
    /// @param _amount Amount of ETH to be deposited
    function deposit(uint256 _amount) external;

    /// @notice Allow user to deposit ETH and transfer equivalent LsETH to the provided address
    /// @param _recipient Address to which LsETH should go to
    /// @param _amount Amount of ETH to be deposited
    function depositAndTransfer(address _recipient, uint256 _amount) external;

    /// @notice Allow user to redeem LsETH for equivalent amount of ETH
    /// @param _amount Amount of LsETH to be redeemed
    function redeem(uint256 _amount) external;

    /// @notice Allow user to redeem LsETH for equivalent amount of ETH
    /// @param _recipient Address to which redeemed ETH should go to
    /// @param _amount Amount of LsETH to be redeemed
    function redeemTo(address _recipient, uint256 _amount) external;

    // Cross chain functionalities

    /// @notice This function updates the exchange rate of LsETH/ETH
    ///         Is called from L1 once a day after oracle Update on L1
    /// @param _rate The LsETH to ETH exchange rate
    function exchangeRateUpdate(uint256 _rate) external;
}
