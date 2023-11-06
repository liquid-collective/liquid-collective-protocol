//SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import "forge-std/StdInvariant.sol";
import {Base} from "../Base.sol";

abstract contract BaseService {
    Base internal base;

    modifier recordBlockData() {
        // Load time stamp & block number
        base.loadBlockState();
        _; // Execute
        // Save time stamp & block number
        base.writeBlockState();
    }

    constructor(Base _base) {
        base = _base;
    }

    function getTargetSelectors() external view virtual returns (StdInvariant.FuzzSelector memory) {}
}
