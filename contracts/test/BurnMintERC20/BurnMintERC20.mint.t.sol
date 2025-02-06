// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {BurnMintERC20} from "../../src/l2-token/BurnMintERC20.sol";
import {BurnMintERC20Setup} from "./BurnMintERC20Setup.t.sol";

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {Strings} from "openzeppelin-contracts/contracts/utils/Strings.sol";

contract BurnMintERC20_mint is BurnMintERC20Setup {
    event Transfer(address indexed from, address indexed to, uint256 value);

    function test_mint() public {
        uint256 balancePre = s_burnMintERC20.balanceOf(OWNER);

        s_burnMintERC20.grantMintAndBurnRoles(OWNER);

        vm.expectEmit(true, true, true, true);
        emit Transfer(address(0), OWNER, s_amount);

        s_burnMintERC20.mint(OWNER, s_amount);

        assertEq(balancePre + s_amount, s_burnMintERC20.balanceOf(OWNER));
    }

    // Revert

    function test_mint_RevertWhen_SenderNotMinter() public {
        vm.startPrank(STRANGER);

        // OZ Access Control v4.8.3 inherited by BurnMintERC20 does not use custom errors, but the revert message is still useful
        // and should be checked
        vm.expectRevert(
            abi.encodePacked(
                "AccessControl: account ",
                Strings.toHexString(STRANGER),
                " is missing role ",
                Strings.toHexString(uint256(s_burnMintERC20.MINTER_ROLE()), 32)
            )
        );

        s_burnMintERC20.mint(STRANGER, 1e18);
    }

    function test_mint_RevertWhen_InvalidRecipient() public {
        s_burnMintERC20.grantMintAndBurnRoles(OWNER);

        vm.expectRevert(abi.encodeWithSelector(BurnMintERC20.InvalidRecipient.selector, address(s_burnMintERC20)));
        s_burnMintERC20.mint(address(s_burnMintERC20), 1e18);
    }
}
