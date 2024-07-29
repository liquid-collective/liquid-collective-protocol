//SPDX-License-Identifier: Proprietary
pragma solidity 0.8.20;

import "./interfaces/IProtocolVersion.sol";

abstract contract ProtocolVersion is IProtocolVersion {
    function version() external pure returns (string memory) {
        return "1.2.0";
    }
}
