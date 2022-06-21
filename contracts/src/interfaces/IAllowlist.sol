//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

interface IAllowlist {
    function onlyAllowed(address _account, uint256 _mask) external view;

    function isAllowed(address _account, uint256 _mask) external view returns (bool);

    function isDenied(address _account) external view returns (bool);

    function hasPermission(address _account, uint256 _mask) external view returns (bool);
}
