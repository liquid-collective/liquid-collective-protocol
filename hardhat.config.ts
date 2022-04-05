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

dotenv.config();

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.10",
    settings: {
      optimizer: {
        enabled: true,
        runs: 1000,
      },
    },
  },
  contractSizer: {
    runOnCompile: true,
  },
  networks: {
    mockedGoerli: {
      url: process.env.RPC_URL || "",
      accounts: {
        mnemonic: process.env.MNEMONIC || "",
      },
    },
    goerli: {
      url: process.env.RPC_URL || "",
      accounts: {
        mnemonic: process.env.MNEMONIC || "",
      },
    },
    hardhat: {
      accounts: {
        mnemonic: "word word word word word word word word word word word word",
        accountsBalance: "10000000000000000000",
      },
    },
  },
  namedAccounts: {
    deployer: {
      default: 0,
    },
    depositContract: {
      default: "0x00000000219ab540356cBB839Cbe05303d7705Fa",
      goerli: "0xff50ed3d0ec03ac01d4c79aad74928bff48a7b2b", // prater deposit contract
    },
    systemAdministrator: {
      default: 1,
      goerli: "0x71c9DAb681C209bb82270906e3B49388b2C15404",
      mockedGoerli: "0x71c9DAb681C209bb82270906e3B49388b2C15404",
    },
    treasury: {
      default: 1,
      goerli: "0x774c51712F2f1eAFA73681403414D5EE419f2c73",
      mockedGoerli: "0x774c51712F2f1eAFA73681403414D5EE419f2c73",
    },
    proxyAdministrator: {
      default: 2,
      goerli: "0x07706A7D768054c10eB4FC9103Ea322f62831cb9",
      mockedGoerli: "0x07706A7D768054c10eB4FC9103Ea322f62831cb9",
    },
  },
  paths: {
    sources: "./contracts/src",
    cache: "./hardhat-cache",
  },
};

export default config;
