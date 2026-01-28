//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.22;

import "forge-std/Test.sol";

import "../../src/migration/TLC_globalUnlockScheduleMigration.sol";
import "../../src/TLC.1.sol";
import {ERC20VestableVotesUpgradeableV1} from "contracts/src/components/ERC20VestableVotesUpgradeable.1.sol";

contract TlcMigrationTest is Test {
    TlcMigration migrationsContract;
    TLCV1 tlc;
    string rpc = "https://mainnet.infura.io/v3/285952fdf94740b6b5b2c551accab0c9";

    uint32[] newLockDuration = [
        140140800,
        140140800,
        140140800,
        140140800,
        140140800,
        140140800,
        140140800,
        134697600,
        129859200,
        136771200,
        136771200,
        136771200,
        136771200,
        131414400,
        120873600,
        122601600,
        122342400,
        118108800,
        140140800,
        113842800,
        140140800,
        113842800,
        140140800,
        113842800,
        140140800,
        140140800,
        140140800,
        134697600,
        114739200,
        114739200,
        115084800,
        115171200,
        115257600,
        115084800,
        115257600,
        115257600,
        107229600,
        107229600,
        107229600,
        107229600,
        107229600,
        107229600,
        107229600,
        107229600,
        107229600,
        107229600,
        107229600,
        107229600,
        107229600,
        107229600,
        107229600,
        107229600,
        107229600,
        107229600,
        107229600,
        107229600,
        107229600,
        107229600,
        107229600,
        107229600,
        107229600,
        105321600,
        113097600,
        106012800,
        111369600,
        109382400,
        102556800,
        107229600,
        107229600,
        107229600,
        95299200,
        96508800,
        96249600,
        101347200,
        101433600,
        100224000,
        99014400,
        96595200,
        95990400,
        95990400,
        90892800,
        90460800,
        90460800,
        89337600,
        88646400,
        85622400,
        88732800,
        87177600,
        84499200,
        87177600,
        114652800,
        114652800,
        85708800,
        87177600,
        105667200,
        81475200,
        80870400,
        79488000,
        79488000,
        74822400,
        73612800,
        78451200,
        68515200
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
