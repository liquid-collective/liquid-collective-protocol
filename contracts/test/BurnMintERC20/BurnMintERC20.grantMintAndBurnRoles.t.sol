// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {BurnMintERC20} from "../../src/l2-token/BurnMintERC20.sol";
import {BurnMintERC20Setup} from "./BurnMintERC20Setup.t.sol";

import {IAccessControl} from "openzeppelin-contracts/contracts/access/IAccessControl.sol";

contract BurnMintERC20_grantMintAndBurnRoles is BurnMintERC20Setup {
    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);

    function test_GrantMintAndBurnRoles() public {
        assertFalse(s_burnMintERC20.hasRole(s_burnMintERC20.MINTER_ROLE(), STRANGER));
        assertFalse(s_burnMintERC20.hasRole(s_burnMintERC20.BURNER_ROLE(), STRANGER));

        vm.expectEmit(true, true, true, true);
        emit RoleGranted(s_burnMintERC20.MINTER_ROLE(), STRANGER, OWNER);
        vm.expectEmit(true, true, true, true);
        emit RoleGranted(s_burnMintERC20.BURNER_ROLE(), STRANGER, OWNER);

        s_burnMintERC20.grantMintAndBurnRoles(STRANGER);

        assertTrue(s_burnMintERC20.hasRole(s_burnMintERC20.MINTER_ROLE(), STRANGER));
        assertTrue(s_burnMintERC20.hasRole(s_burnMintERC20.BURNER_ROLE(), STRANGER));
    }
}
