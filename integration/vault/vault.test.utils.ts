import { expect } from "chai";
import { ethers } from "hardhat";
import { randomBytes } from "ethers";
import { poseidon2 } from "poseidon-lite";
import { exportSolidityCallData, prove } from "../prove.helper";
import {
  DepositParamsStruct,
  DepositCommitmentParamsStruct,
  TransactionStruct,
  OutputsOwnersStruct,
} from "../../typechain-types/src/Vault";
import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";
import { ERC2771Forwarder, MockERC20, DepositVerifier, Vault } from "../../typechain-types";

// Types for better organization
export interface DepositTestData {
  depositAmount: bigint;
  fee: bigint;
  individualAmounts: bigint[];
  user: HardhatEthersSigner;
  feeRecipient: HardhatEthersSigner;
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
  depositVerifier: DepositVerifier;
  owner: HardhatEthersSigner;
  user: HardhatEthersSigner;
  feeRecipient: HardhatEthersSigner;
  otherUser: HardhatEthersSigner;
  baseForwarder: ERC2771Forwarder; // Add baseForwarder for meta-tx tests
}

// Types for withdraw testing
export interface WithdrawTestData {
  amount: bigint;
  user: HardhatEthersSigner;
}

// Types for spend testing
export interface SpendTestData {
  inputAmounts: bigint[];
  outputAmounts: bigint[];
  publicOutputs: { owner: string; amount: bigint }[];
  user: HardhatEthersSigner;
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
  const [owner, user, feeRecipient, otherUser] = await ethers.getSigners();

  // Deploy PoseidonT3 library
  const PoseidonT3Factory = await ethers.getContractFactory("PoseidonT3");
  const poseidonT3 = await PoseidonT3Factory.deploy();
  await poseidonT3.waitForDeployment();

  // Deploy InputsLib library
  const InputsLibFactory = await ethers.getContractFactory("InputsLib");
  const inputsLib = await InputsLibFactory.deploy();
  await inputsLib.waitForDeployment();

  // Deploy DepositVerifier
  const DepositVerifierFactory = await ethers.getContractFactory("DepositVerifier");
  const depositVerifier = await DepositVerifierFactory.deploy();
  await depositVerifier.waitForDeployment();

  // Deploy MockERC20 token
  const MockERC20Factory = await ethers.getContractFactory("MockERC20");
  const mockToken = await MockERC20Factory.deploy("Mock Token", "MTK");
  await mockToken.waitForDeployment();

  // Deploy all spend verifiers
  const Spend11VerifierFactory = await ethers.getContractFactory("Spend11Verifier");
  const spend11Verifier = await Spend11VerifierFactory.deploy();
  await spend11Verifier.waitForDeployment();

  const Spend12VerifierFactory = await ethers.getContractFactory("Spend12Verifier");
  const spend12Verifier = await Spend12VerifierFactory.deploy();
  await spend12Verifier.waitForDeployment();

  const Spend13VerifierFactory = await ethers.getContractFactory("Spend13Verifier");
  const spend13Verifier = await Spend13VerifierFactory.deploy();
  await spend13Verifier.waitForDeployment();

  const Spend21VerifierFactory = await ethers.getContractFactory("Spend21Verifier");
  const spend21Verifier = await Spend21VerifierFactory.deploy();
  await spend21Verifier.waitForDeployment();

  const Spend22VerifierFactory = await ethers.getContractFactory("Spend22Verifier");
  const spend22Verifier = await Spend22VerifierFactory.deploy();
  await spend22Verifier.waitForDeployment();

  const Spend23VerifierFactory = await ethers.getContractFactory("Spend23Verifier");
  const spend23Verifier = await Spend23VerifierFactory.deploy();
  await spend23Verifier.waitForDeployment();

  const Spend31VerifierFactory = await ethers.getContractFactory("Spend31Verifier");
  const spend31Verifier = await Spend31VerifierFactory.deploy();
  await spend31Verifier.waitForDeployment();

  const Spend32VerifierFactory = await ethers.getContractFactory("Spend32Verifier");
  const spend32Verifier = await Spend32VerifierFactory.deploy();
  await spend32Verifier.waitForDeployment();

  const Spend33VerifierFactory = await ethers.getContractFactory("Spend33Verifier");
  const spend33Verifier = await Spend33VerifierFactory.deploy();
  await spend33Verifier.waitForDeployment();

  const Spend81VerifierFactory = await ethers.getContractFactory("Spend81Verifier");
  const spend81Verifier = await Spend81VerifierFactory.deploy();
  await spend81Verifier.waitForDeployment();

  const Spend161VerifierFactory = await ethers.getContractFactory("Spend161Verifier");
  const spend161Verifier = await Spend161VerifierFactory.deploy();
  await spend161Verifier.waitForDeployment();

  const ForwarderFactory = await ethers.getContractFactory("ERC2771Forwarder");
  const baseForwarder = await ForwarderFactory.deploy("BaseForwarder");
  await baseForwarder.waitForDeployment();

  const VerifiersFactory = await ethers.getContractFactory("Verifiers");
  const verifiers = await VerifiersFactory.deploy(
    await depositVerifier.getAddress(),
    await spend11Verifier.getAddress(),
    await spend12Verifier.getAddress(),
    await spend13Verifier.getAddress(),
    await spend21Verifier.getAddress(),
    await spend22Verifier.getAddress(),
    await spend23Verifier.getAddress(),
    await spend31Verifier.getAddress(),
    await spend32Verifier.getAddress(),
    await spend33Verifier.getAddress(),
    await spend81Verifier.getAddress(),
    await spend161Verifier.getAddress(),
  );
  await verifiers.waitForDeployment();

  // Deploy Vault
  const VaultFactory = await ethers.getContractFactory("Vault", {
    libraries: {
      PoseidonT3: await poseidonT3.getAddress(),
      InputsLib: await inputsLib.getAddress(),
    },
  });

  const vault = await VaultFactory.deploy(await verifiers.getAddress(), await baseForwarder.getAddress());
  await vault.waitForDeployment();

  // Mint tokens to users for testing
  const mintAmount = ethers.parseEther("1000");
  await mockToken.mint(user.address, mintAmount);
  await mockToken.mint(otherUser.address, mintAmount);

  return {
    vault,
    mockToken,
    depositVerifier,
    owner,
    user,
    feeRecipient,
    otherUser,
    baseForwarder, // Export the forwarder for meta-tx tests
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
    total_deposit_amount: testData.depositAmount,
    depositCommitmentParams: commitmentData.depositCommitmentParams,
    fee: testData.fee,
    feeRecipient: testData.feeRecipient.address,
  };
}

// Helper function to approve tokens
export async function approveTokens(user: HardhatEthersSigner, amount: bigint, vault: Vault, mockToken: MockERC20) {
  await mockToken.connect(user).approve(await vault.getAddress(), amount);
}

// Helper function to get balances
export async function getBalances(
  user: HardhatEthersSigner,
  feeRecipient: HardhatEthersSigner,
  vault: Vault,
  mockToken: MockERC20,
) {
  return {
    user: await mockToken.balanceOf(user.address),
    vault: await mockToken.balanceOf(await vault.getAddress()),
    feeRecipient: await mockToken.balanceOf(feeRecipient.address),
  };
}

// Helper function to verify balances after deposit
export function verifyDepositBalances(
  initialBalances: { user: bigint; vault: bigint; feeRecipient: bigint },
  finalBalances: { user: bigint; vault: bigint; feeRecipient: bigint },
  testData: DepositTestData,
) {
  const totalAmount = testData.depositAmount + testData.fee;

  expect(finalBalances.user).to.equal(initialBalances.user - totalAmount);
  expect(finalBalances.vault).to.equal(initialBalances.vault + testData.depositAmount);
  expect(finalBalances.feeRecipient).to.equal(initialBalances.feeRecipient + testData.fee);
}

// Helper function to verify commitments were created
export async function verifyCommitments(hashes: string[], userAddress: string, vault: Vault, mockToken: MockERC20) {
  for (let i = 0; i < hashes.length; i++) {
    const commitment = await vault.commitmentsMap(await mockToken.getAddress(), hashes[i]);
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
  feeRecipient: HardhatEthersSigner,
): Promise<{ hash: string; sValue: string }> {
  // Create a simple deposit to establish a commitment
  const { commitmentData } = await deposit(user, feeRecipient, vault, mockToken, 0n, [amount, 0n, 0n]);

  // Return the hash and sValue of the first commitment (the one with the amount)
  return {
    hash: commitmentData.hashes[0],
    sValue: commitmentData.sValues[0],
  };
}

// Helper function to verify balances after withdraw
export function verifyWithdrawBalances(
  initialBalances: { user: bigint; vault: bigint },
  finalBalances: { user: bigint; vault: bigint },
  testData: WithdrawTestData,
) {
  expect(finalBalances.user).to.equal(initialBalances.user + testData.amount);
  expect(finalBalances.vault).to.equal(initialBalances.vault - testData.amount);
}

// Helper function to verify commitment was removed
export async function verifyCommitmentRemoved(hash: string, vault: Vault, mockToken: MockERC20) {
  const commitment = await vault.commitmentsMap(await mockToken.getAddress(), hash);
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
    const commitment = await vault.commitmentsMap(await mockToken.getAddress(), hash);
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
    const commitment = await vault.commitmentsMap(await mockToken.getAddress(), hash);
    expect(commitment.owner).to.equal(userAddress);
    expect(commitment.locked).to.be.false;
  }
}

export async function deposit(
  user: HardhatEthersSigner,
  feeRecipient: HardhatEthersSigner,
  vault: Vault,
  mockToken: MockERC20,
  fee: bigint,
  individualAmounts: bigint[],
) {
  // Arrange
  const testData: DepositTestData = {
    depositAmount: individualAmounts.reduce((a, b) => a + b, 0n),
    fee,
    individualAmounts,
    user,
    feeRecipient,
  };

  const commitmentData = await generateCommitmentData(testData.individualAmounts, testData.user.address);

  const proofData = await generateDepositProof(
    commitmentData.hashes,
    testData.depositAmount.toString(),
    commitmentData.amounts,
    commitmentData.sValues,
  );

  const depositParams = await createDepositParams(testData, commitmentData, mockToken);
  const totalAmount = testData.depositAmount + testData.fee;

  await approveTokens(testData.user, totalAmount, vault, mockToken);

  // Act
  const tx = await vault.connect(testData.user).deposit(depositParams, proofData.calldata_proof);
  const receipt = await tx.wait();

  return { testData, receipt, commitmentData, depositParams, proofData };
}
