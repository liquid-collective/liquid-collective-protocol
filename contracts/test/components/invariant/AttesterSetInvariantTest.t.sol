// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "forge-std/Test.sol";

import "../../../src/AttestationVerifier.1.sol";
import "../../utils/LibImplementationUnbricker.sol";
import "./AttesterSetHandler.sol";

/// @dev Minimal stand-in for River. The verifier's `onlyRiverAdmin` modifier resolves the admin
///      via `IAdministrable(RiverAddress.get()).getAdmin()`. The runtime cast only needs the
///      selector to resolve, so we expose `getAdmin()` without implementing the full interface
///      (which has 4 methods we'd never exercise here). The invariant test never calls
///      `fetchAndValidateDeposits()`, `recordNewlyFundedPubkeys`, or anything else that would exercise
///      River-shaped behavior, so this is all the wiring the verifier needs.
contract AdminStub {
    address internal immutable _admin;

    constructor(address admin_) {
        _admin = admin_;
    }

    function getAdmin() external view returns (address) {
        return _admin;
    }
}

contract AttesterSetDepositBufferStub {
    address internal immutable _processor;

    constructor(address processor_) {
        _processor = processor_;
    }

    function getProcessor() external view returns (address) {
        return _processor;
    }
}

/// @title AttesterSetInvariantTest
/// @notice Foundry-native invariant test on the attester-set state machine of
///         `AttestationVerifierV1`. Fuzzes random sequences of
///         `(addAttester, removeAttester, setQuorum)` via `AttesterSetHandler` and asserts the
///         five global invariants always hold across all reachable states.
///
///         The five invariants protect against:
///         - storage growth past `MAX_ROOT_ATTESTERS`
///         - soft-bricking the deposit flow by setting quorum > registered count
///         - soft-bricking the deposit flow by setting quorum > `MAX_SIGNATURES`
///         - auth bypass via quorum = 0
///         - desync between enumeration and `isRootAttester` membership
contract AttesterSetInvariantTest is Test {
    AttestationVerifierV1 internal verifier;
    AttesterSetHandler internal handler;

    address internal constant ADMIN = address(0xAD);

    function setUp() public {
        AdminStub riverStub = new AdminStub(ADMIN);
        AttesterSetDepositBufferStub bufferStub = new AttesterSetDepositBufferStub(address(riverStub));

        verifier = new AttestationVerifierV1();
        LibImplementationUnbricker.unbrick(vm, address(verifier));

        address[] memory initial = new address[](3);
        initial[0] = makeAddr("att1");
        initial[1] = makeAddr("att2");
        initial[2] = makeAddr("att3");

        verifier.initAttestationVerifierV1(address(riverStub), address(bufferStub), initial, 2, bytes4(0), initial, 2);

        handler = new AttesterSetHandler(verifier, ADMIN, initial);
        targetContract(address(handler));
    }

    /// @dev The registered attester set never grows beyond the storage cap.
    function invariant_attesterCountBoundedByMax() public {
        assertLe(verifier.getRootAttesterCount(), verifier.MAX_ROOT_ATTESTERS());
    }

    /// @dev Quorum is never higher than the number of registered attesters. A violation here
    ///      would mean `fetchAndValidateDeposits()` could not reach quorum from any valid input — soft-brick.
    function invariant_quorumLeAttesterCount() public {
        assertLe(verifier.getRootAttestationQuorum(), verifier.getRootAttesterCount());
    }

    /// @dev Quorum is never higher than the per-submission signature cap. Same soft-brick
    ///      failure mode as above, different mechanism (`_verifyAttestationQuorum` rejects
    ///      sig arrays larger than MAX_SIGNATURES).
    function invariant_quorumLeMaxSignatures() public {
        assertLe(verifier.getRootAttestationQuorum(), verifier.MAX_SIGNATURES());
    }

    /// @dev Quorum is always positive. A violation here would let the keeper submit deposits
    ///      with zero root signatures — full auth bypass.
    function invariant_quorumPositive() public {
        assertGt(verifier.getRootAttestationQuorum(), 0);
    }

    /// @dev Enumeration is a duplicate-free, zero-free representation of exactly the same set
    ///      exposed by `isRootAttester`, and its length is the canonical count.
    function invariant_enumerationMatchesMembership() public {
        address[] memory members = verifier.getRootAttesters();
        assertEq(members.length, verifier.getRootAttesterCount(), "enumeration length != count");

        for (uint256 i = 0; i < members.length; ++i) {
            assertTrue(members[i] != address(0), "enumeration contains zero address");
            assertTrue(verifier.isRootAttester(members[i]), "enumerated address is not a member");

            for (uint256 j = i + 1; j < members.length; ++j) {
                assertTrue(members[i] != members[j], "enumeration contains duplicate");
            }
        }

        uint256 n = handler.getCandidatesLength();
        for (uint256 i = 0; i < n; i++) {
            address candidate = handler.getCandidate(i);
            uint256 occurrences;
            for (uint256 j = 0; j < members.length; ++j) {
                if (members[j] == candidate) ++occurrences;
            }
            uint256 expected = verifier.isRootAttester(candidate) ? 1 : 0;
            assertEq(occurrences, expected, "enumeration != membership");
        }
    }

    /// @dev Design-time constants must satisfy `MAX_ROOT_ATTESTERS >= MAX_SIGNATURES`.
    ///      A violation would mean even at full attester capacity the system could not reach a
    ///      MAX_SIGNATURES-sized quorum — making invariants 2 and 3 irreconcilable in edge cases.
    function invariant_constantsCoherent() public {
        assertGe(verifier.MAX_ROOT_ATTESTERS(), verifier.MAX_SIGNATURES());
    }
}
