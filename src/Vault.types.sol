// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

struct DepositCommitmentParams {
  uint256 poseidonHash;
  address owner;
  bytes metadata;
}

struct DepositParams {
  address token;
  uint240 amount;
  DepositCommitmentParams[3] depositCommitmentParams;
  uint240 forwarderFee;
  address forwarderFeeRecipient;
}

struct OutputsOwners {
  address owner;
  uint8[] indexes;
}

struct Transaction {
  address token;
  uint256[] inputsPoseidonHashes;
  uint256[] outputsPoseidonHashes;
  bytes[] metadata;
  OutputsOwners[] outputsOwners;
  PublicOutput[] publicOutputs;
}

struct WithdrawItem {
  uint240 amount;
  uint256 sValue;
}

struct WithdrawRecipient {
  address recipient;
  uint240 amount;
}

struct PublicOutput {
  address owner;
  uint240 amount;
}

interface IVaultEvents {
  /**
   * @dev Emitted when `user` deposit `amount` `token` into vault
   */
  event Deposit(address indexed user, address indexed token, uint256 indexed amount);
  /**
   * @dev Emitted when commitment for `owner` with `poseidonHash` and `metadata` is created in scope of `token`
   */
  event CommitmentCreated(address indexed owner, address indexed token, uint256 poseidonHash, bytes metadata);
  /**
   * @dev Emitted when commitment for `owner` with `poseidonHash` and `metadata` is removed (deleted) in scope of
   * `token`
   */
  event CommitmentRemoved(address indexed owner, address indexed token, uint256 poseidonHash);
  /**
   * @dev Emitted when `token` scoped `poseidonHashes` commitments transferred from `from` address to `to` address
   */
  event CommitmentsTransfer(address indexed from, address indexed to, address indexed token, uint256[] poseidonHashes);
  /**
   * @dev Emitted when `owner` spend a confidential amount of some `token`.
   */
  event Spend(address indexed owner, address indexed token, uint256[] inputHashes, uint256[] outputHashes);
  /**
   * @dev Emitted when `owner` withdraw `total` amounts of token from the vault.
   */
  event Withdraw(address indexed user, address indexed token, uint256 indexed total);
}

interface IVault is IVaultEvents {
  /**
   * @dev Returns whether any particular address is the trusted forwarder. Must has identical interface to
   * ERC2771Context.
   */
  function isTrustedForwarder(address forwarder) external view returns (bool);

  /**
   * @dev Pause all whenNotPaused modified methods
   */
  function pause() external;

  /**
   * @dev Unpause all whenNotPaused modified methods
   */
  function unpause() external;

  /**
   * @dev Deposit tokens with commitments and ZK proof validation
   * @param depositParams The deposit parameters including token, amount, and commitments
   * @param proof The ZK proof for the deposit
   */
  function deposit(DepositParams calldata depositParams, uint256[24] calldata proof) external;

  /**
   * @dev Deposit tokens with commitments and ZK proof validation using ERC20 permit
   * @param depositParams The deposit parameters including token, amount, and commitments
   * @param proof The ZK proof for the deposit
   * @param deadline The deadline for the permit
   * @param v The recovery id of the permit signature
   * @param r The r component of the permit signature
   * @param s The s component of the permit signature
   */
  function depositWithPermit(
    DepositParams calldata depositParams,
    uint256[24] calldata proof,
    uint256 deadline,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) external;

  /**
   * @dev Spend commitments by creating new ones (supports multiple inputs and outputs)
   */
  function spend(Transaction calldata transaction, uint256[24] calldata proof) external;

  /**
   * @dev Spend commitments by creating new ones (supports multiple inputs and outputs)
   */
  function spendAndCall(address to, Transaction calldata transaction, uint256[24] calldata proof, bytes calldata data)
    external;

  /**
   * @dev Moves commitments defined by `poseidonHashes` and `token` to `to` address
   * Important: transfer does not destroy the commitments, it only changes the owner and emits an CommitmentsTransfer
   * event.
   * CommitmentsTransfer does not carry metadata, so client will need to find a CommitmentCreated event for the
   * corresponding commitment to get the commitment metadata.
   */
  function transfer(address to, address token, uint256[] calldata poseidonHashes) external;

  /**
   * @dev Withdraw multiple commitments in a single transaction
   */
  function withdraw(address token, WithdrawItem[] calldata items, WithdrawRecipient[] calldata recipients) external;

  /**
   * @dev Compute Poseidon hash of amount and sValue on-chain
   */
  function computePoseidonHash(uint256 amount, uint256 sValue) external pure returns (uint256);

  /**
   * @dev Get commitment details for a given token and poseidon hash
   */
  function getCommitment(address token, uint256 poseidonHash) external view returns (address owner);

  /**
   * @dev Returns address of current Trusted Forwarder contract
   */
  function getTrustedForwarder() external view returns (address);

  /**
   * @dev Returns address of current ProtocolManager contract
   */
  function getManager() external view returns (address);

  /**
   * @dev Returns address of Verifiers umbrella contract
   */
  function getVerifiers() external view returns (address);
}

interface ICommitmentsRecipient {
  function onCommitmentsReceived(address from, Transaction calldata transaction, bytes calldata data) external;
}
