# Protocol Release Process

## Overview

![ETH_Release_Process.jpg](assets/ETH_Release_Process.jpg)

## Step-by-step

1. Create a release branch `release/x.y.z` from the commit we want in `main`
2. Input the parameter in the [deployment scripts](deploy)
3. Set environment variables for the deployer account of the network to deploy on `export PRIVATE_KEY=<private_key>`
4. Set environment variables for the RPC url the network to deploy on `export RPC_URL=<rpc_url>`
5. Deploy the contracts with `yarn hardhat deploy --network <network> --deploy-scripts ./deploy/<network>`
6. Generate meta artifacts `yarn hh run --network <network> ./hardhat_scripts/gen_root_artifacts.ts` & `yarn hh run --network <network> ./hardhat_scripts/gen_meta_artifacts.ts`
7. Commit the generated artifacts in the [deployment folders](deployments)
8. Complete [CHANGELOG](CHANGELOG.md)
8. Merge `release/x.y.z` into `main`
9. Create the GitHub Release with the relevant `x.y.z` tag
10. Create the upgrade proposal in Defender
11. Get the necessary approvals
12. Execute the upgrade proposal in Defender
13. We're done !
