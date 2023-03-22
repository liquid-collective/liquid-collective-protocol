import { DeployFunction } from "hardhat-deploy/dist/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { isDeployed, logStep, logStepEnd } from "../ts-utils/helpers/index";
import { getContractAddress } from "ethers/lib/utils";

const func: DeployFunction = async function ({ deployments, getNamedAccounts, ethers }: HardhatRuntimeEnvironment) {
  const { deployer, executor, proxyAdministrator, tlcMintAccount } = await getNamedAccounts();

  const signer = await ethers.getSigner(deployer);

  const txCount = await signer.getTransactionCount();
  const futureTLCAddress = getContractAddress({
    from: deployer,
    nonce: txCount + 2, // proxy is in 8 txs
  });

  const proxyArtifact = await deployments.getArtifact("TUPProxy");
  const proxyInterface = new ethers.utils.Interface(proxyArtifact.abi);

  const tlcProxyFirewallDeployment = await deployments.deploy("TLCProxyFirewall", {
    contract: "Firewall",
    from: deployer,
    log: true,
    args: [proxyAdministrator, executor, futureTLCAddress, [proxyInterface.getSighash("pause()")]],
  });

  const tlcDeployment = await deployments.deploy("TLC", {
    contract: "TLCV1",
    from: deployer,
    log: true,
    proxy: {
      owner: tlcProxyFirewallDeployment.address,
      proxyContract: "TUPProxy",
      implementationName: "TLCV1_Implementation_0_4_0",
      execute: {
        methodName: "initTLCV1",
        args: [tlcMintAccount],
      },
    },
  });

  if (tlcDeployment.address !== futureTLCAddress) {
    throw new Error(`Invalid future tlc address computation ${futureTLCAddress} != ${tlcDeployment.address}`);
  }

  logStepEnd(__filename);
};

func.skip = async function ({ deployments }: HardhatRuntimeEnvironment): Promise<boolean> {
  logStep(__filename);
  const shouldSkip = await isDeployed("TLC", deployments, __filename);
  if (shouldSkip) {
    console.log("Skipped");
    logStepEnd(__filename);
  }
  return shouldSkip;
};

export default func;
