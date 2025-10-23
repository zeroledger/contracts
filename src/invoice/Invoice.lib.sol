// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import {DepositCommitmentParams} from "src/Vault.types.sol";

library InvoiceLib {
  /**
   * @dev Helper function to compute the paramsHash for invoice parameters.
   * @param vault The address of the Vault contract
   * @param token The address of the token
   * @param amount The amount of tokens
   * @param executionFee The execution fee
   * @param commitmentParams DepositCommitmentParams tuple
   * @param executor The priority executor address
   * @return paramsHash
   */
  function computeParamsHash(
    address vault,
    address token,
    uint240 amount,
    uint240 executionFee,
    DepositCommitmentParams[3] calldata commitmentParams,
    address executor
  ) internal pure returns (bytes32) {
    return keccak256(abi.encode(vault, token, amount, executionFee, commitmentParams, executor));
  }
}
