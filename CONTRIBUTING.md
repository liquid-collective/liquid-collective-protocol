# Welcome to Liquid Collective's contribution guide
Thank you for investing your time in contributing to our project!

Read our [Code of Conduct](./CODE_OF_CONDUCT.md) to keep our community approachable and respectable.

In this guide you will get an overview of the contribution workflow, from opening an issue and creating a pull request (PR) to reviewing and merging the PR.

## Contribution steps
Below we describe the workflow to contribute to this repository:

1. Open an issue describing what you intend to work on. Be as detailed as possible.
2. Code owners will discuss your issue and validate whether we would accept a PR for this.
3. Open a PR:
   1. Fork the repository.
   2. Create your branch.
   3. Open your PR against `main`. We use semantic commits (feat: / fix: / chore: / etc..). Your PR title must express the content of your contribution.
   4. Fill the PR template with relevant information.
4. Your PR will be reviewed by code owners.
5. Your PR will be merged by code owners.

## Scripts

### Install dependencies
```
yarn && yarn link_contracts
```

### Run tests

```
make test
make test-heavy
```

### Run tests include fork tests
```
env MAINNET_FORK_URL=... make test
```

The URL provided must be an archive node endpoint allowing state queries at arbitrary block numbers.

### Run checks
```
forge build && forge fmt --check
```

### Deploy
You need to define the `PRIVATE_KEY` env variable before running these scripts. The private key should unlock an account with enough ETH to cover deployment fees. The deployment account has no ownership on the contracts deployed. Core components addresses are configured in `hardhat.config.ts` in the `namedAccounts` section.

#### Local
To deploy the contracts in an ephemeral EVM instance, run
```
yarn hh deploy
```

#### Holesky
Deployment on the Holesky test network using the Prater Beacon test chain.
```
yarn hh --network holesky
```

### Submodules
Submodules should only be updated by maintainers. If you happen to have submodules included in your PR, please run the following:
```
git submodule update --init --recursive
```

## Live Deployments
All addresses can be found inside the `deployment.NETWORK.json` files

