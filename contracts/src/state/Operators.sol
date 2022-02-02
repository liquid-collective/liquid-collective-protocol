//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

library Operators {
    bytes32 public constant OPERATORS_SLOT =
        bytes32(uint256(keccak256("river.state.operators")) - 1);

    bytes32 public constant OPERATORS_MAPPING_SLOT =
        bytes32(uint256(keccak256("river.state.operatorsMapping")) - 1);

    struct Operator {
        bool active;
        string name;
        address operator;
        uint256 limit;
        uint256 funded;
        uint256 keys;
        uint256 stopped;
    }

    struct SlotOperator {
        Operator[] value;
    }

    struct SlotOperatorMapping {
        mapping(string => uint256) value;
    }

    function _getOperatorIndex(string memory name)
        internal
        view
        returns (uint256)
    {
        bytes32 slot = OPERATORS_MAPPING_SLOT;

        SlotOperatorMapping storage opm;

        assembly {
            opm.slot := slot
        }
        return opm.value[name];
    }

    function _setOperatorIndex(string memory name, uint256 index) internal {
        bytes32 slot = OPERATORS_MAPPING_SLOT;

        SlotOperatorMapping storage opm;

        assembly {
            opm.slot := slot
        }
        opm.value[name] = index;
    }

    function get(string memory name) internal view returns (Operator storage) {
        bytes32 slot = OPERATORS_SLOT;
        uint256 index = _getOperatorIndex(name);

        SlotOperator storage r;

        assembly {
            r.slot := slot
        }

        return r.value[index];
    }

    function getAllActive() internal view returns (Operator[] memory) {
        bytes32 slot = OPERATORS_SLOT;

        SlotOperator storage r;

        assembly {
            r.slot := slot
        }

        uint256 activeCount = 0;

        for (uint256 idx = 0; idx < r.value.length; ++idx) {
            if (r.value[idx].active) {
                ++activeCount;
            }
        }

        Operator[] memory activeOperators = new Operator[](activeCount);

        uint256 activeIdx = 0;
        for (uint256 idx = 0; idx < r.value.length; ++idx) {
            if (r.value[idx].active) {
                activeOperators[activeIdx] = r.value[idx];
                ++activeIdx;
            }
        }

        return activeOperators;
    }

    function set(string memory name, Operator memory newValue) internal {
        uint256 index = _getOperatorIndex(name);

        bytes32 slot = OPERATORS_SLOT;

        SlotOperator storage r;

        assembly {
            r.slot := slot
        }

        if (index == 0) {
            r.value.push(newValue);
            _setOperatorIndex(name, r.value.length - 1);
        } else {
            r.value[index] = newValue;
        }
    }
}
