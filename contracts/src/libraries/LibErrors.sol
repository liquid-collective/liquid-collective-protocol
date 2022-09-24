//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

library LibErrors {
    error Unauthorized(address caller);
    error InvalidCall();
    error InvalidArgument();
    error InvalidZeroAddress();
    error InvalidEmptyString();
    error InvalidFee();
}