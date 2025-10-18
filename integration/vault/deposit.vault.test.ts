import { expect } from "chai";
import { ethers } from "hardhat";
import { loadFixture } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { DepositParamsStruct } from "../../typechain-types/src/Vault";
import {
  DepositTestData,
  deployVaultFixture,
  generateCommitmentData,
  generateDepositProof,
  createDepositParams,
  approveTokens,
  getBalances,
  verifyCommitments,
  verifyDepositBalances,
  verifyDepositEvents,
  deposit,
  getFees,
} from "./vault.test.utils";

describe("Vault Deposit Tests", function () {
  describe("Successful Deposits", function () {
    it("should successfully deposit tokens with valid ZK proof", async function () {
      const { vault, mockToken, user, protocolManager, otherUser, forwarderFeeRecipient } =
        await loadFixture(deployVaultFixture);

      const initialBalances = await getBalances(
        user,
        protocolManager,
        vault,
        mockToken,
        otherUser,
        forwarderFeeRecipient,
      );

      const { testData, receipt, commitmentData, depositFee } = await deposit(
        user,
        vault,
        protocolManager,
        mockToken,
        [ethers.parseEther("30"), ethers.parseEther("40"), ethers.parseEther("60")],
        ethers.parseEther("1"),
        forwarderFeeRecipient,
      );

      // Assert
      const finalBalances = await getBalances(
        user,
        protocolManager,
        vault,
        mockToken,
        otherUser,
        forwarderFeeRecipient,
      );
      verifyDepositBalances(initialBalances, finalBalances, testData, depositFee);
      await verifyCommitments(commitmentData.hashes, testData.user.address, vault, mockToken);
      verifyDepositEvents(receipt);
    });
  });

  describe("Failure Cases", function () {
    it("should fail when trying to reuse a commitment", async function () {
      const { vault, mockToken, user, protocolManager, forwarderFeeRecipient } = await loadFixture(deployVaultFixture);

      const { testData, depositParams, proofData } = await deposit(
        user,
        vault,
        protocolManager,
        mockToken,
        [ethers.parseEther("10"), ethers.parseEther("0"), ethers.parseEther("40")],
        10n,
        forwarderFeeRecipient,
      );

      // Second deposit with same commitments should fail
      await expect(vault.connect(testData.user).deposit(depositParams, proofData.calldata_proof)).to.be.revertedWith(
        "Vault: Commitment already used",
      );
    });

    it("should fail with invalid ZK proof", async function () {
      const { vault, mockToken, user, protocolManager, forwarderFeeRecipient } = await loadFixture(deployVaultFixture);

      // Arrange
      const testData: DepositTestData = {
        depositAmount: ethers.parseEther("50"),
        individualAmounts: [ethers.parseEther("10"), ethers.parseEther("0"), ethers.parseEther("40")],
        user,
        forwarderFee: 10n,
        forwarderFeeRecipient,
      };

      const commitmentData = await generateCommitmentData(testData.individualAmounts, testData.user.address);

      const proofData = await generateDepositProof(
        commitmentData.hashes,
        testData.depositAmount.toString(),
        commitmentData.amounts,
        commitmentData.sValues,
      );

      // Create deposit params with mismatched amount
      const depositParams: DepositParamsStruct = {
        token: await mockToken.getAddress(),
        amount: testData.depositAmount - 10n,
        depositCommitmentParams: commitmentData.depositCommitmentParams,
        forwarderFee: 10n,
        forwarderFeeRecipient,
      };

      const totalAmount = testData.depositAmount + (await getFees(protocolManager, mockToken)).deposit;
      await approveTokens(testData.user, totalAmount, vault, mockToken);

      // Act & Assert
      await expect(vault.connect(testData.user).deposit(depositParams, proofData.calldata_proof)).to.be.revertedWith(
        "Vault: Invalid ZK proof",
      );
    });

    it("should fail with zero amount", async function () {
      const { vault, mockToken, user, protocolManager, forwarderFeeRecipient } = await loadFixture(deployVaultFixture);

      // Arrange
      const testData: DepositTestData = {
        depositAmount: 0n,
        individualAmounts: [ethers.parseEther("10"), ethers.parseEther("20"), ethers.parseEther("30")],
        user,
        forwarderFee: 10n,
        forwarderFeeRecipient,
      };

      const commitmentData = await generateCommitmentData(testData.individualAmounts, testData.user.address);

      const proofData = await generateDepositProof(
        commitmentData.hashes,
        (testData.individualAmounts[0] + testData.individualAmounts[1] + testData.individualAmounts[2]).toString(),
        commitmentData.amounts,
        commitmentData.sValues,
      );

      const depositParams = await createDepositParams(testData, commitmentData, mockToken);
      const totalAmount = testData.depositAmount + (await getFees(protocolManager, mockToken)).deposit;

      await approveTokens(testData.user, totalAmount, vault, mockToken);

      // Act & Assert
      await expect(vault.connect(testData.user).deposit(depositParams, proofData.calldata_proof)).to.be.revertedWith(
        "Vault: Amount must be greater than 0",
      );
    });
  });

  describe("Sponsored Deposits via Forwarder", function () {
    it("should allow a sponsor to execute a deposit for another user via ERC2771Forwarder", async function () {
      const { vault, mockToken, user, protocolManager, owner, forwarder, otherUser, forwarderFeeRecipient } =
        await loadFixture(deployVaultFixture);
      // user = user B (depositor), owner = user A (sponsor)

      // Prepare deposit data
      const depositFee = (await getFees(protocolManager, mockToken)).deposit;
      const forwarderFee = ethers.parseEther("5");
      const depositAmount = ethers.parseEther("50");
      const individualAmounts = [ethers.parseEther("10"), ethers.parseEther("0"), ethers.parseEther("40")];
      const totalAmount = depositAmount + depositFee + forwarderFee;

      // User B approves Vault for tokens directly (not via meta-tx)
      await mockToken.connect(user).approve(await vault.getAddress(), totalAmount);

      // User B deposit calldata (meta-tx)
      const commitmentData = await generateCommitmentData(individualAmounts, user.address);
      const proofData = await generateDepositProof(
        commitmentData.hashes,
        depositAmount.toString(),
        commitmentData.amounts,
        commitmentData.sValues,
      );

      const depositTestData: DepositTestData = {
        depositAmount,
        individualAmounts,
        user,
        forwarderFee,
        forwarderFeeRecipient,
      };
      const depositParams = await createDepositParams(depositTestData, commitmentData, mockToken);
      const depositCalldata = vault.interface.encodeFunctionData("deposit", [depositParams, proofData.calldata_proof]);

      // Prepare ForwardRequestData for deposit only
      const provider = (vault.runner?.provider ?? ethers.provider) as any;
      const chainId = await provider.getNetwork().then((n: { chainId: number }) => n.chainId);
      const forwarderDomain = {
        name: "ZeroLedgerForwarder",
        version: "1",
        chainId,
        verifyingContract: await forwarder.getAddress(),
      };
      const forwardRequestType = {
        ForwardRequest: [
          { name: "from", type: "address" },
          { name: "to", type: "address" },
          { name: "value", type: "uint256" },
          { name: "gas", type: "uint256" },
          { name: "nonce", type: "uint256" },
          { name: "deadline", type: "uint48" },
          { name: "data", type: "bytes" },
        ],
      };
      // Get nonce
      const depositNonce = await forwarder.nonces(user.address);
      // Deadline
      const deadline = Math.floor(Date.now() / 1000) + 3600; // 1 hour from now
      // Build request
      const depositRequest = {
        from: user.address,
        to: await vault.getAddress(),
        value: 0,
        gas: 3_000_000,
        nonce: depositNonce,
        deadline,
        data: depositCalldata,
      };
      // User B signs the request
      const depositSig = await user.signTypedData(forwarderDomain, forwardRequestType, depositRequest);
      // Wrap as ForwardRequestData (with signature)
      const depositReqData = { ...depositRequest, signature: depositSig };
      // Sponsor executes via forwarder
      const initialBalances = await getBalances(
        user,
        protocolManager,
        vault,
        mockToken,
        otherUser,
        forwarderFeeRecipient,
      );
      await forwarder.connect(owner).executeBatch([depositReqData], ethers.ZeroAddress);
      // Assert
      const finalBalances = await getBalances(
        user,
        protocolManager,
        vault,
        mockToken,
        otherUser,
        forwarderFeeRecipient,
      );
      verifyDepositBalances(initialBalances, finalBalances, depositTestData, depositFee);
      await verifyCommitments(commitmentData.hashes, user.address, vault, mockToken);
    });
  });
});
