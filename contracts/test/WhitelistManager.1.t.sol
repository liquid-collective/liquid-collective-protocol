//SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import "./Vm.sol";
import "../src/components/WhitelistManager.1.sol";
import "../src/libraries/Errors.sol";

contract WhitelistManagerV1ExposeInitializer is WhitelistManagerV1 {
    function publicWhitelistManagerInitializeV1(address _whitelistorAddress)
        external
    {
        WhitelistManagerV1.whitelistManagerInitializeV1(_whitelistorAddress);
    }
}

contract WhitelistManagerV1Tests {
    Vm internal vm = Vm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    bytes32 internal withdrawalCredentials = bytes32(uint256(1));

    address internal whitelistor =
        address(0xEA674fdDe714fd979de3EdF0F56AA9716B898ec8);

    WhitelistManagerV1 internal whitelistManager;

    function setUp() public {
        whitelistManager = new WhitelistManagerV1ExposeInitializer();
        WhitelistManagerV1ExposeInitializer(address(whitelistManager))
            .publicWhitelistManagerInitializeV1(whitelistor);
    }

    function testSetWhitelistStatus(address user) public {
        vm.startPrank(whitelistor);
        assert(whitelistManager.isWhitelisted(user) == false);
        whitelistManager.setWhitelistStatus(user, true);
        assert(whitelistManager.isWhitelisted(user) == true);
    }

    function testSetWhitelistStatusUnauthorized(address user) public {
        vm.startPrank(user);
        vm.expectRevert(abi.encodeWithSignature("Unauthorized(address)", user));
        whitelistManager.setWhitelistStatus(user, true);
    }
}
