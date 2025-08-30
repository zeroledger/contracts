import hre from "hardhat";
import ProxyModule from "../ignition/modules/Proxy.module";

async function main() {
  // const connection = await hre.network.connect();
  const [deployer] = await hre.ethers.getSigners();
  const {
    mockERC20,
    inputsLib,
    poseidonT3,
    verifiers,
    vault,
    forwarder,
    manager,
    vaultImplementation,
    forwarderImplementation,
    managerImplementation,
  } = await hre.ignition.deploy(ProxyModule, {
    parameters: {
      Proxy: {
        admin: deployer.address,
        maintainer: deployer.address,
        securityCouncil: deployer.address,
        defaultPaymaster: deployer.address,
      },
    },
  });

  console.log(`Contracts deployed. Addresses:
  mockERC20: ${await mockERC20.getAddress()}
  inputsLib: ${await inputsLib.getAddress()}
  poseidonT3: ${await poseidonT3.getAddress()}
  verifiers: ${await verifiers.getAddress()}
  --------------------------
  vaultImplementation: ${await vaultImplementation.getAddress()}
  forwarderImplementation: ${await forwarderImplementation.getAddress()}
  managerImplementation: ${await managerImplementation.getAddress()}
  --------------------------
  vault: ${await vault.getAddress()}
  forwarder: ${await forwarder.getAddress()}
  manager: ${await manager.getAddress()}
  `);
}

main().catch(console.error);
