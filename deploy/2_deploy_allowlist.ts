import { DeployFunction } from "hardhat-deploy/dist/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { getContractAddress } from "ethers/lib/utils";

const logStep = () => {
  console.log(`=== ${__filename} START`);
  console.log();
};

const logStepEnd = () => {
  console.log();
  console.log(`=== ${__filename} END`);
};

const func: DeployFunction = async function ({ deployments, getNamedAccounts, ethers }: HardhatRuntimeEnvironment) {
  logStep();

  const { deployer, proxyAdministrator, systemAdministrator } = await getNamedAccounts();

  const signer = await ethers.getSigner(deployer);

  const txCount = await signer.getTransactionCount();

  const futureAllowlistAddress = getContractAddress({
    from: deployer,
    nonce: txCount + 2, // proxy is in 3 txs
  });

  const allowlistArtifact = await deployments.getArtifact("AllowlistV1");
  const allowlistInterface = new ethers.utils.Interface(allowlistArtifact.abi);

  const firewallDeployment = await deployments.deploy("Firewall", {
    from: deployer,
    log: true,
    args: [systemAdministrator, proxyAdministrator, futureAllowlistAddress, [allowlistInterface.getSighash("allow")]],
  });

  const allowlistDeployment = await deployments.deploy("AllowlistV1", {
    from: deployer,
    log: true,
    proxy: {
      owner: proxyAdministrator,
      proxyContract: "TUPProxy",
      execute: {
        methodName: "initAllowlistV1",
        args: [firewallDeployment.address, firewallDeployment.address],
      },
    },
  });

  if (allowlistDeployment.address !== futureAllowlistAddress) {
    throw new Error(`Invalid future address computation ${futureAllowlistAddress} != ${allowlistDeployment.address}`);
  }

  logStepEnd();
};
export default func;
