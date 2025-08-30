import hre from "hardhat";
import ProxyModule from "../ignition/modules/Proxy.module";

async function main() {
  // const connection = await hre.network.connect();
  const [deployer] = await hre.ethers.getSigners();

  const params = (
    hre.network.config as unknown as {
      params?: {
        admin: string;
        maintainer: string;
        securityCouncil: string;
        defaultPaymaster: string;
      };
    }
  ).params;

  const admin = params?.admin ?? deployer.address;
  const maintainer = params?.maintainer ?? deployer.address;
  const securityCouncil = params?.securityCouncil ?? deployer.address;
  const defaultPaymaster = params?.defaultPaymaster ?? deployer.address;

  console.log(`Deploying with params:
  admin: ${admin}
  maintainer: ${maintainer}
  securityCouncil: ${securityCouncil}
  defaultPaymaster: ${defaultPaymaster}
  `);

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
        admin: admin,
        maintainer: maintainer,
        securityCouncil: securityCouncil,
        defaultPaymaster: defaultPaymaster,
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
