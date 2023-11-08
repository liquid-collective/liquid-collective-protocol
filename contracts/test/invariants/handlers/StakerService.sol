//SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import {Base} from "../Base.sol";
import {BaseService} from "./BaseService.sol";

uint256 constant MAX_STAKERS = 100;

contract StakerService is BaseService {
    address[] internal stakers;
    address internal currentStaker;

    modifier useStaker(uint256 index) {
        currentStaker = stakers[bound(index, 0, MAX_STAKERS - 1)];
        vm.startPrank(currentStaker);
        _;
        vm.stopPrank();
    }

    constructor(Base _base) BaseService(_base) {
        allowListStakers();
    }

    function allowListStakers() internal prankAllower {
        address[] memory stakerServiceArray = new address[](MAX_STAKERS);
        uint256[] memory stakerServiceMask = new uint256[](MAX_STAKERS);

        for (uint256 index = 0; index < MAX_STAKERS; index++) {
            stakers.push(makeAddr(vm.toString(index)));
            stakerServiceArray[index] = stakers[index];
            stakerServiceMask[index] = 5;
        }

        base.allowlist().allow(stakerServiceArray, stakerServiceMask);
    }

    function getTargetSelectors() external view override returns (StdInvariant.FuzzSelector memory selectors) {
        bytes4[] memory selectorsArray = new bytes4[](4);
        selectorsArray[0] = this.action_stakeAmount.selector;
        selectorsArray[1] = this.action_request_redeem.selector;
        selectorsArray[2] = this.action_request_redeem_all.selector;
        selectorsArray[3] = this.action_claim_redeem_request.selector;

        selectors.selectors = selectorsArray;
        selectors.addr = address(this);
    }

    function action_stakeAmount(uint256 amount, uint256 stakerIndex) public recordBlockData useStaker(stakerIndex) {
        amount = bound(amount, 1e16, 10000 ether);
        console.log("Staking amount of funds");
        base.dealETH(currentStaker, amount);
        base.river().deposit{value: amount}();
    }

    function action_request_redeem(uint256 amount, uint256 stakerIndex) public recordBlockData useStaker(stakerIndex) {
        amount = bound(amount, 1e16, base.river().balanceOf(currentStaker));
        console.log("Unstaking");
        // Keep track of the redeem requests
    }

    function action_request_redeem_all(uint256 stakerIndex) public recordBlockData useStaker(stakerIndex) {
        console.log("Unstaking all funds");
        uint256 balance = base.river().balanceOf(currentStaker);
        // Keep track of the redeem requests
    }

    function action_claim_redeem_request(uint256 stakerIndex) public recordBlockData useStaker(stakerIndex) {
        console.log("Claiming redeem request");
        // Do we have a check on whether it is being done after the cooldown period?
    }
}
