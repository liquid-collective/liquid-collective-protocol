//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../../libraries/LibUnstructuredStorage.sol";

/// @title ConsumedDepositDataBufferIds
/// @notice Unstructured-storage mapping of deposit data buffer IDs that have already been
///         executed through `depositToConsensusLayerWithAttestation`. Prevents replay of
///         a successfully consumed batch: once an ID is recorded here, any subsequent call
///         referencing the same ID reverts in `validate()`.
///
/// @dev    Replay protection is critical for top-ups: a replayed initial-deposit batch
///         would already fail because every pubkey is in `ValidatorPubkeyLookup` after the
///         first execution, but top-ups *require* their pubkeys to be in the lookup, so a
///         second call with the same `depositDataBufferId` and attestations would otherwise
///         re-execute the top-up transfers. The DepositDataBuffer is also expected to
///         produce a unique `depositDataBufferId` per submission (see IDepositDataBuffer
///         natspec), so this mapping is a defense-in-depth on the verifier side.
library ConsumedDepositDataBufferIds {
    bytes32 internal constant CONSUMED_DEPOSIT_DATA_BUFFER_IDS_MAPPING_BASE_SLOT =
        bytes32(uint256(keccak256("attestationVerifier.state.consumedDepositDataBufferIds.mapping")) - 1);

    /// @notice Check if a deposit data buffer ID has already been consumed.
    /// @param depositDataBufferId The batch identifier.
    /// @return True if the ID has been consumed.
    function isConsumed(bytes32 depositDataBufferId) internal view returns (bool) {
        bytes32 slot = keccak256(abi.encode(CONSUMED_DEPOSIT_DATA_BUFFER_IDS_MAPPING_BASE_SLOT, depositDataBufferId));
        return LibUnstructuredStorage.getStorageBool(slot);
    }

    /// @notice Mark a deposit data buffer ID as consumed.
    /// @param depositDataBufferId The batch identifier.
    function markConsumed(bytes32 depositDataBufferId) internal {
        bytes32 slot = keccak256(abi.encode(CONSUMED_DEPOSIT_DATA_BUFFER_IDS_MAPPING_BASE_SLOT, depositDataBufferId));
        LibUnstructuredStorage.setStorageBool(slot, true);
    }
}
