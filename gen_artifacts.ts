import { writeFileSync } from "fs";
import hre from "hardhat";

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
  const firewallAbisFileContent = {};
  for (const firewalled of firewalledContractNames) {
    let baseAbi = [...firewallAbi];
    for (const element of contractsAbis[firewalled]) {
      if (element.stateMutability !== "view" && element.stateMutability !== "pure") {
        baseAbi = [...baseAbi, element];
      }
    }
    firewallAbisFileContent[firewalled] = baseAbi;
  }
  artifactContent.namedAccounts = namedAccounts;
  writeFileSync(artifactName, JSON.stringify(artifactContent, null, 4));
  writeFileSync(`firewall_abis.${network.name}.json`, JSON.stringify(firewallAbisFileContent, null, 4));
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
