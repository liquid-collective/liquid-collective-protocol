# 🌊
![format](https://github.com/River-Protocol/river-contracts/actions/workflows/Format.yaml/badge.svg)
![lint](https://github.com/River-Protocol/river-contracts/actions/workflows/Lint.yaml/badge.svg)
![mythril](https://github.com/River-Protocol/river-contracts/actions/workflows/Mythril.yaml/badge.svg)
![Tests](https://github.com/River-Protocol/river-contracts/actions/workflows/Tests.yaml/badge.svg)

Ethereum Liquid Staking. Documentation available at https://river-protocol.gitbook.io.

## Field Guide
Users interact with this contract through an upgradeable proxy, defined at `contracts/src/TUPProxy.sol`. This requires us to use [unstructured storage](https://blog.openzeppelin.com/upgradeability-using-unstructured-storage/), a Solidity pattern in which we save state variables in their own library rather than as in-line variables in the contract manipulating those variables. Each variable's libary comes with its own getters and setters for the variable value. This lets a future version of the contract access the same values that the old version was relying on. River, as an upgradeable protocol, must also use an Initializer (`contracts/src/Initializer.sol`) to mimic a constructor, since a proxy cannot call that constructor. [See here](https://docs.openzeppelin.com/upgrades-plugins/1.x/writing-upgradeable#initializers).

`TUPProxy.sol` points to the logic at `River.{VERSION_NUMBER}.sol`. In turn, `River.sol` uses the managers in `contracts/src/components/` to accomplish the following logic:

- `TransferManager` to handle incoming ETH from stakers
- `DepositManager` to take deposited ETH and allocate it to validators
- `OperatorsManager` to handle the node operators
- `OracleManager` to receive input from `Oracle.sol`
- `SharesManager` as the ERC20 implementation to credit initial deposits, & reflect earnings reported by the oracle in rebased lsETH balances

`River.sol`, as well as the managers it uses, leverages the state libraries in `contracts/src/state/` to read & set the variables in unstructured storage.

`River.sol` will get its withdrawal logic from `contracts/src/Withdraw.sol`. Since the actual protocol for moving ETH off of a validator post-merge has not yet been defined, this contract is a temporary stub contract, which will be upgraded post-merge.

`Oracle.sol` receives reports of staking rewards from designated reporters, and pushes the data to `River.sol` to modify lsETH balances.

`AllowList.sol` handles the list of recipients allowed to interact with River. `River.sol` reads from it.

We wrap `AllowList`, `Oracle` and `River` in a `Firewall.sol`, through which administrators can make onlyAdmin function calls.

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

#### Local

To deploy the contracts in an ephemeral EVM instance, run

```
yarn hh deploy
```

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
