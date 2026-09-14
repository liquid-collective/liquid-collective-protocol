//SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.34;

import "forge-std/Test.sol";

import "../../../src/TUPProxy.sol";
import "../../../src/RedeemManager.1.sol";
import "../../../src/state/redeemManager/RedeemQueue.2.sol";
import "../../../src/state/shared/Version.sol";
import {
    ITransparentUpgradeableProxy
} from "openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

/// @notice Fork coverage for `initializeRedeemManagerV1_3` against the live mainnet proxy.
/// @dev The unit tests reach version 2 with `_pokeVersionTo`, which asserts nothing about what the live
///      proxy actually holds. Two assumptions decide the financial cutover and are invisible to them:
///      that the stored version is exactly 2, so `init(2)` neither reverts nor silently skips, and that
///      the floor pins to the END of the real queue rather than to a count, an index, or a stale V1
///      layout. The V1_2 migration has already misfired once on a live deployment by running against a
///      queue that was not in the layout it expected, so this class of check is not hypothetical.
contract RateMarkFloorInitializationV1_3 is Test {
    bool internal _skip = false;

    /// @dev deployments/mainnet/RedeemManager_Proxy.json
    address internal constant REDEEM_MANAGER_MAINNET_ADDRESS = 0x080b3a41390b357Ad7e8097644d1DEDf57AD3375;
    /// @dev deployments/mainnet/RedeemManagerProxyFirewall.json — the proxy's admin
    address internal constant REDEEM_MANAGER_MAINNET_PROXY_ADMIN_ADDRESS = 0x2fDeF0b5e87Cf840FfE46E3A5318b1d59960DfCd;

    /// @dev The version `initializeRedeemManagerV1_3` requires to be stored before it runs
    uint256 internal constant EXPECTED_PRE_UPGRADE_VERSION = 2;

    function setUp() external {
        try vm.envString("MAINNET_FORK_RPC_URL") returns (string memory rpcUrl) {
            // No block literal is baked in: the cutover block is not known until the upgrade is
            // scheduled, and a stale pin would silently stop covering the state being upgraded. Set
            // MAINNET_FORK_BLOCK to pin the run; without it the fork follows the chain tip.
            uint256 forkBlock = vm.envOr("MAINNET_FORK_BLOCK", uint256(0));
            if (forkBlock == 0) {
                vm.createSelectFork(rpcUrl);
            } else {
                vm.createSelectFork(rpcUrl, forkBlock);
            }
            console.log("5.rateMarkFloorInitializationV1_3.t.sol is active at block", block.number);
        } catch {
            _skip = true;
        }
    }

    modifier shouldSkip() {
        if (!_skip) {
            _;
        }
    }

    /// @notice Reads the raw version slot, which has no public getter (`version()` returns a string)
    function _storedVersion() internal view returns (uint256) {
        return uint256(vm.load(REDEEM_MANAGER_MAINNET_ADDRESS, Version.VERSION_SLOT));
    }

    function _upgradeTo(RedeemManagerV1 _implementation, bytes memory _data) internal {
        vm.prank(REDEEM_MANAGER_MAINNET_PROXY_ADMIN_ADDRESS);
        if (_data.length == 0) {
            ITransparentUpgradeableProxy(REDEEM_MANAGER_MAINNET_ADDRESS).upgradeTo(address(_implementation));
        } else {
            ITransparentUpgradeableProxy(REDEEM_MANAGER_MAINNET_ADDRESS)
                .upgradeToAndCall(address(_implementation), _data);
        }
    }

    /// The upgrade as governance will actually execute it: implementation and initializer in one call.
    /// The floor must land on the end position of the live queue, every pending request must survive
    /// byte-for-byte, and no mark may exist yet — a mark created before the floor is pinned would cover
    /// pre-upgrade demand that cannot use it.
    function test_initializeV1_3_pinsFloorAtLivePreUpgradeQueueEnd() external shouldSkip {
        RedeemManagerV1 redeemManager = RedeemManagerV1(REDEEM_MANAGER_MAINNET_ADDRESS);

        // `init(2)` reverts if the live version is anything else, so the upgrade's success depends on
        // this. Asserting it separately distinguishes "wrong version" from any later failure.
        assertEq(_storedVersion(), EXPECTED_PRE_UPGRADE_VERSION, "live version is not 2");

        uint256 oldCount = redeemManager.getRedeemRequestCount();
        assertGt(oldCount, 0, "no pre-upgrade requests to protect");

        RedeemQueueV2.RedeemRequest[] memory oldRequests = new RedeemQueueV2.RedeemRequest[](oldCount);
        for (uint32 i = 0; i < oldCount; ++i) {
            oldRequests[i] = redeemManager.getRedeemRequestDetails(i);
        }

        // The queue is append-only and claiming preserves `height + amount`, so the last request's end
        // position is the total LsETH ever requested. That is the cutover the floor must pin.
        RedeemQueueV2.RedeemRequest memory lastRequest = oldRequests[oldCount - 1];
        uint256 expectedFloor = lastRequest.height + lastRequest.amount;

        RedeemManagerV1 newImplementation = new RedeemManagerV1();
        vm.expectEmit(true, true, true, true);
        emit IRedeemManagerV1.SetRateMarkFloor(expectedFloor);
        _upgradeTo(newImplementation, abi.encodeWithSelector(RedeemManagerV1.initializeRedeemManagerV1_3.selector));

        assertEq(_storedVersion(), EXPECTED_PRE_UPGRADE_VERSION + 1, "version did not advance");
        assertEq(redeemManager.version(), "1.3.0");

        // The cutover itself
        assertEq(redeemManager.getRateMarkFloor(), expectedFloor);

        // A floor of 0 would leave every pre-upgrade request markable, and a floor equal to the request
        // COUNT rather than the LsETH end position would be off by orders of magnitude. Both are the
        // mistakes this asserts against, so pin the relationship rather than only the value.
        assertGt(redeemManager.getRateMarkFloor(), oldCount, "floor looks like a count, not a position");

        // Nothing may be marked before the first post-upgrade report
        assertEq(redeemManager.getRateMarkCount(), 0);

        // Every pending request survives the upgrade untouched
        assertEq(redeemManager.getRedeemRequestCount(), oldCount);
        for (uint32 i = 0; i < oldCount; ++i) {
            RedeemQueueV2.RedeemRequest memory newRequest = redeemManager.getRedeemRequestDetails(i);
            assertEq(newRequest.amount, oldRequests[i].amount);
            assertEq(newRequest.maxRedeemableEth, oldRequests[i].maxRedeemableEth);
            assertEq(newRequest.recipient, oldRequests[i].recipient);
            assertEq(newRequest.height, oldRequests[i].height);
            assertEq(newRequest.initiator, oldRequests[i].initiator);

            // Pre-upgrade requests have no anchor, which is what routes them to the legacy payout cap
            assertEq(redeemManager.getRedeemRequestAnchor(i).lsETHAtRequest, 0);
            assertEq(redeemManager.getRedeemRequestAnchor(i).ethAtRequest, 0);
        }
    }

    /// The initializer is version-gated, not access-controlled, so a replay is only stopped by the
    /// stored version having advanced. Verified against live state rather than a poked slot.
    function test_initializeV1_3_revertsWhenRunTwice() external shouldSkip {
        RedeemManagerV1 redeemManager = RedeemManagerV1(REDEEM_MANAGER_MAINNET_ADDRESS);
        RedeemManagerV1 newImplementation = new RedeemManagerV1();
        _upgradeTo(newImplementation, abi.encodeWithSelector(RedeemManagerV1.initializeRedeemManagerV1_3.selector));

        uint256 pinnedFloor = redeemManager.getRateMarkFloor();

        vm.expectRevert(
            abi.encodeWithSignature(
                "InvalidInitialization(uint256,uint256)", EXPECTED_PRE_UPGRADE_VERSION, EXPECTED_PRE_UPGRADE_VERSION + 1
            )
        );
        redeemManager.initializeRedeemManagerV1_3();

        assertEq(redeemManager.getRateMarkFloor(), pinnedFloor, "floor moved on a rejected replay");
    }
}
