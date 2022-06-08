# Post Deployment Process

When we do a full deployment of our contracts (not just an upgrade), we need to populate some initial data. This can include data for the sake of demonstration if we're doing a testnet deployment, and otherwise includes some necessary initial data for a mainnet deployment.

## All Deployments

For all deployments, we must:

1. Update the deployment scripts for our contracts, in the contracts repository under the `deploy` folder
    1. [Example pr](https://github.com/River-Protocol/river-contracts/pull/47)
2. Deploy via `yarn hh --network goerli`, from the multisig account
3. Update the config values we use in the contract repository under `deployments` with the output of your deployment
    1. In particular, the ABIs (`RiverV1.json`, etc) that will be reused in by the [River CLI](https://github.com/River-Protocol/river) and [Allowlist Service](https://github.com/River-Protocol/Allowlist-Service)
    2. [Example pr](https://github.com/River-Protocol/river-contracts/pull/53/files)

## Testnet Deployments

For testnet deployments, we must:

1. Add example data on the testnet instance:
    1. Give appropriate permissions to three accounts owned by the releasing dev, using OZ defender:
        1. Staker allowlist
        2. Node operators
        3. Oracle members
    2. Deposit some ETH using the UI via the first account
    3. Add some node operators, then validator keys, from the CLI via the second account
    4. Deposit that staked ETH to those new validators via `depositToConsensusLayer()` from the admin account in OZ defender
    5. Run an oracle report from the CLI via the third account
2. Add customers to testnet allowlist so they can make example deposits or node operations
3. Note any bugs in steps 1 and 2, and make fast follow contributions to contracts or the reference dapp

## Mainnet Deployments

For mainnet deployments, the main task is to set the initial roles from the multisig account via OpenZeppelin Defender:

1. Set the Allowlist Service's account as an Allower
    1. TODO insert once this is set up
2. Set the Integrators' accounts as Node Operators
    1. TODO link a resource that we can expect these operator addresses to live at
3. Add the oracle accounts as Oracle Members
    1. TODO link a resource that we can expect these operator addresses to live at
4. Ask the Integrators to begin sending accounts to add to the allowlist via the Allowlist Service
