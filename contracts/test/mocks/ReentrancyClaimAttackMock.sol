// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../../src/interfaces/IRedeemManager.1.sol";

/// @notice Attacker contract: re-enters claimRedeemRequests inside receive()
/// to prove reentrancy protection is enforced.
contract ReentrancyClaimAttackMock {
    IRedeemManagerV1 public immutable target;
    uint32[] internal _reqIds;
    uint32[] internal _eventIds;
    bool public reentrancySucceeded;

    constructor(address _target) {
        target = IRedeemManagerV1(_target);
    }

    function setAttackIds(uint32[] calldata reqIds, uint32[] calldata eventIds) external {
        _reqIds = reqIds;
        _eventIds = eventIds;
    }

    receive() external payable {
        try target.claimRedeemRequests(_reqIds, _eventIds, true, type(uint16).max) {
            reentrancySucceeded = true;
        } catch {}
    }
}
