//SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {BaseService} from "./BaseService.sol";
import {Base} from "../Base.sol";

contract StakerService is BaseService {
    constructor(Base _base) BaseService(_base) {}

    function getTargetSelectors() external view override returns (StdInvariant.FuzzSelector memory selectors) {
        bytes4[] memory selectorsArray = new bytes4[](3);
        selectorsArray[0] = this.action_stakeAll.selector;
        selectorsArray[1] = this.action_stakePercent.selector;
        selectorsArray[2] = this.action_unstakeAll.selector;

        selectors.selectors = selectorsArray;
        selectors.addr = address(this);
    }

    function action_stakeAll() public recordBlockData {
        console.log("Staking all funds");
    }

    function action_stakePercent(uint256) public recordBlockData {
        console.log("Staking percentage of funds");
    }

    function action_unstakeAll() public recordBlockData {
        console.log("Unstaking all funds");
    }
}
