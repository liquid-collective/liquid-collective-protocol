// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "forge-std/Test.sol";

import "../../src/ConsolidationAttestationBuffer.sol";
import "./handlers/ConsolidationAttestationBufferHandler.sol";

/// @title ConsolidationAttestationBufferInvariantTest
/// @notice Invariants for the consolidation attestation relay and sticky error path.
contract ConsolidationAttestationBufferInvariantTest is Test {
    ConsolidationAttestationBuffer internal buffer;
    ConsolidationAttestationBufferHandler internal handler;

    function setUp() public {
        buffer = new ConsolidationAttestationBuffer();
        handler = new ConsolidationAttestationBufferHandler(buffer);

        targetContract(address(handler));

        bytes4[] memory selectors = new bytes4[](2);
        selectors[0] = ConsolidationAttestationBufferHandler.submit.selector;
        selectors[1] = ConsolidationAttestationBufferHandler.raiseError.selector;
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

    /// @notice C3: a flagged consolidation hash stays flagged.
    function invariant_flaggedHashesStayFlagged() public {
        uint256 len = handler.ghost_flaggedHashesLength();
        for (uint256 i = 0; i < len; i++) {
            assertTrue(
                buffer.isConsolidationErrored(handler.ghost_flaggedHashAt(i)), "C3: flagged hash became unflagged"
            );
        }
    }

    /// @notice C4: every invalid pubkey hash recorded by a first error report stays invalid.
    function invariant_invalidPubkeysStayInvalid() public {
        uint256 len = handler.ghost_invalidPubkeyHashesLength();
        for (uint256 i = 0; i < len; i++) {
            assertTrue(
                buffer.isInvalidPubkeyHash(handler.ghost_invalidPubkeyHashAt(i)), "C4: invalid pubkey hash became valid"
            );
        }
    }
}
