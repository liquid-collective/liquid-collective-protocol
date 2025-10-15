# TypeScript Verification Guide

Complete guide for running the TypeScript version of the TLC migration verification script.

## 📋 Overview

The TypeScript version (`fetch_and_verify.ts`) provides type safety and better IDE support while performing the same verification as the JavaScript version.

## 🚀 Quick Start

### Prerequisites

The project already has TypeScript installed! Just make sure you have Node.js available:

```bash
# Check if node is available
node --version

# If not, source nvm (if using nvm)
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
```

### Run the Script

```bash
# Run with npx ts-node (recommended)
npx ts-node fetch_and_verify.ts

# Or if npx doesn't work, use the full nvm setup:
export NVM_DIR="$HOME/.nvm" && [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh" && npx ts-node fetch_and_verify.ts
```

That's it! The script will:
1. ✅ Fetch all 103 vesting schedules from mainnet
2. ✅ Calculate lock durations (`1793454446 - start`)
3. ✅ Verify against expected values
4. ✅ Display results and save to JSON files

## 📦 Installation (If Needed)

If you need to install dependencies from scratch:

```bash
# Install all project dependencies
npm install

# Or just install the required packages
npm install ethers@5 typescript@4.5.4 ts-node@10.4.0
```

## 🎯 What the Script Does

### Fetches Real Data
Connects to Ethereum mainnet and fetches all 103 vesting schedules from:
```
Contract: 0xb5Fe6946836D687848B5aBd42dAbF531d5819632
Function: getVestingSchedule(uint256 index)
```

### Calculates Lock Durations
For each schedule (0-102):
```typescript
const calculatedLockDuration = OCTOBER_31_2026 - schedule.start
// Where OCTOBER_31_2026 = 1793454446
```

### Verifies Against Expected Values
Compares calculated values with the expected lock durations from the migration file.

## 📊 Example Output

```
========================================================================================================================
FETCH AND VERIFY TLC VESTING SCHEDULE LOCK DURATIONS
========================================================================================================================
Contract: 0xb5Fe6946836D687848B5aBd42dAbF531d5819632
RPC URL: https://eth.llamarpc.com
Target Date: October 31, 2026 (1793454446)
Total schedules: 103

Fetching data from mainnet...

  Fetched and verified 20/103...
  Fetched and verified 40/103...
  Fetched and verified 60/103...
  Fetched and verified 80/103...
  Fetched and verified 100/103...
✅ Fetched all 103 schedules!

========================================================================================================================
VERIFICATION RESULTS
========================================================================================================================

Index | Start        | Current Lock | Calculated Lock (1793454446 - start) | Expected Lock | Status
------------------------------------------------------------------------------------------------------------------------
    0 |   1653264000 |      2629800 |                             140190446 |     140190446 | ✅ PASS
    1 |   1653264000 |      2629800 |                             140190446 |     140190446 | ✅ PASS
    ...
   21 |   1679562000 |      2629800 |                             113892446 |     113892446 | ✅ PASS
    ...
  102 |   1724889600 |     31622400 |                              68564846 |      68564846 | ✅ PASS
------------------------------------------------------------------------------------------------------------------------

========================================================================================================================
SUMMARY
========================================================================================================================
Total schedules: 103
Passed: 103
Failed: 0

✅ ALL VERIFICATIONS PASSED!
All lock durations match the expected values.
========================================================================================================================

💾 Detailed results saved to: verification_results.json
💾 Schedule starts saved to: schedule_starts.json
```

## 📁 Output Files

The script creates two JSON files:

### 1. `schedule_starts.json`
Array of all schedule start timestamps:
```json
{
  "contractAddress": "0xb5Fe6946836D687848B5aBd42dAbF531d5819632",
  "fetchedAt": "2025-10-15T08:47:27.494Z",
  "totalSchedules": 103,
  "scheduleStarts": [
    1653264000,
    1653264000,
    1653264000,
    ...
  ]
}
```

### 2. `verification_results.json`
Complete verification details with pass/fail for each schedule:
```json
{
  "contractAddress": "0xb5Fe6946836D687848B5aBd42dAbF531d5819632",
  "fetchedAt": "2025-10-15T08:47:27.494Z",
  "targetDate": 1793454446,
  "totalSchedules": 103,
  "passed": 103,
  "failed": 0,
  "scheduleStarts": [...],
  "detailedResults": [
    {
      "index": 0,
      "start": 1653264000,
      "currentLockDuration": 2629800,
      "calculatedLockDuration": 140190446,
      "expectedLockDuration": 140190446,
      "matches": true,
      "end": 1655893800
    },
    ...
  ]
}
```

## 🔧 Configuration

### Use Different RPC Endpoint

If the default RPC is slow or rate-limited:

```bash
# Use your own RPC
RPC_URL=https://eth.drpc.org npx ts-node fetch_and_verify.ts

# Or use Infura
RPC_URL=https://mainnet.infura.io/v3/YOUR_API_KEY npx ts-node fetch_and_verify.ts

# Or use Alchemy
RPC_URL=https://eth-mainnet.g.alchemy.com/v2/YOUR_API_KEY npx ts-node fetch_and_verify.ts
```

### Add to package.json Scripts

For convenience, you can add this to your `package.json`:

```json
{
  "scripts": {
    "verify:tlc": "ts-node fetch_and_verify.ts",
    "verify:tlc:custom-rpc": "RPC_URL=$RPC_URL ts-node fetch_and_verify.ts"
  }
}
```

Then run:
```bash
npm run verify:tlc
```

## 🐛 Troubleshooting

### "Cannot find module 'ts-node'"

```bash
npm install ts-node@10.4.0
```

### "Cannot find module 'ethers'"

```bash
npm install ethers@5
```

### "env: node: No such file or directory"

You need to set up your Node.js environment:

```bash
# If using nvm
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"

# Then run the script
npx ts-node fetch_and_verify.ts
```

### Connection Timeout or Rate Limited

Use a different RPC endpoint:

```bash
# Free options:
RPC_URL=https://eth.drpc.org npx ts-node fetch_and_verify.ts
RPC_URL=https://rpc.ankr.com/eth npx ts-node fetch_and_verify.ts
RPC_URL=https://eth.llamarpc.com npx ts-node fetch_and_verify.ts
```

### TypeScript Compilation Errors

If you see type errors, the script should still run. To fix them permanently:

```bash
# Update TypeScript
npm install typescript@latest

# Or ignore type checking (not recommended)
npx ts-node --transpile-only fetch_and_verify.ts
```

## 🎓 Understanding the Code

### Type Safety

The TypeScript version includes proper types:

```typescript
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
```

### Expected Lock Durations

Hard-coded from the migration file:

```typescript
const EXPECTED_LOCK_DURATIONS: Record<number, number> = {
    0: 140190446,  // migrations[0]
    7: 134747246,  // migrations[1]
    21: 113892446, // migrations[12]
    // ... etc
};
```

### Verification Logic

```typescript
const calculatedLockDuration = OCTOBER_31_2026 - start;
const expectedLockDuration = EXPECTED_LOCK_DURATIONS[i];
const matches = calculatedLockDuration === expectedLockDuration;
```

## 📖 Comparison: TypeScript vs JavaScript

| Feature | TypeScript (`fetch_and_verify.ts`) | JavaScript (`fetch_and_verify.js`) |
|---------|-----------------------------------|-----------------------------------|
| Type Safety | ✅ Yes | ❌ No |
| IDE Support | ✅ Better autocomplete | ⚠️ Basic |
| Runtime | Requires ts-node | Native node |
| Speed | Slightly slower (compile time) | Slightly faster |
| Debugging | Better type hints | Standard |
| Recommended For | Development & verification | Production scripts |

## ✅ Best Practices

### 1. Run Before PR Review
```bash
npx ts-node fetch_and_verify.ts
```

### 2. Save Results
The JSON files are automatically saved for future reference.

### 3. Check Exit Code
```bash
npx ts-node fetch_and_verify.ts
echo $?  # 0 = success, 1 = failures found
```

### 4. Use in CI/CD
```yaml
# .github/workflows/verify-tlc.yml
- name: Verify TLC Migration
  run: npx ts-node fetch_and_verify.ts
```

## 🚀 Advanced Usage

### Run with Node Flags

```bash
# Increase memory if needed
NODE_OPTIONS="--max-old-space-size=4096" npx ts-node fetch_and_verify.ts

# Enable debugging
NODE_OPTIONS="--inspect" npx ts-node fetch_and_verify.ts
```

### Import and Use Programmatically

```typescript
import { fetchAndVerify } from './fetch_and_verify';

async function main() {
    try {
        await fetchAndVerify();
        console.log('Verification complete!');
    } catch (error) {
        console.error('Verification failed:', error);
        process.exit(1);
    }
}

main();
```

## 📞 Need Help?

### Quick Commands Reference

| Task | Command |
|------|---------|
| Run verification | `npx ts-node fetch_and_verify.ts` |
| Use custom RPC | `RPC_URL=https://... npx ts-node fetch_and_verify.ts` |
| Install deps | `npm install ethers@5 ts-node@10.4.0` |
| Check Node | `node --version` |
| Setup nvm | `export NVM_DIR="$HOME/.nvm" && [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"` |

### Related Files

- `fetch_and_verify.ts` - TypeScript verification script (this guide)
- `fetch_and_verify.js` - JavaScript version (alternative)
- `QUICK_START_VERIFICATION.md` - General verification guide
- `contracts/src/migration/TLC_globalUnlockScheduleMigration.sol` - Migration file being verified

## 🎯 Summary

The TypeScript version provides:
- ✅ **Type safety** for catching errors early
- ✅ **Better IDE support** with autocomplete
- ✅ **Same functionality** as JavaScript version
- ✅ **Complete verification** of all 103 schedules
- ✅ **Detailed results** saved to JSON files

**To run now:**
```bash
npx ts-node fetch_and_verify.ts
```

That's it! The script will fetch, calculate, verify, and report all results automatically. 🎉

