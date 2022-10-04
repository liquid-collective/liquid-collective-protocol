import * as dotenv from "dotenv";

import "hardhat-deploy";
import { HardhatUserConfig } from "hardhat/config";
import "@nomiclabs/hardhat-etherscan";
import "@nomiclabs/hardhat-waffle";
import "@typechain/hardhat";
import "hardhat-gas-reporter";
import "solidity-coverage";
import "hardhat-docgen";
import "hardhat-contract-sizer";
import "@primitivefi/hardhat-dodoc";

dotenv.config();

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.10",
    settings: {
      optimizer: {
        enabled: true,
        runs: 100,
      },
    },
  },
  dodoc: {
    outputDir: "natspec",
  },
  contractSizer: {
    runOnCompile: true,
  },
  networks: {
    mockedGoerli: {
      url: process.env.RPC_URL || "",
      accounts: [process.env.PRIVATE_KEY || "0x0000000000000000000000000000000000000000000000000000000000000000"],
    },
    goerli: {
      url: process.env.RPC_URL || "",
      accounts: [process.env.PRIVATE_KEY || "0x0000000000000000000000000000000000000000000000000000000000000000"],
      gas: 5000000,
    },
    hardhat: {
      accounts: {
        mnemonic: "word word word word word word word word word word word word",
        accountsBalance: "10000000000000000000",
      },
    },
    local: {
      url: "http://localhost:8888", // anvil --port 8888
      accounts: ["0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"], // default anvil private key
    },
  },
  namedAccounts: {
    deployer: {
      default: 0,
    },
    depositContract: {
      default: "0x00000000219ab540356cBB839Cbe05303d7705Fa",
      goerli: "0xff50ed3d0ec03ac01d4c79aad74928bff48a7b2b", // prater deposit contract
      local: "0x00000000219ab540356cBB839Cbe05303d7705Fa",
    },
    governor: {
      default: 1,
      goerli: "0x892D14B50Cc7a8278fa254A63B6c5b8B1a110ff1",
      mockedGoerli: "0x71c9DAb681C209bb82270906e3B49388b2C15404",
      local: "0x71c9DAb681C209bb82270906e3B49388b2C15404",
    },
    executor: {
      default: 1,
      goerli: "0xc025F2b41820c80F32AF27EFe95cf379C4A959F8",
      mockedGoerli: "0x7932EdA85E33D8e13f7C110ACBEb4a5A8B53dda9",
      local: "0x71c9DAb681C209bb82270906e3B49388b2C15404",
    },
    proxyAdministrator: {
      default: 2,
      goerli: "0x67bc791A7EA5A98DDcEcBbF6580aE1BB310F5d9B",
      mockedGoerli: "0x07706A7D768054c10eB4FC9103Ea322f62831cb9",
      local: "0x07706A7D768054c10eB4FC9103Ea322f62831cb9",
    },
    collector: {
      default: 1,
      goerli: "0x892D14B50Cc7a8278fa254A63B6c5b8B1a110ff1",
      mockedGoerli: "0x71c9DAb681C209bb82270906e3B49388b2C15404",
      local: "0x71c9DAb681C209bb82270906e3B49388b2C15404",
    },
  },
  paths: {
    sources: "./contracts/src",
    cache: "./hardhat-cache",
  },
};

export default config;
