import * as dotenv from "dotenv";

import "hardhat-deploy";
import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-verify";
import "@nomiclabs/hardhat-waffle";
import "@typechain/hardhat";
import "hardhat-gas-reporter";
import "solidity-coverage";
import "hardhat-docgen";
import "hardhat-contract-sizer";
import "@primitivefi/hardhat-dodoc";
import * as tdly from "@tenderly/hardhat-tenderly";
import { tenderly } from "hardhat";
tdly.setup({ automaticVerifications: false });

dotenv.config();

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.20",
    settings: {
      viaIR: true,
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
    mainnet: {
      url: process.env.RPC_URL || "",
      accounts: [process.env.PRIVATE_KEY || "0x0000000000000000000000000000000000000000000000000000000000000000"],
    },
    hardhat: {
      accounts: {
        mnemonic: "word word word word word word word word word word word word",
        accountsBalance: "10000000000000000000",
      },
    },
    local: {
      url: "http://localhost:8545", // anvil --port 8888
      accounts: ["0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"], // default anvil private key
    },
    tenderly: {
      url: process.env.TENDERLY_URL || "",
    },
    hoodi: {
      url: process.env.RPC_URL || "",
      accounts: [process.env.PRIVATE_KEY || "0x0000000000000000000000000000000000000000000000000000000000000000"],
      gas: 5000000,
    },
  },
  namedAccounts: {
    deployer: {
      default: 0,
    },
    depositContract: {
      default: "0x00000000219ab540356cBB839Cbe05303d7705Fa",
      local: "0x00000000219ab540356cBB839Cbe05303d7705Fa",
      mainnet: "0x00000000219ab540356cBB839Cbe05303d7705Fa",
      tenderly: "0x4242424242424242424242424242424242424242",
      hoodi: "0x00000000219ab540356cBB839Cbe05303d7705Fa",
    },
    governor: {
      default: 1,
      local: "0x71c9DAb681C209bb82270906e3B49388b2C15404",
      mainnet: "0xE3208Aa9d1186c1D1C8A5b76E794b2B68E6cb3a5",
      tenderly: "0x0e9eAd2FEB500DB46E6EB95b352FA4a86aC13dBE",
      hoodi: "0xF733B0eCf2141db2956d8Ea9ab98e5Cc33CA2f80",
    },
    executor: {
      default: 1,
      local: "0x71c9DAb681C209bb82270906e3B49388b2C15404",
      mainnet: "0xDE55C9dc78f985fE1502484Cb98EBfAB66A56B62",
      tenderly: "0xe953E4df3dDd575D2C1E1950ec4Fa33CF89947DA",
      hoodi: "0xF733B0eCf2141db2956d8Ea9ab98e5Cc33CA2f80",
    },
    proxyAdministrator: {
      default: 2,
      local: "0x07706A7D768054c10eB4FC9103Ea322f62831cb9",
      mainnet: "0x8EE3fC0Bcd7B57429203751C5bE5fdf1AB8409f3",
      tenderly: "0x8EE3fC0Bcd7B57429203751C5bE5fdf1AB8409f3",
      hoodi: "0xF733B0eCf2141db2956d8Ea9ab98e5Cc33CA2f80",
    },
    collector: {
      default: 1,
      local: "0x71c9DAb681C209bb82270906e3B49388b2C15404",
      mainnet: "0xE3208Aa9d1186c1D1C8A5b76E794b2B68E6cb3a5",
      tenderly: "0xc5DB3C539900B1A2889c37BEaE789D0EB57e8681",
      hoodi: "0xF733B0eCf2141db2956d8Ea9ab98e5Cc33CA2f80",
    },
    tlcMintAccount: {
      default: 1,
      local: "0x7932EdA85E33D8e13f7C110ACBEb4a5A8B53dda9",
      mainnet: "0x070cbF96cac223D88401D6227577f9FA480C57C8",
      tenderly: "0x67AB27C56cDB02C6c0f8B89948350Ebbb1837577", // EOA
    },
  },
  paths: {
    sources: "./contracts/src",
    cache: "./hardhat-cache",
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY || "",
    customChains: [
      {
        network: "hoodi",
        chainId: 560048,
        urls: {
          apiURL: "https://api-hoodi.etherscan.io/api",
          browserURL: "https://hoodi.etherscan.io",
        },
      },
    ],
  },
  tenderly: {
    project: process.env.TENDERLY_PROJECT_ID,
    username: process.env.TENDERLY_USERNAME,
    privateVerification: false,
  },
};

export default config;
