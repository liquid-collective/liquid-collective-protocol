//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "./libraries/Errors.sol";

/// @title FirewallV1
/// @author Figment
/// @notice This contract protects calls to underlying target contracts by ensuring the caller holds
///         a proper role
contract FirewallV1 {
    mapping(bytes4 => bool) internal executorCanCall;

    address public governor;
    address public executor;
    address internal destination;

    // governor_ should be the most trustworthy entity in the underlying protocol - often, a DAO governor
    // executor_ should be a trustworthy entity that takes care of time-sensitive actions in the underlying protocol
    constructor(
        address governor_,
        address executor_,
        address destination_
    ) {
        governor = governor_;
        executor = executor_;
        destination = destination_;
        // River methods
        executorCanCall[getSelector("setOperatorStatus(uint256,bool)")] = true;
        executorCanCall[getSelector("setOperatorStoppedValidatorCount(uint256,uint256)")] = true;
        executorCanCall[getSelector("setOperatorLimit(uint256,uint256)")] = true;
        executorCanCall[getSelector("depositToConsensusLayer(uint256)")] = true;
        executorCanCall[getSelector("setOracle(address)")] = true;
        // Oracle methods
        executorCanCall[getSelector("addMember(address)")] = true;
        executorCanCall[getSelector("removeMember(address)")] = true;
        executorCanCall[getSelector("setQuorum(uint256)")] = true;
        executorCanCall[getSelector("setBeaconSpec(uint64,uint64,uint64,uint64)")] = true;
        executorCanCall[getSelector("setBeaconBounds(uint256,uint256)")] = true;
        // Firewall methods
        executorCanCall[getSelector("changeExecutor(address)")] = true;
    }

    /// @dev convert function sig, of form "functionName(arg1Type,arg2Type)", to the 4 bytes used in
    ///      a contract call, accessible at msg.sig
    function getSelector(string memory functionSig) internal pure returns (bytes4) {
        return bytes4(keccak256(bytes(functionSig)));
    }

    modifier ifGovernor() {
        if (msg.sender == governor) {
            _;
        } else {
            revert Errors.Unauthorized(msg.sender);
        }
    }

    /// @dev Change the governor
    function changeGovernor(address newGovernor) external ifGovernor {
        governor = newGovernor;
    }

    /// @dev Change the executor
    function changeExecutor(address newExecutor) external {
        executor = newExecutor;
    }

    /// @dev make a function only callable by the governor.
    function makeGovernorOnly(bytes4 functionSelector) external ifGovernor {
        executorCanCall[functionSelector] = false;
    }

    /// @dev make a function callable by the governor or executor
    function makeGovernorOrExecutor(bytes4 functionSelector) external ifGovernor {
        executorCanCall[functionSelector] = true;
    }

    /// @dev Validate that the caller is allowed to make the call in msg.sig
    function _checkCallerRole() internal view {
        if (msg.sender == governor || (executorCanCall[msg.sig] && msg.sender == executor)) {
            return;
        }
        revert Errors.Unauthorized(msg.sender);
    }

    /// @dev Forwards the current call to `destination`.
    ///      This function does not return to its internal call site, it will return directly to the external caller.
    function _forward(address destination_, uint256 value) internal {
        assembly {
            // Copy msg.data. We take full control of memory in this inline assembly
            // block because it will not return to Solidity code. We overwrite the
            // Solidity scratch pad at memory position 0.
            calldatacopy(0, 0, calldatasize())

            // Call the destination.
            // out and outsize are 0 because we don't know the size yet.
            let result := call(gas(), destination_, value, 0, calldatasize(), 0, 0)

            // Copy the returned data.
            returndatacopy(0, 0, returndatasize())

            switch result
            // call returns 0 on error.
            case 0 {
                revert(0, returndatasize())
            }
            default {
                return(0, returndatasize())
            }
        }
    }

    function _fallback() internal virtual {
        _checkCallerRole();
        _forward(destination, msg.value);
    }

    fallback() external payable virtual {
        _fallback();
    }

    receive() external payable virtual {
        _fallback();
    }
}
