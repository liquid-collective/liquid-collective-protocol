//SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import "../Vm.sol";
import "../../src/components/AllowlistManager.1.sol";
import "../../src/libraries/Errors.sol";
import "../../src/libraries/LibOwnable.sol";
import "../utils/UserFactory.sol";

contract AllowlistManagerV1ExposeInitializer is AllowlistManagerV1 {
    function publicAllowlistManagerInitializeV1(address _AllowlistorAddress) external {
        AllowlistManagerV1.initAllowlistManagerV1(_AllowlistorAddress);
    }

    function sudoSetAdmin(address admin) external {
        LibOwnable._setAdmin(admin);
    }
}

contract AllowlistManagerV1Tests {
    Vm internal vm = Vm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    UserFactory internal uf = new UserFactory();

    bytes32 internal withdrawalCredentials = bytes32(uint256(1));

    address internal testAdmin = address(0xFA674fDde714fD979DE3EdF0f56aa9716b898eC8);
    address internal allower = address(0xEA674fdDe714fd979de3EdF0F56AA9716B898ec8);

    AllowlistManagerV1 internal allowlistManager;

    function setUp() public {
        allowlistManager = new AllowlistManagerV1ExposeInitializer();
        AllowlistManagerV1ExposeInitializer(address(allowlistManager)).publicAllowlistManagerInitializeV1(allower);
        AllowlistManagerV1ExposeInitializer(address(allowlistManager)).sudoSetAdmin(testAdmin);
    }

    function testSetAllowlistStatus(uint256 userSalt) public {
        address user = uf._new(userSalt);
        vm.startPrank(allower);
        assert(allowlistManager.isAllowed(user) == false);
        allowlistManager.allow(user, true);
        assert(allowlistManager.isAllowed(user) == true);
    }

    function testSetAllowlistStatusUnauthorized(uint256 userSalt) public {
        address user = uf._new(userSalt);
        vm.startPrank(user);
        assert(user != allower);
        vm.expectRevert(abi.encodeWithSignature("Unauthorized(address)", user));
        allowlistManager.allow(user, true);
    }

    function testSetAllower(uint256 adminSalt, uint256 newAllowerSalt) public {
        address admin = uf._new(adminSalt);
        address newAllower = uf._new(newAllowerSalt);
        AllowlistManagerV1ExposeInitializer(address(allowlistManager)).sudoSetAdmin(admin);
        assert(allowlistManager.getAllower() == allower);
        vm.startPrank(admin);
        allowlistManager.setAllower(newAllower);
        assert(allowlistManager.getAllower() == newAllower);
    }

    function testSetAllowerUnauthorized(uint256 nonAdminSalt, uint256 newAllowerSalt) public {
        address nonAdmin = uf._new(nonAdminSalt);
        address newAllower = uf._new(newAllowerSalt);
        vm.startPrank(nonAdmin);
        assert(nonAdmin != testAdmin);
        vm.expectRevert(abi.encodeWithSignature("Unauthorized(address)", nonAdmin));
        allowlistManager.setAllower(newAllower);
    }
}
