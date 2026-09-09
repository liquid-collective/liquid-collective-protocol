// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "forge-std/Test.sol";

import "../../src/AttestationVerifier.1.sol";
import "../../src/interfaces/IAdministrable.sol";
import "../../src/interfaces/IAttestationVerifier.1.sol";
import "../../src/libraries/LibErrors.sol";
import "../utils/LibImplementationUnbricker.sol";

/// @dev River stand-in whose admin is deliberately DIFFERENT from the verifier's. Its
///      `getAdmin()` exists only so the tests can prove the verifier never consults it —
///      if the old `onlyRiverAdmin` gate came back, `riverAdmin` would regain access and
///      `testRiverAdmin_hasNoRightsOnVerifier` would fail.
contract RiverAdminStub {
    address internal immutable _riverAdmin;

    constructor(address riverAdmin_) {
        _riverAdmin = riverAdmin_;
    }

    function getAdmin() external view returns (address) {
        return _riverAdmin;
    }
}

contract DepositBufferProcessorStub {
    address internal immutable _processor;

    constructor(address processor_) {
        _processor = processor_;
    }

    function getProcessor() external view returns (address) {
        return _processor;
    }
}

/// @title AttestationVerifierAdminTest
/// @notice Covers the verifier's local governance: the admin is set at initialization, is
///         independent of River's admin, gates every admin setter, and rotates through the
///         two-step `proposeAdmin`/`acceptAdmin` flow inherited from `Administrable`.
contract AttestationVerifierAdminTest is Test {
    AttestationVerifierV1 internal verifier;
    RiverAdminStub internal river;

    address internal admin = makeAddr("verifierAdmin");
    address internal riverAdmin = makeAddr("riverAdmin");
    address internal stranger = makeAddr("stranger");

    address internal rootAttester1 = makeAddr("rootAttester1");
    address internal rootAttester2 = makeAddr("rootAttester2");
    address internal consolidationAttester1 = makeAddr("consolidationAttester1");
    address internal consolidationAttester2 = makeAddr("consolidationAttester2");
    address internal depositBufferForRiver;

    function setUp() public {
        river = new RiverAdminStub(riverAdmin);
        depositBufferForRiver = address(new DepositBufferProcessorStub(address(river)));
        verifier = _freshVerifier();
        _init(verifier, admin, address(river), depositBufferForRiver);
    }

    // -----------------------------------------------------------------------
    // Helpers
    // -----------------------------------------------------------------------

    function _freshVerifier() internal returns (AttestationVerifierV1 fresh) {
        fresh = new AttestationVerifierV1();
        LibImplementationUnbricker.unbrick(vm, address(fresh));
    }

    /// @dev Internal so `vm.expectRevert` pierces through to the init external call.
    function _init(AttestationVerifierV1 target, address admin_, address river_, address depositBuffer_) internal {
        address[] memory rootAttesters = new address[](2);
        rootAttesters[0] = rootAttester1;
        rootAttesters[1] = rootAttester2;
        address[] memory consolidationAttesters = new address[](2);
        consolidationAttesters[0] = consolidationAttester1;
        consolidationAttesters[1] = consolidationAttester2;

        target.initAttestationVerifierV1(
            admin_, river_, depositBuffer_, rootAttesters, 1, bytes4(0), consolidationAttesters, 1
        );
    }

    /// @dev Calldata for every `onlyAdmin`-gated function, used to assert the gate uniformly.
    ///      The assertions below compare the exact revert data against `Unauthorized(caller)`,
    ///      so a call whose body would revert for its own reasons cannot masquerade as a
    ///      passing auth check.
    function _adminGatedCalls() internal returns (bytes[] memory calls) {
        bytes[] memory pubkeys = new bytes[](1);
        pubkeys[0] = new bytes(48);

        calls = new bytes[](8);
        calls[0] = abi.encodeCall(IAttestationVerifierV1.setDepositDataBuffer, (makeAddr("newBuffer")));
        calls[1] = abi.encodeCall(IAttestationVerifierV1.setDepositDomainFromForkVersion, (bytes4(0)));
        calls[2] = abi.encodeCall(IAttestationVerifierV1.setRootAttester, (makeAddr("newRootAttester"), true));
        calls[3] = abi.encodeCall(IAttestationVerifierV1.setRootAttestationQuorum, (1));
        calls[4] = abi.encodeCall(
            IAttestationVerifierV1.setConsolidationCommitteeAttester, (makeAddr("newConsolidationAttester"), true)
        );
        calls[5] = abi.encodeCall(IAttestationVerifierV1.setConsolidationCommitteeAttestationQuorum, (1));
        calls[6] = abi.encodeCall(IAttestationVerifierPectraMigrationV1.migratePrePectraValidatorPubkeys, (0, 0, 0));
        calls[7] = abi.encodeCall(IAttestationVerifierPectraMigrationV1.removePrePectraValidatorPubkeys, (pubkeys));
    }

    /// @dev Asserts every admin-gated function reverts `Unauthorized(caller)` for `caller`.
    function _assertAllAdminCallsUnauthorized(address caller) internal {
        bytes[] memory calls = _adminGatedCalls();
        bytes memory expected = abi.encodeWithSelector(LibErrors.Unauthorized.selector, caller);

        for (uint256 i = 0; i < calls.length; ++i) {
            vm.prank(caller);
            (bool ok, bytes memory ret) = address(verifier).call(calls[i]);
            assertFalse(ok, "admin-gated call must revert for an unauthorized caller");
            assertEq(ret, expected, "expected LibErrors.Unauthorized(caller)");
        }
    }

    // -----------------------------------------------------------------------
    // Initialization
    // -----------------------------------------------------------------------

    function testInit_setsAdmin() public {
        assertEq(verifier.getAdmin(), admin, "admin must be the address passed at init");
        assertEq(verifier.getPendingAdmin(), address(0), "no pending admin right after init");
    }

    function testInit_emitsSetAdmin() public {
        AttestationVerifierV1 fresh = _freshVerifier();
        vm.expectEmit(true, true, true, true);
        emit IAdministrable.SetAdmin(admin);
        _init(fresh, admin, address(river), depositBufferForRiver);
    }

    /// @dev `AdministratorAddress.set` runs `LibSanitize._notZeroAddress`, so a deploy cannot
    ///      leave the verifier ungoverned.
    function testInit_revertsOnZeroAdmin() public {
        AttestationVerifierV1 fresh = _freshVerifier();
        vm.expectRevert(LibErrors.InvalidZeroAddress.selector);
        _init(fresh, address(0), address(river), depositBufferForRiver);
    }

    /// @dev The admin is independent of River's — passing the same address is a deployment
    ///      choice, not something the contract enforces.
    function testInit_adminMayDifferFromRiverAdmin() public {
        assertTrue(admin != riverAdmin, "test setup must use distinct addresses");
        assertEq(verifier.getAdmin(), admin);
    }

    // -----------------------------------------------------------------------
    // Authorization
    // -----------------------------------------------------------------------

    /// @dev Regression guard for the removed `onlyRiverAdmin` gate: River's admin is just
    ///      another stranger to this contract.
    function testRiverAdmin_hasNoRightsOnVerifier() public {
        _assertAllAdminCallsUnauthorized(riverAdmin);
    }

    function testAdminGatedCalls_revertForStranger() public {
        _assertAllAdminCallsUnauthorized(stranger);
    }

    /// @dev The mirror of the two tests above: the admin clears the gate on every one of them.
    ///      Asserted as "never `Unauthorized`" rather than "always succeeds" because two entries
    ///      (`migratePrePectraValidatorPubkeys`, `removePrePectraValidatorPubkeys`) reach past the
    ///      modifier into River wiring and pre-Pectra lookup state this fixture deliberately
    ///      does not set up — those bodies are covered in
    ///      `ConsensusLayerDepositManagerAttestation.t.sol`.
    function testAdminGatedCalls_adminIsNeverUnauthorized() public {
        bytes[] memory calls = _adminGatedCalls();
        for (uint256 i = 0; i < calls.length; ++i) {
            vm.prank(admin);
            (, bytes memory ret) = address(verifier).call(calls[i]);
            if (ret.length >= 4) {
                bytes4 selector = bytes4(ret);
                assertTrue(selector != LibErrors.Unauthorized.selector, "admin must clear the onlyAdmin gate");
            }
        }
    }

    /// @dev Proves the cross-contract lookup is gone: with a plain EOA (no code) at the River
    ///      address, `IAdministrable(river).getAdmin()` would have reverted and bricked every
    ///      admin setter. Under local governance the calls go through.
    function testAdminFunctions_workWhenRiverHasNoCode() public {
        address riverEoa = makeAddr("riverEoa");
        assertEq(riverEoa.code.length, 0, "River stand-in must have no code");
        address depositBufferForRiverEoa = address(new DepositBufferProcessorStub(riverEoa));

        AttestationVerifierV1 fresh = _freshVerifier();
        _init(fresh, admin, riverEoa, depositBufferForRiverEoa);

        vm.prank(admin);
        fresh.setRootAttestationQuorum(2);
        assertEq(fresh.getRootAttestationQuorum(), 2);
    }

    // -----------------------------------------------------------------------
    // Two-step admin transfer
    // -----------------------------------------------------------------------

    function testProposeAdmin_onlyAdmin() public {
        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(LibErrors.Unauthorized.selector, stranger));
        verifier.proposeAdmin(stranger);
    }

    function testProposeAdmin_setsPendingAdminAndEmits() public {
        address newAdmin = makeAddr("newAdmin");

        vm.expectEmit(true, true, true, true);
        emit IAdministrable.SetPendingAdmin(newAdmin);
        vm.prank(admin);
        verifier.proposeAdmin(newAdmin);

        assertEq(verifier.getPendingAdmin(), newAdmin);
        assertEq(verifier.getAdmin(), admin, "admin does not change until the proposal is accepted");
    }

    function testAcceptAdmin_onlyPendingAdmin() public {
        address newAdmin = makeAddr("newAdmin");
        vm.prank(admin);
        verifier.proposeAdmin(newAdmin);

        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(LibErrors.Unauthorized.selector, stranger));
        verifier.acceptAdmin();
    }

    function testAcceptAdmin_transfersControl() public {
        address newAdmin = makeAddr("newAdmin");

        vm.prank(admin);
        verifier.proposeAdmin(newAdmin);
        vm.prank(newAdmin);
        verifier.acceptAdmin();

        assertEq(verifier.getAdmin(), newAdmin);
        assertEq(verifier.getPendingAdmin(), address(0), "pending admin resets on acceptance");

        // The old admin loses access...
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(LibErrors.Unauthorized.selector, admin));
        verifier.setRootAttestationQuorum(2);

        // ...and the new one gains it.
        vm.prank(newAdmin);
        verifier.setRootAttestationQuorum(2);
        assertEq(verifier.getRootAttestationQuorum(), 2);
    }
}
