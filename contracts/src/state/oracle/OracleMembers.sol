//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

library OracleMembers {
    /* Hardcoded hex is: bytes32(uint256(keccak256("river.state.oracleMembers")) - 1) */
    bytes32 internal constant ORACLE_MEMBERS_SLOT =
        hex"c4aba040293e5848600dd7b64a390db880c4a70937c23383e6c5b6619689863a";

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
