import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import MockERC20Module from "./MockERC20.module";
import PoseidonT3Module from "./PoseidonT3.module";
import InputsLibModule from "./InputsLib.module";
import VerifiersModule from "./Verifiers.module";
import VaultModule from "./Vault.module";
import ForwarderModule from "./Forwarder.module";
import ProtocolManagerModule from "./ProtocolManager.module";

export default buildModule("Proxy", (m) => {
  const admin = m.getParameter("admin");
  const treasureManager = m.getParameter("treasureManager");
  const securityCouncil = m.getParameter("securityCouncil");

  const { mockERC20 } = m.useModule(MockERC20Module);
  const { inputsLib } = m.useModule(InputsLibModule);
  const { poseidonT3 } = m.useModule(PoseidonT3Module);

  const { verifiers } = m.useModule(VerifiersModule);

  const { vault: vaultImplementation } = m.useModule(VaultModule);
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

  m.call(protocolManager, "initialize", [admin, securityCouncil, treasureManager]);
  m.call(forwarder, "initialize(address)", [protocolManager]);
  m.call(vault, "initialize", [verifiers, forwarder, protocolManager]);

  return {
    mockERC20,
    inputsLib,
    poseidonT3,
    verifiers,
    vaultImplementation,
    forwarderImplementation,
    protocolManagerImplementation,
    vault,
    forwarder,
    protocolManager,
  };
});
