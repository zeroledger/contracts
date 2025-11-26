import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

export default buildModule("MockERC20", (m) => {
  const mockERC20 = m.contract("MockERC20", ["MockUSDZ", "USDZ0"]);

  return {
    mockERC20,
  };
});
