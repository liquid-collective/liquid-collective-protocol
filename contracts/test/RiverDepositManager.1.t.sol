// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "forge-std/Test.sol";

import "../src/RiverDepositManager.1.sol";
import "../src/interfaces/components/IConsensusLayerDepositManager.1.sol";
import "./utils/LibImplementationUnbricker.sol";

/// @title RiverDepositManagerV1 direct-call safety tests
/// @notice RiverDepositManagerV1 is only meant to be reached through River's delegatecall stub, where it
///         runs in River's storage context. A DIRECT call to the standalone contract runs against its own
///         zeroed storage, so it cannot move funds. These tests pin that self-protection property.
contract RiverDepositManagerV1DirectCallTest is Test {
    RiverDepositManagerV1 internal manager;

    function setUp() public {
        manager = new RiverDepositManagerV1();
        LibImplementationUnbricker.unbrick(vm, address(manager));
    }

    /// @notice A direct deposit call reverts OnlyKeeper because the standalone contract's KeeperAddress
    ///         slot is zero, so `msg.sender != KeeperAddress.get()` for any real caller.
    function test_directDepositCallRevertsOnlyKeeper() public {
        bytes[] memory signatures = new bytes[](0);
        vm.expectRevert(IConsensusLayerDepositManagerV1.OnlyKeeper.selector);
        manager.depositToConsensusLayerWithAttestation(bytes32(0), bytes32(0), signatures);
    }

    /// @notice The standalone contract exposes no keeper/verifier configuration and holds no ETH.
    function test_standaloneStateIsInert() public {
        assertEq(manager.getKeeper(), address(0));
        assertEq(manager.getAttestationVerifier(), address(0));
        assertEq(address(manager).balance, 0);
    }
}
