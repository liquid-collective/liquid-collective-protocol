//SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.20;

import "forge-std/Test.sol";

import "../../../src/TUPProxy.sol";
import "../../../src/RedeemManager.1.sol";
import "../../../src/state/redeemManager/RedeemQueue.1.sol";
import "../../../src/state/redeemManager/RedeemQueue.2.sol";
import "../../../src/state/redeemManager/WithdrawalStack.sol";
import {ITransparentUpgradeableProxy} from
    "openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

interface MockIRedeemManagerV1 {
    function getRedeemRequestDetails(uint32 _redeemRequestId)
        external
        view
        returns (RedeemQueueV1.RedeemRequest memory);

    function getRedeemRequestCount() external view returns (uint256);
}

contract RedeemQueueMigrationV1_2 is Test {
    bool internal _skip = false;
    string internal _rpcUrl;

    address internal constant REDEEM_MANAGER_STAGING_ADDRESS = 0x0693875efbF04dDAd955c04332bA3324472DF980;
    address internal constant REDEEM_MANAGER_STAGING_PROXY_ADMIN_ADDRESS = 0x80Cf8bD4abf6C078C313f72588720AB86d45c5E6;

    function setUp() external {
        try vm.envString("TENDERLY_URL") returns (string memory rpcUrl) {
            _rpcUrl = rpcUrl;
            vm.createSelectFork(rpcUrl, 2440752);
            console.log("1.RedeemQueueMigrationV1_2.t.sol is active");
        } catch {
            _skip = true;
        }
    }

    modifier shouldSkip() {
        if (!_skip) {
            _;
        }
    }

    function test_migrate_allRedeemRequestsInOneCall() external shouldSkip {
        // Getting the RedeemManager proxy instance
        TUPProxy redeemManagerProxy = TUPProxy(payable(REDEEM_MANAGER_STAGING_ADDRESS));

        // Getting RedeemManagerV1 instance before the upgrade
        MockIRedeemManagerV1 RedeemManager = MockIRedeemManagerV1(REDEEM_MANAGER_STAGING_ADDRESS);
        // Getting all redeem request details, and count before the upgrade
        uint256 oldCount = RedeemManager.getRedeemRequestCount();
        RedeemQueueV1.RedeemRequest[155] memory oldRequests;
        for (uint256 i = 0; i < 155; i++) {
            oldRequests[i] = RedeemManager.getRedeemRequestDetails(uint32(i));
        }

        // Set up the fork at a new block for making the v1_2_1 upgrade, and testing
        vm.createSelectFork(_rpcUrl, 2440762);
        // Upgrade the RedeemManager
        RedeemManagerV1 newImplementation = new RedeemManagerV1();
        vm.prank(REDEEM_MANAGER_STAGING_PROXY_ADMIN_ADDRESS);
        ITransparentUpgradeableProxy(address(redeemManagerProxy)).upgradeToAndCall(
            address(newImplementation), abi.encodeWithSelector(RedeemManagerV1.initializeRedeemManagerV1_2.selector)
        );

        // After upgrade: check that state before the upgrade, and state after upgrade are same.
        RedeemManagerV1 RManager = RedeemManagerV1(REDEEM_MANAGER_STAGING_ADDRESS);
        uint256 newCount = RManager.getRedeemRequestCount();
        assertEq(newCount, oldCount);

        for (uint32 i = 0; i < newCount; i++) {
            RedeemQueueV2.RedeemRequest memory newRequest = RManager.getRedeemRequestDetails(i);

            assertEq(newRequest.amount, oldRequests[i].amount);
            assertEq(newRequest.maxRedeemableEth, oldRequests[i].maxRedeemableEth);
            assertEq(newRequest.recipient, oldRequests[i].recipient);
            assertEq(newRequest.height, oldRequests[i].height);
            assertEq(newRequest.initiator, oldRequests[i].recipient);
        }
    }
}
