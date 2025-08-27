// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

// not upgradable contracts & interfaces

// solhint-disable-next-line no-unused-imports
import {ERC2771Forwarder} from "@openzeppelin/contracts/metatx/ERC2771Forwarder.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Verifiers} from "./Verifiers.sol";

// libs
import {PoseidonT3} from "poseidon-solidity/PoseidonT3.sol";
import {Roles} from "src/Roles.lib.sol";
import {
  Commitment,
  DepositCommitmentParams,
  DepositParams,
  OutputsOwners,
  Transaction,
  WithdrawItem
} from "./Vault.types.sol";
import {InputsLib} from "./Inputs.lib.sol";

/**
 * @title Vault
 * @dev A contract that manages ERC20 tokens with commitments and ZK proofs for deposits, withdrawals, and spending
 */
contract Vault is Initializable, UUPSUpgradeable, AccessControlUpgradeable, ReentrancyGuardUpgradeable {
  struct State {
    // Mapping to track if a commitment hash has been deposited
    mapping(address => mapping(uint256 => Commitment)) commitmentsMap;
    Verifiers verifiers;
    address trustedForwarder;
  }

  // Events
  event TokenDeposited(address indexed user, address indexed token, uint256 total_deposit_amount, uint256 fee);
  event CommitmentCreated(address indexed owner, address indexed token, uint256 poseidonHash, bytes metadata);
  event CommitmentRemoved(address indexed owner, address indexed token, uint256 poseidonHash);
  event TransactionSpent(
    address indexed owner, address indexed token, uint256[] inputHashes, uint256[] outputHashes, uint256 fee
  );
  event Withdrawal(address indexed user, address indexed token, uint256 total, uint256 fee);

  // todo rerun
  // keccak256(abi.encode(uint256(keccak256("storage.zeroledger")) - 1)) & ~bytes32(uint256(0xff))
  bytes32 internal constant STORAGE_LOCATION = 0x60ea44b2fada15ab3d55d1b53c0f3a65e4a3da4f8f909905e012d14a90d3b300;

  function _getStorage() internal pure returns (State storage $) {
    // solhint-disable-next-line no-inline-assembly
    assembly {
      $.slot := STORAGE_LOCATION
    }
  }

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }

  function initialize(address verifiers, address trustedForwarder) public initializer {
    __AccessControl_init();
    __UUPSUpgradeable_init();
    __ReentrancyGuard_init();
    __vault_init_unchained(verifiers, trustedForwarder);

    _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    _grantRole(Roles.MAINTAINER, msg.sender);
  }

  function upgradeCallBack(address, address, address) external reinitializer(0) {}

  function _authorizeUpgrade(address newImplementation) internal override onlyRole(Roles.MAINTAINER) {}

  function __vault_init_unchained(address verifiers, address trustedForwarder) internal {
    State storage $ = _getStorage();
    $.trustedForwarder = trustedForwarder;
    $.verifiers = Verifiers(verifiers);
  }

  /**
   * @dev Returns whether any particular address is the trusted forwarder. Must has identical interface to
   * ERC2771Context.
   */
  function isTrustedForwarder(address forwarder) public view virtual returns (bool) {
    return _getStorage().trustedForwarder == forwarder;
  }

  /**
   * @dev Override for `msg.sender`. Defaults to the original `msg.sender` whenever
   * a call is not performed by the trusted forwarder or the calldata length is less than
   * 20 bytes (an address length).
   */
  function _msgSender() internal view override returns (address) {
    uint256 calldataLength = msg.data.length;
    uint256 contextSuffixLength = _contextSuffixLength();
    if (calldataLength >= contextSuffixLength && isTrustedForwarder(msg.sender)) {
      unchecked {
        return address(bytes20(msg.data[calldataLength - contextSuffixLength:]));
      }
    } else {
      return super._msgSender();
    }
  }

  /**
   * @dev Override for `msg.data`. Defaults to the original `msg.data` whenever
   * a call is not performed by the trusted forwarder or the calldata length is less than
   * 20 bytes (an address length).
   */
  function _msgData() internal view override returns (bytes calldata) {
    uint256 calldataLength = msg.data.length;
    uint256 contextSuffixLength = _contextSuffixLength();
    if (calldataLength >= contextSuffixLength && isTrustedForwarder(msg.sender)) {
      unchecked {
        return msg.data[:calldataLength - contextSuffixLength];
      }
    } else {
      return super._msgData();
    }
  }

  /**
   * @dev ERC-2771 specifies the context as being a single address (20 bytes).
   */
  function _contextSuffixLength() internal pure override returns (uint256) {
    return 20;
  }

  /**
   * @dev Deposit tokens with commitments and ZK proof validation
   */
  function deposit(DepositParams calldata depositParams, uint256[24] calldata proof) external nonReentrant {
    State storage $ = _getStorage();
    address token = depositParams.token;
    uint256 total_deposit_amount = depositParams.total_deposit_amount;
    DepositCommitmentParams[3] calldata depositCommitmentParams = depositParams.depositCommitmentParams;
    require(token != address(0), "Vault: Invalid token address");
    require(total_deposit_amount > 0, "Vault: Amount must be greater than 0");
    require(
      $.verifiers.depositVerifier().verify(
        proof, InputsLib.depositInputs(depositCommitmentParams, total_deposit_amount)
      ),
      "Vault: Invalid ZK proof"
    );

    // Check that no commitment has been used before and
    // assign commitments to addresses before external call
    for (uint256 i = 0; i < depositCommitmentParams.length; i++) {
      uint256 poseidonHash = depositCommitmentParams[i].poseidonHash;
      if (poseidonHash == InputsLib.SHARED_INPUT) {
        continue;
      }
      require($.commitmentsMap[token][poseidonHash].owner == address(0), "Vault: Commitment already used");
      $.commitmentsMap[token][poseidonHash] = Commitment({owner: depositCommitmentParams[i].owner, locked: false});
      emit CommitmentCreated(
        depositCommitmentParams[i].owner, token, poseidonHash, depositCommitmentParams[i].metadata
      );
    }

    uint256 fee = depositParams.fee;
    IERC20(token).transferFrom(_msgSender(), address(this), total_deposit_amount);
    if (fee > 0) {
      IERC20(token).transferFrom(_msgSender(), depositParams.feeRecipient, fee);
    }
    emit TokenDeposited(_msgSender(), token, total_deposit_amount, fee);
  }

  /**
   * @dev Validate that all input indexes are owned by the sender
   */
  function _validateInputIndexes(Transaction calldata transaction) internal view {
    for (uint256 i = 0; i < transaction.inputsPoseidonHashes.length; i++) {
      uint256 poseidonHash = transaction.inputsPoseidonHashes[i];
      if (poseidonHash == InputsLib.SHARED_INPUT) {
        continue;
      }
      require(
        _getStorage().commitmentsMap[transaction.token][poseidonHash].owner == _msgSender(),
        "Vault: Input commitment not found"
      );
    }
  }

  /**
   * @dev Delete input commitments and emit events
   */
  function _deleteInputCommitments(Transaction calldata transaction) internal {
    State storage $ = _getStorage();
    for (uint256 i = 0; i < transaction.inputsPoseidonHashes.length; i++) {
      uint256 inputHash = transaction.inputsPoseidonHashes[i];
      if (inputHash == InputsLib.SHARED_INPUT) {
        continue;
      }
      address inputOwner = $.commitmentsMap[transaction.token][inputHash].owner;
      delete $.commitmentsMap[transaction.token][inputHash];
      emit CommitmentRemoved(inputOwner, transaction.token, inputHash);
    }
  }

  /**
   * @dev Create output commitments using indexes from output witnesses
   */
  function _createOutputCommitments(Transaction calldata transaction) internal {
    State storage $ = _getStorage();
    for (uint256 i = 0; i < transaction.outputsOwners.length; i++) {
      OutputsOwners memory outputWitness = transaction.outputsOwners[i];
      address outputOwner = outputWitness.owner;

      for (uint256 j = 0; j < outputWitness.indexes.length; j++) {
        uint8 outputIndex = outputWitness.indexes[j];
        uint256 outputHash = transaction.outputsPoseidonHashes[outputIndex];
        if (outputHash == InputsLib.SHARED_INPUT) {
          continue;
        }
        $.commitmentsMap[transaction.token][outputHash] = Commitment({owner: outputOwner, locked: false});
        emit CommitmentCreated(outputOwner, transaction.token, outputHash, transaction.metadata[outputIndex]);
      }
    }
  }

  /**
   * @dev Spend commitments by creating new ones (supports multiple inputs and outputs)
   */
  // solhint-disable-next-line code-complexity
  function spend(Transaction calldata transaction, uint256[24] calldata proof) external nonReentrant {
    require(transaction.token != address(0), "Vault: Invalid token address");
    require(transaction.inputsPoseidonHashes.length > 0, "Vault: No inputs provided");
    require(transaction.outputsPoseidonHashes.length > 0, "Vault: No outputs provided");

    _validateInputIndexes(transaction);

    State storage $ = _getStorage();

    bool isValidProof = false;
    if (transaction.inputsPoseidonHashes.length == 1 && transaction.outputsPoseidonHashes.length == 1) {
      isValidProof = $.verifiers.spend11Verifier().verify(proof, InputsLib.fillSpend3Inputs(transaction));
    } else if (transaction.inputsPoseidonHashes.length == 1 && transaction.outputsPoseidonHashes.length == 2) {
      isValidProof = $.verifiers.spend12Verifier().verify(proof, InputsLib.fillSpend4Inputs(transaction));
    } else if (transaction.inputsPoseidonHashes.length == 1 && transaction.outputsPoseidonHashes.length == 3) {
      isValidProof = $.verifiers.spend13Verifier().verify(proof, InputsLib.fillSpend5Inputs(transaction));
    } else if (transaction.inputsPoseidonHashes.length == 2 && transaction.outputsPoseidonHashes.length == 1) {
      isValidProof = $.verifiers.spend21Verifier().verify(proof, InputsLib.fillSpend4Inputs(transaction));
    } else if (transaction.inputsPoseidonHashes.length == 2 && transaction.outputsPoseidonHashes.length == 2) {
      isValidProof = $.verifiers.spend22Verifier().verify(proof, InputsLib.fillSpend5Inputs(transaction));
    } else if (transaction.inputsPoseidonHashes.length == 2 && transaction.outputsPoseidonHashes.length == 3) {
      isValidProof = $.verifiers.spend23Verifier().verify(proof, InputsLib.fillSpend6Inputs(transaction));
    } else if (transaction.inputsPoseidonHashes.length == 3 && transaction.outputsPoseidonHashes.length == 1) {
      isValidProof = $.verifiers.spend31Verifier().verify(proof, InputsLib.fillSpend5Inputs(transaction));
    } else if (transaction.inputsPoseidonHashes.length == 3 && transaction.outputsPoseidonHashes.length == 2) {
      isValidProof = $.verifiers.spend32Verifier().verify(proof, InputsLib.fillSpend6Inputs(transaction));
    } else if (transaction.inputsPoseidonHashes.length == 3 && transaction.outputsPoseidonHashes.length == 3) {
      isValidProof = $.verifiers.spend33Verifier().verify(proof, InputsLib.fillSpend7Inputs(transaction));
    } else if (transaction.inputsPoseidonHashes.length == 8 && transaction.outputsPoseidonHashes.length == 1) {
      isValidProof = $.verifiers.spend81Verifier().verify(proof, InputsLib.fillSpend10Inputs(transaction));
    } else if (transaction.inputsPoseidonHashes.length == 16 && transaction.outputsPoseidonHashes.length == 1) {
      isValidProof = $.verifiers.spend161Verifier().verify(proof, InputsLib.fillSpend18Inputs(transaction));
    }

    require(isValidProof, "Vault: Invalid ZK proof");

    _deleteInputCommitments(transaction);

    _createOutputCommitments(transaction);

    for (uint8 i = 0; i < transaction.publicOutputs.length; i++) {
      if (transaction.publicOutputs[i].amount > 0) {
        IERC20(transaction.token).transfer(transaction.publicOutputs[i].owner, transaction.publicOutputs[i].amount);
      }
    }

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
   */
  function redeemCommitment(address token, WithdrawItem calldata item) internal {
    require(token != address(0), "Vault: Invalid token address");
    require(item.amount > 0, "Vault: Amount must be greater than 0");

    uint256 poseidonHash = computePoseidonHash(item.amount, item.sValue);
    if (poseidonHash == InputsLib.SHARED_INPUT) {
      return;
    }

    State storage $ = _getStorage();

    Commitment storage commitment = $.commitmentsMap[token][poseidonHash];
    require(commitment.owner != address(0), "Vault: Commitment not found");
    require(commitment.owner == _msgSender(), "Vault: Only assigned address can withdraw");

    delete $.commitmentsMap[token][poseidonHash];

    emit CommitmentRemoved(_msgSender(), token, poseidonHash);
  }

  /**
   * @dev Withdraw multiple commitments in a single transaction
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
    IERC20(token).transfer(recipient, total - fee);
    if (fee > 0) {
      IERC20(token).transfer(feeRecipient, fee);
    }
    emit Withdrawal(_msgSender(), token, total, fee);
  }

  /**
   * @dev Compute Poseidon hash of amount and sValue on-chain
   */
  function computePoseidonHash(uint256 amount, uint256 sValue) public pure returns (uint256) {
    return PoseidonT3.hash([amount, sValue]);
  }

  /**
   * @dev Get commitment details for a given token and poseidon hash
   */
  function getCommitment(address token, uint256 poseidonHash) external view returns (address owner, bool locked) {
    Commitment memory commitment = _getStorage().commitmentsMap[token][poseidonHash];
    return (commitment.owner, commitment.locked);
  }
}
