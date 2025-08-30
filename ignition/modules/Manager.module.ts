import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

export default buildModule("Manager", (m) => {
  const manager = m.contract("Manager", []);

  return {
    manager,
  };
});
