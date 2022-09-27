//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "../../libraries/LibSanitize.sol";

library Operators {
    bytes32 internal constant OPERATORS_SLOT = bytes32(uint256(keccak256("river.state.operators")) - 1);

    bytes32 internal constant OPERATORS_MAPPING_SLOT = bytes32(uint256(keccak256("river.state.operatorsMapping")) - 1);

    struct Operator {
        bool active;
        string name;
        address operator;
        uint256 limit;
        uint256 funded;
        uint256 keys;
        uint256 stopped;
        uint256 latestKeysEditBlockNumber;
    }

    struct CachedOperator {
        bool active;
        string name;
        address operator;
        uint256 limit;
        uint256 funded;
        uint256 keys;
        uint256 stopped;
        uint256 index;
        uint256 picked;
    }

    struct SlotOperator {
        Operator[] value;
    }

    error OperatorNotFound(uint256 index);

    function get(uint256 index) internal view returns (Operator storage) {
        bytes32 slot = OPERATORS_SLOT;

        SlotOperator storage r;

        assembly {
            r.slot := slot
        }

        if (r.value.length <= index) {
            revert OperatorNotFound(index);
        }

        return r.value[index];
    }

    function getCount() internal view returns (uint256) {
        bytes32 slot = OPERATORS_SLOT;

        SlotOperator storage r;

        assembly {
            r.slot := slot
        }

        return r.value.length;
    }

    function _hasFundableKeys(Operators.Operator memory operator) internal pure returns (bool) {
        return (operator.active && operator.limit > operator.funded);
    }

    function getAllActive() internal view returns (Operator[] memory) {
        bytes32 slot = OPERATORS_SLOT;

        SlotOperator storage r;

        assembly {
            r.slot := slot
        }

        uint256 activeCount = 0;
        uint256 operatorCount = r.value.length;

        for (uint256 idx = 0; idx < operatorCount;) {
            if (r.value[idx].active) {
                unchecked {
                    ++activeCount;
                }
            }
            unchecked {
                ++idx;
            }
        }

        Operator[] memory activeOperators = new Operator[](activeCount);

        uint256 activeIdx = 0;
        for (uint256 idx = 0; idx < operatorCount;) {
            if (r.value[idx].active) {
                activeOperators[activeIdx] = r.value[idx];
                unchecked {
                    ++activeIdx;
                }
            }
            unchecked {
                ++idx;
            }
        }

        return activeOperators;
    }

    function getAllFundable() internal view returns (CachedOperator[] memory) {
        bytes32 slot = OPERATORS_SLOT;

        SlotOperator storage r;

        assembly {
            r.slot := slot
        }

        uint256 activeCount = 0;
        uint256 operatorCount = r.value.length;

        for (uint256 idx = 0; idx < operatorCount;) {
            if (_hasFundableKeys(r.value[idx])) {
                unchecked {
                    ++activeCount;
                }
            }
            unchecked {
                ++idx;
            }
        }

        CachedOperator[] memory activeOperators = new CachedOperator[](activeCount);

        uint256 activeIdx = 0;
        for (uint256 idx = 0; idx < operatorCount;) {
            Operator memory op = r.value[idx];
            if (_hasFundableKeys(op)) {
                activeOperators[activeIdx] = CachedOperator({
                    active: op.active,
                    name: op.name,
                    operator: op.operator,
                    limit: op.limit,
                    funded: op.funded,
                    keys: op.keys,
                    stopped: op.stopped,
                    index: idx,
                    picked: 0
                });
                unchecked {
                    ++activeIdx;
                }
            }
            unchecked {
                ++idx;
            }
        }

        return activeOperators;
    }

    function push(Operator memory newValue) internal returns (uint256) {
        LibSanitize._notZeroAddress(newValue.operator);
        LibSanitize._notEmptyString(newValue.name);
        bytes32 slot = OPERATORS_SLOT;

        SlotOperator storage r;

        assembly {
            r.slot := slot
        }

        r.value.push(newValue);

        return r.value.length;
    }

    function setKeys(uint256 opIndex, uint256 newKeys) internal {
        Operator storage op = get(opIndex);

        op.keys = newKeys;
        op.latestKeysEditBlockNumber = block.number;
    }
}
