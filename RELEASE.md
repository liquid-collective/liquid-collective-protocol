# Protocol Release Process

## Overview

![ETH_Release_Process.jpg](assets/ETH_Release_Process.jpg)

## Step-by-step

1. Create a release branch `release/x.y.z` from the commit we want in `main`
2. Input the parameter in the [deployment scripts](deploy)
3. Deploy the contracts with `yarn hardhat deploy`
4. Commit the generated artifacts in the [deployment folders](deployments)
5. Merge `release/x.y.z` into `main`
6. Create the GitHub Release with the relevant `x.y.z` tag
7. Create the upgrade proposal in Defender
8. Get the necessary approvals
9. Execute the upgrade proposal in Defender
10. We're done !