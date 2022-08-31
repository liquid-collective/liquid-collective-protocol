# Staking Contracts changelog

## v0.3.0 (August 31st 2022)

### :dizzy: Features

- [[contracts] Operator Registry is now in its own contract](https://github.com/River-Protocol/river-contracts/pull/110)

### 🕹️ Others

- [[docs] Add architecture diagram in README](https://github.com/River-Protocol/river-contracts/pull/111)


## v0.2.2 (August 18th 2022)

### :dizzy: Features

- [contracts] New `goerli` deployment
- [contracts] New `mockedGoerli` deployment

### :hammer_and_wrench: Bug Fixes

- [[contracts] feat: revamp the execution layer fee recipient](https://github.com/River-Protocol/river-contracts/pull/104)
- [[contracts] HAL-01: DONATE CALL BEFORE DEPOSIT LEADS LOSS OF POSSIBLE REWARDS](https://github.com/River-Protocol/river-contracts/pull/93)
- [[contracts] HAL-03: DIVISION BY ZERO](https://github.com/River-Protocol/river-contracts/pull/103)
- [[contracts] HAL-04: MALICIOUS OWNER CAN ADD AN OPERATOR WITH EXISTING NAME](https://github.com/River-Protocol/river-contracts/pull/95)
- [[contracts] HAL-05: SINGLE-STEP OWNERSHIP CHANGE](https://github.com/River-Protocol/river-contracts/pull/96)
- [[contracts] HAL-07: MISSING REENTRANCY GUARD](https://github.com/River-Protocol/river-contracts/pull/97)
- [[contracts] HAL-08: IGNORED RETURN VALUES](https://github.com/River-Protocol/river-contracts/pull/98)
- [[contracts] HAL-09: LACK OF ZERO ADDRESS CHECKS](https://github.com/River-Protocol/river-contracts/pull/99)
- [[contracts] HAL-11: USE UNCHECKED KEYWORD FOR GAS OPTIMISATION](https://github.com/River-Protocol/river-contracts/pull/100)
- [[contracts] HAL-12: USE OF POST-FIX INCREMENT ON FOR LOOPS](https://github.com/River-Protocol/river-contracts/pull/100)
- [[contracts] [HAL-13] Remove assert() on depositAmount, since it is derived from constants](https://github.com/River-Protocol/river-contracts/pull/101)
- [[contracts] [HAL-14] Remove comparison to true or false](https://github.com/River-Protocol/river-contracts/pull/102)

### 🕹️ Others

- [ci] update formatter to use foundry formatting

## v0.2.1 (July 15th 2022)

### :hammer_and_wrench: Bug Fixes

- [[contracts] fix oracle river interface + add oracle to river tests](https://github.com/River-Protocol/river-contracts/pull/79)

## v0.2.0 (July 6th 2022)

### :dizzy: Features

- [[contracts] add treasury and admin setter](https://github.com/River-Protocol/river-contracts/pull/75)
- [[contracts] add zero address fallback on proxy](https://github.com/River-Protocol/river-contracts/pull/74)
- [[contracts] add `setOperatorLimits` method for batch limit updates](https://github.com/River-Protocol/river-contracts/pull/72)
- [[contracts] add fee recipient address to operators](https://github.com/River-Protocol/river-contracts/pull/71)
- [[contracts] allow deposit and transfer in a single contract call](https://github.com/River-Protocol/river-contracts/pull/69)
- [[contracts] add new deposit events](https://github.com/River-Protocol/river-contracts/pull/62)
- [[contracts] add WLSETH](https://github.com/River-Protocol/river-contracts/pull/57)
- [[contracts] split allowlist from river](https://github.com/River-Protocol/river-contracts/pull/41)
- [[contracts] add firewall contract](https://github.com/River-Protocol/river-contracts/pull/36)
- [[contracts] add execution layer fee recipient](https://github.com/River-Protocol/river-contracts/pull/35)

### :hammer_and_wrench: Bug Fixes

- [[contracts] operator limit should always be lower than key count](https://github.com/River-Protocol/river-contracts/pull/70)
- [[contracts] remove referral address from deposit](https://github.com/River-Protocol/river-contracts/pull/68)
- [[contracts] fix `totalSupply` and `totalUnderlyingSupply`](https://github.com/River-Protocol/river-contracts/pull/64)
- [[contracts] remove allowlist controls on transfer](https://github.com/River-Protocol/river-contracts/pull/61)

### 🕹️ Others

- [[ci] remove scheduled jobs](https://github.com/River-Protocol/river-contracts/pull/76)
- [[ci] store mythril reports in github artifacts](https://github.com/River-Protocol/river-contracts/pull/67)
- [[ci] store test and gas reports in github artifacts](https://github.com/River-Protocol/river-contracts/pull/66)


## v0.1.0 (May 26th 2022)

Initial implementation