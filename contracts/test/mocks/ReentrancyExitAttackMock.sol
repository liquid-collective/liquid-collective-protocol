// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../../src/interfaces/IOperatorRegistry.1.sol";

/// @notice Attacker contract: registered as the keeper, it re-enters requestETHExits
/// from its receive() (triggered by the excess-fee refund the function sends back to
/// msg.sender) to prove the nonReentrant guard is enforced.
contract ReentrancyExitAttackMock {
    IOperatorsRegistryV1 public immutable target;
    bool public reentrancySucceeded;
    bool internal _armed;

    IOperatorsRegistryV1.ExitETHAllocation[] internal _allocations;

    constructor(address _target) {
        target = IOperatorsRegistryV1(_target);
    }

    /// @notice Primes the CL exit allocation re-used for both the outer and the re-entrant call.
    function setAttackAllocation(IOperatorsRegistryV1.ExitETHAllocation[] calldata allocations) external {
        delete _allocations;
        for (uint256 i = 0; i < allocations.length; ++i) {
            _allocations.push(allocations[i]);
        }
    }

    /// @notice Outer entrypoint. Attaches excess ETH so requestETHExits refunds it to this
    /// contract mid-execution, invoking receive() before the function has returned.
    function attack() external payable {
        _armed = true;
        target.requestETHExits{value: msg.value}(_allocations, new IOperatorsRegistryV1.ELExitETHAllocation[](0), 0);
    }

    receive() external payable {
        if (!_armed) {
            return;
        }
        _armed = false; // single re-entry attempt; avoids an infinite refund loop
        try target.requestETHExits(_allocations, new IOperatorsRegistryV1.ELExitETHAllocation[](0), 0) {
            reentrancySucceeded = true;
        } catch {}
    }
}
