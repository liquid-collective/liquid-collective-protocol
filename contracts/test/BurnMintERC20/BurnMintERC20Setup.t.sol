// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {BurnMintERC20} from "contracts/src/l2-token/BurnMintERC20.sol";
import {BaseTest} from "./BaseTest.t.sol";
import {TUPProxy} from "contracts/src/TUPProxy.sol";
import "../utils/LibImplementationUnbricker.sol";

contract BurnMintERC20Setup is BaseTest {
    BurnMintERC20 internal s_burnMintERC20;

    address internal s_mockPool = makeAddr("s_mockPool");
    uint256 internal s_amount = 1e18;

    address internal s_alice;
    address implementation;

    function setUp() public virtual override {
        BaseTest.setUp();

        s_alice = makeAddr("alice");

        implementation = address(new BurnMintERC20());
        s_burnMintERC20 = BurnMintERC20(address(new TUPProxy(implementation, address(this), new bytes(0))));
        s_burnMintERC20.initialize("Chainlink Token", "LINK", address(this));
        // Set s_mockPool to be a burner and minter
        s_burnMintERC20.grantMintAndBurnRoles(s_mockPool);
        deal(address(s_burnMintERC20), OWNER, s_amount);
    }
}
