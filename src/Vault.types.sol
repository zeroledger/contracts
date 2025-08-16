// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

// Represents a UTXO commitment: who can spend it and whether it's used
struct Commitment {
  address owner; // authorized spender (via ECDSA)
  bool locked; // true if already locked in conditional spending
}

struct DepositCommitmentParams {
  uint256 poseidonHash;
  address owner;
  bytes metadata;
}

struct DepositParams {
  address token;
  uint240 amount;
  DepositCommitmentParams[3] depositCommitmentParams;
  uint240 forwarderFee;
  address forwarderFeeRecipient;
}

struct OutputsOwners {
  address owner; // owner of new UTXO commitment
  uint8[] indexes; // positions in the outputsPoseidonHashes
}

struct Transaction {
  address token;
  uint256[] inputsPoseidonHashes; // UTXO commitments to consume
  uint256[] outputsPoseidonHashes; // New UTXO commitments to create
  bytes[] metadata; // metadata data for each output
  OutputsOwners[] outputsOwners; // addresses for outputs
  PublicOutput[] publicOutputs; // public outputs
}

struct WithdrawItem {
  uint240 amount;
  uint256 sValue;
}

struct WithdrawRecipient {
  address recipient;
  uint240 amount;
}

struct PublicOutput {
  address owner;
  uint240 amount;
}
