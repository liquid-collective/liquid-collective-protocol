//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.20;

import "../state/tlc/VestingSchedules.2.sol";
import "../state/tlc/IgnoreGlobalUnlockSchedule.sol";

struct VestingScheduleMigration {
    // number of consecutive schedules to migrate with the same parameters
    uint8 scheduleCount;
    // The new lock duration
    uint32 newLockDuration;
    // if != 0, the new start value
    uint64 newStart;
    // if != 0, the new end value
    uint64 newEnd;
    // set cliff to 0 if true
    bool setCliff;
    // if true set vesting duration to 86400
    bool setDuration;
    // if true set vesting period duration to 86400
    bool setPeriodDuration;
    // if true schedule will not be subject to global unlock schedule
    bool ignoreGlobalUnlock;
}

uint256 constant OCTOBER_31_2026 = 1793454446;

contract TlcMigration {
    error CliffTooLong(uint256 i);
    error WrongUnlockDate(uint256 i);
    error WrongEnd(uint256 i);

    function migrate() external {
        VestingScheduleMigration[] memory migrations = new VestingScheduleMigration[](60);
        // 0 -> 6
        migrations[0] = VestingScheduleMigration({
            scheduleCount: 7,
            newStart: 0,
            newEnd: 0,
            newLockDuration: 140190446, //108604800, // 75772800
            setCliff: false,
            setDuration: false,
            setPeriodDuration: false,
            ignoreGlobalUnlock: false
        });
        // 7
        migrations[1] = VestingScheduleMigration({
            scheduleCount: 1,
            newStart: 0,
            newEnd: 0,
            newLockDuration: 134747246, //103161600, // 70329600
            setCliff: false,
            setDuration: false,
            setPeriodDuration: false,
            ignoreGlobalUnlock: false
        });
        // 8
        migrations[2] = VestingScheduleMigration({
            scheduleCount: 1,
            newStart: 0,
            newEnd: 0,
            newLockDuration: 129908846, //98323200, // 65491200
            setCliff: false,
            setDuration: false,
            setPeriodDuration: false,
            ignoreGlobalUnlock: false
        });
        // 9 -> 12
        migrations[3] = VestingScheduleMigration({
            scheduleCount: 4,
            newStart: 0,
            newEnd: 0,
            newLockDuration: 136820846, //105235200, // 72403200
            setCliff: false,
            setDuration: false,
            setPeriodDuration: false,
            ignoreGlobalUnlock: false
        });
        // 13
        migrations[4] = VestingScheduleMigration({
            scheduleCount: 1,
            newStart: 0,
            newEnd: 0,
            newLockDuration: 131464046, //99878400, // 67046400
            setCliff: false,
            setDuration: false,
            setPeriodDuration: false,
            ignoreGlobalUnlock: false
        });
        // 14
        migrations[5] = VestingScheduleMigration({
            scheduleCount: 1,
            newStart: 0,
            newEnd: 0,
            newLockDuration: 120923246, //89337600, // 56505600
            setCliff: false,
            setDuration: false,
            setPeriodDuration: false,
            ignoreGlobalUnlock: false
        });
        // 15
        migrations[6] = VestingScheduleMigration({
            scheduleCount: 1,
            newStart: 0,
            newEnd: 0,
            newLockDuration: 122651246, //91065600, // 58233600
            setCliff: false,
            setDuration: false,
            setPeriodDuration: false,
            ignoreGlobalUnlock: false
        });
        // 16
        migrations[7] = VestingScheduleMigration({
            scheduleCount: 1,
            newStart: 0,
            newEnd: 0,
            newLockDuration: 122392046, //90806400, // 57974400
            setCliff: false,
            setDuration: false,
            setPeriodDuration: false,
            ignoreGlobalUnlock: false
        });
        // 17
        migrations[8] = VestingScheduleMigration({
            scheduleCount: 1,
            newStart: 0,
            newEnd: 0,
            newLockDuration: 118158446, //86572800, // 53740800
            setCliff: false,
            setDuration: false,
            setPeriodDuration: false,
            ignoreGlobalUnlock: true
        });
        // 18
        migrations[9] = VestingScheduleMigration({
            scheduleCount: 1,
            newStart: 0,
            newEnd: 0,
            newLockDuration: 140190446, //108604800, // 75772800
            setCliff: false,
            setDuration: false,
            setPeriodDuration: false,
            ignoreGlobalUnlock: false
        });
        // 19
        migrations[10] = VestingScheduleMigration({
            scheduleCount: 1,
            newStart: 0,
            newEnd: 0,
            newLockDuration: 113892446, //82306800, // 49474800
            setCliff: false,
            setDuration: false,
            setPeriodDuration: false,
            ignoreGlobalUnlock: false
        });
        // 20
        migrations[11] = VestingScheduleMigration({
            scheduleCount: 1,
            newStart: 0,
            newEnd: 0,
            newLockDuration: 140190446, //108604800, // 75772800
            setCliff: false,
            setDuration: false,
            setPeriodDuration: false,
            ignoreGlobalUnlock: false
        });
        // 21
        migrations[12] = VestingScheduleMigration({
            scheduleCount: 1,
            newStart: 0,
            newEnd: 0,
            newLockDuration: 113892446, //82306800, // 49474800
            setCliff: false,
            setDuration: false,
            setPeriodDuration: false,
            ignoreGlobalUnlock: false
        });
        // 22
        migrations[13] = VestingScheduleMigration({
            scheduleCount: 1,
            newStart: 0,
            newEnd: 0,
            newLockDuration: 140190446, //108604800, // 75772800
            setCliff: false,
            setDuration: false,
            setPeriodDuration: false,
            ignoreGlobalUnlock: false
        });
        // 23
        migrations[14] = VestingScheduleMigration({
            scheduleCount: 1,
            newStart: 0,
            newEnd: 0,
            newLockDuration: 113892446, //82306800, // 49474800
            setCliff: false,
            setDuration: false,
            setPeriodDuration: false,
            ignoreGlobalUnlock: false
        });
        // 24 -> 26
        migrations[15] = VestingScheduleMigration({
            scheduleCount: 3,
            newStart: 0,
            newEnd: 0,
            newLockDuration: 140190446, //108604800, // 75772800
            setCliff: false,
            setDuration: false,
            setPeriodDuration: false,
            ignoreGlobalUnlock: false
        });
        // 27
        migrations[16] = VestingScheduleMigration({
            scheduleCount: 1,
            newStart: 0,
            newEnd: 0,
            newLockDuration: 134747246, //103161600, // 70329600
            setCliff: false,
            setDuration: false,
            setPeriodDuration: false,
            ignoreGlobalUnlock: false
        });
        // 28 -> 29
        migrations[17] = VestingScheduleMigration({
            scheduleCount: 2,
            newStart: 0,
            newEnd: 0,
            newLockDuration: 114788846, //83203200, // 50371200
            setCliff: false,
            setDuration: false,
            setPeriodDuration: false,
            ignoreGlobalUnlock: false
        });
        // 30
        migrations[18] = VestingScheduleMigration({
            scheduleCount: 1,
            newStart: 0,
            newEnd: 0,
            newLockDuration: 115134446, //83548800, // 50716800
            setCliff: false,
            setDuration: false,
            setPeriodDuration: false,
            ignoreGlobalUnlock: true
        });
        // 31
        migrations[19] = VestingScheduleMigration({
            scheduleCount: 1,
            newStart: 0,
            newEnd: 0,
            newLockDuration: 115220846, //83635200, // 50803200
            setCliff: false,
            setDuration: false,
            setPeriodDuration: false,
            ignoreGlobalUnlock: true
        });
        // 32
        migrations[20] = VestingScheduleMigration({
            scheduleCount: 1,
            newStart: 0,
            newEnd: 0,
            newLockDuration: 115307246, //83721600, // 50889600
            setCliff: false,
            setDuration: false,
            setPeriodDuration: false,
            ignoreGlobalUnlock: true
        });
        // 33
        migrations[21] = VestingScheduleMigration({
            scheduleCount: 1,
            newStart: 0,
            newEnd: 0,
            newLockDuration: 115134446, //83548800, // 50716800
            setCliff: false,
            setDuration: false,
            setPeriodDuration: false,
            ignoreGlobalUnlock: true
        });
        // 34 -> 35
        migrations[22] = VestingScheduleMigration({
            scheduleCount: 2,
            newStart: 0,
            newEnd: 0,
            newLockDuration: 115307246, //83721600, // 50889600
            setCliff: false,
            setDuration: false,
            setPeriodDuration: false,
            ignoreGlobalUnlock: true
        });
        // 36 -> 60
        migrations[23] = VestingScheduleMigration({
            scheduleCount: 25,
            newStart: 0,
            newEnd: 0,
            newLockDuration: 107279246, //75693600, // 42861600
            setCliff: false,
            setDuration: false,
            setPeriodDuration: false,
            ignoreGlobalUnlock: false
        });
        // 61
        migrations[24] = VestingScheduleMigration({
            scheduleCount: 1,
            newStart: 0,
            newEnd: 0,
            newLockDuration: 105371246, //73785600, // 40953600
            setCliff: false,
            setDuration: false,
            setPeriodDuration: false,
            ignoreGlobalUnlock: false
        });
        // 62
        migrations[25] = VestingScheduleMigration({
            scheduleCount: 1,
            newStart: 0,
            newEnd: 0,
            newLockDuration: 113147246, //81561600, // 48729600
            setCliff: false,
            setDuration: false,
            setPeriodDuration: false,
            ignoreGlobalUnlock: false
        });
        // 63
        migrations[26] = VestingScheduleMigration({
            scheduleCount: 1,
            newStart: 0,
            newEnd: 0,
            newLockDuration: 106062446, //74476800, // 41644800
            setCliff: false,
            setDuration: false,
            setPeriodDuration: false,
            ignoreGlobalUnlock: true
        });
        // 64
        migrations[27] = VestingScheduleMigration({
            scheduleCount: 1,
            newStart: 0,
            newEnd: 0,
            newLockDuration: 111419246, //79833600, // 47001600
            setCliff: false,
            setDuration: false,
            setPeriodDuration: false,
            ignoreGlobalUnlock: true
        });
        // 65
        migrations[28] = VestingScheduleMigration({
            scheduleCount: 1,
            newStart: 0,
            newEnd: 0,
            newLockDuration: 109432046, //77846400, // 45014400
            setCliff: false,
            setDuration: false,
            setPeriodDuration: false,
            ignoreGlobalUnlock: true
        });
        // 66
        migrations[29] = VestingScheduleMigration({
            scheduleCount: 1,
            newStart: 0,
            newEnd: 0,
            newLockDuration: 102606446, //71020800, // 38188800
            setCliff: false,
            setDuration: false,
            setPeriodDuration: false,
            ignoreGlobalUnlock: true
        });
        // 67 -> 69
        migrations[30] = VestingScheduleMigration({
            scheduleCount: 3,
            newStart: 0,
            newEnd: 0,
            newLockDuration: 107279246, //75693600, // 42861600
            setCliff: false,
            setDuration: false,
            setPeriodDuration: false,
            ignoreGlobalUnlock: false
        });
        // 70
        migrations[31] = VestingScheduleMigration({
            scheduleCount: 1,
            newStart: 0,
            newEnd: 0,
            newLockDuration: 95348846, //63763200, // 33004800
            setCliff: false,
            setDuration: false,
            setPeriodDuration: false,
            ignoreGlobalUnlock: false
        });
        // 71
        migrations[32] = VestingScheduleMigration({
            scheduleCount: 1,
            newStart: 0,
            newEnd: 0,
            newLockDuration: 96558446, //64972800, // 34214400
            setCliff: false,
            setDuration: false,
            setPeriodDuration: false,
            ignoreGlobalUnlock: false
        });
        // 72
        migrations[33] = VestingScheduleMigration({
            scheduleCount: 1,
            newStart: 0,
            newEnd: 0,
            newLockDuration: 96299246, //64713600, // 33955200
            setCliff: false,
            setDuration: false,
            setPeriodDuration: false,
            ignoreGlobalUnlock: false
        });
        // 73
        migrations[34] = VestingScheduleMigration({
            scheduleCount: 1,
            newStart: 0,
            newEnd: 0,
            newLockDuration: 101396846, //69811200, // 39052800
            setCliff: false,
            setDuration: false,
            setPeriodDuration: false,
            ignoreGlobalUnlock: true
        });
        // 74
        migrations[35] = VestingScheduleMigration({
            scheduleCount: 1,
            newStart: 0,
            newEnd: 0,
            newLockDuration: 101483246, //69897600, // 41731200
            setCliff: false,
            setDuration: false,
            setPeriodDuration: false,
            ignoreGlobalUnlock: false
        });
        // 75
        migrations[36] = VestingScheduleMigration({
            scheduleCount: 1,
            newStart: 0,
            newEnd: 0,
            newLockDuration: 100273646, //68688000, // 40521600
            setCliff: false,
            setDuration: false,
            setPeriodDuration: false,
            ignoreGlobalUnlock: false
        });
        // 76
        migrations[37] = VestingScheduleMigration({
            scheduleCount: 1,
            newStart: 0,
            newEnd: 0,
            newLockDuration: 99064046, //67478400, // 39312900
            setCliff: false,
            setDuration: false,
            setPeriodDuration: false,
            ignoreGlobalUnlock: false
        });
        // 77
        migrations[38] = VestingScheduleMigration({
            scheduleCount: 1,
            newStart: 0,
            newEnd: 0,
            newLockDuration: 96644846, //65059200, // 36892800
            setCliff: false,
            setDuration: false,
            setPeriodDuration: false,
            ignoreGlobalUnlock: false
        });
        // 78 -> 79
        migrations[39] = VestingScheduleMigration({
            scheduleCount: 2,
            newStart: 0,
            newEnd: 0,
            newLockDuration: 96040046, //64454400, // 36288000
            setCliff: false,
            setDuration: false,
            setPeriodDuration: false,
            ignoreGlobalUnlock: false
        });
        // 80
        migrations[40] = VestingScheduleMigration({
            scheduleCount: 1,
            newStart: 0,
            newEnd: 0,
            newLockDuration: 90942446, //59356800, // 33523200
            setCliff: false,
            setDuration: false,
            setPeriodDuration: false,
            ignoreGlobalUnlock: false
        });
        // 81 -> 82
        migrations[41] = VestingScheduleMigration({
            scheduleCount: 2,
            newStart: 0,
            newEnd: 0,
            newLockDuration: 90510446, //58924800, // 33091200
            setCliff: false,
            setDuration: false,
            setPeriodDuration: false,
            ignoreGlobalUnlock: true
        });
        // 83
        migrations[42] = VestingScheduleMigration({
            scheduleCount: 1,
            newStart: 0,
            newEnd: 0,
            newLockDuration: 89387246, //57801600, // 38016000
            setCliff: false,
            setDuration: false,
            setPeriodDuration: false,
            ignoreGlobalUnlock: true
        });
        // 84
        migrations[43] = VestingScheduleMigration({
            scheduleCount: 1,
            newStart: 0,
            newEnd: 0,
            newLockDuration: 88696046, //57110400, // 37324800
            setCliff: false,
            setDuration: false,
            setPeriodDuration: false,
            ignoreGlobalUnlock: false
        });
        // 85
        migrations[44] = VestingScheduleMigration({
            scheduleCount: 1,
            newStart: 0,
            newEnd: 0,
            newLockDuration: 85672046, //54086400, // 34300800
            setCliff: false,
            setDuration: false,
            setPeriodDuration: false,
            ignoreGlobalUnlock: false
        });
        // 86
        migrations[45] = VestingScheduleMigration({
            scheduleCount: 1,
            newStart: 0,
            newEnd: 0,
            newLockDuration: 88782446, //57196800, // 39571200
            setCliff: false,
            setDuration: false,
            setPeriodDuration: false,
            ignoreGlobalUnlock: false
        });
        // 87
        migrations[46] = VestingScheduleMigration({
            scheduleCount: 1,
            newStart: 0,
            newEnd: 0,
            newLockDuration: 87227246, //55641600, // 38016000
            setCliff: false,
            setDuration: false,
            setPeriodDuration: false,
            ignoreGlobalUnlock: false
        });
        // 88
        migrations[47] = VestingScheduleMigration({
            scheduleCount: 1,
            newStart: 0,
            newEnd: 0,
            newLockDuration: 84548846, //52963200, // 35337600
            setCliff: false,
            setDuration: false,
            setPeriodDuration: false,
            ignoreGlobalUnlock: false
        });
        // 89
        migrations[48] = VestingScheduleMigration({
            scheduleCount: 1,
            newStart: 0,
            newEnd: 0,
            newLockDuration: 87227246, //55641600, // 38016000
            setCliff: false,
            setDuration: false,
            setPeriodDuration: false,
            ignoreGlobalUnlock: false
        });
        // 90 -> 91
        migrations[49] = VestingScheduleMigration({
            scheduleCount: 2,
            newStart: 0,
            newEnd: 0,
            newLockDuration: 114702446, //83116800, // 65491200
            setCliff: false,
            setDuration: false,
            setPeriodDuration: false,
            ignoreGlobalUnlock: false
        });
        // 92
        migrations[50] = VestingScheduleMigration({
            scheduleCount: 1,
            newStart: 0,
            newEnd: 0,
            newLockDuration: 85758446, //54172800, // 36547200
            setCliff: false,
            setDuration: false,
            setPeriodDuration: false,
            ignoreGlobalUnlock: false
        });
        // 93
        migrations[51] = VestingScheduleMigration({
            scheduleCount: 1,
            newStart: 0,
            newEnd: 0,
            newLockDuration: 87227246, //55641600, // 38016000
            setCliff: false,
            setDuration: false,
            setPeriodDuration: false,
            ignoreGlobalUnlock: false
        });
        // 94
        migrations[52] = VestingScheduleMigration({
            scheduleCount: 1,
            newStart: 0,
            newEnd: 0,
            newLockDuration: 105716846, //74131200, // 56505600
            setCliff: false,
            setDuration: false,
            setPeriodDuration: false,
            ignoreGlobalUnlock: false
        });
        // 95
        migrations[53] = VestingScheduleMigration({
            scheduleCount: 1,
            newStart: 0,
            newEnd: 0,
            newLockDuration: 81524846, //49939200, // 35424000
            setCliff: false,
            setDuration: false,
            setPeriodDuration: false,
            ignoreGlobalUnlock: true
        });
        // 96
        migrations[54] = VestingScheduleMigration({
            scheduleCount: 1,
            newStart: 0,
            newEnd: 0,
            newLockDuration: 80920046, //49334400, // 34819200
            setCliff: false,
            setDuration: false,
            setPeriodDuration: false,
            ignoreGlobalUnlock: false
        });
        // 97 -> 98
        migrations[55] = VestingScheduleMigration({
            scheduleCount: 2,
            newStart: 0,
            newEnd: 0,
            newLockDuration: 79537646, //47952000, // 36547200
            setCliff: false,
            setDuration: false,
            setPeriodDuration: false,
            ignoreGlobalUnlock: false
        });
        // 99
        migrations[56] = VestingScheduleMigration({
            scheduleCount: 1,
            newStart: 0,
            newEnd: 0,
            newLockDuration: 74872046, //43286400, // 33696000
            setCliff: false,
            setDuration: false,
            setPeriodDuration: false,
            ignoreGlobalUnlock: false
        });
        // 100
        migrations[57] = VestingScheduleMigration({
            scheduleCount: 1,
            newStart: 0,
            newEnd: 0,
            newLockDuration: 73662446, //42076800, // 32486400
            setCliff: false,
            setDuration: false,
            setPeriodDuration: false,
            ignoreGlobalUnlock: false
        });
        // 101
        migrations[58] = VestingScheduleMigration({
            scheduleCount: 1,
            newStart: 0,
            newEnd: 0,
            newLockDuration: 78500846, //46915200, // 37324800
            setCliff: false,
            setDuration: false,
            setPeriodDuration: false,
            ignoreGlobalUnlock: false
        });
        // 102
        migrations[59] = VestingScheduleMigration({
            scheduleCount: 1,
            newStart: 0,
            newEnd: 0,
            newLockDuration: 68564846, //36979200, // 32918400
            setCliff: false,
            setDuration: false,
            setPeriodDuration: false,
            ignoreGlobalUnlock: true
        });

        // All schedules covered

        uint256 index = 0;
        for (uint256 i = 0; i < migrations.length; i++) {
            VestingScheduleMigration memory migration = migrations[i];
            for (uint256 j = 0; j < migration.scheduleCount; j++) {
                VestingSchedulesV2.VestingSchedule storage sch = VestingSchedulesV2.get(index);

                bool isRevoked = false;
                if (sch.start + sch.duration != sch.end) {
                    isRevoked = true;
                }
                // Modifications
                sch.lockDuration = migration.newLockDuration;
                if (migration.newStart != 0) {
                    sch.start = migration.newStart;
                }
                if (migration.newEnd != 0) {
                    sch.end = migration.newEnd;
                }
                if (migration.setCliff) {
                    sch.cliffDuration = 0;
                }
                if (migration.setDuration) {
                    sch.duration = 86400;
                }
                if (migration.setPeriodDuration) {
                    sch.periodDuration = 86400;
                }
                if (migration.ignoreGlobalUnlock) {
                    IgnoreGlobalUnlockSchedule.set(index, true);
                }

                // Post effects checks
                // check cliff is not longer than duration
                if (sch.cliffDuration > sch.duration) {
                    revert CliffTooLong(index);
                }
                // sanity checks on non revoked schedules
                if (!isRevoked && (sch.end != sch.start + sch.duration)) {
                    revert WrongEnd(index);
                }
                // check all the schedules are locked until unix : 1793454446
                if (sch.start + sch.lockDuration != OCTOBER_31_2026) {
                    revert WrongUnlockDate(index);
                }

                index += 1;
            }
        }
    }
}
