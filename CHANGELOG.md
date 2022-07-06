# Staking Contracts changelog

## v0.2.0 (July 6th 2021)

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