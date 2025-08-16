import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

export default buildModule("ProtocolManager", (m) => {
  const protocolManager = m.contract("ProtocolManager", [], { id: `ProtocolManager_${process.env.VERSION_TAG}` });

  return {
    protocolManager,
  };
});
