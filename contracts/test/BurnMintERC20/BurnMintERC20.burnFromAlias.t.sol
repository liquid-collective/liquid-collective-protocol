// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {BurnMintERC20} from "../../src/l2-token/BurnMintERC20.sol";
import {BurnMintERC20Setup} from "./BurnMintERC20Setup.t.sol";

import {Strings} from "openzeppelin-contracts/contracts/utils/Strings.sol";

contract BurnMintERC20_burnFromAlias is BurnMintERC20Setup {
    function setUp() public virtual override {
        BurnMintERC20Setup.setUp();
    }

    function test_burn() public {
        s_burnMintERC20.approve(s_mockPool, s_amount);

        changePrank(s_mockPool);

        s_burnMintERC20.burn(OWNER, s_amount);

        assertEq(0, s_burnMintERC20.balanceOf(OWNER));
    }

    // Reverts

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

        s_burnMintERC20.burn(OWNER, s_amount);
    }

    function test_burn_RevertWhen_InsufficientAllowance() public {
        changePrank(s_mockPool);

        vm.expectRevert("ERC20: insufficient allowance");

        s_burnMintERC20.burn(OWNER, s_amount);
    }

    function test_burn_RevertWhen_ExceedsBalance() public {
        s_burnMintERC20.approve(s_mockPool, s_amount * 2);

        changePrank(s_mockPool);

        vm.expectRevert("ERC20: burn amount exceeds balance");

        s_burnMintERC20.burn(OWNER, s_amount * 2);
    }
}
