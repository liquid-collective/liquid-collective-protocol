// SPDX-License-Identifier: CC0-1.0
// Originally derived from the Ethereum 2.0 Deposit Contract (CC0-1.0)
// https://github.com/ethereum/consensus-specs/blob/dev/solidity_deposit_contract/deposit_contract.sol
pragma solidity ^0.8.34;

/// @title Lib Uint256
/// @notice Utilities to perform uint operations
library LibUint256 {
    /// @notice Converts a value to little endian (64 bits)
    /// @param _value The value to convert
    /// @return result The converted value
    function toLittleEndian64(uint256 _value) internal pure returns (uint256 result) {
        uint256 tempValue = _value;
        result = tempValue & 0xFF;
        tempValue >>= 8;

        result = (result << 8) | (tempValue & 0xFF);
        tempValue >>= 8;

        result = (result << 8) | (tempValue & 0xFF);
        tempValue >>= 8;

        result = (result << 8) | (tempValue & 0xFF);
        tempValue >>= 8;

        result = (result << 8) | (tempValue & 0xFF);
        tempValue >>= 8;

        result = (result << 8) | (tempValue & 0xFF);
        tempValue >>= 8;

        result = (result << 8) | (tempValue & 0xFF);
        tempValue >>= 8;

        result = (result << 8) | (tempValue & 0xFF);
        tempValue >>= 8;

        assert(0 == tempValue); // fully converted
        result <<= (24 * 8);
    }

    /// @notice Returns the minimum value
    /// @param _a First value
    /// @param _b Second value
    /// @return Smallest value between _a and _b
    function min(uint256 _a, uint256 _b) internal pure returns (uint256) {
        return (_a > _b ? _b : _a);
    }

    /// @notice Returns the max value
    /// @param _a First value
    /// @param _b Second value
    /// @return Highest value between _a and _b
    function max(uint256 _a, uint256 _b) internal pure returns (uint256) {
        return (_a < _b ? _b : _a);
    }

    /// @notice Performs a ceiled division
    /// @param _a Numerator
    /// @param _b Denominator
    /// @return ceil(_a / _b)
    function ceil(uint256 _a, uint256 _b) internal pure returns (uint256) {
        return (_a / _b) + (_a % _b > 0 ? 1 : 0);
    }
}
