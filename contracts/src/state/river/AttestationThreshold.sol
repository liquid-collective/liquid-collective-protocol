//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../../libraries/LibUnstructuredStorage.sol";

library AttestationThreshold {
    bytes32 internal constant ATTESTATION_THRESHOLD_SLOT =
        bytes32(uint256(keccak256("river.state.attestationThreshold")) - 1);

    function get() internal view returns (uint256) {
        return LibUnstructuredStorage.getStorageUint256(ATTESTATION_THRESHOLD_SLOT);
    }

    function set(uint256 newValue) internal {
        LibUnstructuredStorage.setStorageUint256(ATTESTATION_THRESHOLD_SLOT, newValue);
    }
}
