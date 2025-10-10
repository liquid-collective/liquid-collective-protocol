//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.20;

import "forge-std/Test.sol";

import "../../src/migration/TLC_globalUnlockScheduleMigration.sol";
import "../../src/TLC.1.sol";
import {ERC20VestableVotesUpgradeableV1} from "contracts/src/components/ERC20VestableVotesUpgradeable.1.sol";

contract TlcMigrationTest is Test {
    TlcMigration migrationsContract;
    TLCV1 tlc;
    string rpc = "https://mainnet.infura.io/v3/285952fdf94740b6b5b2c551accab0c9";

    uint32[] newLockDuration = [
        140190446,
        140190446,
        140190446,
        140190446,
        140190446,
        140190446,
        140190446,
        134747246,
        129908846,
        136820846,
        136820846,
        136820846,
        136820846,
        131464046,
        120923246,
        122651246,
        122392046,
        118158446,
        140190446,
        113892446,
        140190446,
        113892446,
        140190446,
        113892446,
        140190446,
        140190446,
        140190446,
        134747246,
        114788846,
        114788846,
        115134446,
        115220846,
        115307246,
        115134446,
        115307246,
        115307246,
        107279246,
        107279246,
        107279246,
        107279246,
        107279246,
        107279246,
        107279246,
        107279246,
        107279246,
        107279246,
        107279246,
        107279246,
        107279246,
        107279246,
        107279246,
        107279246,
        107279246,
        107279246,
        107279246,
        107279246,
        107279246,
        107279246,
        107279246,
        107279246,
        107279246,
        105371246,
        113147246,
        106062446,
        111419246,
        109432046,
        102606446,
        107279246,
        107279246,
        107279246,
        95348846,
        96558446,
        96299246,
        101396846,
        101483246,
        100273646,
        99064046,
        96644846,
        96040046,
        96040046,
        90942446,
        90510446,
        90510446,
        89387246,
        88696046,
        85672046,
        88782446,
        87227246,
        84548846,
        87227246,
        114702446,
        114702446,
        85758446,
        87227246,
        105716846,
        81524846,
        80920046,
        79537646,
        79537646,
        74872046,
        73662446,
        78500846,
        68564846
    ];

    bool[] isGlobalUnlockedScheduleIgnoredOld;

    function setUp() public {
        rpc = vm.rpcUrl("mainnet");
        vm.createFork(rpc);
    }

    function testCreate() public {
        migrationsContract = new TlcMigration();
    }

    function testGas() public {
        vm.createSelectFork(rpc, 23541980);
        migrationsContract = new TlcMigration();
        proxy tlcProxy = proxy(0xb5Fe6946836D687848B5aBd42dAbF531d5819632);
        vm.prank(0x0D1dE267015a75F5069fD1c9ed382210B3002cEb);
        tlcProxy.upgradeToAndCall(address(migrationsContract), abi.encodeWithSignature("migrate()"));
    }

    function testMigrate() public {
        // Significantly faster when cached locally, run a local fork for best perf (anvil recommended)
        vm.createSelectFork(rpc, 23541980);

        proxy tlcProxy = proxy(0xb5Fe6946836D687848B5aBd42dAbF531d5819632);
        assertEq(tlcProxy.getVestingScheduleCount(), 103);

        VestingSchedulesV2.VestingSchedule[] memory schedulesBefore = new VestingSchedulesV2.VestingSchedule[](103);
        for (uint256 i = 0; i < 103; i++) {
            schedulesBefore[i] = TLCV1(address(tlcProxy)).getVestingSchedule(i);
            isGlobalUnlockedScheduleIgnoredOld.push(
                ERC20VestableVotesUpgradeableV1(address(tlcProxy)).isGlobalUnlockedScheduleIgnored(i)
            );
            //console.log("%s,%s,%s", i, schedulesBefore[i].start, schedulesBefore[i].end);
        }

        migrationsContract = new TlcMigration();
        vm.prank(0x0D1dE267015a75F5069fD1c9ed382210B3002cEb);
        tlcProxy.upgradeToAndCall(address(migrationsContract), abi.encodeWithSignature("migrate()"));

        tlc = new TLCV1();
        vm.prank(0x0D1dE267015a75F5069fD1c9ed382210B3002cEb);
        tlcProxy.upgradeTo(address(0xF8745c392feF5c91fa1cdB0202efF7Ca08dF55ce));

        assertEq(tlcProxy.getVestingScheduleCount(), 103);

        // Check that the all the values that shouldn't change didn't
        for (uint256 i = 0; i < tlcProxy.getVestingScheduleCount(); i++) {
            VestingSchedulesV2.VestingSchedule memory schedule = TLCV1(address(tlcProxy)).getVestingSchedule(i);
            assertEq(schedule.start, schedulesBefore[i].start);
            assertEq(schedule.end, schedulesBefore[i].end);
            assertEq(schedule.cliffDuration, schedulesBefore[i].cliffDuration);
            assertEq(schedule.duration, schedulesBefore[i].duration);
            assertEq(schedule.periodDuration, schedulesBefore[i].periodDuration);
            assertEq(schedule.amount, schedulesBefore[i].amount);
            assertEq(schedule.creator, schedulesBefore[i].creator);
            assertEq(schedule.beneficiary, schedulesBefore[i].beneficiary);
            assertEq(schedule.revocable, schedulesBefore[i].revocable);
            assertEq(schedule.releasedAmount, schedulesBefore[i].releasedAmount);
            assertEq(
                isGlobalUnlockedScheduleIgnoredOld[i],
                ERC20VestableVotesUpgradeableV1(address(tlcProxy)).isGlobalUnlockedScheduleIgnored(i)
            );
        }
        // Check that the value we should have changed did change
        for (uint256 i = 0; i < tlcProxy.getVestingScheduleCount(); i++) {
            VestingSchedulesV2.VestingSchedule memory schedule = TLCV1(address(tlcProxy)).getVestingSchedule(i);
            assertEq(schedule.lockDuration, newLockDuration[i]);
        }
    }
}

interface proxy {
    function admin() external view returns (address);
    function upgradeTo(address newImplementation) external;
    function upgradeToAndCall(address newImplementation, bytes calldata cdata) external payable;
    function migrate() external;
    function getVestingScheduleCount() external view returns (uint256);
    function getMigrationCount() external view returns (uint256);
}
