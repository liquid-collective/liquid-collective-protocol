//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.20;

import {IFloatManager} from "./../interfaces/IFloatManager.sol";

abstract contract FloatManagerL2 is IFloatManager {
    function _onFloatOperation() internal virtual;
    function _bridgeOperation(address _to, uint256 _amount, uint32 _minGasLimit, bytes calldata _extraData)
        internal
        virtual;

    // Float functions
    /// @notice Used to bridge LsETH present in the contract
    /// @param _amount Amount of LsETH to be bridged
    function bridgeAmount(address _to, uint256 _amount, uint32 _minGasLimit, bytes calldata _extraData) external {
        _bridgeOperation(_to, _amount, _minGasLimit, _extraData);
    }

    /// @notice Add ETH into the float which could be used for redeeming users
    /// @param _amount Amount of ETH being added
    function addFloatETH(uint256 _amount) external {
        _onFloatOperation();
    }

    /// @notice Remove usable ETH from float
    /// @param _amount Amount of ETH that can be removed
    function removeFloatETH(uint256 _amount) external {
        _onFloatOperation();
    }
}
