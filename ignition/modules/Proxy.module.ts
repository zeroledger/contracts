import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import MockERC20Module from "./MockERC20.module";
import VerifiersModule from "./Verifiers.module";
import VaultModule from "./Vault.module";
import ForwarderModule from "./Forwarder.module";
import ProtocolManagerModule from "./ProtocolManager.module";
import AdministratorModule from "./Administrator.module";

export default buildModule("Proxy", (m) => {
  const { mockERC20 } = m.useModule(MockERC20Module);
  const { verifiers } = m.useModule(VerifiersModule);
  const { administrator } = m.useModule(AdministratorModule);

  const { vault: vaultImplementation, poseidonT3, inputsLib } = m.useModule(VaultModule);
  const { forwarder: forwarderImplementation } = m.useModule(ForwarderModule);
  const { protocolManager: protocolManagerImplementation } = m.useModule(ProtocolManagerModule);

  const forwarderProxy = m.contract("ERC1967Proxy", [forwarderImplementation, "0x"], { id: "ForwarderProxy" });
  const protocolManagerProxy = m.contract("ERC1967Proxy", [protocolManagerImplementation, "0x"], {
    id: "ProtocolManagerProxy",
  });
  const vaultProxy = m.contract("ERC1967Proxy", [vaultImplementation, "0x"], { id: "VaultProxy" });

  const forwarder = m.contractAt("Forwarder", forwarderProxy);
  const protocolManager = m.contractAt("ProtocolManager", protocolManagerProxy);
  const vault = m.contractAt("Vault", vaultProxy);

  m.call(protocolManager, "initialize", [administrator, [{ token: mockERC20, maxTVL: m.getParameter("maxTVL") }]]);
  m.call(forwarder, "initialize(address)", [administrator]);
  m.call(vault, "initialize", [verifiers, forwarder, protocolManager, administrator]);

  return {
    mockERC20,
    verifiers,
    vaultImplementation,
    forwarderImplementation,
    protocolManagerImplementation,
    vault,
    forwarder,
    protocolManager,
    administrator,
    poseidonT3,
    inputsLib,
  };
});
