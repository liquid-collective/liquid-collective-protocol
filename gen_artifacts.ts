import { existsSync, mkdirSync, writeFileSync } from "fs";
import hre from "hardhat";
import { join } from "path";

const firewalledContract = ["RiverV1", "AllowlistV1", "OracleV1", "OperatorsRegistryV1"];

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
    if (contractName === "Firewall") {
      firewallAbi = artifactContent.contracts[contractName].abi;
    }
    artifactContent.contracts[contractName] = artifactContent.contracts[contractName].address;
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
