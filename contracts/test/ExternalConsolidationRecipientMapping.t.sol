//SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.34;

import "forge-std/Test.sol";

import "./utils/UserFactory.sol";
import "./utils/LibImplementationUnbricker.sol";

import "../src/Allowlist.1.sol";
import "../src/AttestationVerifier.1.sol";
import "../src/interfaces/IAttestationVerifier.1.sol";
import "../src/libraries/LibAllowlistMasks.sol";

/// @notice Minimal River mock exposing getAllowlist() — all the verifier's recipient-mapping flow needs.
contract ConsolidationRecipientRiverMock {
    address internal allowlist;

    constructor(address _allowlist) {
        allowlist = _allowlist;
    }

    function getAllowlist() external view returns (address) {
        return allowlist;
    }
}

/// @notice Exercises the external-consolidation recipient mapping, which now lives inside
///         AttestationVerifierV1 (setRecipient/getRecipient). The mapping functions only need
///         RiverAddress.get() to resolve the allowlist, so the verifier's River pointer is wired
///         directly rather than running its full initializer.
abstract contract VerifierRecipientMappingTestBase is Test {
    AttestationVerifierV1 internal verifier;
    AllowlistV1 internal allowlist;
    ConsolidationRecipientRiverMock internal river;
    UserFactory internal uf = new UserFactory();
    address internal admin;

    bytes32 internal constant RIVER_ADDRESS_SLOT = bytes32(uint256(keccak256("river.state.riverAddress")) - 1);

    event SetRecipient(address indexed withdrawalCredential, address indexed recipient);

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

contract VerifierRecipientMappingTests is VerifierRecipientMappingTestBase {
    function setUp() public {
        admin = makeAddr("admin");
        allowlist = new AllowlistV1();
        LibImplementationUnbricker.unbrick(vm, address(allowlist));
        allowlist.initAllowlistV1(admin, admin);
        allowlist.initAllowlistV1_1(admin);
        river = new ConsolidationRecipientRiverMock(address(allowlist));
        verifier = new AttestationVerifierV1();
        LibImplementationUnbricker.unbrick(vm, address(verifier));
        // The recipient-mapping functions resolve the allowlist via RiverAddress.get(); set it directly.
        vm.store(address(verifier), RIVER_ADDRESS_SLOT, bytes32(uint256(uint160(address(river)))));
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
        verifier.setRecipient(recipient);
        vm.stopPrank();

        assertEq(verifier.getRecipient(sender), recipient);
    }

    function testSetRecipientCanOverwrite() external {
        address sender = makeAddr("sender");
        address firstRecipient = makeAddr("firstRecipient");
        address secondRecipient = makeAddr("secondRecipient");
        _allowConsolidation(sender);

        vm.startPrank(sender);
        verifier.setRecipient(firstRecipient);
        verifier.setRecipient(secondRecipient);
        vm.stopPrank();

        assertEq(verifier.getRecipient(sender), secondRecipient);
    }

    function testSetRecipientUnauthorized() external {
        address sender = makeAddr("sender");
        address recipient = makeAddr("recipient");

        vm.startPrank(sender);
        vm.expectRevert(abi.encodeWithSignature("Unauthorized(address)", sender));
        verifier.setRecipient(recipient);
        vm.stopPrank();
    }

    function testSetRecipientDeniedSender() external {
        address sender = makeAddr("sender");
        address recipient = makeAddr("recipient");
        _allowConsolidation(sender);
        _deny(sender);

        vm.startPrank(sender);
        vm.expectRevert(abi.encodeWithSignature("Denied(address)", sender));
        verifier.setRecipient(recipient);
        vm.stopPrank();
    }

    function testSetRecipientDeniedRecipient() external {
        address sender = makeAddr("sender");
        address recipient = makeAddr("recipient");
        _allowConsolidation(sender);
        _deny(recipient);

        vm.startPrank(sender);
        vm.expectRevert(abi.encodeWithSelector(IAttestationVerifierV1.RecipientIsDenied.selector));
        verifier.setRecipient(recipient);
        vm.stopPrank();

        assertEq(verifier.getRecipient(sender), address(0));
    }

    function testSetRecipientZeroRecipientClearsRecipient() external {
        address sender = makeAddr("sender");
        address recipient = makeAddr("recipient");
        _allowConsolidation(sender);

        vm.startPrank(sender);
        verifier.setRecipient(recipient);
        verifier.setRecipient(address(0));
        vm.stopPrank();

        assertEq(verifier.getRecipient(sender), address(0));
    }

    function testGetRecipientUnset() external {
        assertEq(verifier.getRecipient(makeAddr("withdrawalCredential")), address(0));
    }
}
