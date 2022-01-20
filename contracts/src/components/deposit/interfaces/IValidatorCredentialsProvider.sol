//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

interface IValidatorCredentialsProvider {
    function getValidatorKeys(uint256 amount)
        external
        returns (bytes memory, bytes memory);
}
