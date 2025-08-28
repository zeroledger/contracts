// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.21;

import {VaultTest} from "./VaultTest.util.sol";
import {DepositParams, DepositCommitmentParams} from "src/Vault.types.sol";

contract VaultDepositTest is VaultTest {
  function setUp() public {
    baseSetup();
  }

  function test_deposit_success() public {
    depositVerifier.setVerificationResult(true);
    // Setup deposit parameters
    uint256 depositAmount = 100e18;
    uint256 fee = 5e18;
    uint256 totalAmount = depositAmount + fee;

    // Create commitment parameters with unique poseidon hashes
    DepositCommitmentParams[3] memory commitmentParams;
    commitmentParams[0] = DepositCommitmentParams({poseidonHash: 123456789, owner: alice, metadata: "metadata1"});
    commitmentParams[1] = DepositCommitmentParams({poseidonHash: 987654321, owner: bob, metadata: "metadata2"});
    commitmentParams[2] = DepositCommitmentParams({poseidonHash: 555666777, owner: charlie, metadata: "metadata3"});

    DepositParams memory depositParams = DepositParams({
      token: address(mockToken),
      total_deposit_amount: depositAmount,
      depositCommitmentParams: commitmentParams,
      fee: fee,
      feeRecipient: feeRecipient
    });

    // Create a dummy proof (24 uint256 values)
    uint256[24] memory proof = getDummyProof();

    // Approve tokens for the vault
    vm.startPrank(alice);
    mockToken.approve(address(vault), totalAmount);

    // Record initial balances
    uint256 aliceInitialBalance = mockToken.balanceOf(alice);
    uint256 vaultInitialBalance = mockToken.balanceOf(address(vault));
    uint256 feeRecipientInitialBalance = mockToken.balanceOf(feeRecipient);

    // Perform deposit
    vault.deposit(depositParams, proof);

    // Verify balances after deposit
    assertEq(mockToken.balanceOf(alice), aliceInitialBalance - totalAmount, "Alice balance should be reduced");
    assertEq(
      mockToken.balanceOf(address(vault)), vaultInitialBalance + depositAmount, "Vault should receive deposit amount"
    );
    assertEq(mockToken.balanceOf(feeRecipient), feeRecipientInitialBalance + fee, "Fee recipient should receive fee");

    // Verify commitments were created
    (address owner1, bool locked1) = vault.getCommitment(address(mockToken), 123456789);
    (address owner2, bool locked2) = vault.getCommitment(address(mockToken), 987654321);
    (address owner3, bool locked3) = vault.getCommitment(address(mockToken), 555666777);

    assertEq(owner1, alice, "Commitment 1 should be assigned to Alice");
    assertEq(owner2, bob, "Commitment 2 should be assigned to Bob");
    assertEq(owner3, charlie, "Commitment 3 should be assigned to Charlie");
    assertFalse(locked1, "Commitment 1 should not be locked");
    assertFalse(locked2, "Commitment 2 should not be locked");
    assertFalse(locked3, "Commitment 3 should not be locked");

    vm.stopPrank();
  }
}
