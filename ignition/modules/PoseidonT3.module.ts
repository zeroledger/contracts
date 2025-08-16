import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

export default buildModule("PoseidonT3", (m) => {
  const poseidonT3 = m.contract("PoseidonT3", []);

  return {
    poseidonT3,
  };
});
