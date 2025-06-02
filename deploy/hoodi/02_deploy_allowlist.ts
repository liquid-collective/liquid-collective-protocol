import { DeployFunction } from "hardhat-deploy/dist/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { getContractAddress } from "ethers/lib/utils";
import { isDeployed, logStep, logStepEnd } from "../../ts-utils/helpers/index";
import { verify } from "../../scripts/helpers";

const implementationVersion = "1_2_1";

const func: DeployFunction = async function ({
  deployments,
  getNamedAccounts,
  ethers,
  network,
}: HardhatRuntimeEnvironment) {
  if (!["hardhat", "local", "tenderly", "hoodi"].includes(network.name)) {
    throw new Error("Invalid network for hoodi deployment");
  }
  const { deployer, proxyAdministrator, governor, executor } = await getNamedAccounts();

  const signer = await ethers.getSigner(deployer);

  const txCount = await signer.getTransactionCount();

  const proxyArtifact = await deployments.getArtifact("TUPProxy");
  const proxyInterface = new ethers.utils.Interface(proxyArtifact.abi);

  const futureAllowlistAddress = getContractAddress({
    from: deployer,
    nonce: txCount + 3, // proxy is in 4 txs
  });

  const firewallDeployment = await deployments.deploy("AllowlistFirewall", {
    contract: "Firewall",
    from: deployer,
    log: true,
    args: [governor, executor, futureAllowlistAddress, []],
  });

  await verify("Firewall", firewallDeployment.address, [governor, executor, futureAllowlistAddress, []]);

  const allowlistProxyFirewallDeployment = await deployments.deploy("AllowlistProxyFirewall", {
    contract: "Firewall",
    from: deployer,
    log: true,
    args: [proxyAdministrator, executor, futureAllowlistAddress, [proxyInterface.getSighash("pause()")]],
  });
  await verify("Firewall", allowlistProxyFirewallDeployment.address, allowlistProxyFirewallDeployment.args);

  const allowlistDeployment = await deployments.deploy("Allowlist", {
    contract: "AllowlistV1",
    from: deployer,
    log: true,
    proxy: {
      owner: allowlistProxyFirewallDeployment.address,
      proxyContract: "TUPProxy",
      implementationName: `AllowlistV1_Implementation_${implementationVersion}`,
      execute: {
        methodName: "initAllowlistV1",
        args: [firewallDeployment.address, firewallDeployment.address],
      },
    },
  });

  await verify("TUPProxy", allowlistDeployment.address, allowlistDeployment.args, allowlistDeployment.libraries);
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

func.tags = ["all", "allowlist"];

export default func;
