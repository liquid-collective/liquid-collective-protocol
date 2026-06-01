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
///      `validate()`, `recordNewlyFundedPubkeys`, or anything else that would exercise
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
///         four global invariants always hold across all reachable states.
///
///         The four invariants protect against:
///         - storage growth past `MAX_DEPOSIT_COMMITTEE_ATTESTERS`
///         - soft-bricking the deposit flow by setting quorum > registered count
///         - soft-bricking the deposit flow by setting quorum > `MAX_SIGNATURES`
///         - auth bypass via quorum = 0
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

        verifier.initAttestationVerifierV1(address(riverStub), address(0xBEEF), initial, 2, bytes4(0));

        handler = new AttesterSetHandler(verifier, ADMIN, initial);
        targetContract(address(handler));
    }

    /// @dev The registered attester set never grows beyond the storage cap.
    function invariant_attesterCountBoundedByMax() public {
        assertLe(verifier.getDepositCommitteeAttesterCount(), 32);
    }

    /// @dev Quorum is never higher than the number of registered attesters. A violation here
    ///      would mean `validate()` could not reach quorum from any valid input — soft-brick.
    function invariant_quorumLeAttesterCount() public {
        assertLe(
            verifier.getDepositCommitteeAttestationQuorum(),
            verifier.getDepositCommitteeAttesterCount()
        );
    }

    /// @dev Quorum is never higher than the per-submission signature cap. Same soft-brick
    ///      failure mode as above, different mechanism (`_verifyAttestationQuorum` rejects
    ///      sig arrays larger than MAX_SIGNATURES).
    function invariant_quorumLeMaxSignatures() public {
        assertLe(verifier.getDepositCommitteeAttestationQuorum(), 20);
    }

    /// @dev Quorum is always positive. A violation here would let the keeper submit deposits
    ///      with zero deposit-committee signatures — full auth bypass.
    function invariant_quorumPositive() public {
        assertGt(verifier.getDepositCommitteeAttestationQuorum(), 0);
    }
}
