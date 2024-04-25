//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.20;

interface IFloatManager {
    /// @notice Used to bridge LsETH present in the contract
    /// @param _amount Amount of LsETH to be bridged
    function bridgeAmount(address _to, uint256 _amount, uint32 _minGasLimit, bytes calldata _extraData) external;

    // Float functions
    /// @notice Add ETH into the float which could be used for redeeming users
    /// @param _amount Amount of ETH being added
    function addFloatETH(uint256 _amount) external;

    /// @notice Remove usable ETH from float
    /// @param _amount Amount of ETH that can be removed
    function removeFloatETH(uint256 _amount) external;
}
