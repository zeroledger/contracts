import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import MockERC20Module from "./MockERC20.module";
import PoseidonT3Module from "./PoseidonT3.module";
import InputsLibModule from "./InputsLib.module";
import VerifiersModule from "./Verifiers.module";
import VaultModule from "./Vault.module";
import ForwarderModule from "./Forwarder.module";
import ManagerModule from "./Manager.module";

export default buildModule("Proxy", (m) => {
  const admin = m.getParameter("admin");
  const maintainer = m.getParameter("maintainer");
  const securityCouncil = m.getParameter("securityCouncil");

  const { mockERC20 } = m.useModule(MockERC20Module);
  const { inputsLib } = m.useModule(InputsLibModule);
  const { poseidonT3 } = m.useModule(PoseidonT3Module);

  const { verifiers } = m.useModule(VerifiersModule);

  const { vault: vaultImplementation } = m.useModule(VaultModule);
  const { forwarder: forwarderImplementation } = m.useModule(ForwarderModule);
  const { manager: managerImplementation } = m.useModule(ManagerModule);

  const forwarderProxy = m.contract("ERC1967Proxy", [forwarderImplementation, "0x"], { id: "ForwarderProxy" });
  const managerProxy = m.contract("ERC1967Proxy", [managerImplementation, "0x"], { id: "ManagerProxy" });
  const vaultProxy = m.contract("ERC1967Proxy", [vaultImplementation, "0x"], { id: "VaultProxy" });

  const forwarder = m.contractAt("Forwarder", forwarderProxy);
  const manager = m.contractAt("Manager", managerProxy);
  const vault = m.contractAt("Vault", vaultProxy);

  m.call(forwarder, "initialize(address,address,address)", [manager, admin, maintainer]);
  m.call(vault, "initialize", [verifiers, forwarder, manager, admin, maintainer, securityCouncil]);
  m.call(manager, "initialize", [m.getParameter("defaultPaymaster"), admin, maintainer, securityCouncil]);

  return {
    mockERC20,
    inputsLib,
    poseidonT3,
    verifiers,
    vaultImplementation,
    forwarderImplementation,
    managerImplementation,
    vault,
    forwarder,
    manager,
  };
});
