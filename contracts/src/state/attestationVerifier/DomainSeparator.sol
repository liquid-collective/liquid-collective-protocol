//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../../libraries/LibUnstructuredStorage.sol";

/// @title Domain Separator Storage
/// @notice Stores the EIP-712 domain separator used by the AttestationVerifier,
///         computed once at initialisation time.
/// @dev    The cached separator binds `verifyingContract` to River's address (not the
///         verifier's own address) so attester signing tooling can sign against
///         River's identity rather than a sibling verifier that may be redeployed.
///         Also bakes in `block.chainid` at `set()` time. Ethereum L1 preserves
///         `chainid` across regular hard forks so the cache is safe in the normal case.
library DomainSeparator {
    /// @notice Storage slot of the domain separator
    bytes32 internal constant DOMAIN_SEPARATOR_SLOT =
        bytes32(uint256(keccak256("attestationVerifier.state.domainSeparator")) - 1);

    /// @notice Retrieve the cached domain separator
    /// @return The cached domain separator
    function get() internal view returns (bytes32) {
        return LibUnstructuredStorage.getStorageBytes32(DOMAIN_SEPARATOR_SLOT);
    }

    /// @notice Cache the domain separator
    /// @param newValue The new domain separator
    function set(bytes32 newValue) internal {
        LibUnstructuredStorage.setStorageBytes32(DOMAIN_SEPARATOR_SLOT, newValue);
    }
}
