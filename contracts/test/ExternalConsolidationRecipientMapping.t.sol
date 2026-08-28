//SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.34;

import "forge-std/Test.sol";

import "./utils/UserFactory.sol";
import "./utils/LibImplementationUnbricker.sol";

import "../src/Allowlist.1.sol";
import "../src/ExternalConsolidationRecipientMapping.1.sol";
import "../src/interfaces/IExternalConsolidationRecipientMapping.1.sol";
import "../src/libraries/LibAllowlistMasks.sol";

contract ExternalConsolidationRecipientMappingRiverMock {
    address internal allowlist;

    constructor(address _allowlist) {
        allowlist = _allowlist;
    }

    function getAllowlist() external view returns (address) {
        return allowlist;
    }
}

abstract contract ExternalConsolidationRecipientMappingV1TestBase is Test {
    ExternalConsolidationRecipientMappingV1 internal mappingContract;
    AllowlistV1 internal allowlist;
    ExternalConsolidationRecipientMappingRiverMock internal river;
    UserFactory internal uf = new UserFactory();
    address internal admin;

    event SetRiver(address indexed river);
    event SetRecipient(address indexed withdrawalCredentialAddress, address indexed recipient);

    function _allowConsolidation(address account) internal {
        address[] memory accounts = new address[](1);
        accounts[0] = account;
        uint256[] memory permissions = new uint256[](1);
        permissions[0] = LibAllowlistMasks.CONSOLIDATE_MASK;

        vm.prank(admin);
        allowlist.setAllowPermissions(accounts, permissions);
    }

    function _deny(address account) internal {
        address[] memory accounts = new address[](1);
        accounts[0] = account;
        uint256[] memory permissions = new uint256[](1);
        permissions[0] = LibAllowlistMasks.DENY_MASK;

        vm.prank(admin);
        allowlist.setDenyPermissions(accounts, permissions);
    }
}

contract ExternalConsolidationRecipientMappingV1InitializationTests is ExternalConsolidationRecipientMappingV1TestBase {
    function setUp() public {
        admin = makeAddr("admin");
        allowlist = new AllowlistV1();
        LibImplementationUnbricker.unbrick(vm, address(allowlist));
        allowlist.initAllowlistV1(admin, admin);
        river = new ExternalConsolidationRecipientMappingRiverMock(address(allowlist));
        mappingContract = new ExternalConsolidationRecipientMappingV1();
        LibImplementationUnbricker.unbrick(vm, address(mappingContract));
    }

    function testInitialization() external {
        vm.expectEmit(true, true, true, true);
        emit SetRiver(address(river));
        mappingContract.initExternalConsolidationRecipientMappingV1(address(river));
    }

    function testCannotReinitialize() external {
        mappingContract.initExternalConsolidationRecipientMappingV1(address(river));

        vm.expectRevert(abi.encodeWithSignature("InvalidInitialization(uint256,uint256)", 0, 1));
        mappingContract.initExternalConsolidationRecipientMappingV1(address(river));
    }
}

contract ExternalConsolidationRecipientMappingV1Tests is ExternalConsolidationRecipientMappingV1TestBase {
    function setUp() public {
        admin = makeAddr("admin");
        allowlist = new AllowlistV1();
        LibImplementationUnbricker.unbrick(vm, address(allowlist));
        allowlist.initAllowlistV1(admin, admin);
        allowlist.initAllowlistV1_1(admin);
        river = new ExternalConsolidationRecipientMappingRiverMock(address(allowlist));
        mappingContract = new ExternalConsolidationRecipientMappingV1();
        LibImplementationUnbricker.unbrick(vm, address(mappingContract));
        mappingContract.initExternalConsolidationRecipientMappingV1(address(river));
    }

    function testSetRecipient(uint256 senderSalt, uint256 recipientSalt) external {
        address sender = uf._new(senderSalt);
        address recipient = uf._new(recipientSalt);
        vm.assume(sender != address(0));
        vm.assume(recipient != address(0));

        _allowConsolidation(sender);

        vm.startPrank(sender);
        vm.expectEmit(true, true, true, true);
        emit SetRecipient(sender, recipient);
        mappingContract.setRecipient(recipient);
        vm.stopPrank();

        assertEq(mappingContract.getRecipient(sender), recipient);
    }

    function testSetRecipientCanOverwrite() external {
        address sender = makeAddr("sender");
        address firstRecipient = makeAddr("firstRecipient");
        address secondRecipient = makeAddr("secondRecipient");
        _allowConsolidation(sender);

        vm.startPrank(sender);
        mappingContract.setRecipient(firstRecipient);
        mappingContract.setRecipient(secondRecipient);
        vm.stopPrank();

        assertEq(mappingContract.getRecipient(sender), secondRecipient);
    }

    function testSetRecipientUnauthorized() external {
        address sender = makeAddr("sender");
        address recipient = makeAddr("recipient");

        vm.startPrank(sender);
        vm.expectRevert(abi.encodeWithSignature("Unauthorized(address)", sender));
        mappingContract.setRecipient(recipient);
        vm.stopPrank();
    }

    function testSetRecipientDeniedSender() external {
        address sender = makeAddr("sender");
        address recipient = makeAddr("recipient");
        _allowConsolidation(sender);
        _deny(sender);

        vm.startPrank(sender);
        vm.expectRevert(abi.encodeWithSignature("Denied(address)", sender));
        mappingContract.setRecipient(recipient);
        vm.stopPrank();
    }

    function testSetRecipientDeniedRecipient() external {
        address sender = makeAddr("sender");
        address recipient = makeAddr("recipient");
        _allowConsolidation(sender);
        _deny(recipient);

        vm.startPrank(sender);
        vm.expectRevert(abi.encodeWithSelector(IExternalConsolidationRecipientMappingV1.RecipientIsDenied.selector));
        mappingContract.setRecipient(recipient);
        vm.stopPrank();

        assertEq(mappingContract.getRecipient(sender), address(0));
    }

    function testSetRecipientZeroRecipientClearsRecipient() external {
        address sender = makeAddr("sender");
        address recipient = makeAddr("recipient");
        _allowConsolidation(sender);

        vm.startPrank(sender);
        mappingContract.setRecipient(recipient);
        mappingContract.setRecipient(address(0));
        vm.stopPrank();

        assertEq(mappingContract.getRecipient(sender), address(0));
        assertEq(mappingContract.resolveRecipient(sender), sender);
    }

    function testGetRecipientUnset() external {
        assertEq(mappingContract.getRecipient(makeAddr("withdrawalCredentialAddress")), address(0));
    }

    function testResolveRecipientUnsetReturnsWithdrawalCredentialAddress() external {
        address withdrawalCredentialAddress = makeAddr("withdrawalCredentialAddress");

        assertEq(mappingContract.resolveRecipient(withdrawalCredentialAddress), withdrawalCredentialAddress);
    }

    function testResolveRecipientSetReturnsMappedRecipient() external {
        address withdrawalCredentialAddress = makeAddr("withdrawalCredentialAddress");
        address recipient = makeAddr("recipient");
        _allowConsolidation(withdrawalCredentialAddress);

        vm.prank(withdrawalCredentialAddress);
        mappingContract.setRecipient(recipient);

        assertEq(mappingContract.resolveRecipient(withdrawalCredentialAddress), recipient);
    }

    function testVersion() external {
        assertEq(mappingContract.version(), "1.3.0");
    }
}
