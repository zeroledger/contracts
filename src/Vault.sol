// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {AccessManagedUpgradeable} from
  "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";

// not upgradable contracts & interfaces

// solhint-disable-next-line no-unused-imports
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Verifiers} from "src/Verifiers.sol";

// libs
import {PoseidonT3} from "@poseidon-solidity/PoseidonT3.sol";
import {
  IVault,
  DepositCommitmentParams,
  DepositParams,
  OutputsOwners,
  Transaction,
  WithdrawItem,
  WithdrawRecipient,
  ICommitmentsRecipient
} from "./Vault.types.sol";
import {InputsLib} from "./Inputs.lib.sol";
import {ProtocolManager} from "src/ProtocolManager.sol";

/**
 * @title Vault
 * @dev A contract that manages ERC20 tokens with commitments and ZK proofs for deposits, withdrawals, and spending
 */
contract Vault is
  Initializable,
  UUPSUpgradeable,
  AccessManagedUpgradeable,
  ReentrancyGuardUpgradeable,
  PausableUpgradeable,
  IVault
{
  using SafeERC20 for IERC20;

  struct State {
    mapping(address token => mapping(uint256 commitmentId => address owner)) commitmentsMap;
    Verifiers verifiers;
    address trustedForwarder;
    ProtocolManager manager;
  }

  // keccak256(abi.encode(uint256(keccak256("storage.zeroledger.Vault")) - 1)) & ~bytes32(uint256(0xff))
  bytes32 internal constant STORAGE_LOCATION = 0x4ff14ff3d6d11019b33840a324a7911c48c76118cab5bf9ddf96218a30397600;

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

  function initialize(address verifiers, address trustedForwarder, address protocolManager, address initialAuthority)
    public
    initializer
  {
    __UUPSUpgradeable_init();
    __ReentrancyGuard_init();
    __Pausable_init();
    __AccessManaged_init(initialAuthority);
    __vault_init_unchained(verifiers, trustedForwarder, protocolManager);
  }

  function upgradeCallBack() external reinitializer(0) {}

  function _authorizeUpgrade(address newImplementation) internal override restricted {}

  function __vault_init_unchained(address verifiers, address trustedForwarder, address manager) internal {
    State storage $ = _getStorage();
    $.trustedForwarder = trustedForwarder;
    $.manager = ProtocolManager(manager);
    $.verifiers = Verifiers(verifiers);
  }

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

  function pause() external restricted {
    _pause();
  }

  function unpause() external restricted {
    _unpause();
  }

  function deposit(DepositParams calldata depositParams, uint256[24] calldata proof)
    external
    nonReentrant
    whenNotPaused
  {
    _deposit(depositParams, proof);
    address from = _msgSender();
    IERC20 t = IERC20(depositParams.token);
    t.safeTransferFrom(from, address(this), depositParams.amount);
    State storage $ = _getStorage();
    t.safeTransferFrom(from, address($.manager), $.manager.getFees(depositParams.token).deposit);
    t.safeTransferFrom(from, depositParams.forwarderFeeRecipient, depositParams.forwarderFee);
    emit Deposit(from, depositParams.token, depositParams.amount);
  }

  function depositWithPermit(
    DepositParams calldata depositParams,
    uint256[24] calldata proof,
    uint256 deadline,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) external nonReentrant whenNotPaused {
    require(deadline >= block.timestamp, "Vault: Permit expired");
    _deposit(depositParams, proof);
    State storage $ = _getStorage();
    uint256 depositFee = $.manager.getFees(depositParams.token).deposit;
    address from = _msgSender();

    IERC20Permit(depositParams.token).permit(
      from, address(this), depositParams.amount + depositFee + depositParams.forwarderFee, deadline, v, r, s
    );

    IERC20 t = IERC20(depositParams.token);

    t.safeTransferFrom(from, address(this), depositParams.amount);
    t.safeTransferFrom(from, address($.manager), depositFee);
    t.safeTransferFrom(from, depositParams.forwarderFeeRecipient, depositParams.forwarderFee);

    emit Deposit(from, depositParams.token, depositParams.amount);
  }

  function _deposit(DepositParams calldata depositParams, uint256[24] calldata proof) internal {
    State storage $ = _getStorage();
    address token = depositParams.token;
    uint256 amount = depositParams.amount;
    DepositCommitmentParams[3] calldata depositCommitmentParams = depositParams.depositCommitmentParams;
    require(token != address(0), "Vault: Invalid token address");
    require(amount > 0, "Vault: Amount must be greater than 0");
    uint240 maxTVL = $.manager.getMaxTVL(token);
    require(IERC20(token).balanceOf(address(this)) + amount <= maxTVL, "Vault: Amount exceeds max TVL");
    require(
      $.verifiers.depositVerifier().verify(proof, InputsLib.depositInputs(depositCommitmentParams, amount)),
      "Vault: Invalid ZK proof"
    );

    // Check that no commitment has been used before and
    // assign commitments to addresses before external call
    for (uint256 i = 0; i < depositCommitmentParams.length; i++) {
      uint256 poseidonHash = depositCommitmentParams[i].poseidonHash;
      if (poseidonHash == InputsLib.SHARED_INPUT) {
        continue;
      }
      require($.commitmentsMap[token][poseidonHash] == address(0), "Vault: Commitment already used");
      $.commitmentsMap[token][poseidonHash] = depositCommitmentParams[i].owner;
      emit CommitmentCreated(
        depositCommitmentParams[i].owner, token, poseidonHash, depositCommitmentParams[i].metadata
      );
    }
  }

  /**
   * @dev Validate that all input indexes are owned by the sender
   */
  function _validateInputIndexes(Transaction calldata transaction) internal view {
    address commitmentOwner = _msgSender();
    for (uint256 i = 0; i < transaction.inputsPoseidonHashes.length; i++) {
      uint256 poseidonHash = transaction.inputsPoseidonHashes[i];
      if (poseidonHash == InputsLib.SHARED_INPUT) {
        continue;
      }
      require(
        _getStorage().commitmentsMap[transaction.token][poseidonHash] == commitmentOwner,
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
      address inputOwner = $.commitmentsMap[transaction.token][inputHash];
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
        $.commitmentsMap[transaction.token][outputHash] = outputOwner;
        emit CommitmentCreated(outputOwner, transaction.token, outputHash, transaction.metadata[outputIndex]);
      }
    }
  }

  // solhint-disable-next-line code-complexity
  function _spend(Transaction calldata transaction, uint256[24] calldata proof) internal {
    require(transaction.token != address(0), "Vault: Invalid token address");
    require(transaction.inputsPoseidonHashes.length > 0, "Vault: No inputs provided");
    require(transaction.outputsPoseidonHashes.length > 0, "Vault: No outputs provided");

    _validateInputIndexes(transaction);

    State storage $ = _getStorage();
    uint240 spendFee = $.manager.getFees(transaction.token).spend;

    bool isValidProof = false;
    if (transaction.inputsPoseidonHashes.length == 1 && transaction.outputsPoseidonHashes.length == 1) {
      isValidProof = $.verifiers.spend11Verifier().verify(proof, InputsLib.fillSpend3Inputs(transaction, spendFee));
    } else if (transaction.inputsPoseidonHashes.length == 1 && transaction.outputsPoseidonHashes.length == 2) {
      isValidProof = $.verifiers.spend12Verifier().verify(proof, InputsLib.fillSpend4Inputs(transaction, spendFee));
    } else if (transaction.inputsPoseidonHashes.length == 1 && transaction.outputsPoseidonHashes.length == 3) {
      isValidProof = $.verifiers.spend13Verifier().verify(proof, InputsLib.fillSpend5Inputs(transaction, spendFee));
    } else if (transaction.inputsPoseidonHashes.length == 2 && transaction.outputsPoseidonHashes.length == 1) {
      isValidProof = $.verifiers.spend21Verifier().verify(proof, InputsLib.fillSpend4Inputs(transaction, spendFee));
    } else if (transaction.inputsPoseidonHashes.length == 2 && transaction.outputsPoseidonHashes.length == 2) {
      isValidProof = $.verifiers.spend22Verifier().verify(proof, InputsLib.fillSpend5Inputs(transaction, spendFee));
    } else if (transaction.inputsPoseidonHashes.length == 2 && transaction.outputsPoseidonHashes.length == 3) {
      isValidProof = $.verifiers.spend23Verifier().verify(proof, InputsLib.fillSpend6Inputs(transaction, spendFee));
    } else if (transaction.inputsPoseidonHashes.length == 3 && transaction.outputsPoseidonHashes.length == 1) {
      isValidProof = $.verifiers.spend31Verifier().verify(proof, InputsLib.fillSpend5Inputs(transaction, spendFee));
    } else if (transaction.inputsPoseidonHashes.length == 3 && transaction.outputsPoseidonHashes.length == 2) {
      isValidProof = $.verifiers.spend32Verifier().verify(proof, InputsLib.fillSpend6Inputs(transaction, spendFee));
    } else if (transaction.inputsPoseidonHashes.length == 3 && transaction.outputsPoseidonHashes.length == 3) {
      isValidProof = $.verifiers.spend33Verifier().verify(proof, InputsLib.fillSpend7Inputs(transaction, spendFee));
    } else if (transaction.inputsPoseidonHashes.length == 8 && transaction.outputsPoseidonHashes.length == 1) {
      isValidProof = $.verifiers.spend81Verifier().verify(proof, InputsLib.fillSpend10Inputs(transaction, spendFee));
    } else if (transaction.inputsPoseidonHashes.length == 16 && transaction.outputsPoseidonHashes.length == 1) {
      isValidProof = $.verifiers.spend161Verifier().verify(proof, InputsLib.fillSpend18Inputs(transaction, spendFee));
    }

    require(isValidProof, "Vault: Invalid ZK proof");

    _deleteInputCommitments(transaction);

    _createOutputCommitments(transaction);

    IERC20 t = IERC20(transaction.token);

    for (uint8 i = 0; i < transaction.publicOutputs.length; i++) {
      if (transaction.publicOutputs[i].amount > 0) {
        t.safeTransfer(transaction.publicOutputs[i].owner, transaction.publicOutputs[i].amount);
      }
    }
    t.safeTransfer(address($.manager), spendFee);

    emit Spend(_msgSender(), transaction.token, transaction.inputsPoseidonHashes, transaction.outputsPoseidonHashes);
  }

  function spend(Transaction calldata transaction, uint256[24] calldata proof) external nonReentrant whenNotPaused {
    _spend(transaction, proof);
  }

  function spendAndCall(address to, Transaction calldata transaction, uint256[24] calldata proof, bytes calldata data)
    external
    nonReentrant
    whenNotPaused
  {
    _spend(transaction, proof);
    ICommitmentsRecipient(to).onCommitmentsReceived(_msgSender(), transaction, data);
  }

  function transfer(address to, address token, uint256[] calldata poseidonHashes) external {
    require(token != address(0), "Vault: Invalid token address");
    State storage $ = _getStorage();
    address commitmentOwner = _msgSender();

    for (uint256 i = 0; i < poseidonHashes.length; i++) {
      uint256 poseidonHash = poseidonHashes[i];
      require($.commitmentsMap[token][poseidonHash] == commitmentOwner, "Vault: Only assigned address can withdraw");
      $.commitmentsMap[token][poseidonHash] = to;
    }
    emit CommitmentsTransfer(commitmentOwner, to, token, poseidonHashes);
  }

  /**
   * @dev Removes commitment by providing amount and secret
   */
  function _redeemCommitment(address token, address commitmentOwner, WithdrawItem calldata item) internal {
    require(token != address(0), "Vault: Invalid token address");
    require(item.amount > 0, "Vault: Amount must be greater than 0");

    uint256 poseidonHash = computePoseidonHash(item.amount, item.sValue);
    if (poseidonHash == InputsLib.SHARED_INPUT) {
      return;
    }

    State storage $ = _getStorage();

    require($.commitmentsMap[token][poseidonHash] == commitmentOwner, "Vault: Only assigned address can withdraw");

    delete $.commitmentsMap[token][poseidonHash];

    emit CommitmentRemoved(commitmentOwner, token, poseidonHash);
  }

  function withdraw(address token, WithdrawItem[] calldata items, WithdrawRecipient[] calldata recipients)
    external
    nonReentrant
    whenNotPaused
  {
    uint256 totalProvided = 0;
    address commitmentOwner = _msgSender();
    for (uint256 i = 0; i < items.length; i++) {
      _redeemCommitment(token, commitmentOwner, items[i]);
      totalProvided += items[i].amount;
    }
    uint240 totalRequested = 0;
    for (uint256 i = 0; i < recipients.length; i++) {
      totalRequested += recipients[i].amount;
    }
    State storage $ = _getStorage();
    uint240 fee = $.manager.getFees(token).withdraw;
    require(totalProvided == totalRequested + fee, "Vault: Unequal total provided and requested amounts");
    IERC20 t = IERC20(token);
    for (uint256 i = 0; i < recipients.length; i++) {
      t.safeTransfer(recipients[i].recipient, recipients[i].amount);
    }
    t.safeTransfer(address($.manager), fee);
    emit Withdraw(commitmentOwner, token, totalProvided);
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
  function getCommitment(address token, uint256 poseidonHash) external view returns (address owner) {
    return _getStorage().commitmentsMap[token][poseidonHash];
  }

  function getTrustedForwarder() external view returns (address) {
    return _getStorage().trustedForwarder;
  }

  function getManager() external view returns (address) {
    return address(_getStorage().manager);
  }

  function getVerifiers() external view returns (address) {
    return address(_getStorage().verifiers);
  }
}
