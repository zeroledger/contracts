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
  address owner; // owner of new UTXO commitment
  uint8[] indexes; // positions in the outputsPoseidonHashes
}

struct Transaction {
  address token;
  uint256[] inputsPoseidonHashes; // UTXO commitments to consume
  uint256[] outputsPoseidonHashes; // New UTXO commitments to create
  bytes[] metadata; // metadata data for each output
  OutputsOwners[] outputsOwners; // addresses for outputs
  PublicOutput[] publicOutputs; // public outputs
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

interface IVault {
  /**
   * @dev Emitted when `user` deposit `amount` `token` into vault
   */
  event Deposit(address indexed user, address indexed token, uint256 amount);
  /**
   * @dev Emitted when commitment for `owner` with `poseidonHash` and `metadata` is created in scope of `token`
   */
  event CommitmentCreated(address indexed owner, address indexed token, uint256 commitment, bytes metadata);
  /**
   * @dev Emitted when commitment for `owner` with `poseidonHash` and `metadata` is removed (deleted) in scope of
   * `token`
   */
  event CommitmentRemoved(address indexed owner, address indexed token, uint256 commitment);
  /**
   * @dev Emitted when `owner` spend a confidential amount of some `token`.
   */
  event Spend(address indexed owner, address indexed token, uint256[] inputCommitments, uint256[] outputCommitments);
  /**
   * @dev Emitted when `owner` withdraw `total` amounts of token from the vault.
   */
  event Withdrawal(address indexed user, address indexed token, uint256 indexed total);
}

interface ICommitmentsRecipient {
  function onCommitmentsReceived(address from, uint256[] calldata commitments, bytes calldata data)
    external
    returns (bytes4);
}
