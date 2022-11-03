# Staking Contracts changelog

## v0.5.0-beta (November 3rd 2022)

### :dizzy: Features

- [[contracts] feat: add proxy firewall deployments and tests](https://github.com/liquid-collective/liquid-collective-protocol/pull/153)
- [[contracts] Deploy updated version of TLC](https://github.com/liquid-collective/liquid-collective-protocol/pull/163)
- [[contracts] ETH-277: chore(dev+staging): deploy all proxy firewalls](https://github.com/liquid-collective/liquid-collective-protocol/pull/154)
- [[contracts] Deploy proxy firewalls and TLC to mainnet](https://github.com/liquid-collective/liquid-collective-protocol/pull/160)

## v0.4.0 (October 5th 2022)

### :dizzy: Features

- [[contracts] Contracts have been deployed to mainnet](https://github.com/liquid-collective/liquid-collective-protocol/pull/152)
  
### :hammer_and_wrench: Bug Fixes

- [[contracts] [SPEARBIT/2] Re-initialize Oracle reports on remove](https://github.com/liquid-collective/liquid-collective-protocol/pull/118)
- [[contracts] [SPEARBIT/3] Update operator selection](https://github.com/liquid-collective/liquid-collective-protocol/pull/119)
- [[contracts] [SPEARBIT/4] Add a ethToDeposit storage var that accounts for incoming ETH](https://github.com/liquid-collective/liquid-collective-protocol/pull/120)
- [[contracts] [SPEARBIT/5] Remove dust on WLSETH burn](https://github.com/liquid-collective/liquid-collective-protocol/pull/121)
- [[contracts] [SPEARBIT/6] Use native bytes lib](https://github.com/liquid-collective/liquid-collective-protocol/pull/122)
- [[contracts] [SPEARBIT/8] Remove operators rewarding from River contract](https://github.com/liquid-collective/liquid-collective-protocol/pull/123)
- [[contracts] [SPEARBIT/9] Update ERC-20s](https://github.com/liquid-collective/liquid-collective-protocol/pull/124)
- [[contracts] [SPEARBIT/10] Add validation checks on constructors](https://github.com/liquid-collective/liquid-collective-protocol/pull/125)
- [[contracts] [SPEARBIT/11] Convert LibOwnable to Administrable contract](https://github.com/liquid-collective/liquid-collective-protocol/pull/126)
- [[contracts] [SPEARBIT/12] Add check on oracle member index when not found](https://github.com/liquid-collective/liquid-collective-protocol/pull/127)
- [[contracts] [SPEARBIT/13] Add a max on pullEL fees](https://github.com/liquid-collective/liquid-collective-protocol/pull/128)
- [[contracts] [SPEARBIT/14] Remove name to operator index resolution mechanism](https://github.com/liquid-collective/liquid-collective-protocol/pull/129)
- [[contracts] [SPEARBIT/15] Ensure invariant on Oracle quorum](https://github.com/liquid-collective/liquid-collective-protocol/pull/130)
- [[contracts] [SPEARBIT/18] Update token names](https://github.com/liquid-collective/liquid-collective-protocol/pull/131)
- [[contracts] [SPEARBIT/19] Update constants](https://github.com/liquid-collective/liquid-collective-protocol/pull/132)
- [[contracts] [SPEARBIT/20] Oracle gas optimisations](https://github.com/liquid-collective/liquid-collective-protocol/pull/133)
- [[contracts] [SPEARBIT/21] Remove TRANSFER_MASK](https://github.com/liquid-collective/liquid-collective-protocol/pull/134)
- [[contracts] [SPEARBIT/22] Maintain limit at key count if both were equal before key removal](https://github.com/liquid-collective/liquid-collective-protocol/pull/135)
- [[contracts] [SPEARBIT/23] Update requires to errors](https://github.com/liquid-collective/liquid-collective-protocol/pull/136)
- [[contracts] [SPEARBIT/24] Operator Registry gas optimisations](https://github.com/liquid-collective/liquid-collective-protocol/pull/137)
- [[contracts] [SPEARBIT/25] River gas optimisations](https://github.com/liquid-collective/liquid-collective-protocol/pull/138)
- [[contracts] [SPEARBIT/26] Update getters and setters](https://github.com/liquid-collective/liquid-collective-protocol/pull/139)
- [[contracts] [SPEARBIT/27] Prevent operator limit update on keys out of scope](https://github.com/liquid-collective/liquid-collective-protocol/pull/140)
- [[contracts] [SPEARBIT/28] Add RewardsEarned event](https://github.com/liquid-collective/liquid-collective-protocol/pull/142)
- [[contracts] [SPEARBIT/29] Move all fees to bps](https://github.com/liquid-collective/liquid-collective-protocol/pull/143)
- [[contracts] [SPEARBIT/30] Var Renamings](https://github.com/liquid-collective/liquid-collective-protocol/pull/144)
- [[contracts] [SPEARBIT/31] Add missing events](https://github.com/liquid-collective/liquid-collective-protocol/pull/145)
- [[contracts] [SPEARBIT/32] Remove unused code](https://github.com/liquid-collective/liquid-collective-protocol/pull/149)
- [[contracts] [SPEARBIT/33] Documentation and natspec](https://github.com/liquid-collective/liquid-collective-protocol/pull/147)
- [[contracts] Spearbit: Add SetRiver event on Oracle and add tests](https://github.com/liquid-collective/liquid-collective-protocol/pull/146)

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