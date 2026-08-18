import "@nomiclabs/hardhat-ethers";
import { HardhatUserConfig } from "hardhat/config";
const config: HardhatUserConfig = {
  solidity: { version: "0.8.34", settings: { optimizer: { enabled: true, runs: 100 } } },
  paths: { sources: "./contracts/src" },
  networks: { hoodi: { url: process.env.RPC_URL || "" } },
};
export default config;
