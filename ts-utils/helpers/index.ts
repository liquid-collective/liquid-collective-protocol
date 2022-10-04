import { DeploymentsExtension } from "hardhat-deploy/dist/types";

export const logStep = (filename: string) => {
  console.log(`=== ${filename} START`);
  console.log();
};

export const logStepEnd = (filename: string) => {
  console.log();
  console.log(`=== ${filename} END`);
};

export const isDeployed = async (
  name: string,
  deployments: DeploymentsExtension,
  filename: string
): Promise<boolean> => {
  try {
    const checkedDeployment = await deployments.get(name);
    return checkedDeployment.receipt?.status === 1;
  } catch (e) {
    return false;
  }
};
