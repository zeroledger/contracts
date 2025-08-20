import { dynamicAddress } from "@dgma/hardhat-sol-bundler";

const config = {
  MockERC20: {
    args: ["MockERC20", "MCK"],
  },
  ERC2771Forwarder: {
    args: ["ZeroLedgerForwarder"],
  },
  InputsLib: {},
  PoseidonT3: {},
  DepositVerifier: {},
  Spend11Verifier: {},
  Spend12Verifier: {},
  Spend13Verifier: {},
  Spend21Verifier: {},
  Spend22Verifier: {},
  Spend23Verifier: {},
  Spend31Verifier: {},
  Spend32Verifier: {},
  Spend33Verifier: {},
  Spend81Verifier: {},
  Spend161Verifier: {},
  Verifiers: {
    args: [
      dynamicAddress("DepositVerifier"),
      dynamicAddress("Spend11Verifier"),
      dynamicAddress("Spend12Verifier"),
      dynamicAddress("Spend13Verifier"),
      dynamicAddress("Spend21Verifier"),
      dynamicAddress("Spend22Verifier"),
      dynamicAddress("Spend23Verifier"),
      dynamicAddress("Spend31Verifier"),
      dynamicAddress("Spend32Verifier"),
      dynamicAddress("Spend33Verifier"),
      dynamicAddress("Spend81Verifier"),
      dynamicAddress("Spend161Verifier"),
    ],
  },
  Vault: {
    options: {
      libs: {
        PoseidonT3: dynamicAddress("PoseidonT3"),
        InputsLib: dynamicAddress("InputsLib"),
      },
    },
    args: [dynamicAddress("Verifiers"), dynamicAddress("ERC2771Forwarder")],
  },
};

export default {
  hardhat: {
    config: config,
  },
  localhost: { lockFile: "./local.deployment-lock.json", config: config },
  opSepolia: {
    lockFile: "./deployment-lock.json",
    // verify: true,
    // plugins: [VerifyPlugin],
    config: config,
  },
};
