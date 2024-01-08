// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import "../../contracts/src/OperatorsRegistry.1.sol";
import "../../contracts/src/state/operatorsRegistry/Operators.2.sol";
contract OperatorsRegistryV1Harness is OperatorsRegistryV1 {
    
    function getOperatorAddress(uint256 index) external view returns (address) {
        OperatorsV2.Operator memory op = OperatorsV2.get(index);
        return op.operator;
    }

    function operatorStateIsValid(uint256 opIndex) external view returns (bool) {
        OperatorsV2.Operator memory op = OperatorsV2.get(opIndex);
        return op.keys >= op.limit &&
            op.limit >= op.funded &&
            op.funded >= op.requestedExits;
    }

    function operatorIsActive(uint256 opIndex) external view returns (bool) {
        OperatorsV2.Operator memory op = OperatorsV2.get(opIndex);
        return op.active;
    }

    function getValidatorKey(uint256 opIndex, uint256 valIndex) external view returns (bytes memory) {
        (bytes memory publicKey, bytes memory signature) = ValidatorKeys.get(opIndex, valIndex);
        return publicKey;
    }

    function getActiveValidatorsCount(OperatorsV2.CachedOperator memory operator) internal
        returns (uint256)
    {
        return operator.funded - operator.requestedExits;// + operator.picked;
    }

    function getOperatorsSaturationDiscrepancy() internal
        returns (uint256)
    {
        //TODO we need to also check the saturated operators for the upper limit
        (OperatorsV2.CachedOperator[] memory operators, uint256 fundableOperatorCount) = OperatorsV2.getAllFundable();

        if (fundableOperatorCount <= 1) {
            return 0;
        }
        uint256 minSaturation = getActiveValidatorsCount(operators[0]);
        uint256 maxSaturation = minSaturation;

        for (uint256 idx = 1; idx < fundableOperatorCount; ++idx) {
            uint256 saturation = getActiveValidatorsCount(operators[idx]);
            if (saturation > maxSaturation) {
                maxSaturation = saturation;
            }
            if (saturation < minSaturation) {
                minSaturation = saturation;
            }
        }
        return maxSaturation - minSaturation;
    }

}
