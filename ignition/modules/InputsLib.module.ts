import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

export default buildModule("InputsLib", (m) => {
  const inputsLib = m.contract("InputsLib", []);

  return {
    inputsLib,
  };
});
