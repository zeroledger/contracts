import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

export default buildModule("Verifiers", (m) => {
  // Deploy individual verifiers first
  const depositVerifier = m.contract("DepositVerifier");
  const spend11Verifier = m.contract("Spend11Verifier");
  const spend12Verifier = m.contract("Spend12Verifier");
  const spend13Verifier = m.contract("Spend13Verifier");
  const spend21Verifier = m.contract("Spend21Verifier");
  const spend22Verifier = m.contract("Spend22Verifier");
  const spend23Verifier = m.contract("Spend23Verifier");
  const spend31Verifier = m.contract("Spend31Verifier");
  const spend32Verifier = m.contract("Spend32Verifier");
  const spend33Verifier = m.contract("Spend33Verifier");
  const spend81Verifier = m.contract("Spend81Verifier");
  const spend161Verifier = m.contract("Spend161Verifier");

  // Deploy Verifiers contract with the deployed verifier addresses
  const verifiers = m.contract("Verifiers", [
    depositVerifier,
    spend11Verifier,
    spend12Verifier,
    spend13Verifier,
    spend21Verifier,
    spend22Verifier,
    spend23Verifier,
    spend31Verifier,
    spend32Verifier,
    spend33Verifier,
    spend81Verifier,
    spend161Verifier,
  ]);

  return {
    verifiers,
  };
});
