import { existsSync, mkdirSync, writeFileSync } from "fs";
import hre from "hardhat";
import { join } from "path";
import { ethers } from "ethers";

const firewalledContract = [
  "River",
  "Allowlist",
  "Oracle",
  "OperatorsRegistry",
  "Allowlist_Proxy",
  "OperatorsRegistry_Proxy",
  "Oracle_Proxy",
  "River_Proxy",
];

function getConstructorAbi(abi: any[]): any {
  for (const elem of abi) {
    if (elem.type === "constructor") {
      return elem;
    }
  }
  return null;
}

function getConstructorTypes(inputs: any[]): string[] {
  let res: string[] = [];
  for (const inp of inputs) {
    res = [...res, inp.type];
  }
  return res;
}

async function decodeConstructorArguments(
  contractName: string,
  artifactContent: any,
  networkName: string
): Promise<any> {
  const completeArtifactPath = join(__dirname, "deployments", networkName, `${contractName}.json`);
  if (existsSync(completeArtifactPath)) {
    const completeArtifact = require(completeArtifactPath);
    if (completeArtifact.execute !== undefined) {
      const intf = new ethers.utils.Interface(completeArtifact.abi);
      const encoded = intf.encodeFunctionData(completeArtifact.execute.methodName, completeArtifact.execute.args);
      const decoded = { ...intf.decodeFunctionData(completeArtifact.execute.methodName, encoded) };

      const keys = Object.keys(decoded);
      for (const key of keys) {
        if (!isNaN(parseInt(key, 10))) {
          delete decoded[key];
        } else {
          decoded[key] = decoded[key].toString();
        }
      }
      return {
        type: "proxy",
        methodName: completeArtifact.execute.methodName,
        args: decoded,
      };
    } else if (completeArtifact.args !== undefined) {
      const constructorAbi = getConstructorAbi(completeArtifact.abi);
      if (constructorAbi === null) {
        return null;
      }
      const constructorTypes = getConstructorTypes(constructorAbi.inputs);
      const encoded = ethers.utils.defaultAbiCoder.encode(constructorTypes, completeArtifact.args);
      const decoded = { ...ethers.utils.defaultAbiCoder.decode(constructorAbi.inputs, encoded) };

      const keys = Object.keys(decoded);
      for (const key of keys) {
        if (!isNaN(parseInt(key, 10))) {
          delete decoded[key];
        } else {
          decoded[key] = decoded[key].toString();
        }
      }
      return {
        type: "constructor",
        args: decoded,
      };
    }
  }
  return null;
}

async function main() {
  const network = hre.network;
  if (network.name === "hardhat") {
    throw new Error("Cannot generate artifacts for hardhat network");
  }
  const artifactName = `deployment.${network.name}.json`;
  hre.run("export", { export: artifactName });
  await new Promise((resolve) => setTimeout(resolve, 5000));
  const artifactContent = require(`./${artifactName}`);
  const namedAccounts = await hre.getNamedAccounts();
  const contractNames = Object.keys(artifactContent.contracts);
  let firewallAbi;
  const contractsAbis = {};
  for (const contractName of contractNames) {
    if (firewalledContract.includes(contractName)) {
      contractsAbis[contractName] = artifactContent.contracts[contractName].abi;
    }
    if (contractName === "RiverFirewall") {
      firewallAbi = artifactContent.contracts[contractName].abi;
    }
    const constructorArgs = await decodeConstructorArguments(
      contractName,
      artifactContent.contracts[contractName],
      network.name
    );
    if (constructorArgs !== null) {
      artifactContent.contracts[contractName] = {
        address: artifactContent.contracts[contractName].address,
        deploymentParams: constructorArgs,
      };
    } else {
      artifactContent.contracts[contractName] = artifactContent.contracts[contractName].address;
    }
  }
  const firewalledContractNames = Object.keys(contractsAbis);
  for (const firewalled of firewalledContractNames) {
    let baseAbi = [...firewallAbi];
    for (const element of contractsAbis[firewalled]) {
      if (element.stateMutability !== "view" && element.stateMutability !== "pure") {
        baseAbi = [...baseAbi, element];
      }
    }
    const dirName = `deployments/${network.name}/firewallAbis`;
    if (!existsSync(dirName)) {
      mkdirSync(dirName);
    }
    const fileName = join(dirName, `${firewalled}.abi.json`);
    writeFileSync(fileName, JSON.stringify(baseAbi, null, 4));
  }
  artifactContent.namedAccounts = namedAccounts;
  writeFileSync(artifactName, JSON.stringify(artifactContent, null, 4));
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
