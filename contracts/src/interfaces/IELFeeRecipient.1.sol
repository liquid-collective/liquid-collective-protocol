//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

interface IELFeeRecipientV1 {
    event SetRiver(address indexed river);

    error InvalidCall();

    function initELFeeRecipientV1(address _riverAddress) external;
    function pullELFees() external;
    receive() external payable;
    fallback() external payable;
}
