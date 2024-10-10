//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.20;

import "forge-std/Test.sol";

import "../../src/migration/TLC_globalUnlockScheduleMigration.sol";
import "../../src/TLC.1.sol";

contract TlcMigrationTest is Test {
    TlcMigration migrationsContract;
    TLCV1 tlc;
    string rpc;

    uint32[] newLockDuration = [
        108604800,
        108604800,
        108604800,
        108604800,
        108604800,
        108604800,
        108604800,
        103161600,
        98323200,
        105235200,
        105235200,
        105235200,
        105235200,
        99878400,
        89337600,
        91065600,
        90806400,
        86572800,
        108604800,
        82306800,
        108604800,
        82306800,
        108604800,
        82306800,
        108604800,
        108604800,
        108604800,
        103161600,
        83203200,
        83203200,
        83548800,
        83635200,
        83721600,
        83548800,
        83721600,
        83721600,
        75693600,
        75693600,
        75693600,
        75693600,
        75693600,
        75693600,
        75693600,
        75693600,
        75693600,
        75693600,
        75693600,
        75693600,
        75693600,
        75693600,
        75693600,
        75693600,
        75693600,
        75693600,
        75693600,
        75693600,
        75693600,
        75693600,
        75693600,
        75693600,
        75693600,
        73785600,
        81561600,
        74476800,
        79833600,
        77846400,
        71020800,
        75693600,
        75693600,
        75693600,
        63763200,
        64972800,
        64713600,
        69811200,
        69897600,
        68688000,
        67478400,
        65059200,
        64454400,
        64454400,
        59356800,
        58924800,
        58924800,
        57801600,
        57110400,
        54086400,
        57196800,
        55641600,
        52963200,
        55641600,
        83116800,
        83116800,
        54172800,
        55641600,
        74131200,
        49939200,
        49334400,
        47952000,
        47952000,
        43286400,
        42076800,
        46915200,
        36979200
    ];

    function setUp() public {
        rpc = vm.rpcUrl("mainnet");
        vm.createFork(rpc);
    }

    function testCreate() public {
        migrationsContract = new TlcMigration();
    }

    function testGas() public {
        vm.createSelectFork(rpc, 20934540);
        migrationsContract = new TlcMigration();
        proxy tlcProxy = proxy(0xb5Fe6946836D687848B5aBd42dAbF531d5819632);
        vm.prank(0x0D1dE267015a75F5069fD1c9ed382210B3002cEb);
        tlcProxy.upgradeToAndCall(address(migrationsContract), abi.encodeWithSignature("migrate()"));
    }

    function testMigrate() public {
        // Significantly faster when cached locally, run a local fork for best perf (anvil recommended)
        vm.createSelectFork(rpc, 20934540);

        proxy tlcProxy = proxy(0xb5Fe6946836D687848B5aBd42dAbF531d5819632);
        assertEq(tlcProxy.getVestingScheduleCount(), 103);

        VestingSchedulesV2.VestingSchedule[] memory schedulesBefore = new VestingSchedulesV2.VestingSchedule[](103);
        for (uint256 i = 0; i < 103; i++) {
            schedulesBefore[i] = TLCV1(address(tlcProxy)).getVestingSchedule(i);
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
