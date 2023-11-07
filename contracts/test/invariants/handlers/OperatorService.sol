// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import "../../utils/BytesGenerator.sol";

import {Base} from "../Base.sol";
import {BaseService} from "./BaseService.sol";

contract OperatorService is BaseService, BytesGenerator {
    string internal operatorOneName = "NodeMasters";
    string internal operatorTwoName = "StakePros";

    uint256 internal operatorOneIndex;
    uint256 internal operatorTwoIndex;

    address internal operatorOne;
    address internal operatorOneFeeRecipient;
    address internal operatorTwo;
    address internal operatorTwoFeeRecipient;

    constructor(Base _base) BaseService(_base) {
        operatorOne = makeAddr("operatorOne");
        operatorTwo = makeAddr("operatorTwo");
        staticOperatorsSetup();
    }

    function staticOperatorsSetup() internal prankAdmin {
        base.oracle().addMember(base.oracleMember(), 1);

        operatorOneIndex = base.operatorsRegistry().addOperator(operatorOneName, operatorOne);
        operatorTwoIndex = base.operatorsRegistry().addOperator(operatorTwoName, operatorTwo);

        bytes memory hundredKeysOp1 = genBytes((48 + 96) * 100);

        base.operatorsRegistry().addValidators(operatorOneIndex, 100, hundredKeysOp1);

        bytes memory hundredKeysOp2 = genBytes((48 + 96) * 100);

        base.operatorsRegistry().addValidators(operatorTwoIndex, 100, hundredKeysOp2);

        uint256[] memory operatorIndexes = new uint256[](2);
        operatorIndexes[0] = operatorOneIndex;
        operatorIndexes[1] = operatorTwoIndex;
        uint32[] memory operatorLimits = new uint32[](2);
        operatorLimits[0] = 100;
        operatorLimits[1] = 100;

        base.operatorsRegistry().setOperatorLimits(operatorIndexes, operatorLimits, block.number);
    }

    // function getTargetSelectors() external view override returns (StdInvariant.FuzzSelector memory selectors) {
    // }

    // TODO: Add the dynamic operator management
}
