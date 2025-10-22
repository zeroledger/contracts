// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import {IVault, DepositParams, DepositCommitmentParams} from "./Vault.types.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/**
 * @dev Contract for a one-time invoice with a priority deadline.
 * Using deployCreate2Clone, the invoice initiator can preview the invoice address and request payment.
 * Once payment is received, the invoice can be deployed and executed.
 * The executionFee should cover contract deployment and execution costs.
 */
contract Invoice is Initializable {
  struct InvoiceState {
    bytes32 paramsHash;
    uint256 priorityDeadline;
  }

  // keccak256(abi.encode(uint256(keccak256("invoice.zeroledger")) - 1)) & ~bytes32(uint256(0xff))
  bytes32 internal constant STORAGE_LOCATION = 0xf1ee228d9f24f6e688c439ca913a801b6d219979c1a4f6a63061be9d75e25000;

  function _getStorage() internal pure returns (InvoiceState storage $) {
    // solhint-disable-next-line no-inline-assembly
    assembly {
      $.slot := STORAGE_LOCATION
    }
  }

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }

  function initialize(bytes32 paramsHash_) public initializer {
    InvoiceState storage $ = _getStorage();
    $.paramsHash = paramsHash_;
    $.priorityDeadline = block.timestamp + 1 days;
  }

  /**
   * @dev Executes an invoice with a priority deadline.
   * Before the priority deadline, only the specified executor can execute the invoice.
   * After the deadline, anyone can execute it, and msg.sender receives the executionFee.
   * @param vault The address of the Vault contract
   * @param token The address of the token to deposit
   * @param amount The amount of tokens to deposit
   * @param executionFee The fee paid to the executor for processing the invoice
   * @param commitmentParams The commitment parameters for the deposit
   * @param proof The ZK proof for the deposit
   * @param executor The address of the priority executor (before deadline)
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
    InvoiceState storage $ = _getStorage();
    bytes32 computedParamsHash = keccak256(abi.encode(vault, token, amount, executionFee, commitmentParams, executor));
    require(computedParamsHash == $.paramsHash, "Invoice: Invalid params hash");
    if (block.timestamp < $.priorityDeadline) {
      IVault(vault).deposit(DepositParams(token, amount, commitmentParams, executionFee, executor), proof);
    } else {
      IVault(vault).deposit(DepositParams(token, amount, commitmentParams, executionFee, msg.sender), proof);
    }
  }
}
