# 🌊
![format](https://github.com/River-Protocol/river-contracts/actions/workflows/Format.yaml/badge.svg)
![lint](https://github.com/River-Protocol/river-contracts/actions/workflows/Lint.yaml/badge.svg)
![mythril](https://github.com/River-Protocol/river-contracts/actions/workflows/Mythril.yaml/badge.svg)
![Tests](https://github.com/River-Protocol/river-contracts/actions/workflows/Tests.yaml/badge.svg)

Ethereum Liquid Staking. Documentation available at https://river-protocol.gitbook.io.

## Scripts

### Install dependencies

```
yarn
```

### Run tests

```
yarn test
```

### Run checks

```
yarn lint:check && yarn format:check
```

### Deploy

You need to define the `MNEMONIC` env variable before running these scripts. The mnemonic should unlock an account with enough ETH to cover deployment fees. The deployment account has no ownership on the contracts deployed. Core components addresses are configured in `hardhat.config.ts` in the `namedAccounts` section.

#### Goerli

Deployment on the goerli test network using the Prater Beacon test chain.

```
yarn hh --network goerli
```

#### Goerli with mocked DepositContract

Deployment on the goerli test network using a mocked DepositContract that emits the same event as the real DepositContract, but transfers back the funds to the treasury address.

```
yarn hh --network mockedGoerli
```

## Live Deployments

### Goerli (`goerli`)

| Contract | Address | Artifact |
|---|---|---|
| RiverV1  | [`0x2E83624ef8737B5e26F567F7310202e5D4252578`](https://goerli.etherscan.io/address/0x2E83624ef8737B5e26F567F7310202e5D4252578) | [📜](./deployments/goerli/RiverV1.json) |
| OracleV1  | [`0x04895E3052C0e7BCffE0138FF5e4902449481878`](https://goerli.etherscan.io/address/0x04895E3052C0e7BCffE0138FF5e4902449481878)  | [📜](./deployments/goerli/OracleV1.json) |
|  WithdrawV1 | [`0xB5EC5a8c3034f66A6d22a79149816C24Db633C00`](https://goerli.etherscan.io/address/0xB5EC5a8c3034f66A6d22a79149816C24Db633C00)  | [📜](./deployments/goerli/WithdrawV1.json) |

### Goerli with mocked deposit contract (`mockedGoerli`)

| Contract | Address | Artifact |
|---|---|---|
| RiverV1  | [`0x50f89c88C3C80D8CcB88036fdcba5cC3480456b2`](https://goerli.etherscan.io/address/0x50f89c88C3C80D8CcB88036fdcba5cC3480456b2) | [📜](./deployments/mockedGoerli/RiverV1.json) |
| OracleV1  | [`0x4C1bd8176C729d37A270FF36CDFCf547c9F84676`](https://goerli.etherscan.io/address/0x4C1bd8176C729d37A270FF36CDFCf547c9F84676)  | [📜](./deployments/mockedGoerli/OracleV1.json) |
|  WithdrawV1 | [`0x3C7CF2e9597d18B08353e7734F958B707350121E`](https://goerli.etherscan.io/address/0x3C7CF2e9597d18B08353e7734F958B707350121E)  | [📜](./deployments/mockedGoerli/WithdrawV1.json) |