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
  bool track;
  uint8[] indexes;
}

struct PublicOutput {
  uint240 amount;
  bool track;
  address owner;
}

struct Transaction {
  uint256[] inputsPoseidonHashes;
  uint256[] outputsPoseidonHashes;
  address token;
  bytes[] metadata;
  OutputsOwners[] outputsOwners;
  PublicOutput[] publicOutputs;
}

/// @title IVaultEvents
/// @notice Events for the Vault contract
/// @author Zeroledger
interface IVaultEvents {
  /**
   * @notice Emitted when `user` deposit `amount` `token` into vault
   * @param user The address that deposited the tokens
   * @param token The token that was deposited
   * @param amount The amount that was deposited
   */
  event Deposit(address indexed user, address indexed token, uint256 indexed amount);
  /**
   * @notice Emitted when commitment for `owner` with `poseidonHash` and `metadata` is created in scope of `token`
   * @param owner The owner of the commitment
   * @param token The token that the commitment is in scope of
   * @param poseidonHash The poseidon hash of the commitment
   * @param metadata The metadata of the commitment
   */
  event CommitmentCreated(address indexed owner, address indexed token, uint256 poseidonHash, bytes metadata);
  /**
   * @notice Emitted when commitment for `owner` with `poseidonHash` and `metadata` is removed (deleted) in scope of
   * `token`
   * @param owner The owner of the commitment
   * @param token The token that the commitment is in scope of
   * @param poseidonHash The poseidon hash of the commitment
   */
  event CommitmentRemoved(address indexed owner, address indexed token, uint256 poseidonHash);
  /**
   * @notice Emitted when `token` scoped `poseidonHash` commitment transferred from `from` address to `to` address
   * @param from The address that transferred the commitment
   * @param to The address that received the commitment
   * @param token The token that was transferred
   * @param poseidonHash The poseidon hash of the commitment that was transferred
   */
  event CommitmentTransfer(address indexed from, address indexed to, address indexed token, uint256 poseidonHash);
  /**
   * @notice Emitted when `owner` spend a confidential amount of some `token` to `to` address
   * @param from The address that spent the confidential amount
   * @param to The address that received the confidential amount
   * @param token The token that was spent
   */
  event ConfidentialSpend(address indexed from, address indexed to, address indexed token);
  /**
   * @notice Emitted when `owner` spend a public `amount` of some `token` to `to` address
   * @param from The address that spent the public amount
   * @param to The address that received the public amount
   * @param token The token that was spent
   * @param amount The amount that was spent
   */
  event PublicSpend(address indexed from, address indexed to, address indexed token, uint240 amount);
}

/// @title IVault
/// @notice Interface for the Vault contract
/// @author Zeroledger
interface IVault is IVaultEvents {
  /**
   * @notice Returns whether any particular address is the trusted forwarder. Must has identical interface to
   * ERC2771Context.
   * @param forwarder The address to check if it is the trusted forwarder
   * @return isTrustedForwarder Whether the address is the trusted forwarder
   */
  function isTrustedForwarder(address forwarder) external view returns (bool);

  /**
   * @notice Pause all whenNotPaused modified methods
   */
  function pause() external;

  /**
   * @notice Unpause all whenNotPaused modified methods
   */
  function unpause() external;

  /**
   * @notice Deposit tokens with commitments and ZK proof validation
   * @param depositParams The deposit parameters including token, amount, and commitments
   * @param proof The ZK proof for the deposit
   */
  function deposit(DepositParams calldata depositParams, uint256[24] calldata proof) external;

  /**
   * @notice Deposit tokens with commitments and ZK proof validation using ERC20 permit
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
   * @notice Spend commitments by creating new ones (supports multiple inputs and outputs)
   * @param transaction The transaction containing the commitments to spend
   * @param proof The ZK proof for the spend
   */
  function spend(Transaction calldata transaction, uint256[24] calldata proof) external;

  /**
   * @notice Spend commitments by creating new ones (supports multiple inputs and outputs)
   * @param transaction The transaction containing the commitments to spend
   * @param proof The ZK proof for the spend
   */
  function spendAndCall(
    address to,
    Transaction calldata transaction,
    uint256[24] calldata proof,
    bytes calldata data
  ) external;

  /**
   * @notice Moves commitments defined by `poseidonHashes` and `token` to `to` address
   * Important: transfer does not destroy the commitments, it only changes the owner and emits an CommitmentsTransfer
   * event.
   * CommitmentsTransfer does not carry metadata, so client will need to find a CommitmentCreated event for the
   * corresponding commitment to get the commitment metadata.
   * @param to The address to move the commitments to
   * @param token The token to move the commitments for
   * @param poseidonHash The poseidon hash of the commitment to move
   */
  function transfer(address to, address token, uint256 poseidonHash) external;

  /**
   * @notice Compute Poseidon hash of amount and sValue on-chain
   * @param amount The amount to compute the poseidon hash for
   * @param sValue The sValue to compute the poseidon hash for
   * @return poseidonHash The poseidon hash of the amount and sValue
   */
  function computePoseidonHash(uint256 amount, uint256 sValue) external pure returns (uint256);

  /**
   * @notice Get commitment details for a given token and poseidon hash
   * @param token The token to get the commitment details for
   * @param poseidonHash The poseidon hash of the commitment
   * @return owner The owner of the commitment
   */
  function getCommitment(address token, uint256 poseidonHash) external view returns (address owner);

  /**
   * @notice Returns the address of the Trusted Forwarder contract
   * @return The address of the Trusted Forwarder contract
   */
  function getTrustedForwarder() external view returns (address);

  /**
   * @notice Returns the address of the ProtocolManager contract
   * @return The address of the ProtocolManager contract
   */
  function getManager() external view returns (address);

  /**
   * @notice Returns the address of the Verifiers umbrella contract
   * @return The address of the Verifiers umbrella contract
   */
  function getVerifiers() external view returns (address);
}

/// @title ICommitmentsRecipient
/// @notice Interface for contracts that receive commitments
/// @author Zeroledger
interface ICommitmentsRecipient {
  /// @notice Called when commitments are received
  /// @param from The address that sent the commitments
  /// @param transaction The transaction containing the commitments
  /// @param data Additional data sent with the transaction
  function onCommitmentsReceived(address from, Transaction calldata transaction, bytes calldata data) external;
}

/// @title IVaultErrors
/// @notice Custom errors for gas optimization
/// @author Zeroledger
interface IVaultErrors {
  error PermitExpired();
  error AmountMustBeGreaterThanZero();
  error AmountExceedsMaxTVL(uint256 currentBalance, uint256 amount, uint240 maxTVL);
  error InvalidZKProof();
  error CommitmentAlreadyUsed(uint256 poseidonHash);
  error InputCommitmentNotFound(uint256 poseidonHash);
  error NoInputsProvided();
  error NoOutputsProvided();
  error InvalidOwner(address token, uint256 poseidonHash, address caller);
}
