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
  "TLC_Proxy",
  "RedeemManager_Proxy"
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

function getValue(
  decodedValue: any,
  namedAccountsMapping: { [key: string]: string },
  contractsMapping: { [key: string]: string }
): any {
  let res;
  if (namedAccountsMapping[decodedValue.toLowerCase()] !== undefined) {
    res = {
      value: decodedValue.toString(),
      namedAccount: namedAccountsMapping[decodedValue.toLowerCase()],
    };
  }
  if (contractsMapping[decodedValue.toLowerCase()] !== undefined) {
    if (res) {
      if (typeof res === "string") {
        res = {
          value: decodedValue,
          contract: contractsMapping[decodedValue.toLowerCase()],
        };
      } else {
        res.contract = contractsMapping[decodedValue.toLowerCase()];
      }
    } else {
      res = {
        value: decodedValue.toString(),
        contract: contractsMapping[decodedValue.toLowerCase()],
      };
    }
  }
  return res;
}

async function decodeConstructorArguments(
  contractName: string,
  artifactContent: any,
  networkName: string,
  namedAccountsMapping: { [key: string]: string },
  contractsMapping: { [key: string]: string }
): Promise<any> {
  const completeArtifactPath = join(process.cwd(), "deployments", networkName, `${contractName}.json`);
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
          decoded[key] = getValue(decoded[key].toString(), namedAccountsMapping, contractsMapping);
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
          decoded[key] = getValue(decoded[key].toString(), namedAccountsMapping, contractsMapping);
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
  const artifactName = join(process.cwd(), `deployment.${network.name}.json`);
  hre.run("export", { export: artifactName });
  await new Promise((resolve) => setTimeout(resolve, 5000));
  const artifactContent = require(artifactName);
  const namedAccounts = await hre.getNamedAccounts();
  const contractNames = Object.keys(artifactContent.contracts).filter((a) => !(a.includes("firewallAbis/") || a.includes("combinedImplementations/")))
  let firewallAbi;
  const contractsAbis = {};
  const inversedNamedAccounts = {};
  for (const namedAccount of Object.keys(namedAccounts)) {
    if (inversedNamedAccounts[namedAccounts[namedAccount].toLowerCase()] === undefined) {
      inversedNamedAccounts[namedAccounts[namedAccount].toLowerCase()] = namedAccount;
    } else {
      inversedNamedAccounts[namedAccounts[namedAccount].toLowerCase()] += "," + namedAccount;
    }
  }
  const inversedContracts = {};
  for (const contract of contractNames) {
    if (artifactContent.contracts[contract].address) {
      inversedContracts[artifactContent.contracts[contract].address.toLowerCase()] = contract;
    }
  }
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
      network.name,
      inversedNamedAccounts,
      inversedContracts
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
