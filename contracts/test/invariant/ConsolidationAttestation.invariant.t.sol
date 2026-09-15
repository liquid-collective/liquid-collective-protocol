// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "forge-std/Test.sol";

import "../../src/ConsolidationAttestation.sol";
import "./handlers/ConsolidationAttestationHandler.sol";

/// @title ConsolidationAttestationInvariantTest
/// @notice Invariants for the consolidation attestation relay.
contract ConsolidationAttestationInvariantTest is Test {
    bytes32 internal constant DOMAIN_SEPARATOR = keccak256("consolidation-attestation-invariant-domain");

    ConsolidationAttestation internal buffer;
    ConsolidationAttestationHandler internal handler;

    function setUp() public {
        buffer = new ConsolidationAttestation(DOMAIN_SEPARATOR);
        handler = new ConsolidationAttestationHandler(buffer);

        targetContract(address(handler));

        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = ConsolidationAttestationHandler.submit.selector;
        targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));
    }

    /// @notice C1: lastAttestationIdx monotonically increases and equals successful submissions.
    function invariant_indexEqualsSubmissions() public {
        assertEq(buffer.lastAttestationIdx(), handler.ghost_submissions(), "C1: lastAttestationIdx != submissions");
    }

    /// @notice C2: the buffer never holds ETH (it has no payable entry points).
    function invariant_neverHoldsEth() public {
        assertEq(address(buffer).balance, 0, "C2: buffer holds ETH");
    }
}
