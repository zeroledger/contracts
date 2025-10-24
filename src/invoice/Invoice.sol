// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {IVault, DepositParams, DepositCommitmentParams} from "src/Vault.types.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {InvoiceLib} from "./Invoice.lib.sol";

contract Invoice is Initializable {
  event InvoiceProcessed(address indexed vault, address indexed token, uint256 indexed amount);

  struct InvoiceState {
    bytes32 paramsHash;
    uint256 priorityDeadline;
  }

  address public immutable factory;

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
    factory = msg.sender;
    _disableInitializers();
  }

  modifier onlyFactory() {
    require(msg.sender == factory, "Invoice: Only factory can initialize");
    _;
  }

  /**
   * @dev Initializes the invoice clone. Can only be called by the factory via deployInvoice.
   * This ensures that the paramsHash used for initialization matches the one used for address prediction.
   * @param paramsHash_ The hash of invoice parameters
   */
  function initialize(bytes32 paramsHash_) public initializer onlyFactory {
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
  function processInvoice(
    address vault,
    address token,
    uint240 amount,
    uint240 executionFee,
    DepositCommitmentParams[3] calldata commitmentParams,
    uint256[24] calldata proof,
    address executor
  ) external {
    InvoiceState storage $ = _getStorage();
    bytes32 computedParamsHash =
      InvoiceLib.computeParamsHash(vault, token, amount, executionFee, commitmentParams, executor);
    require(computedParamsHash == $.paramsHash, "Invoice: Invalid params hash");
    // Note: amount now includes all fees (depositFee + executionFee)
    IERC20(token).approve(vault, amount);
    if (block.timestamp < $.priorityDeadline) {
      IVault(vault).deposit(DepositParams(token, amount, commitmentParams, executionFee, executor), proof);
    } else {
      IVault(vault).deposit(DepositParams(token, amount, commitmentParams, executionFee, msg.sender), proof);
    }

    emit InvoiceProcessed(vault, token, amount);
  }
}
