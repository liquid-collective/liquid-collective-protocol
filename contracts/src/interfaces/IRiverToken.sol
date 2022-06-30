//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

interface IRiverToken {
    function balanceOfUnderlying(address _owner) external view returns (uint256 balance);

    function underlyingBalanceFromShares(uint256 shares) external view returns (uint256);

    function sharesFromUnderlyingBalance(uint256 underlyingBalance) external view returns (uint256);

    function transferFrom(
        address _from,
        address _to,
        uint256 _value
    ) external returns (bool);

    function transfer(address _to, uint256 _value) external returns (bool);
}
