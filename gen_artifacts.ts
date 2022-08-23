import { writeFileSync } from "fs";
import hre from "hardhat";

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
  for (const contractName of contractNames) {
    artifactContent.contracts[contractName] = artifactContent.contracts[contractName].address;
  }
  artifactContent.namedAccount = namedAccounts;
  writeFileSync(artifactName, JSON.stringify(artifactContent, null, 4));
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
