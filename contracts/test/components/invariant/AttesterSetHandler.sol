// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "forge-std/Test.sol";

import "../../../src/AttestationVerifier.1.sol";

/// @title AttesterSetHandler
/// @notice Fuzzer-target for the attester-set state machine on `AttestationVerifierV1`.
///         Exposes bounded wrappers around the three admin-gated calls that mutate the
///         (attester set, quorum) pair. Reverts are swallowed so the fuzzer can explore freely;
///         the invariant test asserts post-state correctness regardless of which calls reverted.
contract AttesterSetHandler is Test {
    AttestationVerifierV1 internal immutable verifier;
    address internal immutable admin;

    /// @dev Deterministic candidate pool. Sized > MAX_DEPOSIT_COMMITTEE_ATTESTERS so the
    ///      fuzzer can drive the cap branch. Includes the initial attesters so removals can
    ///      hit a currently-registered address.
    address[] internal candidates;

    constructor(AttestationVerifierV1 _verifier, address _admin, address[] memory _initialAttesters) {
        verifier = _verifier;
        admin = _admin;
        for (uint256 i = 0; i < _initialAttesters.length; i++) {
            candidates.push(_initialAttesters[i]);
        }
        uint256 cap = _verifier.MAX_DEPOSIT_COMMITTEE_ATTESTERS();
        uint256 paddingCount = cap + 10 - _initialAttesters.length;
        for (uint256 i = 0; i < paddingCount; i++) {
            candidates.push(address(uint160(0x1000 + i)));
        }
    }

    /// @dev Register an attester. Picks a deterministic candidate from the seeded pool.
    function addAttester(uint256 seed) external {
        address target = candidates[seed % candidates.length];
        vm.prank(admin);
        // solhint-disable-next-line no-empty-blocks
        try verifier.setDepositCommitteeAttester(target, true) {} catch {}
    }

    /// @dev Deregister an attester. Same candidate pool — most picks hit registered addresses.
    function removeAttester(uint256 seed) external {
        address target = candidates[seed % candidates.length];
        vm.prank(admin);
        // solhint-disable-next-line no-empty-blocks
        try verifier.setDepositCommitteeAttester(target, false) {} catch {}
    }

    /// @dev Set quorum. Bound the input so we cover zero, in-range, over-MAX-SIGS, and
    ///      over-attesterCount branches without wasting fuzzer cycles on huge numbers.
    function setQuorum(uint256 q) external {
        uint256 bounded = bound(q, 0, verifier.MAX_SIGNATURES() + 5);
        vm.prank(admin);
        // solhint-disable-next-line no-empty-blocks
        try verifier.setDepositCommitteeAttestationQuorum(bounded) {} catch {}
    }
}
