// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IBurnMintERC20} from "contracts/src/l2-token/IBurnMintERC20.sol";

import {BurnMintERC20Setup} from "./BurnMintERC20Setup.t.sol";

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IERC165} from "openzeppelin-contracts/contracts/utils/introspection/IERC165.sol";

contract BurnMintERC20_supportsInterface is BurnMintERC20Setup {
    function test_SupportsInterface() public {
        assertTrue(s_burnMintERC20.supportsInterface(type(IERC20).interfaceId));
        assertTrue(s_burnMintERC20.supportsInterface(type(IBurnMintERC20).interfaceId));
        assertTrue(s_burnMintERC20.supportsInterface(type(IERC165).interfaceId));
    }
}
