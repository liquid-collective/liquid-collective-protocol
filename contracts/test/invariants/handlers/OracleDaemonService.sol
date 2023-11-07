// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import "forge-std/StdInvariant.sol";

import {Base} from "../Base.sol";
import {BaseService} from "./BaseService.sol";

import {IOracleManagerV1} from "../../../src/interfaces/components/IOracleManager.1.sol";
contract OracleDaemonService is BaseService {
    constructor(Base _base) BaseService(_base) {}

    function getTargetSelectors() external view override returns (StdInvariant.FuzzSelector memory selectors) {
        bytes4[] memory selectorsArray = new bytes4[](1);
        selectorsArray[0] = this.action_report.selector;

        selectors.selectors = selectorsArray;
        selectors.addr = address(this);
    }

    function action_report() external prankOracleMember {
        IOracleManagerV1.ConsensusLayerReport memory dummyReport;
        dummyReport.stoppedValidatorCountPerOperator = new uint32[](1);
        base.oracle().reportConsensusLayerData(dummyReport);
    }
}
