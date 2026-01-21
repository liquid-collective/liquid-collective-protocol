// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {BurnMintERC20} from "../../src/l2-token/BurnMintERC20.sol";
import {BurnMintERC20Setup} from "./BurnMintERC20Setup.t.sol";

contract BurnMintERC20_getCCIPAdmin is BurnMintERC20Setup {
    event CCIPAdminTransferred(address indexed previousAdmin, address indexed newAdmin);

    function test_getCCIPAdmin() public {
        assertEq(OWNER, s_burnMintERC20.getCCIPAdmin());
    }

    function test_setCCIPAdmin() public {
        address newAdmin = makeAddr("newAdmin");

        vm.expectEmit(true, true, true, true);
        emit CCIPAdminTransferred(OWNER, newAdmin);

        s_burnMintERC20.setCCIPAdmin(newAdmin);

        assertEq(newAdmin, s_burnMintERC20.getCCIPAdmin());
    }
}
