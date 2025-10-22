// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import {IVault, DepositParams, DepositCommitmentParams} from "./Vault.types.sol";

/**
 * @dev Contract for one-time invoice with priority deadline
 * Using create2 invoice initiator can preview invoice address and ask for payment.
 * Once payment is received, invoice can be deployed and executed.
 * executionFee should cover contract deployment and execution costs.
 */
contract Invoice {
  bytes32 public immutable paramsHash;
  uint256 public immutable priorityDeadline;

  constructor(bytes32 paramsHash_) {
    paramsHash = paramsHash_;
    priorityDeadline = block.timestamp + 1 days;
  }

  /**
   * @dev execute an invoice with priority deadline
   * @param vault The address of the Vault
   * @param token The address of the token
   * @param amount The amount of the token
   * @param executionFee The fee for the execution
   * @param commitmentParams The commitment parameters
   * @param proof The proof for the deposit
   * @param executor The address of the executor
   */
  function createInvoice(
    address vault,
    address token,
    uint240 amount,
    uint240 executionFee,
    DepositCommitmentParams[3] calldata commitmentParams,
    uint256[24] calldata proof,
    address executor
  ) external {
    bytes32 computedParamsHash = keccak256(abi.encode(vault, token, amount, executionFee, commitmentParams, executor));
    require(computedParamsHash == paramsHash, "InvoiceProcessor: Invalid params hash");
    if (block.timestamp < priorityDeadline) {
      IVault(vault).deposit(DepositParams(token, amount, commitmentParams, executionFee, executor), proof);
    } else {
      IVault(vault).deposit(DepositParams(token, amount, commitmentParams, executionFee, msg.sender), proof);
    }
  }
}
