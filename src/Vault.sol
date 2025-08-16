// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import {IERC20} from "node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuard} from "node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {
  DepositVerifier,
  Spend11Verifier,
  Spend12Verifier,
  Spend13Verifier,
  Spend21Verifier,
  Spend22Verifier,
  Spend23Verifier,
  Spend31Verifier,
  Spend32Verifier,
  Spend161Verifier
} from "./Verifiers.sol";
import {PoseidonT3} from "node_modules/poseidon-solidity/PoseidonT3.sol";

import {
  Commitment,
  DepositCommitmentParams,
  DepositParams,
  OutputsOwners,
  Transaction,
  WithdrawItem
} from "./Vault.types.sol";
import {InputsLib} from "./Inputs.lib.sol";

import {ERC2771Context} from "node_modules/@openzeppelin/contracts/metatx/ERC2771Context.sol";
import {ERC2771Forwarder} from "node_modules/@openzeppelin/contracts/metatx/ERC2771Forwarder.sol";

/**
 * @title Vault
 * @dev A contract that manages ERC20 tokens with commitments and ZK proofs for deposits, withdrawals, and spending
 */
contract Vault is ReentrancyGuard, ERC2771Context {
  // Mapping to track if a commitment hash has been deposited
  mapping(address => mapping(uint256 => Commitment)) public commitmentsMap;

  // DepositVerifier contract for ZK proof validation
  DepositVerifier public immutable depositVerifier;

  // Spend11Verifier contract for ZK proof validation
  Spend11Verifier public immutable spend11Verifier;

  // Spend12Verifier contract for ZK proof validation
  Spend12Verifier public immutable spend12Verifier;

  // Spend13Verifier contract for ZK proof validation
  Spend13Verifier public immutable spend13Verifier;

  // Spend21Verifier contract for ZK proof validation
  Spend21Verifier public immutable spend21Verifier;

  // Spend22Verifier contract for ZK proof validation
  Spend22Verifier public immutable spend22Verifier;

  // Spend23Verifier contract for ZK proof validation
  Spend23Verifier public immutable spend23Verifier;

  // Spend31Verifier contract for ZK proof validation
  Spend31Verifier public immutable spend31Verifier;

  // Spend32Verifier contract for ZK proof validation
  Spend32Verifier public immutable spend32Verifier;

  // Spend161Verifier contract for ZK proof validation
  Spend161Verifier public immutable spend161Verifier;

  // Events
  event TokenDeposited(address indexed user, address indexed token, uint256 total_deposit_amount, uint256 fee);
  event CommitmentCreated(address indexed owner, address indexed token, uint256 poseidonHash, bytes metadata);
  event CommitmentRemoved(address indexed owner, address indexed token, uint256 poseidonHash);
  event TransactionSpent(
    address indexed owner, address indexed token, uint256[] inputHashes, uint256[] outputHashes, uint256 fee
  );
  event Withdrawal(address indexed user, address indexed token, uint256 total, uint256 fee);

  constructor(
    address _depositVerifier,
    address _spend11Verifier,
    address _spend12Verifier,
    address _spend13Verifier,
    address _spend21Verifier,
    address _spend22Verifier,
    address _spend23Verifier,
    address _spend31Verifier,
    address _spend32Verifier,
    address _spend161Verifier,
    address _trustedForwarder
  ) ERC2771Context(_trustedForwarder) {
    depositVerifier = DepositVerifier(_depositVerifier);
    spend11Verifier = Spend11Verifier(_spend11Verifier);
    spend12Verifier = Spend12Verifier(_spend12Verifier);
    spend13Verifier = Spend13Verifier(_spend13Verifier);
    spend21Verifier = Spend21Verifier(_spend21Verifier);
    spend22Verifier = Spend22Verifier(_spend22Verifier);
    spend23Verifier = Spend23Verifier(_spend23Verifier);
    spend31Verifier = Spend31Verifier(_spend31Verifier);
    spend32Verifier = Spend32Verifier(_spend32Verifier);
    spend161Verifier = Spend161Verifier(_spend161Verifier);
  }

  /**
   * @dev Deposit tokens with commitments and ZK proof validation
   * @param depositParams The deposit parameters
   * @param proof ZK proof bytes
   */
  function deposit(DepositParams calldata depositParams, uint256[24] calldata proof) external nonReentrant {
    address token = depositParams.token;
    uint256 total_deposit_amount = depositParams.total_deposit_amount;
    DepositCommitmentParams[3] calldata depositCommitmentParams = depositParams.depositCommitmentParams;
    uint256 fee = depositParams.fee;
    address feeRecipient = depositParams.feeRecipient;
    require(token != address(0), "Vault: Invalid token address");
    require(total_deposit_amount > 0, "Vault: Amount must be greater than 0");
    // Check that no commitment has been used before
    for (uint256 i = 0; i < 3; i++) {
      require(
        commitmentsMap[token][depositCommitmentParams[i].poseidonHash].owner == address(0),
        "Vault: Commitment already used"
      );
    }

    // Verify ZK proof
    bool isValidProof =
      depositVerifier.verify(proof, InputsLib.depositInputs(depositCommitmentParams, total_deposit_amount));
    require(isValidProof, "Vault: Invalid ZK proof");

    // Assign commitments to addresses before external call
    for (uint256 i = 0; i < depositCommitmentParams.length; i++) {
      commitmentsMap[token][depositCommitmentParams[i].poseidonHash] =
        Commitment({owner: depositCommitmentParams[i].owner, locked: false});
      emit CommitmentCreated(
        depositCommitmentParams[i].owner,
        token,
        depositCommitmentParams[i].poseidonHash,
        depositCommitmentParams[i].metadata
      );
    }

    // Transfer tokens from user to contract (external call)
    IERC20(token).transferFrom(_msgSender(), address(this), total_deposit_amount);
    if (fee > 0) {
      IERC20(token).transferFrom(_msgSender(), feeRecipient, fee);
    }
    emit TokenDeposited(_msgSender(), token, total_deposit_amount, fee);
  }

  /**
   * @dev Validate that all input indexes are owned by the sender
   */
  function _validateInputIndexes(Transaction calldata transaction) internal view {
    for (uint256 i = 0; i < transaction.inputsPoseidonHashes.length; i++) {
      require(
        commitmentsMap[transaction.token][transaction.inputsPoseidonHashes[i]].owner == _msgSender(),
        "Vault: Input commitment not found"
      );
    }
  }

  /**
   * @dev Delete input commitments and emit events
   */
  function _deleteInputCommitments(Transaction calldata transaction) internal {
    for (uint256 i = 0; i < transaction.inputsPoseidonHashes.length; i++) {
      uint256 inputHash = transaction.inputsPoseidonHashes[i];
      address inputOwner = commitmentsMap[transaction.token][inputHash].owner;
      delete commitmentsMap[transaction.token][inputHash];
      emit CommitmentRemoved(inputOwner, transaction.token, inputHash);
    }
  }

  /**
   * @dev Create output commitments using indexes from output witnesses
   */
  function _createOutputCommitments(Transaction calldata transaction) internal {
    for (uint256 i = 0; i < transaction.outputsOwners.length; i++) {
      OutputsOwners memory outputWitness = transaction.outputsOwners[i];
      address outputOwner = outputWitness.owner;

      for (uint256 j = 0; j < outputWitness.indexes.length; j++) {
        uint8 outputIndex = outputWitness.indexes[j];
        uint256 outputHash = transaction.outputsPoseidonHashes[outputIndex];
        commitmentsMap[transaction.token][outputHash] = Commitment({owner: outputOwner, locked: false});
        emit CommitmentCreated(outputOwner, transaction.token, outputHash, transaction.metadata[outputIndex]);
      }
    }
  }

  /**
   * @dev Spend commitments by creating new ones (supports multiple inputs and outputs)
   * @param transaction The transaction data
   * @param proof ZK proof bytes
   */
  function spend(Transaction calldata transaction, uint256[24] calldata proof) external nonReentrant {
    require(transaction.token != address(0), "Vault: Invalid token address");
    require(transaction.inputsPoseidonHashes.length > 0, "Vault: No inputs provided");
    require(transaction.outputsPoseidonHashes.length > 0, "Vault: No outputs provided");

    // Validate indexes using separate methods to reduce stack size
    _validateInputIndexes(transaction);

    // Verify ZK proof based on input/output combination
    bool isValidProof = false;
    if (transaction.inputsPoseidonHashes.length == 1 && transaction.outputsPoseidonHashes.length == 1) {
      isValidProof = spend11Verifier.verify(proof, InputsLib.fillSpend3Inputs(transaction));
    } else if (transaction.inputsPoseidonHashes.length == 1 && transaction.outputsPoseidonHashes.length == 2) {
      isValidProof = spend12Verifier.verify(proof, InputsLib.fillSpend4Inputs(transaction));
    } else if (transaction.inputsPoseidonHashes.length == 1 && transaction.outputsPoseidonHashes.length == 3) {
      isValidProof = spend13Verifier.verify(proof, InputsLib.fillSpend5Inputs(transaction));
    } else if (transaction.inputsPoseidonHashes.length == 2 && transaction.outputsPoseidonHashes.length == 1) {
      isValidProof = spend21Verifier.verify(proof, InputsLib.fillSpend4Inputs(transaction));
    } else if (transaction.inputsPoseidonHashes.length == 2 && transaction.outputsPoseidonHashes.length == 2) {
      isValidProof = spend22Verifier.verify(proof, InputsLib.fillSpend5Inputs(transaction));
    } else if (transaction.inputsPoseidonHashes.length == 2 && transaction.outputsPoseidonHashes.length == 3) {
      isValidProof = spend23Verifier.verify(proof, InputsLib.fillSpend6Inputs(transaction));
    } else if (transaction.inputsPoseidonHashes.length == 3 && transaction.outputsPoseidonHashes.length == 1) {
      isValidProof = spend31Verifier.verify(proof, InputsLib.fillSpend5Inputs(transaction));
    } else if (transaction.inputsPoseidonHashes.length == 3 && transaction.outputsPoseidonHashes.length == 2) {
      isValidProof = spend32Verifier.verify(proof, InputsLib.fillSpend6Inputs(transaction));
    } else if (transaction.inputsPoseidonHashes.length == 16 && transaction.outputsPoseidonHashes.length == 1) {
      isValidProof = spend161Verifier.verify(proof, InputsLib.fillSpend18Inputs(transaction));
    }

    require(isValidProof, "Vault: Invalid ZK proof");

    // Delete all input commitments from storage (saves gas)
    _deleteInputCommitments(transaction);

    // Create new output commitments using the indexes from output witnesses
    _createOutputCommitments(transaction);

    // Transfer fee to fee recipient
    for (uint8 i = 0; i < transaction.publicOutputs.length; i++) {
      if (transaction.publicOutputs[i].amount > 0) {
        IERC20(transaction.token).transfer(transaction.publicOutputs[i].owner, transaction.publicOutputs[i].amount);
      }
    }

    // Emit single transaction event for the atomic operation
    emit TransactionSpent(
      _msgSender(),
      transaction.token,
      transaction.inputsPoseidonHashes,
      transaction.outputsPoseidonHashes,
      InputsLib.computePublicOutputAmount(transaction.publicOutputs)
    );
  }

  /**
   * @dev Removes commitment by providing amount and secret
   * @param token The ERC20 token address
   * @param item The decoded commitment
   */
  function redeemCommitment(address token, WithdrawItem calldata item) private {
    require(token != address(0), "Vault: Invalid token address");
    require(item.amount > 0, "Vault: Amount must be greater than 0");

    // Compute the Poseidon hash on-chain
    uint256 poseidonHash = computePoseidonHash(item.amount, item.sValue);

    // Get the commitment
    Commitment storage commitment = commitmentsMap[token][poseidonHash];
    require(commitment.owner != address(0), "Vault: Commitment not found");
    require(commitment.owner == _msgSender(), "Vault: Only assigned address can withdraw");

    // Delete the commitment from storage (saves gas)
    delete commitmentsMap[token][poseidonHash];

    // Emit withdrawal event
    emit CommitmentRemoved(_msgSender(), token, poseidonHash);
  }

  /**
   * @dev Withdraw multiple commitments in a single transaction
   * @param token The ERC20 token address
   * @param items The withdrawal items
   */
  function withdraw(address token, WithdrawItem[] calldata items, address recipient, uint256 fee, address feeRecipient)
    external
    nonReentrant
  {
    uint256 total = 0;
    for (uint256 i = 0; i < items.length; i++) {
      redeemCommitment(token, items[i]);
      total += items[i].amount;
    }
    // Transfer tokens to the owner
    IERC20(token).transfer(recipient, total - fee);
    if (fee > 0) {
      IERC20(token).transfer(feeRecipient, fee);
    }
    emit Withdrawal(_msgSender(), token, total, fee);
  }

  /**
   * @dev Compute Poseidon hash of amount and sValue on-chain
   * @param amount The amount field element
   * @param sValue The entropy field element
   * @return The computed Poseidon hash
   */
  function computePoseidonHash(uint256 amount, uint256 sValue) public pure returns (uint256) {
    return PoseidonT3.hash([amount, sValue]);
  }

  /**
   * @dev Get commitment details for a given token and poseidon hash
   * @param token The ERC20 token address
   * @param poseidonHash The poseidon hash to look up
   * @return owner The owner of the commitment
   * @return locked Whether the commitment has been locked
   */
  function getCommitment(address token, uint256 poseidonHash) external view returns (address owner, bool locked) {
    Commitment memory commitment = commitmentsMap[token][poseidonHash];
    return (commitment.owner, commitment.locked);
  }
}
