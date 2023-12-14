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

| Contract                                                                                                                             |                                                         Mainnet                                                         |                                                             Goerli                                                             | Holesky                                                                                                                         |
| ------------------------------------------------------------------------------------------------------------------------------------ | :---------------------------------------------------------------------------------------------------------------------: | :----------------------------------------------------------------------------------------------------------------------------: | :-------------------------------------------------------------------------------------------------------------------------------: |
| [TLC](https://github.com/liquid-collective/liquid-collective-protocol/blob/main/contracts/src/TLC.1.sol)                             | [`0xb5Fe6946836D687848B5aBd42dAbF531d5819632`](https://etherscan.io/address/0xb5Fe6946836D687848B5aBd42dAbF531d5819632) | [`0xb2f102b87022bf5a64e012b39FF25a404102e301`](https://goerli.etherscan.io/address/0xb2f102b87022bf5a64e012b39FF25a404102e301) | [`0xA8048bd67D228709dEE9e593a574836dE565F80E`](https://holesky.etherscan.io/address/0xA8048bd67D228709dEE9e593a574836dE565F80E) |
| [River (LsETH)](https://github.com/liquid-collective/liquid-collective-protocol/blob/main/contracts/src/River.1.sol)                 | [`0x8c1BEd5b9a0928467c9B1341Da1D7BD5e10b6549`](https://etherscan.io/address/0x8c1BEd5b9a0928467c9B1341Da1D7BD5e10b6549) | [`0x3ecCAdA3e11c1Cc3e9B5a53176A67cc3ABDD3E46`](https://goerli.etherscan.io/address/0x3ecCAdA3e11c1Cc3e9B5a53176A67cc3ABDD3E46) | [`0x08CC4d7cE071BB80EB30184da96692C312Cfa904`](https://holesky.etherscan.io/address/0x08CC4d7cE071BB80EB30184da96692C312Cfa904) |
| [OperatorsRegistry](https://github.com/liquid-collective/liquid-collective-protocol/blob/main/contracts/src/OperatorsRegistry.1.sol) | [`0x1235f1b60df026B2620e48E735C422425E06b725`](https://etherscan.io/address/0x1235f1b60df026B2620e48E735C422425E06b725) | [`0xf06BEd337f29CB856b072dc8d57A2c22FB2eC2CB`](https://goerli.etherscan.io/address/0xf06BEd337f29CB856b072dc8d57A2c22FB2eC2CB) | [`0xE335BCEA51Dce6f8aa76f74487338bCB6C361d4c`](https://holesky.etherscan.io/address/0xE335BCEA51Dce6f8aa76f74487338bCB6C361d4c) |
| [Oracle](https://github.com/liquid-collective/liquid-collective-protocol/blob/main/contracts/src/Oracle.1.sol)                       | [`0x895a57eD71025D51fe4080530A3489D92E230683`](https://etherscan.io/address/0x895a57eD71025D51fe4080530A3489D92E230683) | [`0x088050c58ae0F447d52674Ac58e20DD2FB68E2da`](https://goerli.etherscan.io/address/0x088050c58ae0F447d52674Ac58e20DD2FB68E2da) | [`0x0C20959C12Eb226eC7DddC25109124AE850ED4BE`](https://holesky.etherscan.io/address/0x0C20959C12Eb226eC7DddC25109124AE850ED4BE) |
| [Allowlist](https://github.com/liquid-collective/liquid-collective-protocol/blob/main/contracts/src/Allowlist.1.sol)                 | [`0xebc83Bb472b2816Ec5B5de8D34F0eFc9088BB2ce`](https://etherscan.io/address/0xebc83Bb472b2816Ec5B5de8D34F0eFc9088BB2ce) | [`0xe7B74d98D46A8e0979B0342172A3A4890F852558`](https://goerli.etherscan.io/address/0xe7B74d98D46A8e0979B0342172A3A4890F852558) | [`0x2135EFc45c42c6242E3ACE651220D0af679eB63c`](https://holesky.etherscan.io/address/0x2135EFc45c42c6242E3ACE651220D0af679eB63c) |
| [Withdraw](https://github.com/liquid-collective/liquid-collective-protocol/blob/main/contracts/src/Withdraw.1.sol)                   | [`0x0AFd81862eEA47322Cf85Db39D3D07e8A3c25154`](https://etherscan.io/address/0x0AFd81862eEA47322Cf85Db39D3D07e8A3c25154) | [`0x40a369DD92f043A6782F4d071f9D2ba22b4Ea14d`](https://goerli.etherscan.io/address/0x40a369DD92f043A6782F4d071f9D2ba22b4Ea14d) | [`0x20028A25F159A8e92c315525b04eA3A972e81496`](https://holesky.etherscan.io/address/0x20028A25F159A8e92c315525b04eA3A972e81496) |
| [ELFeeRecipient](https://github.com/liquid-collective/liquid-collective-protocol/blob/main/contracts/src/ELFeeRecipient.1.sol)       | [`0x7D16d2c4e96BCFC8f815E15b771aC847EcbDB48b`](https://etherscan.io/address/0x7D16d2c4e96BCFC8f815E15b771aC847EcbDB48b) | [`0x5654f8dFFE80ca9Fa270540C44F230CEeB0EA3bB`](https://goerli.etherscan.io/address/0x5654f8dFFE80ca9Fa270540C44F230CEeB0EA3bB) | [`0x2343A2cF4F4b2109400dBC0143437151b119bFdd`](https://holesky.etherscan.io/address/0x2343A2cF4F4b2109400dBC0143437151b119bFdd) |
| [RedeemManager](https://github.com/liquid-collective/liquid-collective-protocol/blob/main/contracts/src/RedeemManager.1.sol)         | [`0x080b3a41390b357Ad7e8097644d1DEDf57AD3375`](https://etherscan.io/address/0x080b3a41390b357Ad7e8097644d1DEDf57AD3375) | [`0x0693875efbf04ddad955c04332ba3324472df980`](https://goerli.etherscan.io/address/0x0693875efbf04ddad955c04332ba3324472df980) | [`0x5C86D68e518cFa722985971d473b525FcC5821D2`](https://holesky.etherscan.io/address/0x5C86D68e518cFa722985971d473b525FcC5821D2) |
| [WLSETH](https://github.com/liquid-collective/liquid-collective-protocol/blob/main/contracts/src/WLSETH.1.sol)                       |                                                           n/a                                                           | [`0x39dca666d863f9a5fcd0f54aedc38583ab1478bc`](https://goerli.etherscan.io/address/0x39dca666d863f9a5fcd0f54aedc38583ab1478bc) | [`0xa98665963FB5f7cc27A8364584297eb080daD78F`](https://holesky.etherscan.io/address/0xa98665963FB5f7cc27A8364584297eb080daD78F) |

## Security

If you're interested in learning more about Liquid Collective security processes, including security audits and the protocol's vulnerability disclosure policy, see: [Liquid Collective Security](https://github.com/liquid-collective/security)

## Contributing

For guidance on setting up a development environment and how to make a contribution to Liquid Collective, see the [contributing guidelines](./CONTRIBUTING.md).

## Licensing

The primary license for Liquid Collective is the Business Source License 1.1 (`BUSL-1.1`), see [`LICENSE`](./LICENSE). However, some files are dual licensed as indicated in its SPDX header.
