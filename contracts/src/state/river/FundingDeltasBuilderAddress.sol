//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../../libraries/LibSanitize.sol";
import "../../libraries/LibUnstructuredStorage.sol";

/// @title Funding Deltas Builder Address Storage
/// @notice Utility to manage the FundingDeltasBuilder address in River storage.
library FundingDeltasBuilderAddress {
    /// @notice Storage slot of the FundingDeltasBuilder address
    bytes32 internal constant FUNDING_DELTAS_BUILDER_ADDRESS_SLOT =
        bytes32(uint256(keccak256("river.state.fundingDeltasBuilderAddress")) - 1);

    /// @notice Retrieve the FundingDeltasBuilder address
    /// @return The FundingDeltasBuilder address
    function get() internal view returns (address) {
        return LibUnstructuredStorage.getStorageAddress(FUNDING_DELTAS_BUILDER_ADDRESS_SLOT);
    }

    /// @notice Sets the FundingDeltasBuilder address
    /// @param _newValue New FundingDeltasBuilder address
    function set(address _newValue) internal {
        LibSanitize._notZeroAddress(_newValue);
        LibUnstructuredStorage.setStorageAddress(FUNDING_DELTAS_BUILDER_ADDRESS_SLOT, _newValue);
    }
}
