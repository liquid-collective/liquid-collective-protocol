//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../../src/AttestationVerifier.1.sol";
import "../../src/interfaces/IWithdraw.1.sol";

/// @title AttestationVerifierV1 Exposed Harness
/// @notice Test-only harness exposing the internal validation routines of AttestationVerifierV1.
///         `_validateConsolidation` and `_validateSelfConsolidation` became internal when the
///         consolidator-facing entry points moved onto the verifier; unit tests that exercised
///         them directly (previously external + onlyRiver) go through this harness instead.
contract AttestationVerifierV1ExposedHarness is AttestationVerifierV1 {
    function exposed_validateConsolidation(IAttestationVerifierV1.ConsolidationObject calldata consolidation)
        external
    {
        _validateConsolidation(consolidation);
    }

    function exposed_validateSelfConsolidation(bytes[] calldata pubkeys)
        external
        returns (IWithdrawV1.ConsolidationRequest[] memory)
    {
        return _validateSelfConsolidation(pubkeys);
    }
}
