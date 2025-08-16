import { expect } from "chai";
import { ethers } from "hardhat";
import { randomBytes, ZeroAddress } from "ethers";
import { loadFixture } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import {
  deployVaultFixture,
  getBalances,
  WithdrawTestData,
  createCommitmentForWithdraw,
  verifyWithdrawBalances,
  verifyCommitmentRemoved,
  verifyWithdrawEvents,
  deposit,
} from "./vault.test.utils";

describe("Vault Withdraw Tests", function () {
  describe("Successful Withdrawals", function () {
    it("should successfully withdraw tokens with valid commitment", async function () {
      const { vault, mockToken, user, feeRecipient } = await loadFixture(deployVaultFixture);

      // Arrange
      const testData: WithdrawTestData = {
        amount: ethers.parseEther("50"),
        user,
      };

      // Create a commitment first
      const commitmentData = await createCommitmentForWithdraw(
        testData.amount,
        testData.user,
        vault,
        mockToken,
        feeRecipient,
      );

      const initialBalances = await getBalances(testData.user, feeRecipient, vault, mockToken);

      // Act
      const tx = await vault.connect(testData.user).withdraw(
        await mockToken.getAddress(),
        [
          {
            amount: testData.amount,
            sValue: commitmentData.sValue,
          },
        ],
        testData.user.address,
        0n,
        ZeroAddress,
      );
      const receipt = await tx.wait();

      // Assert
      const finalBalances = await getBalances(testData.user, feeRecipient, vault, mockToken);
      verifyWithdrawBalances(initialBalances, finalBalances, testData);
      await verifyCommitmentRemoved(commitmentData.hash, vault, mockToken);
      verifyWithdrawEvents(receipt);
    });

    it("should successfully withdraw multiple commitments", async function () {
      const { vault, mockToken, user, feeRecipient } = await loadFixture(deployVaultFixture);

      // Arrange - Create multiple commitments
      const amounts = [ethers.parseEther("10"), ethers.parseEther("20"), ethers.parseEther("30")];

      const commitmentData: { hash: string; sValue: string }[] = [];
      for (let i = 0; i < amounts.length; i++) {
        const data = await createCommitmentForWithdraw(amounts[i], user, vault, mockToken, feeRecipient);
        commitmentData.push(data);
      }

      const initialBalances = await getBalances(user, feeRecipient, vault, mockToken);

      // Act - Withdraw all commitments in a single transaction
      const withdrawItems = commitmentData.map((data) => ({
        amount: amounts[commitmentData.indexOf(data)],
        sValue: data.sValue,
      }));

      await vault.connect(user).withdraw(await mockToken.getAddress(), withdrawItems, user.address, 0n, ZeroAddress);

      // Assert
      const finalBalances = await getBalances(user, feeRecipient, vault, mockToken);
      const totalWithdrawn = amounts.reduce((sum, amount) => sum + amount, 0n);

      expect(finalBalances.user).to.equal(initialBalances.user + totalWithdrawn);
      expect(finalBalances.vault).to.equal(initialBalances.vault - totalWithdrawn);

      // Verify all commitments were removed
      for (const data of commitmentData) {
        await verifyCommitmentRemoved(data.hash, vault, mockToken);
      }
    });

    it("should successfully withdraw from a complex deposit", async function () {
      const { vault, mockToken, user, feeRecipient } = await loadFixture(deployVaultFixture);

      const { commitmentData } = await deposit(user, feeRecipient, vault, mockToken, ethers.parseEther("5"), [
        ethers.parseEther("30"),
        ethers.parseEther("40"),
        ethers.parseEther("30"),
      ]);

      // Now withdraw one of the commitments
      const withdrawAmount = ethers.parseEther("30");
      const sValue = commitmentData.sValues[0]; // Use the sValue from the first commitment

      const initialBalances = await getBalances(user, feeRecipient, vault, mockToken);

      // Act
      const tx = await vault
        .connect(user)
        .withdraw(await mockToken.getAddress(), [{ amount: withdrawAmount, sValue }], user.address, 0n, ZeroAddress);
      const receipt = await tx.wait();

      // Assert
      const finalBalances = await getBalances(user, feeRecipient, vault, mockToken);
      expect(finalBalances.user).to.equal(initialBalances.user + withdrawAmount);
      expect(finalBalances.vault).to.equal(initialBalances.vault - withdrawAmount);

      // Verify the withdrawn commitment was removed
      await verifyCommitmentRemoved(commitmentData.hashes[0], vault, mockToken);

      // Verify other commitments still exist
      const commitment1 = await vault.commitmentsMap(await mockToken.getAddress(), commitmentData.hashes[1]);
      const commitment2 = await vault.commitmentsMap(await mockToken.getAddress(), commitmentData.hashes[2]);
      expect(commitment1.owner).to.equal(user.address);
      expect(commitment2.owner).to.equal(user.address);

      verifyWithdrawEvents(receipt);
    });
  });

  describe("Failure Cases", function () {
    it("should fail when withdrawing non-existent commitment", async function () {
      const { vault, mockToken, user } = await loadFixture(deployVaultFixture);

      // Arrange
      const testData: WithdrawTestData = {
        amount: ethers.parseEther("50"),
        user,
      };

      // Act & Assert - Try to withdraw without creating commitment
      await expect(
        vault.connect(testData.user).withdraw(
          await mockToken.getAddress(),
          [
            {
              amount: testData.amount,
              sValue: `0x${Buffer.from(randomBytes(32)).toString("hex")}`,
            },
          ],
          testData.user.address,
          0n,
          ZeroAddress,
        ),
      ).to.be.revertedWith("Vault: Commitment not found");
    });

    it("should fail when withdrawing with wrong amount", async function () {
      const { vault, mockToken, user, feeRecipient } = await loadFixture(deployVaultFixture);

      // Arrange
      const originalAmount = ethers.parseEther("50");
      const wrongAmount = ethers.parseEther("100");

      // Create a commitment first
      const commitmentData = await createCommitmentForWithdraw(originalAmount, user, vault, mockToken, feeRecipient);

      // Act & Assert - Try to withdraw with wrong amount
      await expect(
        vault.connect(user).withdraw(
          await mockToken.getAddress(),
          [
            {
              amount: wrongAmount,
              sValue: commitmentData.sValue,
            },
          ],
          user.address,
          0n,
          ZeroAddress,
        ),
      ).to.be.revertedWith("Vault: Commitment not found");
    });

    it("should fail when withdrawing with wrong sValue", async function () {
      const { vault, mockToken, user, feeRecipient } = await loadFixture(deployVaultFixture);

      // Arrange
      const amount = ethers.parseEther("50");
      const wrongSValue = `0x${Buffer.from(randomBytes(32)).toString("hex")}`;

      // Create a commitment first
      await createCommitmentForWithdraw(amount, user, vault, mockToken, feeRecipient);

      // Act & Assert - Try to withdraw with wrong sValue
      await expect(
        vault
          .connect(user)
          .withdraw(await mockToken.getAddress(), [{ amount, sValue: wrongSValue }], user.address, 0n, ZeroAddress),
      ).to.be.revertedWith("Vault: Commitment not found");
    });

    it("should fail when withdrawing commitment owned by different user", async function () {
      const { vault, mockToken, user, otherUser, feeRecipient } = await loadFixture(deployVaultFixture);

      // Arrange
      const testData: WithdrawTestData = {
        amount: ethers.parseEther("50"),
        user,
      };

      // Create a commitment owned by user
      const commitmentData = await createCommitmentForWithdraw(
        testData.amount,
        testData.user,
        vault,
        mockToken,
        feeRecipient,
      );

      // Act & Assert - Try to withdraw with different user
      await expect(
        vault.connect(otherUser).withdraw(
          await mockToken.getAddress(),
          [
            {
              amount: testData.amount,
              sValue: commitmentData.sValue,
            },
          ],
          testData.user.address,
          0n,
          ZeroAddress,
        ),
      ).to.be.revertedWith("Vault: Only assigned address can withdraw");
    });

    it("should fail when withdrawing already withdrawn commitment", async function () {
      const { vault, mockToken, user, feeRecipient } = await loadFixture(deployVaultFixture);

      // Arrange
      const testData: WithdrawTestData = {
        amount: ethers.parseEther("50"),
        user,
      };

      // Create and withdraw a commitment
      const commitmentData = await createCommitmentForWithdraw(
        testData.amount,
        testData.user,
        vault,
        mockToken,
        feeRecipient,
      );

      await vault.connect(testData.user).withdraw(
        await mockToken.getAddress(),
        [
          {
            amount: testData.amount,
            sValue: commitmentData.sValue,
          },
        ],
        testData.user.address,
        0n,
        ZeroAddress,
      );

      // Act & Assert - Try to withdraw the same commitment again
      await expect(
        vault.connect(testData.user).withdraw(
          await mockToken.getAddress(),
          [
            {
              amount: testData.amount,
              sValue: commitmentData.sValue,
            },
          ],
          testData.user.address,
          0n,
          ZeroAddress,
        ),
      ).to.be.revertedWith("Vault: Commitment not found");
    });

    it("should fail with zero amount", async function () {
      const { vault, mockToken, user } = await loadFixture(deployVaultFixture);

      // Arrange
      const testData: WithdrawTestData = {
        amount: 0n,
        user,
      };

      // Act & Assert
      await expect(
        vault.connect(testData.user).withdraw(
          await mockToken.getAddress(),
          [
            {
              amount: testData.amount,
              sValue: `0x${Buffer.from(randomBytes(32)).toString("hex")}`,
            },
          ],
          testData.user.address,
          0n,
          ZeroAddress,
        ),
      ).to.be.revertedWith("Vault: Amount must be greater than 0");
    });

    it("should fail with invalid token address", async function () {
      const { vault, user } = await loadFixture(deployVaultFixture);

      // Arrange
      const testData: WithdrawTestData = {
        amount: ethers.parseEther("50"),
        user,
      };

      // Act & Assert
      await expect(
        vault.connect(testData.user).withdraw(
          ethers.ZeroAddress,
          [
            {
              amount: testData.amount,
              sValue: `0x${Buffer.from(randomBytes(32)).toString("hex")}`,
            },
          ],
          testData.user.address,
          0n,
          ZeroAddress,
        ),
      ).to.be.revertedWith("Vault: Invalid token address");
    });
  });
});
