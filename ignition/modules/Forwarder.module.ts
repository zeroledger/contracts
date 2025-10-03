import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

export default buildModule("Forwarder", (m) => {
  const forwarder = m.contract("Forwarder", [], { id: `Forwarder_${process.env.VERSION_TAG ?? 0}` });

  return {
    forwarder,
  };
});
