//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

interface IAllowlist {
    function isAllowed(address _user, uint256 _mask) external view returns (bool);
}
