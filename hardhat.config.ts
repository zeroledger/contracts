import dotenv from "dotenv";
const config = dotenv.config();

import "@nomicfoundation/hardhat-toolbox";
import "@openzeppelin/hardhat-upgrades";
import "@nomicfoundation/hardhat-foundry";
import "hardhat-abi-exporter";
import { ZeroHash, getBytes, id, hexlify, concat, Wallet } from "ethers";

if (config.error) {
  console.error(config.error);
}

const deployerAccounts = [config?.parsed?.PRIVATE_KEY || ZeroHash];

const DEFAULT_RPC = "https:random.com";

function mkCreateXSalt() {
  const addr20 = getBytes(new Wallet(deployerAccounts[0]).address); // 20 bytes
  const flag1 = getBytes("0x01"); // 1 byte
  const rnd11 = getBytes(id("zeroledger"));
  const salt = hexlify(concat([addr20, flag1, rnd11])); // 32 bytes hex
  console.log("CreateX salt:", salt);
  return salt;
}

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
  ignition: {
    strategyConfig: {
      create2: {
        salt: mkCreateXSalt(),
      },
    },
  },
  abiExporter: {
    path: "./abi",
    runOnCompile: false,
    clear: true,
    only: ["Vault", "MockERC20", "Forwarder", "ProtocolManager"],
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
        admin: config?.parsed?.TESTNET_ADMIN_ADDRESS,
        treasureManager: config?.parsed?.TESTNET_TREASURE_MANAGER_ADDRESS,
        securityCouncil: config?.parsed?.TESTNET_SECURITY_COUNCIL_ADDRESS,
      },
    },
  },
  etherscan: {
    apiKey: {
      baseSepolia: config?.parsed?.BASE_API_KEY,
    },
  },
};
