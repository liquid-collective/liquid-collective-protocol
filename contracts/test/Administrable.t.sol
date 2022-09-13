//SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import "../src/Administrable.sol";
import "forge-std/Test.sol";

contract WithAdmin is Administrable {
    constructor(address _admin) {
        _setAdmin(_admin);
    }
}

contract AdministrableTest is Test {
    WithAdmin internal wa;
    address internal admin;

    function setUp() external {
        admin = makeAddr("admin");
        wa = new WithAdmin(admin);
    }

    function testGetAdmin() external {
        assertEq(wa.getAdministrator(), admin);
    }

    function testProposeAdmin() external {
        assertEq(wa.getAdministrator(), admin);
        assertEq(wa.getPendingAdministrator(), address(0));
        address newAdmin = makeAddr("newAdmin");
        vm.prank(admin);
        wa.proposeAdmin(newAdmin);
        assertEq(wa.getAdministrator(), admin);
        assertEq(wa.getPendingAdministrator(), newAdmin);
    }

    function testProposeAdminUnauthorized() external {
        address newAdmin = makeAddr("newAdmin");
        vm.expectRevert(abi.encodeWithSignature("Unauthorized(address)", address(this)));
        wa.proposeAdmin(newAdmin);
    }

    function testAcceptAdmin() external {
        assertEq(wa.getAdministrator(), admin);
        assertEq(wa.getPendingAdministrator(), address(0));
        address newAdmin = makeAddr("newAdmin");
        vm.prank(admin);
        wa.proposeAdmin(newAdmin);
        assertEq(wa.getAdministrator(), admin);
        assertEq(wa.getPendingAdministrator(), newAdmin);
        vm.prank(newAdmin);
        wa.acceptAdmin();
        assertEq(wa.getAdministrator(), newAdmin);
        assertEq(wa.getPendingAdministrator(), address(0));
    }

    function testAcceptAdminUnauthorized() external {
        address newAdmin = makeAddr("newAdmin");
        vm.prank(admin);
        wa.proposeAdmin(newAdmin);
        vm.expectRevert(abi.encodeWithSignature("Unauthorized(address)", address(this)));
        wa.acceptAdmin();
    }
}
