import dotenv from "dotenv";
const config = dotenv.config();

import "@nomicfoundation/hardhat-toolbox";
import "@openzeppelin/hardhat-upgrades";
import "@nomicfoundation/hardhat-foundry";
import "hardhat-abi-exporter";

if (config.error) {
  console.error(config.error);
}

const mockRpc = "http://127.0.0.1:8545";
const mockPk = "0xa319d638222ac86847f8f9c228ff411b3e1b68d2dc301e2ba237778475cc25e1";

const deployerAccounts = [config?.parsed?.PRIVATE_KEY || mockPk];

export default {
  solidity: {
    version: "0.8.28",
    settings: {
      optimizer: { enabled: true, runs: 100000000 },
      evmVersion: "prague",
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
    only: ["Vault", "MockERC20", "Forwarder", "ProtocolManager", "Administrator"],
    flat: true,
    spacing: 2,
    format: "json",
  },
  networks: {
    hardhat: {},
    localhost: {
      url: "http://127.0.0.1:8545",
      params: {
        admin: config?.parsed?.TESTNET_ADMIN_ADDRESS,
        maintainer: config?.parsed?.TESTNET_MAINTAINER_ADDRESS,
        treasureManager: config?.parsed?.TESTNET_TREASURE_MANAGER_ADDRESS,
        securityCouncil: config?.parsed?.TESTNET_SECURITY_COUNCIL_ADDRESS,
      },
    },
    baseSepolia: {
      url: config?.parsed?.BASE_SEPOLIA_RPC ?? mockRpc,
      accounts: deployerAccounts,
      params: {
        admin: config?.parsed?.TESTNET_ADMIN_ADDRESS,
        maintainer: config?.parsed?.TESTNET_MAINTAINER_ADDRESS,
        treasureManager: config?.parsed?.TESTNET_TREASURE_MANAGER_ADDRESS,
        securityCouncil: config?.parsed?.TESTNET_SECURITY_COUNCIL_ADDRESS,
      },
    },
    base: {
      url: config?.parsed?.BASE_RPC ?? mockRpc,
      accounts: deployerAccounts,
      params: {
        admin: config?.parsed?.ADMIN_ADDRESS,
        maintainer: config?.parsed?.MAINTAINER_ADDRESS,
        treasureManager: config?.parsed?.TREASURE_MANAGER_ADDRESS,
        securityCouncil: config?.parsed?.SECURITY_COUNCIL_ADDRESS,
      },
    },
  },
  etherscan: {
    apiKey: config?.parsed?.ETHERSCAN_API_KEY,
  },
};
