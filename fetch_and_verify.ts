#!/usr/bin/env ts-node
/**
 * Fetch and Verify TLC Vesting Schedule Lock Durations
 * 
 * This script:
 * 1. Fetches all 103 schedule start timestamps from mainnet
 * 2. Calculates the lock duration for each: 1793454446 - start
 * 3. Displays results in a table with comparison to expected values
 * 
 * Prerequisites:
 *   npm install ethers@5
 * 
 * Usage:
 *   npx ts-node fetch_and_verify.ts
 *   or
 *   npm run verify
 */

import { ethers } from 'ethers';
import * as fs from 'fs';

// Contract details
const CONTRACT_ADDRESS = "0xb5Fe6946836D687848B5aBd42dAbF531d5819632";
const OCTOBER_31_2026 = 1793454446;
const TOTAL_SCHEDULES = 103;

// Simple ABI for getVestingSchedule function
const ABI = [
    "function getVestingSchedule(uint256 index) view returns (uint64 start, uint64 end, uint32 cliffDuration, uint32 duration, uint32 periodDuration, uint32 lockDuration, bool revokable, uint128 amount)"
];

// Types
interface ScheduleResult {
    index: number;
    start?: number;
    currentLockDuration?: number;
    calculatedLockDuration?: number;
    expectedLockDuration?: number;
    matches?: boolean;
    end?: number;
    error?: string;
}

interface OutputData {
    contractAddress: string;
    fetchedAt: string;
    targetDate: number;
    totalSchedules: number;
    passed: number;
    failed: number;
    scheduleStarts: (number | undefined)[];
    detailedResults: ScheduleResult[];
}

interface ScheduleStartsOutput {
    contractAddress: string;
    fetchedAt: string;
    totalSchedules: number;
    scheduleStarts: (number | undefined)[];
}

// Expected lock durations from the migration file
const EXPECTED_LOCK_DURATIONS: Record<number, number> = {
    // migrations[0]: schedules 0-6
    0: 140190446, 1: 140190446, 2: 140190446, 3: 140190446, 4: 140190446, 5: 140190446, 6: 140190446,
    // migrations[1]: schedule 7
    7: 134747246,
    // migrations[2]: schedule 8
    8: 129908846,
    // migrations[3]: schedules 9-12
    9: 136820846, 10: 136820846, 11: 136820846, 12: 136820846,
    // migrations[4]: schedule 13
    13: 131464046,
    // migrations[5]: schedule 14
    14: 120923246,
    // migrations[6]: schedule 15
    15: 122651246,
    // migrations[7]: schedule 16
    16: 122392046,
    // migrations[8]: schedule 17
    17: 118158446,
    // migrations[9]: schedule 18
    18: 140190446,
    // migrations[10]: schedule 19
    19: 113892446,
    // migrations[11]: schedule 20
    20: 140190446,
    // migrations[12]: schedule 21
    21: 113892446,
    // migrations[13]: schedule 22
    22: 140190446,
    // migrations[14]: schedule 23
    23: 113892446,
    // migrations[15]: schedules 24-26
    24: 140190446, 25: 140190446, 26: 140190446,
    // migrations[16]: schedule 27
    27: 134747246,
    // migrations[17]: schedules 28-29
    28: 114788846, 29: 114788846,
    // migrations[18]: schedule 30
    30: 115134446,
    // migrations[19]: schedule 31
    31: 115220846,
    // migrations[20]: schedule 32
    32: 115307246,
    // migrations[21]: schedule 33
    33: 115134446,
    // migrations[22]: schedules 34-35
    34: 115307246, 35: 115307246,
    // migrations[23]: schedules 36-60 (25 schedules)
    36: 107279246, 37: 107279246, 38: 107279246, 39: 107279246, 40: 107279246,
    41: 107279246, 42: 107279246, 43: 107279246, 44: 107279246, 45: 107279246,
    46: 107279246, 47: 107279246, 48: 107279246, 49: 107279246, 50: 107279246,
    51: 107279246, 52: 107279246, 53: 107279246, 54: 107279246, 55: 107279246,
    56: 107279246, 57: 107279246, 58: 107279246, 59: 107279246, 60: 107279246,
    // migrations[24]: schedule 61
    61: 105371246,
    // migrations[25]: schedule 62
    62: 113147246,
    // migrations[26]: schedule 63
    63: 106062446,
    // migrations[27]: schedule 64
    64: 111419246,
    // migrations[28]: schedule 65
    65: 109432046,
    // migrations[29]: schedule 66
    66: 102606446,
    // migrations[30]: schedules 67-69
    67: 107279246, 68: 107279246, 69: 107279246,
    // migrations[31]: schedule 70
    70: 95348846,
    // migrations[32]: schedule 71
    71: 96558446,
    // migrations[33]: schedule 72
    72: 96299246,
    // migrations[34]: schedule 73
    73: 101396846,
    // migrations[35]: schedule 74
    74: 101483246,
    // migrations[36]: schedule 75
    75: 100273646,
    // migrations[37]: schedule 76
    76: 99064046,
    // migrations[38]: schedule 77
    77: 96644846,
    // migrations[39]: schedules 78-79
    78: 96040046, 79: 96040046,
    // migrations[40]: schedule 80
    80: 90942446,
    // migrations[41]: schedules 81-82
    81: 90510446, 82: 90510446,
    // migrations[42]: schedule 83
    83: 89387246,
    // migrations[43]: schedule 84
    84: 88696046,
    // migrations[44]: schedule 85
    85: 85672046,
    // migrations[45]: schedule 86
    86: 88782446,
    // migrations[46]: schedule 87
    87: 87227246,
    // migrations[47]: schedule 88
    88: 84548846,
    // migrations[48]: schedule 89
    89: 87227246,
    // migrations[49]: schedules 90-91
    90: 114702446, 91: 114702446,
    // migrations[50]: schedule 92
    92: 85758446,
    // migrations[51]: schedule 93
    93: 87227246,
    // migrations[52]: schedule 94
    94: 105716846,
    // migrations[53]: schedule 95
    95: 81524846,
    // migrations[54]: schedule 96
    96: 80920046,
    // migrations[55]: schedules 97-98
    97: 79537646, 98: 79537646,
    // migrations[56]: schedule 99
    99: 74872046,
    // migrations[57]: schedule 100
    100: 73662446,
    // migrations[58]: schedule 101
    101: 78500846,
    // migrations[59]: schedule 102
    102: 68564846
};

async function fetchAndVerify(): Promise<void> {
    try {
        // Use provided RPC or default to public endpoint  
        const rpcUrl = process.env.RPC_URL || 'https://eth.llamarpc.com';
        
        console.log('='.repeat(120));
        console.log('FETCH AND VERIFY TLC VESTING SCHEDULE LOCK DURATIONS');
        console.log('='.repeat(120));
        console.log(`Contract: ${CONTRACT_ADDRESS}`);
        console.log(`RPC URL: ${rpcUrl}`);
        console.log(`Target Date: October 31, 2026 (${OCTOBER_31_2026})`);
        console.log(`Total schedules: ${TOTAL_SCHEDULES}`);
        console.log('');
        console.log('Fetching data from mainnet...');
        console.log('');
        
        // Connect to mainnet
        const provider = new ethers.providers.JsonRpcProvider(rpcUrl);
        const contract = new ethers.Contract(CONTRACT_ADDRESS, ABI, provider);
        
        // Fetch all schedules
        const results: ScheduleResult[] = [];
        let errorCount = 0;
        
        for (let i = 0; i < TOTAL_SCHEDULES; i++) {
            try {
                const schedule = await contract.getVestingSchedule(i);
                const start = schedule.start.toNumber();
                const currentLockDuration = schedule.lockDuration;
                const calculatedLockDuration = OCTOBER_31_2026 - start;
                const expectedLockDuration = EXPECTED_LOCK_DURATIONS[i];
                const matches = calculatedLockDuration === expectedLockDuration;
                
                if (!matches) {
                    errorCount++;
                }
                
                results.push({
                    index: i,
                    start: start,
                    currentLockDuration: currentLockDuration,
                    calculatedLockDuration: calculatedLockDuration,
                    expectedLockDuration: expectedLockDuration,
                    matches: matches,
                    end: schedule.end.toNumber()
                });
                
                if ((i + 1) % 20 === 0) {
                    console.log(`  Fetched and verified ${i + 1}/${TOTAL_SCHEDULES}...`);
                }
            } catch (error: any) {
                console.error(`❌ Error fetching schedule ${i}:`, error.message);
                results.push({
                    index: i,
                    error: error.message
                });
            }
        }
        
        console.log(`✅ Fetched all ${TOTAL_SCHEDULES} schedules!`);
        console.log('');
        
        // Display results in table format
        console.log('='.repeat(120));
        console.log('VERIFICATION RESULTS');
        console.log('='.repeat(120));
        console.log('');
        console.log('Index | Start        | Current Lock | Calculated Lock (1793454446 - start) | Expected Lock | Status');
        console.log('-'.repeat(120));
        
        for (const result of results) {
            if (result.error) {
                console.log(`${String(result.index).padStart(5)} | ERROR: ${result.error}`);
            } else {
                const status = result.matches ? '✅ PASS' : '❌ FAIL';
                const idx = String(result.index).padStart(5);
                const start = String(result.start).padStart(12);
                const current = String(result.currentLockDuration).padStart(12);
                const calculated = String(result.calculatedLockDuration).padStart(37);
                const expected = String(result.expectedLockDuration).padStart(13);
                
                console.log(`${idx} | ${start} | ${current} | ${calculated} | ${expected} | ${status}`);
            }
        }
        
        console.log('-'.repeat(120));
        console.log('');
        
        // Summary
        const passedCount = results.filter(r => r.matches).length;
        const failedCount = errorCount;
        
        console.log('='.repeat(120));
        console.log('SUMMARY');
        console.log('='.repeat(120));
        console.log(`Total schedules: ${TOTAL_SCHEDULES}`);
        console.log(`Passed: ${passedCount}`);
        console.log(`Failed: ${failedCount}`);
        console.log('');
        
        if (failedCount > 0) {
            console.log('❌ VERIFICATION FAILED - Discrepancies found:');
            console.log('');
            results.filter(r => !r.matches && !r.error).forEach(r => {
                console.log(`Schedule ${r.index}:`);
                console.log(`  Start: ${r.start}`);
                console.log(`  Formula: ${OCTOBER_31_2026} - ${r.start} = ${r.calculatedLockDuration}`);
                console.log(`  Expected: ${r.expectedLockDuration}`);
                console.log(`  Difference: ${r.calculatedLockDuration! - r.expectedLockDuration!}`);
                console.log('');
            });
        } else {
            console.log('✅ ALL VERIFICATIONS PASSED!');
            console.log('All lock durations match the expected values.');
        }
        
        console.log('='.repeat(120));
        console.log('');
        
        // Save detailed results to file
        const output: OutputData = {
            contractAddress: CONTRACT_ADDRESS,
            fetchedAt: new Date().toISOString(),
            targetDate: OCTOBER_31_2026,
            totalSchedules: TOTAL_SCHEDULES,
            passed: passedCount,
            failed: failedCount,
            scheduleStarts: results.map(r => r.start),
            detailedResults: results
        };
        
        const filename = 'verification_results.json';
        fs.writeFileSync(filename, JSON.stringify(output, null, 2));
        console.log(`💾 Detailed results saved to: ${filename}`);
        console.log('');
        
        // Also save just the starts array for use with other scripts
        const startsFile: ScheduleStartsOutput = {
            contractAddress: CONTRACT_ADDRESS,
            fetchedAt: new Date().toISOString(),
            totalSchedules: TOTAL_SCHEDULES,
            scheduleStarts: results.map(r => r.start)
        };
        fs.writeFileSync('schedule_starts.json', JSON.stringify(startsFile, null, 2));
        console.log(`💾 Schedule starts saved to: schedule_starts.json`);
        
        process.exit(failedCount > 0 ? 1 : 0);
        
    } catch (error: any) {
        console.error('Error:', error);
        process.exit(1);
    }
}

// Run if called directly
if (require.main === module) {
    fetchAndVerify().catch(error => {
        console.error('Fatal error:', error);
        process.exit(1);
    });
}

export { fetchAndVerify };

