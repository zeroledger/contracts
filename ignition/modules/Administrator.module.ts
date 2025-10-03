import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

export default buildModule("Administrator", (m) => {
  const admin = m.getParameter("admin");
  const maintainer = m.getParameter("maintainer");
  const treasureManager = m.getParameter("treasureManager");
  const securityCouncil = m.getParameter("securityCouncil");
  const defaultUpgradeDelay = m.getParameter("defaultUpgradeDelay");
  const administrator = m.contract(
    "Administrator",
    [admin, maintainer, securityCouncil, treasureManager, defaultUpgradeDelay],
    { id: `Administrator_${process.env.VERSION_TAG ?? 0}` },
  );

  return {
    administrator,
  };
});
