# Post Deployment Process

When we do a full deployment of our contracts (not just an upgrade), we need to populate some initial data. This can include necessary seed data & initial account roles to bootstrap the ecosystem, as well as demonstration data for testnet deployments.

## Testnet Deployments

For testnet deployments, we must:

1. Add example data on the testnet instance:
    1. Give appropriate permissions to three accounts owned by the releasing dev, using OZ defender:
        1. Staker allowlist
        2. Node operators
        3. Oracle members
    2. Deposit some ETH using the UI via the first account
    3. Add some validator keys from the CLI via the second account
    4. Flush that staked ETH to those new validators via `depositToConsensusLayer()` from the admin account in OZ defender
    5. Run an oracle report from the CLI via the third account
2. Add customers to those three roles as well, so that they can make example deposits or node operations
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
