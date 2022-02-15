//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

library OracleMembers {
    // review(nmvalera): major
    // Can we split the constant storage from the function logic? So we increase reusability
    // For example could we create a stateless library libraries/storage/AddressArrayStorage.sol that implements get(self), push(self, ...), etc. similarly to https://github.com/aragon/aragonOS/blob/next/contracts/common/UnstructuredStorage.sol? 
    // Then a contract that needs to use an AddressArrayStorage could import it and do something like (not sure it is possible):

    // AddressArrayStorage public constant ORACLE_MEMBERS_SLOT = bytes32(uint256(keccak256(...)) - 1);

    // review(nmvalera): medium
    // Could we hard code the hex instead of calling bytes32(uint256(keccak256(...)) - 1)? It should save some gas at deployment
    // Example: https://github.com/aragon/aragonOS/blob/next/contracts/apps/AppStorage.sol#L15

    // review(nmvalera): minor
    // Rename constant field *_SSLOT instead of *_SLOT to avoid confusing between Eth2.0 slot and storage slot 
    bytes32 public constant ORACLE_MEMBERS_SLOT = bytes32(uint256(keccak256("river.state.oracleMembers")) - 1);

    struct Slot {
        address[] value;
    }

    function get() internal view returns (address[] memory) {
        bytes32 slot = ORACLE_MEMBERS_SLOT;

        Slot storage r;

        assembly {
            r.slot := slot
        }

        return r.value;
    }

    function push(address newOracleMember) internal {
        bytes32 slot = ORACLE_MEMBERS_SLOT;

        Slot storage r;

        assembly {
            r.slot := slot
        }

        r.value.push(newOracleMember);
    }

    function indexOf(address memberAddress) internal view returns (int256) {
        bytes32 slot = ORACLE_MEMBERS_SLOT;

        Slot storage r;

        assembly {
            r.slot := slot
        }

        for (uint256 idx = 0; idx < r.value.length; ++idx) {
            if (r.value[idx] == memberAddress) {
                return int256(idx);
            }
        }

        return int256(-1);
    }

    function deleteItem(uint256 idx) internal {
        bytes32 slot = ORACLE_MEMBERS_SLOT;

        Slot storage r;

        assembly {
            r.slot := slot
        }

        uint256 lastIdx = r.value.length - 1;
        if (lastIdx != idx) {
            r.value[idx] = r.value[lastIdx];
        }

        r.value.pop();
    }
}
