import { DeployFunction } from "hardhat-deploy/dist/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { getContractAddress } from "ethers/lib/utils";
import { isDeployed, logStep, logStepEnd } from "../../ts-utils/helpers/index";
import { verify } from "../../scripts/helpers";

const func: DeployFunction = async function ({
  deployments,
  getNamedAccounts,
  ethers,
  network,
}: HardhatRuntimeEnvironment) {
  if (!["devHolesky", "hardhat","local", "tenderly"].includes(network.name)) {
    throw new Error("Invalid network for devGoerli deployment");
  }
  const { deployer, proxyAdministrator, governor, executor } = await getNamedAccounts();

  const signer = await ethers.getSigner(deployer);

  const txCount = await signer.getTransactionCount();

  const futureAllowlistAddress = getContractAddress({
    from: deployer,
    nonce: txCount + 2, // proxy is in 3 txs
  });

  const firewallDeployment = await deployments.deploy("AllowlistFirewall", {
    contract: "Firewall",
    from: deployer,
    log: true,
    args: [governor, executor, futureAllowlistAddress, []],
  });

  await verify("Firewall", firewallDeployment.address, [governor, executor, futureAllowlistAddress, []]);

  const allowlistDeployment = await deployments.deploy("Allowlist", {
    contract: "AllowlistV1",
    from: deployer,
    log: true,
    proxy: {
      owner: proxyAdministrator,
      proxyContract: "TUPProxy",
      implementationName: "AllowlistV1_Implementation_0_2_2",
      execute: {
        methodName: "initAllowlistV1",
        args: [firewallDeployment.address, firewallDeployment.address],
      },
    },
  });

  await verify("TUPProxy", allowlistDeployment.address, []);
  await verify("AllowlistV1", allowlistDeployment.implementation, []);

  if (allowlistDeployment.address !== futureAllowlistAddress) {
    throw new Error(`Invalid future address computation ${futureAllowlistAddress} != ${allowlistDeployment.address}`);
  }

  logStepEnd(__filename);
};

func.skip = async function ({ deployments }: HardhatRuntimeEnvironment): Promise<boolean> {
  logStep(__filename);
  const shouldSkip = await isDeployed("Allowlist", deployments, __filename);
  if (shouldSkip) {
    console.log("Skipped");
    logStepEnd(__filename);
  }
  return shouldSkip;
};

export default func;
