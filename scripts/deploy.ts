import hre from "hardhat";
import ProxyModule from "../ignition/modules/Proxy.module";
import { getBytes, id, concat } from "ethers";
import { NetworkConfig } from "hardhat/types";

type Params = {
  admin: string;
  maintainer: string;
  treasureManager: string;
  securityCouncil: string;
};

const trueOrThrow = (condition: boolean, message: string) => {
  if (!condition) {
    throw new Error(message);
  }
};

function mkCreateXSalt(deployer: string) {
  const addr20 = getBytes(deployer); // 20 bytes
  const flag1 = getBytes("0x01"); // 1 byte
  const rnd11 = getBytes(id(process.env.CREATE2_SALT ?? "zeroeldger"));
  const salt = concat([addr20, flag1, rnd11]).slice(0, 66); // 32 bytes hex
  return salt;
}

async function main() {
  const [deployer] = await hre.ethers.getSigners();

  const params = {
    admin: deployer.address,
    maintainer: deployer.address,
    treasureManager: deployer.address,
    securityCouncil: deployer.address,
    ...(
      hre.network.config as NetworkConfig & {
        params?: Params;
      }
    ).params,
  };

  const { admin, maintainer, treasureManager, securityCouncil } = params;

  const salt = mkCreateXSalt(deployer.address);

  console.log(`Deploying with params:
  admin: ${admin}
  maintainer: ${maintainer}
  treasureManager: ${treasureManager}
  securityCouncil: ${securityCouncil}
  salt: ${salt}
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
        Proxy: {
          maxTVL: hre.ethers.parseEther("1000000"),
        },
      },
      strategy: hre.network.name === "hardhat" ? "basic" : "create2",
      strategyConfig: {
        salt,
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

  trueOrThrow(await administrator.hasRole(0, admin), "Admin role not correctly set");
  trueOrThrow(await administrator.hasRole(1, maintainer), "Maintainer role not correctly set");
  trueOrThrow(await administrator.hasRole(2, securityCouncil), "Security council role not correctly set");
  trueOrThrow(await administrator.hasRole(3, treasureManager), "Treasure manager role not correctly set");
  trueOrThrow((await forwarder.authority()) === administratorAddress, "Forwarder administrator is not correctly set");
  trueOrThrow(
    (await protocolManager.authority()) === administratorAddress,
    "ProtocolManager administrator is not correctly set",
  );
  trueOrThrow((await vault.authority()) === administratorAddress, "Vault administrator is not correctly set");
  trueOrThrow((await vault.getManager()) === protocolManagerAddress, "Vault manager is not correctly set");
  trueOrThrow((await vault.getVerifiers()) === verifiersAddress, "Vault Verifiers is not correctly set");
  trueOrThrow((await vault.getTrustedForwarder()) === forwarderAddress, "Vault Trusted forwarder is not correctly set");

  console.log(`Correct, contracts deployed and initialized correctly!`);
}

main().catch(console.error);
