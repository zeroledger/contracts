import dotenv from "dotenv";
const config = dotenv.config();

import "@nomicfoundation/hardhat-toolbox";
import "@dgma/hardhat-sol-bundler";
import "@openzeppelin/hardhat-upgrades";
import "hardhat-abi-exporter";
import { ZeroHash } from "ethers";

if (config.error) {
  console.error(config.error);
}

const deployerAccounts = [config?.parsed?.PRIVATE_KEY || ZeroHash];

const DEFAULT_RPC = "https:random.com";

export default {
  solidity: {
    version: "0.8.28",
    settings: {
      optimizer: { enabled: true, runs: 100000000 },
    },
    metadata: {
      appendCBOR: false,
    },
  },
  paths: {
    sources: "src",
    tests: "integration",
  },
  abiExporter: {
    path: "./abi",
    runOnCompile: false,
    clear: true,
    only: ["Vault", "MockERC20", "Forwarder", "Manager"],
    flat: true,
    spacing: 2,
    format: "json",
  },
  networks: {
    hardhat: {},
    localhost: {},
    baseSepolia: {
      url: config?.parsed?.BASE_SEPOLIA_RPC || DEFAULT_RPC,
      accounts: deployerAccounts,
      params: {
        admin: config?.parsed?.SEPOLIA_ADMIN_ADDRESS,
        maintainer: config?.parsed?.SEPOLIA_MAINTAINER_ADDRESS,
        securityCouncil: config?.parsed?.SEPOLIA_SECURITY_COUNCIL_ADDRESS,
        defaultPaymaster: config?.parsed?.SEPOLIA_DEFAULT_PAYMASTER_ADDRESS,
      },
    },
  },
  etherscan: {
    apiKey: {
      baseSepolia: config?.parsed?.BASE_API_KEY,
    },
  },
};
