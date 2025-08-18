// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Transaction, DepositCommitmentParams, PublicOutput} from "./Vault.types.sol";

library InputsLib {
  // poseidon hash of "[0, keccak256("ZeroLedgerSharedInput")]"
  uint256 public constant SHARED_INPUT = 16345784317541686154474118656352090725662212393131703302641232392927716723243;

  function computePublicOutputAmount(PublicOutput[] calldata publicOutputs)
    internal
    pure
    returns (uint256 publicOutputAmount)
  {
    for (uint8 i = 0; i < publicOutputs.length; i++) {
      publicOutputAmount += publicOutputs[i].amount;
    }
    return uint256(publicOutputAmount);
  }

  function fillSpend3Inputs(Transaction calldata transaction) external pure returns (uint256[3] memory publicInputs) {
    publicInputs[0] = transaction.inputsPoseidonHashes[0];
    publicInputs[1] = transaction.outputsPoseidonHashes[0];
    publicInputs[2] = computePublicOutputAmount(transaction.publicOutputs);
  }

  function fillSpend4Inputs(Transaction calldata transaction) external pure returns (uint256[4] memory publicInputs) {
    uint256 totalInputs = transaction.inputsPoseidonHashes.length;
    uint256 totalOutputs = transaction.outputsPoseidonHashes.length;

    // Fill input hashes
    for (uint256 i = 0; i < totalInputs; i++) {
      publicInputs[i] = transaction.inputsPoseidonHashes[i];
    }

    // Fill output hashes
    for (uint256 i = 0; i < totalOutputs; i++) {
      publicInputs[totalInputs + i] = transaction.outputsPoseidonHashes[i];
    }

    // Fill fee at the end
    publicInputs[totalInputs + totalOutputs] = computePublicOutputAmount(transaction.publicOutputs);
  }

  function fillSpend5Inputs(Transaction calldata transaction) external pure returns (uint256[5] memory publicInputs) {
    uint256 totalInputs = transaction.inputsPoseidonHashes.length;
    uint256 totalOutputs = transaction.outputsPoseidonHashes.length;

    // Fill input hashes
    for (uint256 i = 0; i < totalInputs; i++) {
      publicInputs[i] = transaction.inputsPoseidonHashes[i];
    }

    // Fill output hashes
    for (uint256 i = 0; i < totalOutputs; i++) {
      publicInputs[totalInputs + i] = transaction.outputsPoseidonHashes[i];
    }

    // Fill fee at the end
    publicInputs[totalInputs + totalOutputs] = computePublicOutputAmount(transaction.publicOutputs);
  }

  function fillSpend6Inputs(Transaction calldata transaction) external pure returns (uint256[6] memory publicInputs) {
    uint256 totalInputs = transaction.inputsPoseidonHashes.length;
    uint256 totalOutputs = transaction.outputsPoseidonHashes.length;

    // Fill input hashes
    for (uint256 i = 0; i < totalInputs; i++) {
      publicInputs[i] = transaction.inputsPoseidonHashes[i];
    }

    // Fill output hashes
    for (uint256 i = 0; i < totalOutputs; i++) {
      publicInputs[totalInputs + i] = transaction.outputsPoseidonHashes[i];
    }

    // Fill fee at the end
    publicInputs[totalInputs + totalOutputs] = computePublicOutputAmount(transaction.publicOutputs);
  }

  function fillSpend18Inputs(Transaction calldata transaction) external pure returns (uint256[18] memory publicInputs) {
    uint256 totalInputs = transaction.inputsPoseidonHashes.length;
    uint256 totalOutputs = transaction.outputsPoseidonHashes.length;

    // Fill input hashes
    for (uint256 i = 0; i < totalInputs; i++) {
      publicInputs[i] = transaction.inputsPoseidonHashes[i];
    }

    // Fill output hashes
    for (uint256 i = 0; i < totalOutputs; i++) {
      publicInputs[totalInputs + i] = transaction.outputsPoseidonHashes[i];
    }

    // Fill fee at the end
    publicInputs[totalInputs + totalOutputs] = computePublicOutputAmount(transaction.publicOutputs);
  }

  function fillSpend7Inputs(Transaction calldata transaction) external pure returns (uint256[7] memory publicInputs) {
    uint256 totalInputs = transaction.inputsPoseidonHashes.length;
    uint256 totalOutputs = transaction.outputsPoseidonHashes.length;

    // Fill input hashes
    for (uint256 i = 0; i < totalInputs; i++) {
      publicInputs[i] = transaction.inputsPoseidonHashes[i];
    }

    // Fill output hashes
    for (uint256 i = 0; i < totalOutputs; i++) {
      publicInputs[totalInputs + i] = transaction.outputsPoseidonHashes[i];
    }

    // Fill fee at the end
    publicInputs[totalInputs + totalOutputs] = computePublicOutputAmount(transaction.publicOutputs);
  }

  function fillSpend10Inputs(Transaction calldata transaction) external pure returns (uint256[10] memory publicInputs) {
    uint256 totalInputs = transaction.inputsPoseidonHashes.length;
    uint256 totalOutputs = transaction.outputsPoseidonHashes.length;

    // Fill input hashes
    for (uint256 i = 0; i < totalInputs; i++) {
      publicInputs[i] = transaction.inputsPoseidonHashes[i];
    }

    // Fill output hashes
    for (uint256 i = 0; i < totalOutputs; i++) {
      publicInputs[totalInputs + i] = transaction.outputsPoseidonHashes[i];
    }

    // Fill fee at the end
    publicInputs[totalInputs + totalOutputs] = computePublicOutputAmount(transaction.publicOutputs);
  }

  function depositInputs(DepositCommitmentParams[3] calldata depositCommitmentParams, uint256 total_deposit_amount)
    external
    pure
    returns (uint256[4] memory publicInputs)
  {
    publicInputs[0] = depositCommitmentParams[0].poseidonHash;
    publicInputs[1] = depositCommitmentParams[1].poseidonHash;
    publicInputs[2] = depositCommitmentParams[2].poseidonHash;
    publicInputs[3] = total_deposit_amount;
  }
}
