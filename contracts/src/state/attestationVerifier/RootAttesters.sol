//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../../libraries/LibSanitize.sol";
import "../../libraries/LibUnstructuredStorage.sol";

/// @title RootAttesters
/// @notice Unstructured storage library for the enumerable root attester set.
/// @dev The index mapping stores each member's array index plus one. Zero means absent, so
///      membership remains one SLOAD while the array supports bounded enumeration.
library RootAttesters {
    bytes32 internal constant ROOT_ATTESTERS_ARRAY_SLOT =
        bytes32(uint256(keccak256("attestationVerifier.state.rootAttesters.array")) - 1);

    bytes32 internal constant ROOT_ATTESTERS_INDEX_BASE_SLOT =
        bytes32(uint256(keccak256("attestationVerifier.state.rootAttesters.index")) - 1);

    struct Slot {
        address[] value;
    }

    /// @notice Retrieve the storage pointer to the attester array
    /// @return r The array slot
    function _slot() private pure returns (Slot storage r) {
        bytes32 slot = ROOT_ATTESTERS_ARRAY_SLOT;

        // solhint-disable-next-line no-inline-assembly
        assembly {
            r.slot := slot
        }
    }

    /// @notice Retrieve the slot holding the stored position of an account
    /// @param account The account to derive the slot for
    /// @return The storage slot
    function _indexSlot(address account) private pure returns (bytes32) {
        return keccak256(abi.encode(ROOT_ATTESTERS_INDEX_BASE_SLOT, account));
    }

    /// @notice Retrieve all root attesters
    /// @dev The order is not stable and may change when an attester is removed.
    /// @return The root attester list
    function get() internal view returns (address[] memory) {
        return _slot().value;
    }

    /// @notice Retrieve the stored position of an account
    /// @param account The account to look up
    /// @return The account's array index plus one, zero if the account is not a member
    function indexOfPlusOne(address account) internal view returns (uint256) {
        return LibUnstructuredStorage.getStorageUint256(_indexSlot(account));
    }

    /// @notice Check if an account is a root attester
    /// @param account The account to check
    /// @return True if the account is a root attester, false otherwise
    function isRootAttester(address account) internal view returns (bool) {
        return indexOfPlusOne(account) != 0;
    }

    /// @notice Append a root attester to the set
    /// @param account The account to add
    function push(address account) internal {
        LibSanitize._notZeroAddress(account);

        address[] storage members = _slot().value;
        members.push(account);
        LibUnstructuredStorage.setStorageUint256(_indexSlot(account), members.length);
    }

    /// @notice Remove a root attester using unordered swap-and-pop
    /// @param account The account to remove
    function remove(address account) internal {
        uint256 position = indexOfPlusOne(account);
        if (position == 0) return;

        address[] storage members = _slot().value;
        uint256 idx = position - 1;
        uint256 lastIdx = members.length - 1;

        if (lastIdx != idx) {
            address moved = members[lastIdx];
            members[idx] = moved;
            LibUnstructuredStorage.setStorageUint256(_indexSlot(moved), position);
        }

        members.pop();
        LibUnstructuredStorage.setStorageUint256(_indexSlot(account), 0);
    }

    /// @notice Retrieve the root attester count
    /// @return The root attester count
    function getCount() internal view returns (uint256) {
        return _slot().value.length;
    }
}
