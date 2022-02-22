//SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import "../Vm.sol";
import "../../src/components/AllowlistManager.1.sol";
import "../../src/libraries/Errors.sol";

contract AllowlistManagerV1ExposeInitializer is AllowlistManagerV1 {
    function publicAllowlistManagerInitializeV1(address _AllowlistorAddress) external {
        AllowlistManagerV1.initAllowlistManagerV1(_AllowlistorAddress);
    }
}

contract AllowlistManagerV1Tests {
    Vm internal vm = Vm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    bytes32 internal withdrawalCredentials = bytes32(uint256(1));

    address internal Allowlistor = address(0xEA674fdDe714fd979de3EdF0F56AA9716B898ec8);

    AllowlistManagerV1 internal AllowlistManager;

    function setUp() public {
        AllowlistManager = new AllowlistManagerV1ExposeInitializer();
        AllowlistManagerV1ExposeInitializer(address(AllowlistManager)).publicAllowlistManagerInitializeV1(Allowlistor);
    }

    function testSetAllowlistStatus(address user) public {
        vm.startPrank(Allowlistor);
        assert(AllowlistManager.isAllowed(user) == false);
        AllowlistManager.allow(user, true);
        assert(AllowlistManager.isAllowed(user) == true);
    }

    function testSetAllowlistStatusUnauthorized(address user) public {
        vm.startPrank(user);
        vm.expectRevert(abi.encodeWithSignature("Unauthorized(address)", user));
        AllowlistManager.allow(user, true);
    }
}
