// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import {Transaction, DepositCommitmentParams, PublicOutput} from "./Vault.types.sol";

library InputsLib {
  // poseidon hash of "[0, uint256(keccak256("shared-input"))]"
  uint256 public constant SHARED_INPUT = 15137436504035450233189320721078414488136960400594787218856438198681086299747;

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

  function fillSpend3Inputs(Transaction calldata transaction, uint240 spendFee)
    external
    pure
    returns (uint256[3] memory publicInputs)
  {
    publicInputs[0] = transaction.inputsPoseidonHashes[0];
    publicInputs[1] = transaction.outputsPoseidonHashes[0];
    publicInputs[2] = computePublicOutputAmount(transaction.publicOutputs) + spendFee;
  }

  function fillSpend4Inputs(Transaction calldata transaction, uint240 spendFee)
    external
    pure
    returns (uint256[4] memory publicInputs)
  {
    uint256 totalInputs = transaction.inputsPoseidonHashes.length;
    uint256 totalOutputs = transaction.outputsPoseidonHashes.length;

    for (uint256 i = 0; i < totalInputs; i++) {
      publicInputs[i] = transaction.inputsPoseidonHashes[i];
    }

    for (uint256 i = 0; i < totalOutputs; i++) {
      publicInputs[totalInputs + i] = transaction.outputsPoseidonHashes[i];
    }

    publicInputs[totalInputs + totalOutputs] = computePublicOutputAmount(transaction.publicOutputs) + spendFee;
  }

  function fillSpend5Inputs(Transaction calldata transaction, uint240 spendFee)
    external
    pure
    returns (uint256[5] memory publicInputs)
  {
    uint256 totalInputs = transaction.inputsPoseidonHashes.length;
    uint256 totalOutputs = transaction.outputsPoseidonHashes.length;

    for (uint256 i = 0; i < totalInputs; i++) {
      publicInputs[i] = transaction.inputsPoseidonHashes[i];
    }

    for (uint256 i = 0; i < totalOutputs; i++) {
      publicInputs[totalInputs + i] = transaction.outputsPoseidonHashes[i];
    }

    publicInputs[totalInputs + totalOutputs] = computePublicOutputAmount(transaction.publicOutputs) + spendFee;
  }

  function fillSpend6Inputs(Transaction calldata transaction, uint240 spendFee)
    external
    pure
    returns (uint256[6] memory publicInputs)
  {
    uint256 totalInputs = transaction.inputsPoseidonHashes.length;
    uint256 totalOutputs = transaction.outputsPoseidonHashes.length;

    for (uint256 i = 0; i < totalInputs; i++) {
      publicInputs[i] = transaction.inputsPoseidonHashes[i];
    }

    for (uint256 i = 0; i < totalOutputs; i++) {
      publicInputs[totalInputs + i] = transaction.outputsPoseidonHashes[i];
    }

    publicInputs[totalInputs + totalOutputs] = computePublicOutputAmount(transaction.publicOutputs) + spendFee;
  }

  function fillSpend18Inputs(Transaction calldata transaction, uint240 spendFee)
    external
    pure
    returns (uint256[18] memory publicInputs)
  {
    uint256 totalInputs = transaction.inputsPoseidonHashes.length;
    uint256 totalOutputs = transaction.outputsPoseidonHashes.length;

    for (uint256 i = 0; i < totalInputs; i++) {
      publicInputs[i] = transaction.inputsPoseidonHashes[i];
    }

    for (uint256 i = 0; i < totalOutputs; i++) {
      publicInputs[totalInputs + i] = transaction.outputsPoseidonHashes[i];
    }

    publicInputs[totalInputs + totalOutputs] = computePublicOutputAmount(transaction.publicOutputs) + spendFee;
  }

  function fillSpend7Inputs(Transaction calldata transaction, uint240 spendFee)
    external
    pure
    returns (uint256[7] memory publicInputs)
  {
    uint256 totalInputs = transaction.inputsPoseidonHashes.length;
    uint256 totalOutputs = transaction.outputsPoseidonHashes.length;

    for (uint256 i = 0; i < totalInputs; i++) {
      publicInputs[i] = transaction.inputsPoseidonHashes[i];
    }

    for (uint256 i = 0; i < totalOutputs; i++) {
      publicInputs[totalInputs + i] = transaction.outputsPoseidonHashes[i];
    }

    publicInputs[totalInputs + totalOutputs] = computePublicOutputAmount(transaction.publicOutputs) + spendFee;
  }

  function fillSpend10Inputs(Transaction calldata transaction, uint240 spendFee)
    external
    pure
    returns (uint256[10] memory publicInputs)
  {
    uint256 totalInputs = transaction.inputsPoseidonHashes.length;
    uint256 totalOutputs = transaction.outputsPoseidonHashes.length;

    for (uint256 i = 0; i < totalInputs; i++) {
      publicInputs[i] = transaction.inputsPoseidonHashes[i];
    }

    for (uint256 i = 0; i < totalOutputs; i++) {
      publicInputs[totalInputs + i] = transaction.outputsPoseidonHashes[i];
    }

    publicInputs[totalInputs + totalOutputs] = computePublicOutputAmount(transaction.publicOutputs) + spendFee;
  }

  function depositInputs(DepositCommitmentParams[3] calldata depositCommitmentParams, uint256 amount)
    external
    pure
    returns (uint256[4] memory publicInputs)
  {
    publicInputs[0] = depositCommitmentParams[0].poseidonHash;
    publicInputs[1] = depositCommitmentParams[1].poseidonHash;
    publicInputs[2] = depositCommitmentParams[2].poseidonHash;
    publicInputs[3] = amount;
  }
}
