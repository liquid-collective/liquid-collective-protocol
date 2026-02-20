# Liquid Collective Protocol

[![tests](https://github.com/liquid-collective/liquid-collective-protocol/actions/workflows/Tests.yaml/badge.svg)](https://github.com/liquid-collective/liquid-collective-protocol/actions/workflows/Tests.yaml)
[![mythril](https://github.com/liquid-collective/liquid-collective-protocol/actions/workflows/Mythril.yaml/badge.svg)](https://github.com/liquid-collective/liquid-collective-protocol/actions/workflows/Mythril.yaml)
[![lint](https://github.com/liquid-collective/liquid-collective-protocol/actions/workflows/Lint.yaml/badge.svg)](https://github.com/liquid-collective/liquid-collective-protocol/actions/workflows/Lint.yaml)
[![license](https://img.shields.io/badge/license-busl--1.1-blue.svg)](./LICENSE)

This repository contains the Liquid Collective Protocol's smart contracts.

Liquid Collective is a liquid staking protocol designed to meet the needs of institutions, built and run by a collective of leading web3 teams.

Liquid Collective enables users to stake ETH and mint LsETH. The LsETH liquid staking token evidences legal and beneficial ownership of the staked ETH and any network rewards that the staked ETH accrues, minus any fees and penalties.

## Useful Links

- [Liquid Collective Protocol Documentation](https://docs.liquidcollective.io/)
- [Liquid Collective Website](https://liquidcollective.io)
- ![twitter](https://img.shields.io/twitter/follow/liquid_col?style=social)
- [Litepaper](https://liquidcollective.io/litepaper/)
- [Report Security Vulnerability](https://github.com/liquid-collective/security)

## Deployment Addresses
### Ethereum Deployments
| Contract                                                                                                                             |                                                         Mainnet                                                         |                                                              Hoodi                                                              |
|--------------------------------------------------------------------------------------------------------------------------------------|-------------------------------------------------------------------------------------------------------------------------|:-------------------------------------------------------------------------------------------------------------------------------:|
| [TLC](https://github.com/liquid-collective/liquid-collective-protocol/blob/main/contracts/src/TLC.1.sol)                             | [`0xb5Fe6946836D687848B5aBd42dAbF531d5819632`](https://etherscan.io/address/0xb5Fe6946836D687848B5aBd42dAbF531d5819632) |                                                               n/a                                                               |
| [River (LsETH)](https://github.com/liquid-collective/liquid-collective-protocol/blob/main/contracts/src/River.1.sol)                 | [`0x8c1BEd5b9a0928467c9B1341Da1D7BD5e10b6549`](https://etherscan.io/address/0x8c1BEd5b9a0928467c9B1341Da1D7BD5e10b6549) |  [`0x0CA0c58b1986a55876552E0D9532C963625D5646`](https://hoodi.etherscan.io/address/0x0CA0c58b1986a55876552E0D9532C963625D5646)  |
| [OperatorsRegistry](https://github.com/liquid-collective/liquid-collective-protocol/blob/main/contracts/src/OperatorsRegistry.1.sol) | [`0x1235f1b60df026B2620e48E735C422425E06b725`](https://etherscan.io/address/0x1235f1b60df026B2620e48E735C422425E06b725) | [`0x08CC4d7cE071BB80EB30184da96692C312Cfa904`](https://hoodi.etherscan.io/address/0x08CC4d7cE071BB80EB30184da96692C312Cfa904) |
| [Oracle](https://github.com/liquid-collective/liquid-collective-protocol/blob/main/contracts/src/Oracle.1.sol)                       | [`0x895a57eD71025D51fe4080530A3489D92E230683`](https://etherscan.io/address/0x895a57eD71025D51fe4080530A3489D92E230683) | [`0xDb9C7257647169c8F48ddEbB3b30b94e5DF37f78`](https://hoodi.etherscan.io/address/0xDb9C7257647169c8F48ddEbB3b30b94e5DF37f78) |
| [Allowlist](https://github.com/liquid-collective/liquid-collective-protocol/blob/main/contracts/src/Allowlist.1.sol)                 | [`0xebc83Bb472b2816Ec5B5de8D34F0eFc9088BB2ce`](https://etherscan.io/address/0xebc83Bb472b2816Ec5B5de8D34F0eFc9088BB2ce) | [`0x21504e21Dd31ec7f778DFeFc56A5DBaaa63E5BB4`](https://hoodi.etherscan.io/address/0x21504e21Dd31ec7f778DFeFc56A5DBaaa63E5BB4) |
| [CoverageFund](https://github.com/liquid-collective/liquid-collective-protocol/blob/main/contracts/src/CoverageFund.1.sol)           | [`0x32aac358b627b9feaa971cc33304027a41e49a81`](https://etherscan.io/address/0x32aac358b627b9feaa971cc33304027a41e49a81) | [`0x2343A2cF4F4b2109400dBC0143437151b119bFdd`](https://hoodi.etherscan.io/address/0x2343A2cF4F4b2109400dBC0143437151b119bFdd) |
| [Withdraw](https://github.com/liquid-collective/liquid-collective-protocol/blob/main/contracts/src/Withdraw.1.sol)                   | [`0x0AFd81862eEA47322Cf85Db39D3D07e8A3c25154`](https://etherscan.io/address/0x0AFd81862eEA47322Cf85Db39D3D07e8A3c25154) | [`0x9E6Dd63444Af1568261Bea7bB22aB975fA5a5B41`](https://hoodi.etherscan.io/address/0x9E6Dd63444Af1568261Bea7bB22aB975fA5a5B41) |
| [ELFeeRecipient](https://github.com/liquid-collective/liquid-collective-protocol/blob/main/contracts/src/ELFeeRecipient.1.sol)       | [`0x7D16d2c4e96BCFC8f815E15b771aC847EcbDB48b`](https://etherscan.io/address/0x7D16d2c4e96BCFC8f815E15b771aC847EcbDB48b) | [`0xf88d4AD5d6f45ce86952DDc5aACCE5A97501e104`](https://hoodi.etherscan.io/address/0xf88d4AD5d6f45ce86952DDc5aACCE5A97501e104) |
| [RedeemManager](https://github.com/liquid-collective/liquid-collective-protocol/blob/main/contracts/src/RedeemManager.1.sol)         | [`0x080b3a41390b357Ad7e8097644d1DEDf57AD3375`](https://etherscan.io/address/0x080b3a41390b357Ad7e8097644d1DEDf57AD3375) | [`0x5d51E82b75A4F16ef677d5bE20d707b6441A00b7`](https://hoodi.etherscan.io/address/0x5d51E82b75A4F16ef677d5bE20d707b6441A00b7) |
| [WLSETH](https://github.com/liquid-collective/liquid-collective-protocol/blob/main/contracts/src/WLSETH.1.sol)                       |                                                           n/a                                                           |                                                               n/a                                                               |
| [Protocol Metrics](https://github.com/liquid-collective/liquid-collective-protocol/blob/main/contracts/src/ProtocolMetrics.1.sol)    | [`0xf19345EabC46ADF82e85CC2293A657A2dBa5c7d4`](https://etherscan.io/address/0xf19345EabC46ADF82e85CC2293A657A2dBa5c7d4) |                                                               n/a                                                               |

### L2 Deployments
| Contract                                                                                                                             |                                     Chain                                   |                                                     Address                                                                     |
|--------------------------------------------------------------------------------------------------------------------------------------|-----------------------------------------------------------------------------|:-------------------------------------------------------------------------------------------------------------------------------:|
| [LsETH](https://github.com/liquid-collective/liquid-collective-protocol/blob/main/contracts/src/l2-token/BurnMintERC20.sol)          |                                      Base                                   | [`0xB29749498954A3A821ec37BdE86e386dF3cE30B6`](https://basescan.org/address/0xB29749498954A3A821ec37BdE86e386dF3cE30B6)         |
| [LsETH](https://github.com/zircuit-labs/L2UpgradeableERC20/blob/main/contracts/L2UpgradeableERC20.sol)                               |                                      Zircuit                                | [`0xF97c7A9bECe498FD6e31e344643589aACC96206A`](https://explorer.zircuit.com/address/0xF97c7A9bECe498FD6e31e344643589aACC96206A) |
| [LsETH](https://github.com/liquid-collective/liquid-collective-protocol/blob/main/contracts/src/l2-token/BurnMintERC20.sol)          |                                      Linea                                  | [`0xB29749498954A3A821ec37BdE86e386dF3cE30B6`](https://lineascan.build/address/0xB29749498954A3A821ec37BdE86e386dF3cE30B6)      |

### Ethereum Adapters
| Contract                                                                                                                             |                                                         Mainnet                                                         |
|--------------------------------------------------------------------------------------------------------------------------------------|-------------------------------------------------------------------------------------------------------------------------|
| [PendleLsETHSY](https://github.com/liquid-collective/pendle-sy-tests/blob/main/src/PendleLsETHSY.sol)                                | [`0xEC3f66d7FaC189Ed83593C730ef46b67A9d2d455`](https://etherscan.io/address/0xEC3f66d7FaC189Ed83593C730ef46b67A9d2d455) |

## Security

If you're interested in learning more about Liquid Collective security processes, including security audits and the protocol's vulnerability disclosure policy, see: [Liquid Collective Security](https://github.com/liquid-collective/security)

## Contributing

For guidance on setting up a development environment and how to make a contribution to Liquid Collective, see the [contributing guidelines](./CONTRIBUTING.md).

## Licensing

The primary license for Liquid Collective is the Business Source License 1.1 (`BUSL-1.1`), see [`LICENSE`](./LICENSE). However, some files are dual licensed as indicated in its SPDX header.

## Kurtosis deployment command

*Requires Kurtosis running locally as prerequisite*

`npx hardhat deploy --deploy-scripts ./deploy/devHoodi --network kurtosis`