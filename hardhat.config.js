const config = require("dotenv").config();

require("@nomicfoundation/hardhat-foundry");
require("@nomicfoundation/hardhat-toolbox");
require("@dgma/hardhat-sol-bundler");
const { ZeroHash } = require("ethers");
const deployments = require("./deployment.config");

if (config.error) {
  console.error(config.error);
}

const deployerAccounts = [config?.parsed?.PRIVATE_KEY || ZeroHash];

const DEFAULT_RPC = "https:random.com";

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    compilers: [{ version: "0.8.28" }],
    metadata: {
      appendCBOR: false,
    },
  },
  paths: {
    sources: "src",
    tests: "integration",
  },
  networks: {
    hardhat: {
      deployment: deployments.hardhat,
    },
    localhost: {
      deployment: deployments.localhost,
    },
    arbitrumSepolia: {
      url: config?.parsed?.ARBITRUM_SEPOLIA_RPC || DEFAULT_RPC,
      accounts: deployerAccounts,
      deployment: deployments.arbitrumSepolia,
    },
    sepolia: {
      url: config?.parsed?.SEPOLIA_RPC || DEFAULT_RPC,
      accounts: deployerAccounts,
      deployment: deployments.sepolia,
    },
    opSepolia: {
      url: config?.parsed?.OP_SEPOLIA_RPC || DEFAULT_RPC,
      accounts: deployerAccounts,
      deployment: deployments.sepolia,
    },
  },
  etherscan: {
    apiKey: {
      opSepolia: config?.parsed?.OPSCAN_API_KEY,
      arbitrumSepolia: config?.parsed?.ARBISCAN_API_KEY,
      sepolia: config?.parsed?.ETHERSCAN_API_KEY,
    },
    customChains: [
      {
        network: "arbitrumSepolia",
        chainId: 421614,
        urls: {
          apiURL: "https://api-sepolia.arbiscan.io/api",
          browserURL: "https://sepolia-explorer.arbitrum.io",
        },
      },
      {
        network: "sepolia",
        chainId: 11155111,
        urls: {
          apiURL: "https://api-sepolia.etherscan.io/api",
          browserURL: "https://sepolia.etherscan.io/",
        },
      },
      {
        network: "opSepolia",
        chainId: 11155111,
        urls: {
          apiURL: "https://sepolia-optimism.etherscan.io/api",
          browserURL: "https://sepolia-optimism.etherscan.io/",
        },
      },
    ],
  },
};
