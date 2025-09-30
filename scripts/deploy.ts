import hre from "hardhat";
import ProxyModule from "../ignition/modules/Proxy.module";

const trueOrThrow = (condition: boolean, message: string) => {
  if (!condition) {
    throw new Error(message);
  }
};

async function main() {
  const [deployer] = await hre.ethers.getSigners();

  const params = (
    hre.network.config as unknown as {
      params?: {
        admin: string;
        maintainer: string;
        treasureManager: string;
        securityCouncil: string;
      };
    }
  ).params;

  const admin = params?.admin ?? deployer.address;
  const maintainer = params?.maintainer ?? deployer.address;
  const treasureManager = params?.treasureManager ?? deployer.address;
  const securityCouncil = params?.securityCouncil ?? deployer.address;

  console.log(`Deploying with params:
  admin: ${admin}
  maintainer: ${maintainer}
  treasureManager: ${treasureManager}
  securityCouncil: ${securityCouncil}
  `);

  const { mockERC20, inputsLib, poseidonT3, verifiers, vault, forwarder, protocolManager, administrator } =
    await hre.ignition.deploy(ProxyModule, {
      parameters: {
        Administrator: {
          admin: admin,
          maintainer: maintainer,
          treasureManager: treasureManager,
          securityCouncil: securityCouncil,
          defaultUpgradeDelay: 6 * 60 * 60,
        },
      },
    });

  const [
    mockERC20Address,
    inputsLibAddress,
    poseidonT3Address,
    verifiersAddress,
    vaultAddress,
    forwarderAddress,
    protocolManagerAddress,
    administratorAddress,
  ] = await Promise.all([
    mockERC20.getAddress(),
    inputsLib.getAddress(),
    poseidonT3.getAddress(),
    verifiers.getAddress(),
    vault.getAddress(),
    forwarder.getAddress(),
    protocolManager.getAddress(),
    administrator.getAddress(),
  ]);

  console.log(`Contracts deployed. Addresses:
  mockERC20: ${mockERC20Address}
  inputsLib: ${inputsLibAddress}
  poseidonT3: ${poseidonT3Address}
  verifiers: ${verifiersAddress}
  --------------------------
  vault: ${vaultAddress}
  forwarder: ${forwarderAddress}
  protocolManager: ${protocolManagerAddress}
  administrator: ${administratorAddress}
  `);

  console.log(`Checking initialization of contracts...`);

  trueOrThrow(
    await protocolManager.hasRole("0xddb9610f823ee4fc79a9d6f81490c93108f5c8a62aad74abbdf4620bfc3e24cd", admin),
    "Admin role not correctly set",
  );
  trueOrThrow(
    await protocolManager.hasRole(
      "0x3af227978ba13c18dd802878be88b0856d7edba1c796d8d5cf690551b3edf549",
      securityCouncil,
    ),
    "Security council role not correctly set",
  );
  trueOrThrow(
    await protocolManager.hasRole(
      "0x1047eaab78bac649d20efd7e2f6cd82cb12ff7ef3940bbaadce0ef322c16e036",
      treasureManager,
    ),
    "Treasure manager role not correctly set",
  );
  trueOrThrow((await forwarder.getManager()) === protocolManagerAddress, "Forwarder manager role not correctly set");
  trueOrThrow((await vault.getManager()) === protocolManagerAddress, "Vault manager role not correctly set");
  trueOrThrow((await vault.getVerifiers()) === verifiersAddress, "Verifiers role not correctly set");
  trueOrThrow((await vault.getTrustedForwarder()) === forwarderAddress, "Trusted forwarder role not correctly set");

  console.log(`Correct, contracts deployed and initialized correctly!`);
}

main().catch(console.error);
