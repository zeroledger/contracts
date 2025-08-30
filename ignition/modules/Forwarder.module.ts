import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

export default buildModule("Forwarder", (m) => {
  const forwarder = m.contract("Forwarder", []);

  return {
    forwarder,
  };
});
