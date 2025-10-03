import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

export default buildModule("Vault", (m) => {
  const poseidonT3 = m.library("PoseidonT3");
  const inputsLib = m.library("InputsLib");
  const vault = m.contract("Vault", [], {
    libraries: {
      PoseidonT3: poseidonT3,
      InputsLib: inputsLib,
    },
    id: `Vault_${process.env.VERSION_TAG ?? 0}`,
  });

  return {
    vault,
  };
});
