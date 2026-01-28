//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.22;

interface IProtocolVersion {
    /// @notice Retrieves the version of the contract
    /// @return Version of the contract
    function version() external pure returns (string memory);
}
