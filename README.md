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

| Contract                                                                                                                             |                                                         Mainnet                                                         |                                                             Holesky                                                             |                                                              Hoodi                                                              |
|--------------------------------------------------------------------------------------------------------------------------------------|-------------------------------------------------------------------------------------------------------------------------|:-------------------------------------------------------------------------------------------------------------------------------:|:-------------------------------------------------------------------------------------------------------------------------------:|
| [TLC](https://github.com/liquid-collective/liquid-collective-protocol/blob/main/contracts/src/TLC.1.sol)                             | [`0xb5Fe6946836D687848B5aBd42dAbF531d5819632`](https://etherscan.io/address/0xb5Fe6946836D687848B5aBd42dAbF531d5819632) | [`0x1dA1B892575dc5fABbef28FA0F62fE302ED39E83`](https://holesky.etherscan.io/address/0x1dA1B892575dc5fABbef28FA0F62fE302ED39E83) |                                                               n/a                                                               |
| [River (LsETH)](https://github.com/liquid-collective/liquid-collective-protocol/blob/main/contracts/src/River.1.sol)                 | [`0x8c1BEd5b9a0928467c9B1341Da1D7BD5e10b6549`](https://etherscan.io/address/0x8c1BEd5b9a0928467c9B1341Da1D7BD5e10b6549) | [`0x1d8b30cC38Dba8aBce1ac29Ea27d9cFd05379A09`](https://holesky.etherscan.io/address/0x1d8b30cC38Dba8aBce1ac29Ea27d9cFd05379A09) |  [`0x0CA0c58b1986a55876552E0D9532C963625D5646`](https://hoodi.etherscan.io/address/0x0CA0c58b1986a55876552E0D9532C963625D5646)  |
| [OperatorsRegistry](https://github.com/liquid-collective/liquid-collective-protocol/blob/main/contracts/src/OperatorsRegistry.1.sol) | [`0x1235f1b60df026B2620e48E735C422425E06b725`](https://etherscan.io/address/0x1235f1b60df026B2620e48E735C422425E06b725) | [`0xCb8641aF17e19976245bEB68CD50f61c5779b294`](https://holesky.etherscan.io/address/0xCb8641aF17e19976245bEB68CD50f61c5779b294) | [`0x08CC4d7cE071BB80EB30184da96692C312Cfa904`](https://hoodi.etherscan.io/address/0x08CC4d7cE071BB80EB30184da96692C312Cfa904) |
| [Oracle](https://github.com/liquid-collective/liquid-collective-protocol/blob/main/contracts/src/Oracle.1.sol)                       | [`0x895a57eD71025D51fe4080530A3489D92E230683`](https://etherscan.io/address/0x895a57eD71025D51fe4080530A3489D92E230683) | [`0xc8D639f014a78B1cEc17761BFD9E8c80919efbc6`](https://holesky.etherscan.io/address/0xc8D639f014a78B1cEc17761BFD9E8c80919efbc6) | [`0xDb9C7257647169c8F48ddEbB3b30b94e5DF37f78`](https://hoodi.etherscan.io/address/0xDb9C7257647169c8F48ddEbB3b30b94e5DF37f78) |
| [Allowlist](https://github.com/liquid-collective/liquid-collective-protocol/blob/main/contracts/src/Allowlist.1.sol)                 | [`0xebc83Bb472b2816Ec5B5de8D34F0eFc9088BB2ce`](https://etherscan.io/address/0xebc83Bb472b2816Ec5B5de8D34F0eFc9088BB2ce) | [`0x5C783DCD596dad2bDe930f22C3684E77E25b6436`](https://holesky.etherscan.io/address/0x5C783DCD596dad2bDe930f22C3684E77E25b6436) | [`0x21504e21Dd31ec7f778DFeFc56A5DBaaa63E5BB4`](https://hoodi.etherscan.io/address/0x21504e21Dd31ec7f778DFeFc56A5DBaaa63E5BB4) |
| [CoverageFund](https://github.com/liquid-collective/liquid-collective-protocol/blob/main/contracts/src/CoverageFund.1.sol)           | [`0x32aac358b627b9feaa971cc33304027a41e49a81`](https://etherscan.io/address/0x32aac358b627b9feaa971cc33304027a41e49a81) | [`0x8eeaca6f8964771d4e50f899a06f527c2affe15c`](https://holesky.etherscan.io/address/0x8eeaca6f8964771d4e50f899a06f527c2affe15c) | [`0x2343A2cF4F4b2109400dBC0143437151b119bFdd`](https://hoodi.etherscan.io/address/0x2343A2cF4F4b2109400dBC0143437151b119bFdd) |
| [Withdraw](https://github.com/liquid-collective/liquid-collective-protocol/blob/main/contracts/src/Withdraw.1.sol)                   | [`0x0AFd81862eEA47322Cf85Db39D3D07e8A3c25154`](https://etherscan.io/address/0x0AFd81862eEA47322Cf85Db39D3D07e8A3c25154) | [`0xAaF99F2F0C47EF32AB9B5aa3e117c9190b37Ff88`](https://holesky.etherscan.io/address/0xAaF99F2F0C47EF32AB9B5aa3e117c9190b37Ff88) | [`0x9E6Dd63444Af1568261Bea7bB22aB975fA5a5B41`](https://hoodi.etherscan.io/address/0x9E6Dd63444Af1568261Bea7bB22aB975fA5a5B41) |
| [ELFeeRecipient](https://github.com/liquid-collective/liquid-collective-protocol/blob/main/contracts/src/ELFeeRecipient.1.sol)       | [`0x7D16d2c4e96BCFC8f815E15b771aC847EcbDB48b`](https://etherscan.io/address/0x7D16d2c4e96BCFC8f815E15b771aC847EcbDB48b) | [`0x4E44868856A26F4cbB431cC144318D4E7F39a585`](https://holesky.etherscan.io/address/0x4E44868856A26F4cbB431cC144318D4E7F39a585) | [`0xf88d4AD5d6f45ce86952DDc5aACCE5A97501e104`](https://hoodi.etherscan.io/address/0xf88d4AD5d6f45ce86952DDc5aACCE5A97501e104) |
| [RedeemManager](https://github.com/liquid-collective/liquid-collective-protocol/blob/main/contracts/src/RedeemManager.1.sol)         | [`0x080b3a41390b357Ad7e8097644d1DEDf57AD3375`](https://etherscan.io/address/0x080b3a41390b357Ad7e8097644d1DEDf57AD3375) | [`0x0693875efbF04dDAd955c04332bA3324472DF980`](https://holesky.etherscan.io/address/0x0693875efbF04dDAd955c04332bA3324472DF980) | [`0x5d51E82b75A4F16ef677d5bE20d707b6441A00b7`](https://hoodi.etherscan.io/address/0x5d51E82b75A4F16ef677d5bE20d707b6441A00b7) |
| [WLSETH](https://github.com/liquid-collective/liquid-collective-protocol/blob/main/contracts/src/WLSETH.1.sol)                       |                                                           n/a                                                           | [`0x21ae523bf67C81c8e4F640d8f76F9c7B77eCc0bf`](https://holesky.etherscan.io/address/0x21ae523bf67C81c8e4F640d8f76F9c7B77eCc0bf) |                                                               n/a                                                               |
| [Protocol Metrics](https://github.com/liquid-collective/liquid-collective-protocol/blob/main/contracts/src/ProtocolMetrics.1.sol)    | [`0xf19345EabC46ADF82e85CC2293A657A2dBa5c7d4`](https://etherscan.io/address/0xf19345EabC46ADF82e85CC2293A657A2dBa5c7d4) | [`0x0264d6ba1bf1ed4d55630dc5dc5e0eb1b71ae4ca`](https://holesky.etherscan.io/address/0x0264d6ba1bf1ed4d55630dc5dc5e0eb1b71ae4ca) |                                                               n/a                                                               |

## Security

If you're interested in learning more about Liquid Collective security processes, including security audits and the protocol's vulnerability disclosure policy, see: [Liquid Collective Security](https://github.com/liquid-collective/security)

## Contributing

For guidance on setting up a development environment and how to make a contribution to Liquid Collective, see the [contributing guidelines](./CONTRIBUTING.md).

## Licensing

The primary license for Liquid Collective is the Business Source License 1.1 (`BUSL-1.1`), see [`LICENSE`](./LICENSE). However, some files are dual licensed as indicated in its SPDX header.
