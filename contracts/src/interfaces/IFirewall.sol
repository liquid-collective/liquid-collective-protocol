//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

interface IFirewall {
    function changeGovernor(address newGovernor) external;
    function changeExecutor(address newExecutor) external;
    function permissionFunction(bytes4 functionSelector, bool executorCanCall_) external;
    fallback() external payable;
    receive() external payable;
}
