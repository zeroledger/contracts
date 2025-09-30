import { expect } from "chai";
import { ethers, ignition } from "hardhat";
import { randomBytes } from "ethers";
import { poseidon2 } from "poseidon-lite";
import { exportSolidityCallData, prove } from "../prove.helper";
import {
  DepositParamsStruct,
  DepositCommitmentParamsStruct,
  TransactionStruct,
  OutputsOwnersStruct,
  Vault,
} from "../../typechain-types/src/Vault.sol/Vault";
import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";
import { Forwarder, Verifiers } from "../../typechain-types/src";
import { ProtocolManager } from "../../typechain-types/src/ProtocolManager";
import { MockERC20 } from "../../typechain-types/src/helpers/MockERC20";
import ProxyModule from "../../ignition/modules/Proxy.module";

// Types for better organization
export interface DepositTestData {
  depositAmount: bigint;
  forwarderFee: bigint;
  forwarderFeeRecipient: string;
  individualAmounts: bigint[];
  user: HardhatEthersSigner;
}

export interface CommitmentData {
  amounts: string[];
  sValues: string[];
  hashes: string[];
  depositCommitmentParams: [
    DepositCommitmentParamsStruct,
    DepositCommitmentParamsStruct,
    DepositCommitmentParamsStruct,
  ];
}

export interface DepositProofData {
  proofInput: {
    hashes: string[];
    totalAmount: string;
    amounts: string[];
    sValues: string[];
  };
  calldata_proof: any;
}

export interface TestFixture {
  vault: Vault;
  mockToken: MockERC20;
  verifiers: Verifiers;
  owner: HardhatEthersSigner;
  user: HardhatEthersSigner;
  otherUser: HardhatEthersSigner;
  forwarder: Forwarder; // Add zeroLedgerForwarder for meta-tx tests
  protocolManager: ProtocolManager;
  forwarderFeeRecipient: string;
}

// Types for withdraw testing
export interface WithdrawTestData {
  amount: bigint;
  user: HardhatEthersSigner;
  forwarderFee: bigint;
  forwarderFeeRecipient: string;
}

// Types for spend testing
export interface SpendTestData {
  inputAmounts: bigint[];
  outputAmounts: bigint[];
  publicOutputs: { owner: string; amount: bigint }[];
  user: HardhatEthersSigner;
  forwarderFee: bigint;
  forwarderFeeRecipient: string;
}

export interface SpendCommitmentData {
  inputHashes: string[];
  inputSValues: string[];
  inputAmounts: string[];
  outputHashes: string[];
  outputSValues: string[];
  outputAmounts: string[];
}

export interface SpendProofData {
  proofInput: {
    inputs_hashes: string[];
    outputs_hashes: string[];
    fee: string; // This represents the public output amount
    input_amounts: string[];
    input_sValues: string[];
    output_amounts: string[];
    output_sValues: string[];
  };
  calldata_proof: any;
}

const mockMetadata = randomBytes(32);

// Reusable helper functions that can be used by other test files
export async function deployVaultFixture(): Promise<TestFixture> {
  const [owner, user, otherUser, forwarderFeeRecipient] = await ethers.getSigners();

  const { verifiers, vault, forwarder, protocolManager } = await ignition.deploy(ProxyModule, {
    parameters: {
      Proxy: {
        admin: owner.address,
        treasureManager: owner.address,
        securityCouncil: owner.address,
      },
    },
  });

  // Deploy MockERC20 token
  const MockERC20Factory = await ethers.getContractFactory("MockERC20");
  const mockToken = await MockERC20Factory.deploy("Mock Token", "MTK");
  await mockToken.waitForDeployment();

  // Mint tokens to users for testing
  const mintAmount = ethers.parseEther("1000");
  await mockToken.mint(user.address, mintAmount);
  await mockToken.mint(otherUser.address, mintAmount);

  await protocolManager.setFees(await mockToken.getAddress(), {
    deposit: ethers.parseEther("5"),
    spend: ethers.parseEther("5"),
    withdraw: ethers.parseEther("5"),
  });

  await protocolManager.setMaxTVL(await mockToken.getAddress(), ethers.parseEther("10000"));

  return {
    vault: vault as unknown as Vault,
    mockToken,
    verifiers: verifiers as unknown as Verifiers,
    owner,
    user,
    otherUser,
    forwarder: forwarder as unknown as Forwarder, // Export the forwarder for meta-tx tests
    protocolManager: protocolManager as unknown as ProtocolManager,
    forwarderFeeRecipient: forwarderFeeRecipient.address,
  };
}

// Helper function to generate commitment data
export async function generateCommitmentData(
  individualAmounts: bigint[],
  userAddress: string,
): Promise<CommitmentData> {
  const amounts: string[] = [];
  const sValues: string[] = [];
  const hashes: string[] = [];

  for (let i = 0; i < 3; i++) {
    amounts.push(individualAmounts[i].toString());
    const sValue = `0x${Buffer.from(randomBytes(32)).toString("hex")}`;
    sValues.push(sValue);

    const hash = await poseidon2([amounts[i], sValue]);
    hashes.push(hash.toString());
  }

  const depositCommitmentParams: [
    DepositCommitmentParamsStruct,
    DepositCommitmentParamsStruct,
    DepositCommitmentParamsStruct,
  ] = [
    {
      poseidonHash: hashes[0],
      owner: userAddress,
      metadata: mockMetadata,
    },
    {
      poseidonHash: hashes[1],
      owner: userAddress,
      metadata: mockMetadata,
    },
    {
      poseidonHash: hashes[2],
      owner: userAddress,
      metadata: mockMetadata,
    },
  ];

  return { amounts, sValues, hashes, depositCommitmentParams };
}

// Helper function to generate ZK proof
export async function generateDepositProof(
  hashes: string[],
  totalAmount: string,
  amounts: string[],
  sValues: string[],
): Promise<DepositProofData> {
  const proofInput = {
    hashes,
    totalAmount,
    amounts,
    sValues,
  };

  const { proof, publicSignals } = await prove(proofInput, "deposit");
  const { calldata_proof } = await exportSolidityCallData(proof, publicSignals);

  return { proofInput, calldata_proof };
}

// Helper function to create deposit parameters
export async function createDepositParams(
  testData: DepositTestData,
  commitmentData: CommitmentData,
  mockToken: MockERC20,
): Promise<DepositParamsStruct> {
  return {
    token: await mockToken.getAddress(),
    amount: testData.depositAmount,
    depositCommitmentParams: commitmentData.depositCommitmentParams,
    forwarderFee: testData.forwarderFee,
    forwarderFeeRecipient: testData.forwarderFeeRecipient,
  };
}

// Helper function to approve tokens
export async function approveTokens(user: HardhatEthersSigner, amount: bigint, vault: Vault, mockToken: MockERC20) {
  await mockToken.connect(user).approve(await vault.getAddress(), amount);
}

// Helper function to get balances
export async function getBalances(
  user: HardhatEthersSigner,
  protocolManager: ProtocolManager,
  vault: Vault,
  mockToken: MockERC20,
  otherUser: HardhatEthersSigner,
  forwarderFeeRecipient: string,
) {
  return {
    user: await mockToken.balanceOf(user.address),
    vault: await mockToken.balanceOf(await vault.getAddress()),
    protocolManager: await mockToken.balanceOf(await protocolManager.getAddress()),
    otherUser: await mockToken.balanceOf(otherUser.address),
    forwarderFeeRecipient: await mockToken.balanceOf(forwarderFeeRecipient),
  };
}

// Helper function to verify balances after deposit
export function verifyDepositBalances(
  initialBalances: { user: bigint; vault: bigint; protocolManager: bigint; forwarderFeeRecipient: bigint },
  finalBalances: { user: bigint; vault: bigint; protocolManager: bigint; forwarderFeeRecipient: bigint },
  testData: DepositTestData,
  depositFee: bigint,
) {
  expect(finalBalances.user).to.equal(
    initialBalances.user - testData.depositAmount - depositFee - testData.forwarderFee,
  );
  expect(finalBalances.vault).to.equal(initialBalances.vault + testData.depositAmount);
  expect(finalBalances.protocolManager).to.equal(initialBalances.protocolManager + depositFee);
  expect(finalBalances.forwarderFeeRecipient).to.equal(initialBalances.forwarderFeeRecipient + testData.forwarderFee);
}

// Helper function to verify commitments were created
export async function verifyCommitments(hashes: string[], userAddress: string, vault: Vault, mockToken: MockERC20) {
  for (let i = 0; i < hashes.length; i++) {
    const commitment = await vault.getCommitment(await mockToken.getAddress(), hashes[i]);
    expect(commitment.owner).to.equal(userAddress);
    expect(commitment.locked).to.be.false;
  }
}

// Helper function to verify events
export function verifyDepositEvents(receipt: any) {
  expect(receipt?.logs).to.have.length.greaterThan(0);

  // Check for TokenDeposited event
  const tokenDepositedEvent = receipt?.logs?.find((log: any) => log.fragment?.name === "TokenDeposited");
  expect(tokenDepositedEvent).to.not.be.undefined;

  // Check for CommitmentCreated events
  const commitmentCreatedEvents = receipt?.logs?.filter((log: any) => log.fragment?.name === "CommitmentCreated");
  expect(commitmentCreatedEvents).to.have.length(3);
}

// Helper function to create a commitment for withdraw testing
export async function createCommitmentForWithdraw(
  amount: bigint,
  user: HardhatEthersSigner,
  vault: Vault,
  mockToken: MockERC20,
  protocolManager: ProtocolManager,
  forwarderFee: bigint,
  forwarderFeeRecipient: string,
): Promise<{ hash: string; sValue: string }> {
  // Create a simple deposit to establish a commitment
  const { commitmentData } = await deposit(
    user,
    vault,
    protocolManager,
    mockToken,
    [amount, 0n, 0n],
    forwarderFee,
    forwarderFeeRecipient,
  );

  // Return the hash and sValue of the first commitment (the one with the amount)
  return {
    hash: commitmentData.hashes[0],
    sValue: commitmentData.sValues[0],
  };
}

// Helper function to verify balances after withdraw
export function verifyWithdrawBalances(
  initialBalances: { user: bigint; vault: bigint; protocolManager: bigint },
  finalBalances: { user: bigint; vault: bigint; protocolManager: bigint },
  testData: WithdrawTestData,
  withdrawFee: bigint,
) {
  expect(finalBalances.user).to.equal(initialBalances.user + testData.amount - withdrawFee);
  expect(finalBalances.vault).to.equal(initialBalances.vault - testData.amount);
  expect(finalBalances.protocolManager).to.equal(initialBalances.protocolManager + withdrawFee);
}

// Helper function to verify commitment was removed
export async function verifyCommitmentRemoved(hash: string, vault: Vault, mockToken: MockERC20) {
  const commitment = await vault.getCommitment(await mockToken.getAddress(), hash);
  expect(commitment.owner).to.equal(ethers.ZeroAddress);
}

// Helper function to verify withdraw events
export function verifyWithdrawEvents(receipt: any) {
  expect(receipt?.logs).to.have.length.greaterThan(0);

  // Check for CommitmentRemoved event
  const commitmentRemovedEvent = receipt?.logs?.find((log: any) => log.fragment?.name === "CommitmentRemoved");
  expect(commitmentRemovedEvent).to.not.be.undefined;
}

// Helper function to generate spend commitment data
export async function generateSpendCommitmentData(
  depositCommitmentData: CommitmentData,
  outputAmounts: bigint[],
): Promise<SpendCommitmentData> {
  const outputHashes: string[] = [];
  const outputSValues: string[] = [];
  const outputAmountsStr: string[] = [];

  // Generate output commitments
  for (let i = 0; i < outputAmounts.length; i++) {
    const sValue = `0x${Buffer.from(randomBytes(32)).toString("hex")}`;
    const amount = outputAmounts[i].toString();
    const hash = (await poseidon2([amount, sValue])).toString();

    outputHashes.push(hash);
    outputSValues.push(sValue);
    outputAmountsStr.push(amount);
  }

  return {
    inputHashes: [depositCommitmentData.hashes[0]],
    inputSValues: [depositCommitmentData.sValues[0]],
    inputAmounts: [depositCommitmentData.amounts[0]],
    outputHashes,
    outputSValues,
    outputAmounts: outputAmountsStr,
  };
}

// Helper function to generate spend ZK proof
export async function generateSpendProof(
  inputHashes: string[],
  outputHashes: string[],
  publicOutputAmount: string,
  inputAmounts: string[],
  inputSValues: string[],
  outputAmounts: string[],
  outputSValues: string[],
  circuitName: string,
): Promise<SpendProofData> {
  const proofInput = {
    inputs_hashes: inputHashes,
    outputs_hashes: outputHashes,
    fee: publicOutputAmount,
    input_amounts: inputAmounts,
    input_sValues: inputSValues,
    output_amounts: outputAmounts,
    output_sValues: outputSValues,
  };

  const { proof, publicSignals } = await prove(proofInput, circuitName);

  const { calldata_proof } = await exportSolidityCallData(proof, publicSignals);

  return { proofInput, calldata_proof };
}

// Helper function to create spend transaction parameters
export async function createSpendTransaction(
  testData: SpendTestData,
  inputHashes: string[],
  outputHashes: string[],
  mockToken: MockERC20,
): Promise<TransactionStruct> {
  // Create OutputsOwners array - each output goes to the user
  const outputsOwners = [
    {
      owner: testData.user.address,
      indexes: outputHashes.map((_, index) => index),
    } as OutputsOwnersStruct,
  ];

  // Convert publicOutputs to the expected format
  const publicOutputs = testData.publicOutputs.map((output) => ({
    owner: output.owner,
    amount: output.amount,
  }));

  return {
    token: await mockToken.getAddress(),
    inputsPoseidonHashes: inputHashes,
    outputsPoseidonHashes: outputHashes,
    outputsOwners,
    publicOutputs,
    metadata: [mockMetadata, mockMetadata, mockMetadata],
  };
}

// Helper function to verify spend events
export function verifySpendEvents(receipt: any, inputHashes: string[], outputHashes: string[]) {
  expect(receipt?.logs).to.have.length.greaterThan(0);

  // Check for TransactionSpent event
  const transactionSpentEvent = receipt?.logs?.find((log: any) => log.fragment?.name === "TransactionSpent");
  expect(transactionSpentEvent).to.not.be.undefined;

  const commitmentRemovedEvents = receipt?.logs?.filter((log: any) => log.fragment?.name === "CommitmentRemoved");
  expect(commitmentRemovedEvents?.length ?? 0).to.equal(inputHashes.length);

  const commitmentCreatedEvents = receipt?.logs?.filter((log: any) => log.fragment?.name === "CommitmentCreated");
  expect(commitmentCreatedEvents?.length ?? 0).to.equal(outputHashes.length);
}

// Helper function to verify input commitments were removed
export async function verifyInputCommitmentsRemoved(inputHashes: string[], vault: Vault, mockToken: MockERC20) {
  for (const hash of inputHashes) {
    const commitment = await vault.getCommitment(await mockToken.getAddress(), hash);
    expect(commitment.owner).to.equal(ethers.ZeroAddress);
  }
}

// Helper function to verify output commitments were created
export async function verifyOutputCommitmentsCreated(
  outputHashes: string[],
  userAddress: string,
  vault: Vault,
  mockToken: MockERC20,
) {
  for (const hash of outputHashes) {
    const commitment = await vault.getCommitment(await mockToken.getAddress(), hash);
    expect(commitment.owner).to.equal(userAddress);
    expect(commitment.locked).to.be.false;
  }
}

export async function getFees(protocolManager: ProtocolManager, mockToken: MockERC20) {
  const [deposit, spend, withdraw] = (await protocolManager.getFees(await mockToken.getAddress())) as [
    bigint,
    bigint,
    bigint,
  ];
  return { deposit, spend, withdraw };
}

export async function deposit(
  user: HardhatEthersSigner,
  vault: Vault,
  protocolManager: ProtocolManager,
  mockToken: MockERC20,
  individualAmounts: bigint[],
  forwarderFee: bigint,
  forwarderFeeRecipient: string,
) {
  const depositFee = (await getFees(protocolManager, mockToken)).deposit;
  // Arrange
  const testData: DepositTestData = {
    depositAmount: individualAmounts.reduce((a, b) => a + b, 0n),
    individualAmounts,
    user,
    forwarderFee,
    forwarderFeeRecipient,
  };

  const commitmentData = await generateCommitmentData(testData.individualAmounts, testData.user.address);

  const proofData = await generateDepositProof(
    commitmentData.hashes,
    testData.depositAmount.toString(),
    commitmentData.amounts,
    commitmentData.sValues,
  );

  const depositParams = await createDepositParams(testData, commitmentData, mockToken);

  await approveTokens(testData.user, testData.depositAmount + depositFee + testData.forwarderFee, vault, mockToken);

  // Act
  const tx = await vault.connect(testData.user).deposit(depositParams, proofData.calldata_proof);
  const receipt = await tx.wait();

  return { testData, receipt, commitmentData, depositParams, proofData, depositFee };
}
