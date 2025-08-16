import { expect } from "chai";
import { ethers } from "hardhat";
import { loadFixture } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import {
  SpendTestData,
  deployVaultFixture,
  generateSpendCommitmentData,
  generateSpendProof,
  getBalances,
  verifySpendEvents,
  verifyInputCommitmentsRemoved,
  verifyOutputCommitmentsCreated,
  deposit,
  createSpendTransaction,
} from "./vault.test.utils";

describe("Vault Spend12 Tests", function () {
  describe("Successful Spends", function () {
    it("should successfully spend 1 input into 2 outputs with valid ZK proof", async function () {
      const { vault, mockToken, user, feeRecipient } = await loadFixture(deployVaultFixture);

      // Arrange
      const testData: SpendTestData = {
        inputAmounts: [ethers.parseEther("100")],
        outputAmounts: [ethers.parseEther("60"), ethers.parseEther("35")],
        publicOutputs: [
          {
            owner: feeRecipient.address,
            amount: ethers.parseEther("5"),
          },
        ],
        user,
      };

      const { commitmentData: depositCommitmentData } = await deposit(
        testData.user,
        feeRecipient,
        vault,
        mockToken,
        testData.publicOutputs[0].amount,
        [testData.inputAmounts[0], 0n, 0n],
      );

      // Generate output commitment data
      const commitmentData = await generateSpendCommitmentData(depositCommitmentData, testData.outputAmounts);

      // Generate ZK proof using actual input hash and output hashes
      const { calldata_proof } = await generateSpendProof(
        commitmentData.inputHashes,
        commitmentData.outputHashes,
        testData.publicOutputs[0].amount.toString(),
        commitmentData.inputAmounts,
        commitmentData.inputSValues,
        commitmentData.outputAmounts,
        commitmentData.outputSValues,
        "spend_12",
      );

      // Create transaction parameters
      const transaction = await createSpendTransaction(
        testData,
        commitmentData.inputHashes,
        commitmentData.outputHashes,
        mockToken,
      );

      const initialBalances = await getBalances(testData.user, feeRecipient, vault, mockToken);

      // Act
      const tx = await vault.connect(testData.user).spend(transaction, calldata_proof);

      const receipt = await tx.wait();

      // Assert
      const finalBalances = await getBalances(testData.user, feeRecipient, vault, mockToken);

      // Balances should change due to public output transfer from vault to fee recipient
      expect(finalBalances.user).to.equal(initialBalances.user);
      expect(finalBalances.vault).to.equal(initialBalances.vault - testData.publicOutputs[0].amount);
      expect(finalBalances.feeRecipient).to.equal(initialBalances.feeRecipient + testData.publicOutputs[0].amount);

      // Verify input commitment was removed
      await verifyInputCommitmentsRemoved(commitmentData.inputHashes, vault, mockToken);

      // Verify output commitments were created
      await verifyOutputCommitmentsCreated(commitmentData.outputHashes, testData.user.address, vault, mockToken);

      // Verify events
      verifySpendEvents(receipt, commitmentData.inputHashes, commitmentData.outputHashes);
    });
  });
});
