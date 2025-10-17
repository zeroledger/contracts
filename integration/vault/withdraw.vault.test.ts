import { expect } from "chai";
import { ethers } from "hardhat";
import { randomBytes } from "ethers";
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
  getFees,
} from "./vault.test.utils";

describe("Vault Withdraw Tests", function () {
  describe("Successful Withdrawals", function () {
    it("should successfully withdraw tokens with valid commitment", async function () {
      const { vault, mockToken, user, protocolManager, otherUser, forwarderFeeRecipient } =
        await loadFixture(deployVaultFixture);

      // Arrange
      const testData: WithdrawTestData = {
        amount: ethers.parseEther("50"),
        user,
        forwarderFee: 0n,
        forwarderFeeRecipient,
      };

      // Create a commitment first
      const commitmentData = await createCommitmentForWithdraw(
        testData.amount,
        testData.user,
        vault,
        mockToken,
        protocolManager,
        0n,
        forwarderFeeRecipient,
      );

      const initialBalances = await getBalances(
        testData.user,
        protocolManager,
        vault,
        mockToken,
        otherUser,
        forwarderFeeRecipient,
      );
      const withdrawFee = (await getFees(protocolManager, mockToken)).withdraw;
      // Act
      const tx = await vault.connect(testData.user).withdraw(
        await mockToken.getAddress(),
        [
          {
            amount: testData.amount,
            sValue: commitmentData.sValue,
          },
        ],
        [
          {
            recipient: testData.user.address,
            amount: testData.amount - withdrawFee,
          },
        ],
      );
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
      verifyWithdrawBalances(initialBalances, finalBalances, testData, withdrawFee);
      await verifyCommitmentRemoved(commitmentData.hash, vault, mockToken);
      verifyWithdrawEvents(receipt);
    });

    it("should successfully withdraw multiple commitments", async function () {
      const { vault, mockToken, user, protocolManager, otherUser, forwarderFeeRecipient } =
        await loadFixture(deployVaultFixture);

      // Arrange - Create multiple commitments
      const amounts = [ethers.parseEther("10"), ethers.parseEther("20"), ethers.parseEther("30")];
      const totalDeposited = amounts.reduce((sum, amount) => sum + amount, 0n);
      const commitmentData: { hash: string; sValue: string }[] = [];
      for (let i = 0; i < amounts.length; i++) {
        const data = await createCommitmentForWithdraw(
          amounts[i],
          user,
          vault,
          mockToken,
          protocolManager,
          0n,
          forwarderFeeRecipient,
        );
        commitmentData.push(data);
      }

      const initialBalances = await getBalances(
        user,
        protocolManager,
        vault,
        mockToken,
        otherUser,
        forwarderFeeRecipient,
      );

      const withdrawFee = (await getFees(protocolManager, mockToken)).withdraw;
      // Act - Withdraw all commitments in a single transaction
      const withdrawItems = commitmentData.map((data) => ({
        amount: amounts[commitmentData.indexOf(data)],
        sValue: data.sValue,
      }));

      await vault.connect(user).withdraw(await mockToken.getAddress(), withdrawItems, [
        {
          recipient: user.address,
          amount: totalDeposited - withdrawFee,
        },
      ]);

      // Assert
      const finalBalances = await getBalances(
        user,
        protocolManager,
        vault,
        mockToken,
        otherUser,
        forwarderFeeRecipient,
      );
      verifyWithdrawBalances(
        initialBalances,
        finalBalances,
        {
          amount: totalDeposited,
          user: user,
          forwarderFee: 0n,
          forwarderFeeRecipient,
        },
        withdrawFee,
      );

      // Verify all commitments were removed
      for (const data of commitmentData) {
        await verifyCommitmentRemoved(data.hash, vault, mockToken);
      }
    });

    it("should successfully withdraw from a complex deposit", async function () {
      const { vault, mockToken, user, protocolManager, otherUser, forwarderFeeRecipient } =
        await loadFixture(deployVaultFixture);

      const { commitmentData } = await deposit(
        user,
        vault,
        protocolManager,
        mockToken,
        [ethers.parseEther("30"), ethers.parseEther("40"), ethers.parseEther("30")],
        0n,
        forwarderFeeRecipient,
      );

      // Now withdraw one of the commitments
      const withdrawAmount = ethers.parseEther("30");
      const sValue = commitmentData.sValues[0]; // Use the sValue from the first commitment

      const initialBalances = await getBalances(
        user,
        protocolManager,
        vault,
        mockToken,
        otherUser,
        forwarderFeeRecipient,
      );

      const withdrawFee = (await getFees(protocolManager, mockToken)).withdraw;

      // Act
      const tx = await vault.connect(user).withdraw(
        await mockToken.getAddress(),
        [{ amount: withdrawAmount, sValue }],
        [
          {
            recipient: user.address,
            amount: withdrawAmount - withdrawFee,
          },
        ],
      );
      const receipt = await tx.wait();

      // Assert
      const finalBalances = await getBalances(
        user,
        protocolManager,
        vault,
        mockToken,
        otherUser,
        forwarderFeeRecipient,
      );
      verifyWithdrawBalances(
        initialBalances,
        finalBalances,
        {
          amount: withdrawAmount,
          user: user,
          forwarderFee: 0n,
          forwarderFeeRecipient,
        },
        withdrawFee,
      );

      // Verify the withdrawn commitment was removed
      await verifyCommitmentRemoved(commitmentData.hashes[0], vault, mockToken);

      // Verify other commitments still exist
      const commitment1Owner = await vault.getCommitment(await mockToken.getAddress(), commitmentData.hashes[1]);
      const commitment2Owner = await vault.getCommitment(await mockToken.getAddress(), commitmentData.hashes[2]);
      expect(commitment1Owner).to.equal(user.address);
      expect(commitment2Owner).to.equal(user.address);

      verifyWithdrawEvents(receipt);
    });
  });

  describe("Failure Cases", function () {
    it("should fail when withdrawing non-existent commitment", async function () {
      const { vault, mockToken, user, protocolManager, forwarderFeeRecipient } = await loadFixture(deployVaultFixture);

      // Arrange
      const testData: WithdrawTestData = {
        amount: ethers.parseEther("50"),
        user,
        forwarderFee: 0n,
        forwarderFeeRecipient,
      };
      const withdrawFee = (await getFees(protocolManager, mockToken)).withdraw;
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
          [
            {
              recipient: testData.user.address,
              amount: testData.amount - withdrawFee,
            },
          ],
        ),
      ).to.be.revertedWith("Vault: Only assigned address can withdraw");
    });

    it("should fail when withdrawing with wrong amount", async function () {
      const { vault, mockToken, user, protocolManager, forwarderFeeRecipient } = await loadFixture(deployVaultFixture);

      // Arrange
      const originalAmount = ethers.parseEther("50");
      const wrongAmount = ethers.parseEther("100");
      const withdrawFee = (await getFees(protocolManager, mockToken)).withdraw;
      // Create a commitment first
      const commitmentData = await createCommitmentForWithdraw(
        originalAmount,
        user,
        vault,
        mockToken,
        protocolManager,
        0n,
        forwarderFeeRecipient,
      );

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
          [
            {
              recipient: user.address,
              amount: wrongAmount - withdrawFee,
            },
          ],
        ),
      ).to.be.revertedWith("Vault: Only assigned address can withdraw");
    });

    it("should fail when withdrawing with wrong sValue", async function () {
      const { vault, mockToken, user, protocolManager, forwarderFeeRecipient } = await loadFixture(deployVaultFixture);

      // Arrange
      const amount = ethers.parseEther("50");
      const wrongSValue = `0x${Buffer.from(randomBytes(32)).toString("hex")}`;
      const withdrawFee = (await getFees(protocolManager, mockToken)).withdraw;
      // Create a commitment first
      await createCommitmentForWithdraw(amount, user, vault, mockToken, protocolManager, 0n, forwarderFeeRecipient);

      // Act & Assert - Try to withdraw with wrong sValue
      await expect(
        vault.connect(user).withdraw(
          await mockToken.getAddress(),
          [{ amount, sValue: wrongSValue }],
          [
            {
              recipient: user.address,
              amount: amount - withdrawFee,
            },
          ],
        ),
      ).to.be.revertedWith("Vault: Only assigned address can withdraw");
    });

    it("should fail when withdrawing commitment owned by different user", async function () {
      const { vault, mockToken, user, otherUser, protocolManager, forwarderFeeRecipient } =
        await loadFixture(deployVaultFixture);

      // Arrange
      const testData: WithdrawTestData = {
        amount: ethers.parseEther("50"),
        user,
        forwarderFee: 0n,
        forwarderFeeRecipient,
      };

      // Create a commitment owned by user
      const commitmentData = await createCommitmentForWithdraw(
        testData.amount,
        testData.user,
        vault,
        mockToken,
        protocolManager,
        0n,
        forwarderFeeRecipient,
      );

      const withdrawFee = (await getFees(protocolManager, mockToken)).withdraw;

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
          [
            {
              recipient: testData.user.address,
              amount: testData.amount - withdrawFee,
            },
          ],
        ),
      ).to.be.revertedWith("Vault: Only assigned address can withdraw");
    });

    it("should fail when withdrawing already withdrawn commitment", async function () {
      const { vault, mockToken, user, protocolManager, forwarderFeeRecipient } = await loadFixture(deployVaultFixture);

      // Arrange
      const testData: WithdrawTestData = {
        amount: ethers.parseEther("50"),
        user,
        forwarderFee: 0n,
        forwarderFeeRecipient,
      };
      const withdrawFee = (await getFees(protocolManager, mockToken)).withdraw;
      // Create and withdraw a commitment
      const commitmentData = await createCommitmentForWithdraw(
        testData.amount,
        testData.user,
        vault,
        mockToken,
        protocolManager,
        0n,
        forwarderFeeRecipient,
      );

      await vault.connect(testData.user).withdraw(
        await mockToken.getAddress(),
        [
          {
            amount: testData.amount,
            sValue: commitmentData.sValue,
          },
        ],
        [
          {
            recipient: testData.user.address,
            amount: testData.amount - withdrawFee,
          },
        ],
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
          [
            {
              recipient: testData.user.address,
              amount: testData.amount - withdrawFee,
            },
          ],
        ),
      ).to.be.revertedWith("Vault: Only assigned address can withdraw");
    });

    it("should fail with zero amount", async function () {
      const { vault, mockToken, user, forwarderFeeRecipient } = await loadFixture(deployVaultFixture);

      // Arrange
      const testData: WithdrawTestData = {
        amount: 0n,
        user,
        forwarderFee: 0n,
        forwarderFeeRecipient,
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
          [
            {
              recipient: testData.user.address,
              amount: testData.amount,
            },
          ],
        ),
      ).to.be.revertedWith("Vault: Amount must be greater than 0");
    });

    it("should fail with invalid token address", async function () {
      const { vault, user, protocolManager, mockToken, forwarderFeeRecipient } = await loadFixture(deployVaultFixture);

      // Arrange
      const testData: WithdrawTestData = {
        amount: ethers.parseEther("50"),
        user,
        forwarderFee: 0n,
        forwarderFeeRecipient,
      };

      const withdrawFee = (await getFees(protocolManager, mockToken)).withdraw;

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
          [
            {
              recipient: testData.user.address,
              amount: testData.amount - withdrawFee,
            },
          ],
        ),
      ).to.be.revertedWith("Vault: Invalid token address");
    });
  });
});
