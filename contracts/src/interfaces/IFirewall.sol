//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

interface IFirewall {
    event SetExecutor(address indexed executor);
    event SetDestination(address indexed destination);
    event SetExecutorPermissions(bytes4 selector, bool status);

    function setExecutor(address newExecutor) external;
    function allowExecutor(bytes4 functionSelector, bool executorCanCall_) external;
    fallback() external payable;
    receive() external payable;
}
