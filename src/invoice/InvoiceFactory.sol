// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {Invoice, InvoiceLib, DepositCommitmentParams} from "./Invoice.sol";

/**
 * @dev Factory contract for deploying Invoice clones using CREATE2.
 * Allows predictable invoice addresses for payment requests.
 */
contract InvoiceFactory {
  /// @notice The implementation contract address for all invoice clones
  address public immutable invoiceImplementation;

  /// @notice Emitted when a new invoice is deployed
  event InvoiceDeployed(address indexed invoiceAddress, bytes32 indexed paramsHash);

  /**
   * @dev Constructor that deploys the Invoice implementation contract
   */
  constructor() {
    invoiceImplementation = address(new Invoice());
  }

  /**
   * @dev Computes the deterministic address for an invoice clone
   * @param paramsHash The hash of the invoice parameters (used as salt)
   * @return The predicted address of the invoice clone
   */
  function computeInvoiceAddress(bytes32 paramsHash) public view returns (address) {
    return Clones.predictDeterministicAddress(invoiceImplementation, paramsHash);
  }

  /**
   * @dev Deploys a new invoice clone using CREATE2
   * @param paramsHash The hash of the invoice parameters (vault, token, amount, etc.) - used as salt
   * @return invoiceAddress The address of the deployed invoice clone
   */
  function deployInvoice(bytes32 paramsHash) external returns (address invoiceAddress) {
    // Deploy the clone using CREATE2 with paramsHash as salt
    invoiceAddress = Clones.cloneDeterministic(invoiceImplementation, paramsHash);

    // Initialize the invoice with the paramsHash
    Invoice(invoiceAddress).initialize(paramsHash);

    emit InvoiceDeployed(invoiceAddress, paramsHash);

    return invoiceAddress;
  }

  /**
   * @dev Helper function to compute the paramsHash for invoice parameters.
   * This hash is used as both the invoice identifier and CREATE2 salt.
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
  ) public pure returns (bytes32) {
    return InvoiceLib.computeParamsHash(vault, token, amount, executionFee, commitmentParams, executor);
  }
}
