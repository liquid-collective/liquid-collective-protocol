// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {BurnMintERC20} from "../../src/l2-token/BurnMintERC20.sol";
import {BurnMintERC20Setup} from "./BurnMintERC20Setup.t.sol";

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {Strings} from "openzeppelin-contracts/contracts/utils/Strings.sol";

contract BurnMintERC20_burn is BurnMintERC20Setup {
    event Transfer(address indexed from, address indexed to, uint256 value);

    function test_BasicBurn() public {
        s_burnMintERC20.grantRole(s_burnMintERC20.BURNER_ROLE(), OWNER);
        deal(address(s_burnMintERC20), OWNER, s_amount);

        vm.expectEmit(true, true, true, true);
        emit Transfer(OWNER, address(0), s_amount);

        s_burnMintERC20.burn(s_amount);

        assertEq(0, s_burnMintERC20.balanceOf(OWNER));
    }

    // Revert

    function test_burn_RevertWhen_SenderNotBurner() public {
        // OZ Access Control v4.8.3 inherited by BurnMintERC20 does not use custom errors, but the revert message is still useful
        // and should be checked
        vm.expectRevert(
            abi.encodePacked(
                "AccessControl: account ",
                Strings.toHexString(OWNER),
                " is missing role ",
                Strings.toHexString(uint256(s_burnMintERC20.BURNER_ROLE()), 32)
            )
        );

        s_burnMintERC20.burnFrom(STRANGER, s_amount);
    }

    function test_burn_RevertWhen_ExceedsBalance() public {
        changePrank(s_mockPool);

        vm.expectRevert("ERC20: burn amount exceeds balance");

        s_burnMintERC20.burn(s_amount * 2);
    }

    function test_burn_RevertWhen_BurnFromZeroAddress() public {
        s_burnMintERC20.grantRole(s_burnMintERC20.BURNER_ROLE(), address(0));
        changePrank(address(0));

        vm.expectRevert("ERC20: burn from the zero address");

        s_burnMintERC20.burn(0);
    }
}
