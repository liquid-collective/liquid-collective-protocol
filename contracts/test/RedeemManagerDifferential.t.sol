//SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.34;

import "forge-std/Test.sol";

import {RiverMock} from "./RedeemManager.1.t.sol";
import "./utils/UserFactory.sol";
import "./utils/LibImplementationUnbricker.sol";
import "../src/Allowlist.1.sol";
import "../src/RedeemManager.1.sol";
import "../src/TUPProxy.sol";
import "../src/libraries/LibAllowlistMasks.sol";

/// @title Redemption payout differential harness
/// @notice Records what every redeem request is actually paid, over deterministic pseudo-random
///         sequences of requests, stopped-earning reports, withdrawal events and claims.
/// @dev The recorded table is the baseline the rate-mark removal is measured against. Generate it on
///      the pre-change commit, commit it, then regenerate after the change and diff. A row that moves
///      is either a bug or one of the two distribution differences the redesign accepts, and the diff
///      is what forces that call to be made explicitly per row rather than in aggregate.
///
///      Run with `make redemption-baseline`. The target carries a raised gas limit because two
///      hundred scenarios of real contract calls need more than forge's 2^30 default, and it is
///      named for the HEAVY_FUZZING exclusion so `make test` stays fast.
contract RedeemManagerDifferential_HEAVY_FUZZING is Test {
    string internal constant BASELINE_PATH = "./contracts/test/baselines/redemption-payouts.tsv";

    uint256 internal constant SCENARIOS = 200;
    uint256 internal constant STEPS_PER_SCENARIO = 30;
    uint256 internal constant MAX_REQUESTS_PER_SCENARIO = 12;

    uint256 internal constant MIN_RATE = 0.5e18;
    uint256 internal constant MAX_RATE = 2e18;
    uint256 internal constant MIN_REQUEST = 0.1e18;
    uint256 internal constant MAX_REQUEST = 50e18;
    uint256 internal constant MAX_STOPPED_EARNING_ETH = 60e18;

    /// @dev Word count of RedeemQueueV2.RedeemRequest, and the offset of `maxRedeemableEth` in it
    uint256 internal constant QUEUE_STRIDE = 5;
    uint256 internal constant MAX_REDEEMABLE_ETH_FIELD = 1;

    uint8 internal constant ACTION_OPEN = 0;
    uint8 internal constant ACTION_REPORT_STOPPED_EARNING = 1;
    uint8 internal constant ACTION_WITHDRAW = 2;
    uint8 internal constant ACTION_CLAIM = 3;

    AllowlistV1 internal allowlist;
    UserFactory internal uf = new UserFactory();
    address internal allowlistAdmin = makeAddr("allowlistAdmin");
    address internal allowlistAllower = makeAddr("allowlistAllower");
    address internal allowlistDenier = makeAddr("allowlistDenier");

    address internal proxyAdmin = makeAddr("proxyAdmin");
    RedeemManagerV1 internal implementation;

    RedeemManagerV1 internal redeemManager;
    RiverMock internal river;

    uint256 internal rngState;
    uint256 internal userSalt;

    /// @custom:attribute Per-request record, one row per request in the emitted table
    struct RequestRecord {
        address recipient;
        uint256 requestedLsETH;
        uint256 anchorEth;
        uint256 paidEth;
        uint256 remainingLsETH;
        bool anchored;
    }

    RequestRecord[] internal records;
    uint256 internal totalWithdrawnEth;

    function setUp() external {
        allowlist = new AllowlistV1();
        LibImplementationUnbricker.unbrick(vm, address(allowlist));
        allowlist.initAllowlistV1(allowlistAdmin, allowlistAllower);
        allowlist.initAllowlistV1_1(allowlistDenier);

        implementation = new RedeemManagerV1();
        LibImplementationUnbricker.unbrick(vm, address(implementation));
    }

    function testGenerateDifferentialBaseline() external {
        // Truncate, then append a line per request. Accumulating the whole table in one string and
        // writing it once is quadratic in memory copying and overruns the default test gas limit
        // around 150 scenarios.
        vm.writeFile(BASELINE_PATH, "scenario\trequest\trequestedLsETH\tanchorEth\tpaidEth\tremainingLsETH\tanchored\n");

        for (uint256 scenario = 0; scenario < SCENARIOS; ++scenario) {
            _resetScenario(scenario);
            _driveScenario();
            _assertScenarioInvariants(scenario);
            _writeScenario(scenario);
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Scenario driver
    // ─────────────────────────────────────────────────────────────────────────

    /// @dev Fresh storage per scenario. Reusing it would let an earlier scenario's queue, withdrawal
    ///      stack and rate-mark state decide the next scenario's payouts, and the cumulative-LsETH
    ///      axis is global, so nothing short of a new storage space isolates them.
    /// @dev A proxy over one shared implementation rather than a new implementation each time. The
    ///      implementation costs roughly twenty-five times a proxy to deploy, which alone overruns the
    ///      default test gas limit across this many scenarios.
    function _resetScenario(uint256 _scenario) internal {
        river = new RiverMock(address(allowlist));
        redeemManager = RedeemManagerV1(
            address(
                new TUPProxy(
                    address(implementation),
                    proxyAdmin,
                    abi.encodeWithSignature("initializeRedeemManagerV1(address)", address(river))
                )
            )
        );

        delete records;
        totalWithdrawnEth = 0;
        rngState = uint256(keccak256(abi.encode("redemption-differential", _scenario)));
    }

    function _driveScenario() internal {
        for (uint256 step = 0; step < STEPS_PER_SCENARIO; ++step) {
            uint8 action = uint8(_rnd(4));

            if (action == ACTION_OPEN) {
                _stepOpenRequest();
            } else if (action == ACTION_REPORT_STOPPED_EARNING) {
                _stepReportStoppedEarning();
            } else if (action == ACTION_WITHDRAW) {
                _stepReportWithdraw();
            } else {
                _stepClaim();
            }
        }

        // Drain whatever is still claimable, so the table records terminal payouts rather than
        // wherever the random walk happened to stop. A request left mid-fill hides a divergence that
        // only shows up on its last event.
        for (uint256 idx = 0; idx < records.length; ++idx) {
            _claimRequest(uint32(idx));
        }
    }

    function _stepOpenRequest() internal {
        if (records.length >= MAX_REQUESTS_PER_SCENARIO) {
            return;
        }

        river.sudoSetRate(_rndRange(MIN_RATE, MAX_RATE));

        uint256 amount = _rndRange(MIN_REQUEST, MAX_REQUEST);
        address user = _newAllowlistedUser();

        river.sudoDeal(user, amount);
        vm.prank(user);
        river.approve(address(redeemManager), amount);
        vm.prank(user);
        uint32 id = redeemManager.requestRedeem(amount, user);

        // One request in five is made to look pre-upgrade, so the unanchored path and its
        // interaction with the rate mark floor stay in the recorded surface.
        bool anchored = _rnd(5) != 0;
        if (!anchored) {
            _clearRequestAnchor(id);
        }

        records.push(
            RequestRecord({
                recipient: user,
                requestedLsETH: amount,
                anchorEth: redeemManager.getRedeemRequestAnchor(id).ethAtRequest,
                paidEth: 0,
                remainingLsETH: amount,
                anchored: anchored
            })
        );
    }

    /// @dev The LsETH leg is priced at a rate drawn independently of the pool rate, which is what puts
    ///      locked rates both above and below the covered requests' anchor rates into the table. Both
    ///      directions matter: above raises a cap, below lowers it and forfeits later recovery.
    function _stepReportStoppedEarning() internal {
        uint256 stoppedEarningEth = _rnd(MAX_STOPPED_EARNING_ETH);
        if (stoppedEarningEth == 0) {
            return;
        }

        uint256 lockedRate = _rndRange(MIN_RATE, MAX_RATE);
        river.sudoReportStoppedEarningAt(
            address(redeemManager), stoppedEarningEth, (stoppedEarningEth * 1e18) / lockedRate
        );
    }

    function _stepReportWithdraw() internal {
        uint256 demand = redeemManager.getRedeemDemand();
        if (demand == 0) {
            return;
        }

        uint256 settlementRate = _rndRange(MIN_RATE, MAX_RATE);
        river.sudoSetRate(settlementRate);

        uint256 lsETH = _rndRange(1, demand);
        uint256 withdrawnEth = (lsETH * settlementRate) / 1e18;
        if (withdrawnEth == 0) {
            return;
        }

        vm.deal(address(this), withdrawnEth);
        river.sudoReportWithdraw{value: withdrawnEth}(address(redeemManager), lsETH);
        totalWithdrawnEth += withdrawnEth;
    }

    function _stepClaim() internal {
        if (records.length == 0) {
            return;
        }
        _claimRequest(uint32(_rnd(records.length)));
    }

    /// @dev Claims request `_id` for whatever is currently claimable and folds the payout into its
    ///      record. A random depth is used so a request spanning several withdrawal events is
    ///      sometimes settled in one call and sometimes over several, which is the chunking the two
    ///      designs must agree on.
    function _claimRequest(uint32 _id) internal {
        uint32[] memory ids = new uint32[](1);
        ids[0] = _id;

        int64[] memory resolved = redeemManager.resolveRedeemRequests(ids);
        if (resolved[0] < 0) {
            return;
        }

        uint32[] memory eventIds = new uint32[](1);
        eventIds[0] = uint32(uint64(resolved[0]));

        address recipient = records[_id].recipient;
        uint256 balanceBefore = recipient.balance;

        redeemManager.claimRedeemRequests(ids, eventIds, true, uint16(_rndRange(1, 8)));

        records[_id].paidEth += recipient.balance - balanceBefore;
        records[_id].remainingLsETH = redeemManager.getRedeemRequestDetails(_id).amount;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Invariants that must hold under any payout design
    // ─────────────────────────────────────────────────────────────────────────

    function _assertScenarioInvariants(uint256 _scenario) internal {
        uint256 paidTotal = 0;
        for (uint256 idx = 0; idx < records.length; ++idx) {
            paidTotal += records[idx].paidEth;

            // A request whose LsETH has been fully consumed must have been paid something for it.
            // Zero here is the loss-of-funds shape: the redeemer's shares are gone and the ETH the
            // event supplied went to the exceeding buffer instead of to them.
            if (records[idx].remainingLsETH == 0 && records[idx].requestedLsETH > 0) {
                assertGt(records[idx].paidEth, 0, string.concat("zero payout, scenario ", vm.toString(_scenario)));
            }
        }

        // Every wei River handed over is either paid out or still held, and nothing else creates or
        // destroys ETH here. This catches an accounting error independently of the baseline diff.
        assertEq(
            address(redeemManager).balance + paidTotal,
            totalWithdrawnEth,
            string.concat("eth not conserved, scenario ", vm.toString(_scenario))
        );
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Helpers
    // ─────────────────────────────────────────────────────────────────────────

    function _writeScenario(uint256 _scenario) internal {
        for (uint256 idx = 0; idx < records.length; ++idx) {
            RequestRecord storage record = records[idx];
            vm.writeLine(
                BASELINE_PATH,
                string.concat(
                    vm.toString(_scenario),
                    "\t",
                    vm.toString(idx),
                    "\t",
                    vm.toString(record.requestedLsETH),
                    "\t",
                    vm.toString(record.anchorEth),
                    "\t",
                    vm.toString(record.paidEth),
                    "\t",
                    vm.toString(record.remainingLsETH),
                    "\t",
                    record.anchored ? "1" : "0"
                )
            );
        }
    }

    /// @dev Makes a request look the way one created before the stopped-earning upgrade does. Two
    ///      things define that state. The anchor is absent, which is what selects the pre-upgrade code
    ///      path, and `maxRedeemableEth` holds the request-time eth budget the pre-upgrade path caps
    ///      against. Both are set explicitly, because an anchored request stops carrying a budget in
    ///      that field once the credited-eth counter moves into it.
    function _clearRequestAnchor(uint32 _id) internal {
        uint256 requestTimeEth = redeemManager.getRedeemRequestAnchor(_id).ethAtRequest;

        bytes32 anchorSlot =
            keccak256(abi.encode(uint256(_id), bytes32(uint256(keccak256("river.state.redeemRequestAnchor")) - 1)));
        vm.store(address(redeemManager), anchorSlot, bytes32(0));
        vm.store(address(redeemManager), bytes32(uint256(anchorSlot) + 1), bytes32(0));

        vm.store(address(redeemManager), _queueFieldSlot(_id, MAX_REDEEMABLE_ETH_FIELD), bytes32(requestTimeEth));
    }

    /// @dev Storage slot of one field of queue element `_id`. The queue is a dynamic array at a raw
    ///      keccak slot, so elements start at `keccak256(slot)` and stride by the struct's word count.
    function _queueFieldSlot(uint32 _id, uint256 _field) internal pure returns (bytes32) {
        uint256 base = uint256(keccak256(abi.encode(bytes32(uint256(keccak256("river.state.redeemQueue")) - 1))));
        return bytes32(base + uint256(_id) * QUEUE_STRIDE + _field);
    }

    function _newAllowlistedUser() internal returns (address user) {
        user = uf._new(++userSalt);

        address[] memory accounts = new address[](1);
        accounts[0] = user;
        uint256[] memory permissions = new uint256[](1);
        permissions[0] = LibAllowlistMasks.REDEEM_MASK | LibAllowlistMasks.DEPOSIT_MASK;

        vm.prank(allowlistAllower);
        allowlist.setAllowPermissions(accounts, permissions);
    }

    function _rnd(uint256 _bound) internal returns (uint256) {
        rngState = uint256(keccak256(abi.encode(rngState)));
        return _bound == 0 ? 0 : rngState % _bound;
    }

    function _rndRange(uint256 _min, uint256 _max) internal returns (uint256) {
        return _min + _rnd(_max - _min + 1);
    }

    receive() external payable {}
}
