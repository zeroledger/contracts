import { ethers } from "hardhat";
import MockERC20ABI from "../../abi/MockERC20.json";
import { MockERC20 } from "../../typechain-types";

async function prepareFeesParams() {
  const [deposit, spend, withdraw] = process.env.FEES_CONFIG!.split(";").map(Number);
  const tokenAddress = process.env.TOKEN!;

  const token = new ethers.Contract(tokenAddress, MockERC20ABI, (await ethers.getSigners())[0]) as unknown as MockERC20;

  const decimals: bigint = await token.decimals();
  console.log(`Token decimals: ${decimals}`);

  // convert 0.05 to wei
  const depositFee = BigInt(deposit * 100) * 10n ** (decimals - 2n);
  const spendFee = BigInt(spend * 100) * 10n ** (decimals - 2n);
  const withdrawFee = BigInt(withdraw * 100) * 10n ** (decimals - 2n);

  console.log(`["${depositFee}", "${spendFee}", "${withdrawFee}"]`);
}

// Execute the function
prepareFeesParams().catch((error) => {
  console.error("Error preparing fees params:", error);
  process.exit(1);
});
