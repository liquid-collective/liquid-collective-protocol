import { network, tenderly } from "hardhat";
import * as hre from "hardhat";
import { FactoryOptions } from "hardhat/types";

export const verify = async (name: string, contractAddress: string, args: any, libs?: FactoryOptions) => {
  if (network.name == "localhost" || network.name == "local") return;
  else if (network.name == "tenderly") tenderlyVerify(name, contractAddress);
  else {
    await hre.run("verify:verify", {
      address: contractAddress,
      constructorArguments: args,
      libraries: {
        ...libs,
      },
    }).catch((e) => {
      console.log(e.message);
    });
  }
};

const tenderlyVerify = async (name: string, contractAddress: string) => {
  if (network.name === "tenderly") {
    await tenderly.verify({
      name,
      address: contractAddress,
    });
  }
};
