// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "./console.sol";

interface Vm {
    function prank(address) external;

    function startPrank(address) external;

    function stopPrank() external;

    function deal(address, uint256) external;

    function expectRevert(bytes calldata) external;

    function expectEmit(
        bool,
        bool,
        bool,
        bool
    ) external;
}
