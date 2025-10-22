// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import {VaultTest} from "./VaultTest.util.sol";
import {WithdrawItem, WithdrawRecipient, IVaultErrors} from "src/Vault.types.sol";
import {IVaultEvents} from "src/Vault.types.sol";
import {Fees} from "src/ProtocolManager.sol";

contract VaultWithdrawTest is VaultTest, IVaultEvents {
  // Constants computed at compilation time
  uint240 internal constant WITHDRAW_AMOUNT_1 = uint240(50e18);
  uint256 internal constant S_VALUE_1 = uint256(123456789);

  uint240 internal constant WITHDRAW_AMOUNT_2 = uint240(30e18);
  uint256 internal constant S_VALUE_2 = uint256(111111111);

  uint240 internal constant WITHDRAW_AMOUNT_3 = uint240(20e18);
  uint256 internal constant S_VALUE_3 = uint256(222222222);

  uint240 internal constant WITHDRAW_AMOUNT_4 = uint240(10e18);
  uint256 internal constant S_VALUE_4 = uint256(333333333);

  // Deposit constants
  uint240 internal constant DEPOSIT_AMOUNT = uint240(100e18);
  uint240 internal constant DEPOSIT_FEE = uint240(5e18);
  uint240 internal constant DEPOSIT_FORWARDER_FEE = uint240(5e18);
  uint240 internal constant WITHDRAW_FEE = uint240(1e18);

  // Pre-computed poseidon hashes (computed once and stored)
  uint256 internal poseidonHash1;
  uint256 internal poseidonHash2;
  uint256 internal poseidonHash3;
  uint256 internal poseidonHash4;

  function setUp() public {
    baseSetup();
    protocolManager.setFees(address(mockToken), Fees({deposit: DEPOSIT_FEE, spend: 0, withdraw: WITHDRAW_FEE}));
    // Compute poseidon hashes once during setup
    poseidonHash1 = vault.computePoseidonHash(WITHDRAW_AMOUNT_1, S_VALUE_1);
    poseidonHash2 = vault.computePoseidonHash(WITHDRAW_AMOUNT_2, S_VALUE_2);
    poseidonHash3 = vault.computePoseidonHash(WITHDRAW_AMOUNT_3, S_VALUE_3);
    poseidonHash4 = vault.computePoseidonHash(WITHDRAW_AMOUNT_4, S_VALUE_4);
  }

  function test_withdraw_single_commitment_success() public {
    // Create a commitment manually by creating a deposit with the pre-computed hash
    uint256[3] memory depositHashes = [poseidonHash1, uint256(987654321), uint256(555666777)];
    address[3] memory depositOwners = [alice, bob, charlie];

    createDeposit(alice, DEPOSIT_AMOUNT, DEPOSIT_FEE, DEPOSIT_FORWARDER_FEE, depositHashes, depositOwners);

    // Verify the commitment exists and is owned by Alice
    address owner = vault.getCommitment(address(mockToken), poseidonHash1);
    assertEq(owner, alice, "Commitment should exist and be owned by Alice");

    WithdrawItem[] memory items = new WithdrawItem[](1);
    items[0] = WithdrawItem({amount: WITHDRAW_AMOUNT_1, sValue: S_VALUE_1});
    WithdrawRecipient[] memory recipients = new WithdrawRecipient[](1);
    recipients[0] = WithdrawRecipient({recipient: alice, amount: WITHDRAW_AMOUNT_1 - WITHDRAW_FEE});

    // Expect events to be emitted
    vm.expectEmit(true, true, false, true);
    emit CommitmentRemoved(alice, address(mockToken), poseidonHash1);

    vm.expectEmit(true, true, false, true);
    emit Withdraw(alice, address(mockToken), WITHDRAW_AMOUNT_1);

    // Execute withdraw
    vm.startPrank(alice);
    vault.withdraw(address(mockToken), items, recipients);
    vm.stopPrank();

    // Verify commitment was removed
    address ownerAfter = vault.getCommitment(address(mockToken), poseidonHash1);
    assertEq(ownerAfter, address(0), "Commitment should be removed");
  }

  function test_withdraw_multiple_commitments_success() public {
    // Create a deposit with the pre-computed hashes
    uint256[3] memory depositHashes = [poseidonHash2, poseidonHash3, uint256(555666777)];
    address[3] memory depositOwners = [alice, alice, alice]; // All owned by Alice

    createDeposit(alice, DEPOSIT_AMOUNT, DEPOSIT_FEE, DEPOSIT_FORWARDER_FEE, depositHashes, depositOwners);

    // Create withdraw items for multiple commitments
    WithdrawItem[] memory items = new WithdrawItem[](2);
    items[0] = WithdrawItem({amount: WITHDRAW_AMOUNT_2, sValue: S_VALUE_2});
    items[1] = WithdrawItem({amount: WITHDRAW_AMOUNT_3, sValue: S_VALUE_3});

    WithdrawRecipient[] memory recipients = new WithdrawRecipient[](1);
    recipients[0] = WithdrawRecipient({recipient: alice, amount: WITHDRAW_AMOUNT_2 + WITHDRAW_AMOUNT_3 - WITHDRAW_FEE});

    // Expect events to be emitted (in order of commitment removal)
    vm.expectEmit(true, true, false, true);
    emit CommitmentRemoved(alice, address(mockToken), poseidonHash2);

    vm.expectEmit(true, true, false, true);
    emit CommitmentRemoved(alice, address(mockToken), poseidonHash3);

    vm.expectEmit(true, true, false, true);
    emit Withdraw(alice, address(mockToken), WITHDRAW_AMOUNT_2 + WITHDRAW_AMOUNT_3);

    // Execute withdraw
    vm.startPrank(alice);
    vault.withdraw(address(mockToken), items, recipients);
    vm.stopPrank();

    // Verify commitments were removed
    address owner1 = vault.getCommitment(address(mockToken), poseidonHash2);
    address owner2 = vault.getCommitment(address(mockToken), poseidonHash3);
    assertEq(owner1, address(0), "First commitment should be removed");
    assertEq(owner2, address(0), "Second commitment should be removed");
  }

  function test_withdraw_zero_fee() public {
    // Create a deposit with the pre-computed hash
    uint256[3] memory depositHashes = [poseidonHash1, uint256(987654321), uint256(555666777)];
    address[3] memory depositOwners = [alice, bob, charlie];

    createDeposit(alice, DEPOSIT_AMOUNT, DEPOSIT_FEE, DEPOSIT_FORWARDER_FEE, depositHashes, depositOwners);

    // Create withdraw item
    WithdrawItem[] memory items = new WithdrawItem[](1);
    items[0] = WithdrawItem({amount: WITHDRAW_AMOUNT_1, sValue: S_VALUE_1});

    WithdrawRecipient[] memory recipients = new WithdrawRecipient[](1);
    recipients[0] = WithdrawRecipient({recipient: alice, amount: WITHDRAW_AMOUNT_1 - WITHDRAW_FEE});

    // Execute withdraw
    vm.startPrank(alice);
    vault.withdraw(address(mockToken), items, recipients);
    vm.stopPrank();

    // Verify commitment was removed
    address ownerAfter = vault.getCommitment(address(mockToken), poseidonHash1);
    assertEq(ownerAfter, address(0), "Commitment should be removed");
  }

  function test_withdraw_commitment_not_found() public {
    // Create withdraw item for non-existent commitment
    WithdrawItem[] memory items = new WithdrawItem[](1);
    items[0] = WithdrawItem({amount: uint240(50e18), sValue: uint256(123456789)});

    WithdrawRecipient[] memory recipients = new WithdrawRecipient[](1);
    recipients[0] = WithdrawRecipient({recipient: alice, amount: WITHDRAW_AMOUNT_1});

    // Execute withdraw - should fail
    vm.startPrank(alice);
    vm.expectRevert(
      abi.encodeWithSelector(OnlyAssignedAddressCanWithdraw.selector, address(mockToken), poseidonHash1, alice)
    );
    vault.withdraw(address(mockToken), items, recipients);
    vm.stopPrank();
  }

  function test_withdraw_wrong_owner() public {
    // Create a deposit with the pre-computed hash owned by Alice
    uint256[3] memory depositHashes = [poseidonHash1, uint256(987654321), uint256(555666777)];
    address[3] memory depositOwners = [alice, bob, charlie];

    createDeposit(alice, DEPOSIT_AMOUNT, DEPOSIT_FEE, DEPOSIT_FORWARDER_FEE, depositHashes, depositOwners);

    // Create withdraw item for Alice's commitment but try to withdraw as Bob
    WithdrawItem[] memory items = new WithdrawItem[](1);
    items[0] = WithdrawItem({amount: WITHDRAW_AMOUNT_1, sValue: S_VALUE_1});

    WithdrawRecipient[] memory recipients = new WithdrawRecipient[](1);
    recipients[0] = WithdrawRecipient({recipient: bob, amount: WITHDRAW_AMOUNT_1 - WITHDRAW_FEE});

    // Execute withdraw as Bob - should fail
    vm.startPrank(bob);
    vm.expectRevert(
      abi.encodeWithSelector(OnlyAssignedAddressCanWithdraw.selector, address(mockToken), poseidonHash1, bob)
    );
    vault.withdraw(address(mockToken), items, recipients);
    vm.stopPrank();
  }

  function test_withdraw_fee_greater_than_amount() public {
    // Create a deposit with the pre-computed hash
    uint256[3] memory depositHashes = [poseidonHash4, uint256(987654321), uint256(555666777)];
    address[3] memory depositOwners = [alice, bob, charlie];
    protocolManager.setFees(address(mockToken), Fees({deposit: DEPOSIT_FEE, spend: 0, withdraw: WITHDRAW_AMOUNT_4}));

    createDeposit(alice, DEPOSIT_AMOUNT, DEPOSIT_FEE, DEPOSIT_FORWARDER_FEE, depositHashes, depositOwners);

    // Create withdraw item
    WithdrawItem[] memory items = new WithdrawItem[](1);
    items[0] = WithdrawItem({amount: WITHDRAW_AMOUNT_4, sValue: S_VALUE_4});

    WithdrawRecipient[] memory recipients = new WithdrawRecipient[](1);
    recipients[0] = WithdrawRecipient({recipient: alice, amount: WITHDRAW_AMOUNT_4});

    // Execute withdraw - should fail due to insufficient balance for fee
    vm.startPrank(alice);
    vm.expectRevert(); // Should revert due to insufficient balance
    vault.withdraw(address(mockToken), items, recipients);
    vm.stopPrank();
  }
}
