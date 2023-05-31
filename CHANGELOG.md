# Staking Contracts changelog

## v1.0.0 (May 30th 2023)

- [[contracts] add requested exit catchup upon stopped validator count update at oracle report time](https://github.com/liquid-collective/liquid-collective-protocol/pull/211)
- [[contracts] deploy 1.0.0 implementation and contracts to mainnet](https://github.com/liquid-collective/liquid-collective-protocol/pull/215)

## v0.6.0-rc2-devGoerli & v0.6.0-rc2-goerli (April 27th 2023)

- [[contracts] add recipient argument to RiverV1.requestRedeem](https://github.com/liquid-collective/liquid-collective-protocol/pull/202)
- [[contracts] add maxRedeemableEth value to emitted event](https://github.com/liquid-collective/liquid-collective-protocol/pull/206)
- [[contracts] deploy 0.6.0-rc2 contracts for devGoerli](https://github.com/liquid-collective/liquid-collective-protocol/pull/208)
- [[contracts] deploy 0.6.0-rc2 contracts for goerli](https://github.com/liquid-collective/liquid-collective-protocol/pull/208)


## v0.6.0-rc1-devGoerli (April 26th 2023)

### :hammer_and_wrench: Bug Fixes

- [[contracts] fix oracle vote storage issue](https://github.com/liquid-collective/liquid-collective-protocol/pull/193)
- [[contracts] [SPEARBIT/03/23] Oracle fixes](https://github.com/liquid-collective/liquid-collective-protocol/pull/193)
- [[contracts] [SPEARBIT/03/23] Recipient Fixes](https://github.com/liquid-collective/liquid-collective-protocol/pull/194)
- [[contracts] fix invalid index usage on validator exit request flow](https://github.com/liquid-collective/liquid-collective-protocol/pull/195)
- [[contracts] [SPEARBIT/03/23] OperatorsRegistry Fixes](https://github.com/liquid-collective/liquid-collective-protocol/pull/195)
- [[contracts] [SPEARBIT/03/23] River Fixes](https://github.com/liquid-collective/liquid-collective-protocol/pull/196)
- [[contracts] fix redeem manager issue coming from LsETH directly sent to contract](https://github.com/liquid-collective/liquid-collective-protocol/pull/197)
- [[contracts] [SPEARBIT/03/23] RedeemManager Fixes](https://github.com/liquid-collective/liquid-collective-protocol/pull/197)
- [[contracts] [SPEARBIT/03/23] Docs, Styling & Naming](https://github.com/liquid-collective/liquid-collective-protocol/pull/198)
- [[contracts] perform devGoerli deployment](https://github.com/liquid-collective/liquid-collective-protocol/pull/190/commits/8ed58a23972220def3d4d94e70c9be11aee05619)

## v0.5.0 (December 3rd 2022)

### :hammer_and_wrench: Bug Fixes

- [[contracts] [Spearbit] TLC informational and gas optimizations issues](https://github.com/liquid-collective/liquid-collective-protocol/pull/172)
- [[contracts] [Spearbit] ERC20VestableVotesUpgradeable: protect against DOS on escrow (ETH-342)](https://github.com/liquid-collective/liquid-collective-protocol/pull/171)
- [[contracts] [Spearbit] Add deployment script for CoverageFund](https://github.com/liquid-collective/liquid-collective-protocol/pull/170)
- [[contracts] [Spearbit] Sanitize SetCoverageFund](https://github.com/liquid-collective/liquid-collective-protocol/pull/169)
- [[contracts] [Spearbit] CoverageFund informational issues](https://github.com/liquid-collective/liquid-collective-protocol/pull/168)
- [[contracts] [Spearbit] Sanitize inputs for SetMetadataURI](https://github.com/liquid-collective/liquid-collective-protocol/pull/167)
- [[contracts] [Spearbit] Move DENY_MASK to LibAllowlistMask](https://github.com/liquid-collective/liquid-collective-protocol/pull/166)
- [[contracts] Remove dynamic indexed type from Allowlist event](https://github.com/liquid-collective/liquid-collective-protocol/blob/c0517983140f593f8db033c7ab75e6a91556182b/contracts/src/interfaces/IAllowlist.1.sol#L11)

## v0.5.0-beta (November 3rd 2022)

### :dizzy: Features

- [contracts] Add and deploy TLC Governance Token (Beta) (https://github.com/liquid-collective/liquid-collective-protocol/pull/141) (https://github.com/liquid-collective/liquid-collective-protocol/pull/158) (https://github.com/liquid-collective/liquid-collective-protocol/pull/159) (https://github.com/liquid-collective/liquid-collective-protocol/pull/160)(https://github.com/liquid-collective/liquid-collective-protocol/pull/162) (https://github.com/liquid-collective/liquid-collective-protocol/pull/163)
- [contracts] Deploy Firewalls on contract TUP Proxies to give `pause()` permission to Executor (https://github.com/liquid-collective/liquid-collective-protocol/pull/153) (https://github.com/liquid-collective/liquid-collective-protocol/pull/154) (https://github.com/liquid-collective/liquid-collective-protocol/pull/160)

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
