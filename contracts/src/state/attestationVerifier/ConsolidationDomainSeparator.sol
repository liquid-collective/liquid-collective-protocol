//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../../libraries/LibUnstructuredStorage.sol";

/// @title Consolidation Domain Separator Storage
/// @notice Stores the EIP-712 domain separator used for consolidation attestations,
///         computed once at initialisation time.
/// @dev    The cached separator binds `verifyingContract` to River's address (matching
///         the deposit-flow anchor), with a distinct `name` field ("ConsolidationValidation")
///         so attestor signatures cannot be replayed across the deposit and consolidation flows.
///         Also bakes in `block.chainid` at `set()` time.
library ConsolidationDomainSeparator {
    /// @notice Storage slot of the consolidation domain separator
    bytes32 internal constant CONSOLIDATION_DOMAIN_SEPARATOR_SLOT =
        bytes32(uint256(keccak256("attestationVerifier.state.consolidationDomainSeparator")) - 1);

    /// @notice Retrieve the cached domain separator
    /// @return The cached domain separator
    function get() internal view returns (bytes32) {
        return LibUnstructuredStorage.getStorageBytes32(CONSOLIDATION_DOMAIN_SEPARATOR_SLOT);
    }

    /// @notice Cache the domain separator
    /// @param newValue The new domain separator
    function set(bytes32 newValue) internal {
        LibUnstructuredStorage.setStorageBytes32(CONSOLIDATION_DOMAIN_SEPARATOR_SLOT, newValue);
    }
}
