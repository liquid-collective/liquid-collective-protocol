//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "./state/shared/Version.sol";

contract Initializable {
    error InvalidInitialization(uint256 version, uint256 expectedVersion);

    event Initialize(uint256 _version, bytes cdata);

    modifier init(uint256 version) {
        if (version != Version.get()) {
            revert InvalidInitialization(version, Version.get());
        }
        Version.set(version + 1); // prevents reentrency on the called method
        _;
        emit Initialize(version, msg.data);
    }
}
