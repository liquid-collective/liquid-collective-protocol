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
    base: {
      url: process.env.RPC_URL || "",
      accounts: [process.env.PRIVATE_KEY || "0x0000000000000000000000000000000000000000000000000000000000000000"],
    },
    holesky: {
      url: process.env.RPC_URL || "",
      accounts: [process.env.PRIVATE_KEY || "0x0000000000000000000000000000000000000000000000000000000000000000"],
      gas: 5000000,
    },
    devHolesky: {
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
      url: "http://localhost:8545", // anvil --port 8888
      accounts: ["0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"], // default anvil private key
    },
    baseSepolia: {
      url: process.env.RPC_URL || "",
      accounts: [process.env.PRIVATE_KEY || "0x0000000000000000000000000000000000000000000000000000000000000000"],
    },
    sepolia: {
      url: process.env.RPC_URL || "",
      accounts: [process.env.PRIVATE_KEY || "0x0000000000000000000000000000000000000000000000000000000000000000"],
      gas: 5000000,
    },
    tenderly: {
      url: process.env.TENDERLY_URL || "",
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
      holesky: "0x4242424242424242424242424242424242424242",
      devHolesky: "0x4242424242424242424242424242424242424242",
      tenderly: "0x4242424242424242424242424242424242424242",
    },
    governor: {
      default: 1,
      base: "0x43904DAaDb29Ff02e5C72B2707a721095dfb93A6",
      local: "0x71c9DAb681C209bb82270906e3B49388b2C15404",
      mainnet: "0xE3208Aa9d1186c1D1C8A5b76E794b2B68E6cb3a5",
      holesky: "0x9F84E1a8749D331C68Fb0322C9E24a5FB3334398",
      devHolesky: "0x0e9eAd2FEB500DB46E6EB95b352FA4a86aC13dBE",
      baseSepolia: "",
      tenderly: "0x0e9eAd2FEB500DB46E6EB95b352FA4a86aC13dBE",
    },
    executor: {
      default: 1,
      local: "0x71c9DAb681C209bb82270906e3B49388b2C15404",
      mainnet: "0xDE55C9dc78f985fE1502484Cb98EBfAB66A56B62",
      holesky: "0xE22F86Be928E03D50411C588d689C0f33900bb4c",
      devHolesky: "0xe953E4df3dDd575D2C1E1950ec4Fa33CF89947DA",
      baseSepolia: "",
      tenderly: "0xe953E4df3dDd575D2C1E1950ec4Fa33CF89947DA",
    },
    proxyAdministrator: {
      default: 2,
      base: "0x078Fb5A53Ac625eD6C8Eff5C8E316fb911Bf2b16",
      local: "0x07706A7D768054c10eB4FC9103Ea322f62831cb9",
      mainnet: "0x8EE3fC0Bcd7B57429203751C5bE5fdf1AB8409f3",
      holesky: "0x80Cf8bD4abf6C078C313f72588720AB86d45c5E6",
      devHolesky: "0x0FdEe4562D7e6dbA05A9f892D2Be04B83f3E7579",
      sepolia: "0x341C40B94bF2afBFa42573cB78f16Ee15a056238",
      baseSepolia: "0x341C40B94bF2afBFa42573cB78f16Ee15a056238",
      tenderly: "0x8EE3fC0Bcd7B57429203751C5bE5fdf1AB8409f3",
    },
    collector: {
      default: 1,
      local: "0x71c9DAb681C209bb82270906e3B49388b2C15404",
      mainnet: "0xE3208Aa9d1186c1D1C8A5b76E794b2B68E6cb3a5",
      holesky: "0x47f049e943ABFbd27Bb11aF3195FEc153A28598b",
      devHolesky: "0xc5DB3C539900B1A2889c37BEaE789D0EB57e8681",
      tenderly: "0xc5DB3C539900B1A2889c37BEaE789D0EB57e8681",
    },
    tlcMintAccount: {
      default: 1,
      local: "0x7932EdA85E33D8e13f7C110ACBEb4a5A8B53dda9",
      mainnet: "0x070cbF96cac223D88401D6227577f9FA480C57C8",
      holesky: "0xb85f6480A2BffF946Ca1874ad6E2bB55a4CF5059", // EOA
      devHolesky: "0x67AB27C56cDB02C6c0f8B89948350Ebbb1837577", // EOA
      tenderly: "0x67AB27C56cDB02C6c0f8B89948350Ebbb1837577", // EOA
    },
    baseTokenAdmin: {
      default: 1,
      base: "0xBFa8549887E6ddef8Cdf83Cda1Ad24856496fd00",
      baseSepolia: "0x726Da59a3cF0966BeF383d3A00Ac002a66Fece30",
      sepolia: "0x726Da59a3cF0966BeF383d3A00Ac002a66Fece30",
      tenderly: "0x726Da59a3cF0966BeF383d3A00Ac002a66Fece30",
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
        network: "holesky",
        chainId: 17000,
        urls: {
          apiURL: "https://api-holesky.etherscan.io/api",
          browserURL: "https://holesky.etherscan.io",
        },
      },
      {
        network: "baseSepolia",
        chainId: 84532,
        urls: {
          apiURL: "https://api-sepolia.basescan.org/api",
          browserURL: "https://sepolia.basescan.org",
        },
      },
      {
        network: "sepolia",
        chainId: 11155111,
        urls: {
          apiURL: "https://api-sepolia.etherscan.io/api",
          browserURL: "https://sepolia.etherscan.io",
        },
      },
      {
        network: "base",
        chainId: 8453,
        urls: {
          apiURL: "https://api.basescan.org/api",
          browserURL: "https://basescan.org",
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
