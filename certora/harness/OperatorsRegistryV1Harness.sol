// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import "../../contracts/src/OperatorsRegistry.1.sol";
import "../../contracts/src/state/operatorsRegistry/Operators.2.sol";
contract OperatorsRegistryV1Harness is OperatorsRegistryV1 {
    
    function getOperatorAddress(uint256 index) external view returns (address) {
        OperatorsV2.Operator memory op = OperatorsV2.get(index);
        return op.operator;
    }

    function getOperatorsCount() external view returns (uint256) {
        return OperatorsV2.getCount();
    }

    function getActiveOperatorsCount() external view returns (uint256) {
        return OperatorsV2.getAllActive().length;
    }

    function getFundableOperatorsCount() external view returns (uint256) {
        (OperatorsV2.CachedOperator[] memory operators, uint256 fundableOperatorCount) = OperatorsV2.getAllFundable();
        return fundableOperatorCount;
    }

    function operatorStateIsValid(uint256 opIndex) external view returns (bool) {
        OperatorsV2.Operator memory op = OperatorsV2.get(opIndex);
        return op.keys >= op.limit &&
            op.limit >= op.funded &&
            op.funded >= op.requestedExits;
    }

    function getOperatorState(uint256 opIndex) external view 
        returns (uint256, uint256, uint256, uint256, uint32, bool, address) {
        OperatorsV2.Operator memory op = OperatorsV2.get(opIndex);
        uint32 stoppedCount = _getStoppedValidatorsCount(opIndex);
        return (op.keys, op.limit, op.funded, op.requestedExits, 
            stoppedCount, op.active, op.operator);
    }

    function operatorIsActive(uint256 opIndex) external view returns (bool) {
        OperatorsV2.Operator memory op = OperatorsV2.get(opIndex);
        return op.active;
    }

    function getValidatorKey(uint256 opIndex, uint256 valIndex) external view returns (bytes memory) {
        (bytes memory publicKey, bytes memory signature) = ValidatorKeys.get(opIndex, valIndex);
        return publicKey;
    }

    function compare(bytes memory b1, bytes memory b2) external pure returns (bool) {
        return keccak256(abi.encodePacked(b1)) == keccak256(abi.encodePacked(b2));
    }

    function getActiveValidatorsCount(OperatorsV2.Operator memory operator) internal view
        returns (uint256)
    {
        return operator.funded - operator.requestedExits;// + operator.picked;
    }

    function getOperatorsSaturationDiscrepancy() external view returns (uint256)
    {
        OperatorsV2.Operator[] memory ops = OperatorsV2.getAllActive();
        uint256 count = ops.length;

        uint256 minSaturation = type(uint256).max;
        uint256 maxSaturation = type(uint256).min;

        for (uint256 idx = 0; idx < count; ++idx) {
            uint256 saturation = getActiveValidatorsCount(ops[idx]);
            if (saturation > maxSaturation) {
                maxSaturation = saturation;
            }
            if (saturation < minSaturation && ops[idx].limit > ops[idx].funded) {
                minSaturation = saturation;
            }
        }
        return maxSaturation - minSaturation;
    }

    function getOperatorsSaturationDiscrepancy(uint256 index1, uint256 index2) external view returns (uint256)
    {
        OperatorsV2.Operator[] storage ops = OperatorsV2.getAll();
        if (!ops[index1].active || !ops[index2].active) return 0;   //inactive operators are not included in this
        if (_getStoppedValidatorsCount(index1) < ops[index1].requestedExits ||
            _getStoppedValidatorsCount(index2) < ops[index2].requestedExits) 
            return 0;   //validator that didn't comply to exit requests are discarted

        uint256 saturation1 = getActiveValidatorsCount(ops[index1]);
        bool isSaturated1 = ops[index1].limit <= ops[index1].funded;
        uint256 saturation2 = getActiveValidatorsCount(ops[index2]);
        bool isSaturated2 = ops[index2].limit <= ops[index2].funded;
        if (saturation1 == saturation2) return 0;
        if (saturation1 > saturation2 && !isSaturated2)
            return saturation1 - saturation2;
        if (saturation1 < saturation2 && !isSaturated1)
            return saturation2 - saturation1;
        return 0;   //means that the less populated one is already fully saturated
    }
}
