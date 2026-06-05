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
///      `fetchAndValidateDepositObject()`, `recordNewlyFundedPubkeys`, or anything else that would exercise
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
///         - desync between the `count` scalar and the `isRootAttester` mapping
contract AttesterSetInvariantTest is Test {
    AttestationVerifierV1 internal verifier;
    AttesterSetHandler internal handler;

    address internal constant ADMIN = address(0xAD);

    function setUp() public {
        AdminStub riverStub = new AdminStub(ADMIN);

        verifier = new AttestationVerifierV1();
        LibImplementationUnbricker.unbrick(vm, address(verifier));

        address[] memory initial = new address[](3);
        initial[0] = makeAddr("att1");
        initial[1] = makeAddr("att2");
        initial[2] = makeAddr("att3");

        verifier.initAttestationVerifierV1(address(riverStub), address(0xBEEF), initial, 2, bytes4(0), initial, 2);

        handler = new AttesterSetHandler(verifier, ADMIN, initial);
        targetContract(address(handler));
    }

    /// @dev The registered attester set never grows beyond the storage cap.
    function invariant_attesterCountBoundedByMax() public {
        assertLe(verifier.getRootAttesterCount(), verifier.MAX_ROOT_ATTESTERS());
    }

    /// @dev Quorum is never higher than the number of registered attesters. A violation here
    ///      would mean `fetchAndValidateDepositObject()` could not reach quorum from any valid input — soft-brick.
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

    /// @dev The verifier's `count` scalar and its `isRootAttester` mapping must
    ///      stay in sync. A refactor that desyncs them (e.g. increments count without
    ///      writing the flag, or vice versa) would make the contract lie about its own state
    ///      and would not be caught by the four scalar-checking invariants above.
    function invariant_countMatchesMapping() public {
        uint256 expected = 0;
        uint256 n = handler.getCandidatesLength();
        for (uint256 i = 0; i < n; i++) {
            if (verifier.isRootAttester(handler.getCandidate(i))) {
                ++expected;
            }
        }
        assertEq(verifier.getRootAttesterCount(), expected, "count != mapping");
    }

    /// @dev Design-time constants must satisfy `MAX_ROOT_ATTESTERS >= MAX_SIGNATURES`.
    ///      A violation would mean even at full attester capacity the system could not reach a
    ///      MAX_SIGNATURES-sized quorum — making invariants 2 and 3 irreconcilable in edge cases.
    function invariant_constantsCoherent() public {
        assertGe(verifier.MAX_ROOT_ATTESTERS(), verifier.MAX_SIGNATURES());
    }
}
