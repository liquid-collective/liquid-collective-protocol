// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "forge-std/Test.sol";

import "../../src/AttestationBuffer.sol";
import "./handlers/AttestationBufferHandler.sol";

/// @title AttestationBufferInvariantTest
/// @notice Invariants for the AttestationBuffer event relay, ported from the frontrun-mitigation suite.
contract AttestationBufferInvariantTest is Test {
    AttestationBuffer internal buffer;
    AttestationBufferHandler internal handler;

    function setUp() public {
        buffer = new AttestationBuffer();
        handler = new AttestationBufferHandler(buffer);

        targetContract(address(handler));

        bytes4[] memory selectors = new bytes4[](3);
        selectors[0] = AttestationBufferHandler.submit.selector;
        selectors[1] = AttestationBufferHandler.vetoBatch.selector;
        selectors[2] = AttestationBufferHandler.submitToVetoed.selector;
        targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));
    }

    /// @notice A1: lastAttestationIdx monotonically increases and equals the number of submissions.
    function invariant_indexEqualsSubmissions() public {
        assertEq(buffer.lastAttestationIdx(), handler.ghost_submissions(), "A1: lastAttestationIdx != submissions");
    }

    /// @notice A2: the buffer never holds ETH (it has no payable entry points).
    function invariant_neverHoldsEth() public {
        assertEq(address(buffer).balance, 0, "A2: buffer holds ETH");
    }

    /// @notice A3: a vetoed id stays vetoed (the veto is sticky — there is no un-veto).
    function invariant_vetoedIdsStayVetoed() public {
        uint256 len = handler.ghost_vetoedIdsLength();
        for (uint256 i = 0; i < len; i++) {
            assertTrue(buffer.isBatchVetoed(handler.ghost_vetoedIdAt(i)), "A3: vetoed id became unvetoed");
        }
    }
}
