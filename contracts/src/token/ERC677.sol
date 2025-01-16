// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IERC677} from "./IERC677.sol";
import {IERC677Receiver} from "./IERC677Receiver.sol";

import {ERC20Upgradeable} from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";

contract ERC677 is IERC677, ERC20Upgradeable {
    /// @inheritdoc IERC677
    function transferAndCall(address to, uint256 amount, bytes memory data) public returns (bool success) {
        super.transfer(to, amount);
        emit Transfer(msg.sender, to, amount, data);
        if (to.code.length > 0) {
            IERC677Receiver(to).onTokenTransfer(msg.sender, amount, data);
        }
        return true;
    }
}
