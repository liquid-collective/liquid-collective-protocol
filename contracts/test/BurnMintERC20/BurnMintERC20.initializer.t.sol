// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {BurnMintERC20Setup} from "./BurnMintERC20Setup.t.sol";
import {BurnMintERC20} from "../../src/l2-token/BurnMintERC20.sol";
import {TUPProxy} from "contracts/src/TUPProxy.sol";

contract BurnMintERC20_initializer is BurnMintERC20Setup {
    function test_Initializer() public {
        vm.startPrank(s_alice);

        string memory name = "Chainlink token v2";
        string memory symbol = "LINK2";
        uint8 decimals = 18;

        s_burnMintERC20 = BurnMintERC20(address(new TUPProxy(implementation, address(this), new bytes(0))));
        s_burnMintERC20.initialize("Chainlink token v2", "LINK2");

        assertEq(name, s_burnMintERC20.name());
        assertEq(symbol, s_burnMintERC20.symbol());
        assertEq(decimals, s_burnMintERC20.decimals());

        assertTrue(s_burnMintERC20.hasRole(s_burnMintERC20.DEFAULT_ADMIN_ROLE(), s_alice));
    }
}
