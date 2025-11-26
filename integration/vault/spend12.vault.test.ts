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
  getFees,
} from "./vault.test.utils";

describe("Vault Spend12 Tests", function () {
  describe("Successful Spends", function () {
    it("should successfully spend 1 input into 2 outputs with valid ZK proof", async function () {
      const { vault, mockToken, user, protocolManager, otherUser, forwarderFeeRecipient } =
        await loadFixture(deployVaultFixture);

      const inputAmounts = ethers.parseEther("100");

      const { commitmentData: depositCommitmentData } = await deposit(
        user,
        vault,
        protocolManager,
        mockToken,
        [inputAmounts, 0n, 0n],
        0n,
        forwarderFeeRecipient,
      );

      const fees = await getFees(protocolManager, mockToken);

      const outputAmounts = [ethers.parseEther("60"), ethers.parseEther("35") - fees.spend];
      const publicSpend = ethers.parseEther("5");

      // Generate output commitment data
      const commitmentData = await generateSpendCommitmentData(depositCommitmentData, outputAmounts);

      const testData: SpendTestData = {
        inputAmounts: [inputAmounts],
        outputAmounts: outputAmounts,
        publicOutputs: [
          {
            owner: otherUser.address,
            amount: publicSpend,
          },
        ],
        user,
        forwarderFee: 0n,
        forwarderFeeRecipient,
      };

      // Generate ZK proof using actual input hash and output hashes
      const { calldata_proof } = await generateSpendProof(
        commitmentData.inputHashes,
        commitmentData.outputHashes,
        (testData.publicOutputs[0].amount + fees.spend).toString(),
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

      const initialBalances = await getBalances(
        testData.user,
        protocolManager,
        vault,
        mockToken,
        otherUser,
        forwarderFeeRecipient,
      );

      // Act
      const tx = await vault.connect(testData.user).spend(transaction, calldata_proof, false);

      const receipt = await tx.wait();

      // Assert
      const finalBalances = await getBalances(
        testData.user,
        protocolManager,
        vault,
        mockToken,
        otherUser,
        forwarderFeeRecipient,
      );

      // public user balance should not change
      expect(finalBalances.user).to.equal(initialBalances.user);
      // vault balance should decrease by the input amount plus the fee
      expect(finalBalances.vault).to.equal(initialBalances.vault - testData.publicOutputs[0].amount - fees.spend);
      // protocol manager balance should increase by the fee
      expect(finalBalances.protocolManager).to.equal(initialBalances.protocolManager + fees.deposit);
      // other user balance should increase by the public output amount
      expect(finalBalances.otherUser).to.equal(initialBalances.otherUser + testData.publicOutputs[0].amount);

      // Verify input commitment was removed
      await verifyInputCommitmentsRemoved(commitmentData.inputHashes, vault, mockToken);

      // Verify output commitments were created
      await verifyOutputCommitmentsCreated(commitmentData.outputHashes, testData.user.address, vault, mockToken);

      // Verify events
      verifySpendEvents(receipt, commitmentData.inputHashes, commitmentData.outputHashes);
    });
  });
});
