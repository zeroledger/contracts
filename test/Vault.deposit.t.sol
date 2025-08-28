// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import {VaultTest} from "./VaultTest.util.sol";
import {DepositParams, DepositCommitmentParams} from "src/Vault.types.sol";
import {IVaultEvents} from "src/Vault.sol";

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

contract VaultDepositTest is VaultTest, IVaultEvents {
  function setUp() public {
    baseSetup();
  }

  uint240 public constant defaultTotalAmount = uint240(100e18);
  uint240 public constant defaultFee = uint240(5e18);
  uint240 public constant defaultDepositAmount = defaultTotalAmount - defaultFee;

  // Fuzzy test for various deposit amounts and fee scenarios
  function testFuzz_deposit_amounts_and_fees(uint256 totalAmount, uint256 feePercentage) public {
    vm.assume(type(uint240).max >= totalAmount && totalAmount > 1);
    vm.assume(feePercentage < 100);
    uint240 fee = uint240(Math.mulDiv(totalAmount, feePercentage, 100));
    uint240 depositAmount = uint240(totalAmount - fee);

    // Ensure Alice has enough tokens for this test
    if (mockToken.balanceOf(alice) < totalAmount) {
      mockToken.mint(alice, totalAmount);
    }

    uint256 aliceInitialBalance = mockToken.balanceOf(alice);
    uint256 vaultInitialBalance = mockToken.balanceOf(address(vault));
    uint256 feeRecipientInitialBalance = mockToken.balanceOf(feeRecipient);

    createDeposit(
      alice, depositAmount, fee, [uint256(123456789), uint256(987654321), uint256(555666777)], [alice, bob, charlie]
    );

    // Verify balances
    assertEq(mockToken.balanceOf(alice), aliceInitialBalance - totalAmount, "Alice balance should be reduced");
    assertEq(
      mockToken.balanceOf(address(vault)), vaultInitialBalance + depositAmount, "Vault should receive deposit amount"
    );
    assertEq(
      mockToken.balanceOf(feeRecipient), feeRecipientInitialBalance + fee, "Fee recipient should receive correct fee"
    );

    // Verify commitments were created
    (address owner1,) = vault.getCommitment(address(mockToken), 123456789);
    (address owner2,) = vault.getCommitment(address(mockToken), 987654321);
    (address owner3,) = vault.getCommitment(address(mockToken), 555666777);

    assertEq(owner1, alice, "Commitment 1 should be assigned to Alice");
    assertEq(owner2, bob, "Commitment 2 should be assigned to Bob");
    assertEq(owner3, charlie, "Commitment 3 should be assigned to Charlie");

    vm.stopPrank();
  }

  // Test deposit with shared input (zero hash)
  function test_deposit_with_shared_input() public {
    depositVerifier.setVerificationResult(true);

    DepositCommitmentParams[3] memory commitmentParams;
    commitmentParams[0] = DepositCommitmentParams({poseidonHash: 123456789, owner: alice, metadata: "metadata1"});
    commitmentParams[1] = DepositCommitmentParams({
      poseidonHash: 16345784317541686154474118656352090725662212393131703302641232392927716723243,
      owner: bob,
      metadata: "metadata2"
    }); // Shared input
    commitmentParams[2] = DepositCommitmentParams({poseidonHash: 555666777, owner: charlie, metadata: "metadata3"});

    DepositParams memory depositParams = DepositParams({
      token: address(mockToken),
      total_deposit_amount: defaultDepositAmount,
      depositCommitmentParams: commitmentParams,
      fee: defaultFee,
      feeRecipient: feeRecipient
    });

    uint256[24] memory proof = getDummyProof();

    vm.startPrank(alice);
    mockToken.approve(address(vault), defaultTotalAmount);

    vault.deposit(depositParams, proof);

    // Verify only non-shared commitments were created
    (address owner1,) = vault.getCommitment(address(mockToken), 123456789);
    (address owner2,) = vault.getCommitment(
      address(mockToken), 16345784317541686154474118656352090725662212393131703302641232392927716723243
    );
    (address owner3,) = vault.getCommitment(address(mockToken), 555666777);

    assertEq(owner1, alice, "Commitment 1 should be assigned to Alice");
    assertEq(owner2, address(0), "Shared input should not create commitment");
    assertEq(owner3, charlie, "Commitment 3 should be assigned to Charlie");

    vm.stopPrank();
  }

  // Test deposit with same owner for all commitments
  function test_deposit_same_owner_all_commitments() public {
    createDeposit(
      alice,
      defaultDepositAmount,
      defaultFee,
      [uint256(123456789), uint256(987654321), uint256(555666777)],
      [alice, alice, alice]
    );

    // Verify all commitments were created for Alice
    (address owner1,) = vault.getCommitment(address(mockToken), 123456789);
    (address owner2,) = vault.getCommitment(address(mockToken), 987654321);
    (address owner3,) = vault.getCommitment(address(mockToken), 555666777);

    assertEq(owner1, alice, "Commitment 1 should be assigned to Alice");
    assertEq(owner2, alice, "Commitment 2 should be assigned to Alice");
    assertEq(owner3, alice, "Commitment 3 should be assigned to Alice");

    vm.stopPrank();
  }

  // Test deposit with empty metadata
  function test_deposit_empty_metadata() public {
    depositVerifier.setVerificationResult(true);

    DepositCommitmentParams[3] memory commitmentParams;
    commitmentParams[0] = DepositCommitmentParams({poseidonHash: 123456789, owner: alice, metadata: ""});
    commitmentParams[1] = DepositCommitmentParams({poseidonHash: 987654321, owner: bob, metadata: ""});
    commitmentParams[2] = DepositCommitmentParams({poseidonHash: 555666777, owner: charlie, metadata: ""});

    DepositParams memory depositParams = DepositParams({
      token: address(mockToken),
      total_deposit_amount: defaultDepositAmount,
      depositCommitmentParams: commitmentParams,
      fee: defaultFee,
      feeRecipient: feeRecipient
    });

    uint256[24] memory proof = getDummyProof();

    vm.startPrank(alice);
    mockToken.approve(address(vault), defaultTotalAmount);

    vault.deposit(depositParams, proof);

    // Verify commitments were created
    (address owner1,) = vault.getCommitment(address(mockToken), 123456789);
    (address owner2,) = vault.getCommitment(address(mockToken), 987654321);
    (address owner3,) = vault.getCommitment(address(mockToken), 555666777);

    assertEq(owner1, alice, "Commitment 1 should be assigned to Alice");
    assertEq(owner2, bob, "Commitment 2 should be assigned to Bob");
    assertEq(owner3, charlie, "Commitment 3 should be assigned to Charlie");

    vm.stopPrank();
  }

  // Test deposit with zero amount (should fail)
  function test_deposit_zero_amount() public {
    depositVerifier.setVerificationResult(true);

    DepositCommitmentParams[3] memory commitmentParams;
    commitmentParams[0] = DepositCommitmentParams({poseidonHash: 123456789, owner: alice, metadata: "metadata1"});
    commitmentParams[1] = DepositCommitmentParams({poseidonHash: 987654321, owner: bob, metadata: "metadata2"});
    commitmentParams[2] = DepositCommitmentParams({poseidonHash: 555666777, owner: charlie, metadata: "metadata3"});

    DepositParams memory depositParams = DepositParams({
      token: address(mockToken),
      total_deposit_amount: 0,
      depositCommitmentParams: commitmentParams,
      fee: defaultFee,
      feeRecipient: feeRecipient
    });

    uint256[24] memory proof = getDummyProof();

    vm.startPrank(alice);
    mockToken.approve(address(vault), defaultTotalAmount);

    vm.expectRevert("Vault: Amount must be greater than 0");
    vault.deposit(depositParams, proof);

    vm.stopPrank();
  }

  // Test deposit with invalid token address (should fail)
  function test_deposit_invalid_token() public {
    depositVerifier.setVerificationResult(true);

    DepositCommitmentParams[3] memory commitmentParams;
    commitmentParams[0] = DepositCommitmentParams({poseidonHash: 123456789, owner: alice, metadata: "metadata1"});
    commitmentParams[1] = DepositCommitmentParams({poseidonHash: 987654321, owner: bob, metadata: "metadata2"});
    commitmentParams[2] = DepositCommitmentParams({poseidonHash: 555666777, owner: charlie, metadata: "metadata3"});

    DepositParams memory depositParams = DepositParams({
      token: address(0), // Invalid token address
      total_deposit_amount: defaultDepositAmount,
      depositCommitmentParams: commitmentParams,
      fee: defaultFee,
      feeRecipient: feeRecipient
    });

    uint256[24] memory proof = getDummyProof();

    vm.startPrank(alice);
    mockToken.approve(address(vault), defaultTotalAmount);

    vm.expectRevert("Vault: Invalid token address");
    vault.deposit(depositParams, proof);

    vm.stopPrank();
  }

  // Test deposit with invalid ZK proof (should fail)
  function test_deposit_invalid_proof() public {
    depositVerifier.setVerificationResult(false); // Set to false to simulate invalid proof

    DepositCommitmentParams[3] memory commitmentParams;
    commitmentParams[0] = DepositCommitmentParams({poseidonHash: 123456789, owner: alice, metadata: "metadata1"});
    commitmentParams[1] = DepositCommitmentParams({poseidonHash: 987654321, owner: bob, metadata: "metadata2"});
    commitmentParams[2] = DepositCommitmentParams({poseidonHash: 555666777, owner: charlie, metadata: "metadata3"});

    DepositParams memory depositParams = DepositParams({
      token: address(mockToken),
      total_deposit_amount: defaultDepositAmount,
      depositCommitmentParams: commitmentParams,
      fee: defaultFee,
      feeRecipient: feeRecipient
    });

    uint256[24] memory proof = getDummyProof();

    vm.startPrank(alice);
    mockToken.approve(address(vault), defaultTotalAmount);

    vm.expectRevert("Vault: Invalid ZK proof");
    vault.deposit(depositParams, proof);

    vm.stopPrank();
  }

  // Test deposit with reused commitment (should fail)
  function test_deposit_reused_commitment() public {
    depositVerifier.setVerificationResult(true);

    DepositCommitmentParams[3] memory commitmentParams;
    commitmentParams[0] = DepositCommitmentParams({poseidonHash: 123456789, owner: alice, metadata: "metadata1"});
    commitmentParams[1] = DepositCommitmentParams({poseidonHash: 987654321, owner: bob, metadata: "metadata2"});
    commitmentParams[2] = DepositCommitmentParams({poseidonHash: 555666777, owner: charlie, metadata: "metadata3"});

    DepositParams memory depositParams = DepositParams({
      token: address(mockToken),
      total_deposit_amount: defaultDepositAmount,
      depositCommitmentParams: commitmentParams,
      fee: defaultFee,
      feeRecipient: feeRecipient
    });

    uint256[24] memory proof = getDummyProof();

    vm.startPrank(alice);
    mockToken.approve(address(vault), defaultTotalAmount);

    // First deposit should succeed
    vault.deposit(depositParams, proof);

    // Second deposit with same commitments should fail
    vm.expectRevert("Vault: Commitment already used");
    vault.deposit(depositParams, proof);

    vm.stopPrank();
  }

  // Test deposit with insufficient allowance (should fail)
  function test_deposit_insufficient_allowance() public {
    depositVerifier.setVerificationResult(true);

    DepositCommitmentParams[3] memory commitmentParams;
    commitmentParams[0] = DepositCommitmentParams({poseidonHash: 123456789, owner: alice, metadata: "metadata1"});
    commitmentParams[1] = DepositCommitmentParams({poseidonHash: 987654321, owner: bob, metadata: "metadata2"});
    commitmentParams[2] = DepositCommitmentParams({poseidonHash: 555666777, owner: charlie, metadata: "metadata3"});

    DepositParams memory depositParams = DepositParams({
      token: address(mockToken),
      total_deposit_amount: defaultDepositAmount,
      depositCommitmentParams: commitmentParams,
      fee: defaultFee,
      feeRecipient: feeRecipient
    });

    uint256[24] memory proof = getDummyProof();

    vm.startPrank(alice);
    mockToken.approve(address(vault), defaultTotalAmount - 1); // Approve less than needed

    vm.expectRevert(); // Should revert due to insufficient allowance
    vault.deposit(depositParams, proof);

    vm.stopPrank();
  }

  // Test deposit with insufficient balance (should fail)
  function test_deposit_insufficient_balance() public {
    depositVerifier.setVerificationResult(true);

    DepositCommitmentParams[3] memory commitmentParams;
    commitmentParams[0] = DepositCommitmentParams({poseidonHash: 123456789, owner: alice, metadata: "metadata1"});
    commitmentParams[1] = DepositCommitmentParams({poseidonHash: 987654321, owner: bob, metadata: "metadata2"});
    commitmentParams[2] = DepositCommitmentParams({poseidonHash: 555666777, owner: charlie, metadata: "metadata3"});

    DepositParams memory depositParams = DepositParams({
      token: address(mockToken),
      total_deposit_amount: defaultDepositAmount,
      depositCommitmentParams: commitmentParams,
      fee: defaultFee,
      feeRecipient: feeRecipient
    });

    uint256[24] memory proof = getDummyProof();

    vm.startPrank(alice);
    mockToken.approve(address(vault), defaultTotalAmount);

    // Burn Alice's tokens to make balance insufficient
    vm.startPrank(alice);
    mockToken.burn(mockToken.balanceOf(alice) - defaultTotalAmount + 1);
    vm.stopPrank();
    vm.startPrank(bob); // Continue with Bob as the prank

    vm.expectRevert(); // Should revert due to insufficient balance
    vault.deposit(depositParams, proof);

    vm.stopPrank();
  }

  // Test deposit from different user than commitment owner
  function test_deposit_different_user_than_commitment_owner() public {
    depositVerifier.setVerificationResult(true);

    DepositCommitmentParams[3] memory commitmentParams;
    commitmentParams[0] = DepositCommitmentParams({poseidonHash: 123456789, owner: alice, metadata: "metadata1"});
    commitmentParams[1] = DepositCommitmentParams({poseidonHash: 987654321, owner: bob, metadata: "metadata2"});
    commitmentParams[2] = DepositCommitmentParams({poseidonHash: 555666777, owner: charlie, metadata: "metadata3"});

    DepositParams memory depositParams = DepositParams({
      token: address(mockToken),
      total_deposit_amount: defaultDepositAmount,
      depositCommitmentParams: commitmentParams,
      fee: defaultFee,
      feeRecipient: feeRecipient
    });

    uint256[24] memory proof = getDummyProof();

    // Bob deposits but commitments are for Alice, Bob, and Charlie
    vm.startPrank(bob);
    mockToken.approve(address(vault), defaultTotalAmount);

    vault.deposit(depositParams, proof);

    // Verify commitments were created correctly despite different depositor
    (address owner1,) = vault.getCommitment(address(mockToken), 123456789);
    (address owner2,) = vault.getCommitment(address(mockToken), 987654321);
    (address owner3,) = vault.getCommitment(address(mockToken), 555666777);

    assertEq(owner1, alice, "Commitment 1 should be assigned to Alice");
    assertEq(owner2, bob, "Commitment 2 should be assigned to Bob");
    assertEq(owner3, charlie, "Commitment 3 should be assigned to Charlie");

    vm.stopPrank();
  }

  // Test deposit events emission
  function test_deposit_events() public {
    uint240 depositAmount = uint240(100e18);
    uint240 fee = uint240(5e18);
    uint240 totalAmount = depositAmount + fee;

    depositVerifier.setVerificationResult(true);

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

    uint256[24] memory proof = getDummyProof();

    vm.startPrank(alice);
    mockToken.approve(address(vault), totalAmount);

    // Expect events to be emitted (in the order they are actually emitted)
    vm.expectEmit(true, true, false, true);
    emit CommitmentCreated(alice, address(mockToken), 123456789, "metadata1");

    vm.expectEmit(true, true, false, true);
    emit CommitmentCreated(bob, address(mockToken), 987654321, "metadata2");

    vm.expectEmit(true, true, false, true);
    emit CommitmentCreated(charlie, address(mockToken), 555666777, "metadata3");

    vm.expectEmit(true, true, false, true);
    emit TokenDeposited(alice, address(mockToken), depositAmount, fee);

    vault.deposit(depositParams, proof);
    vm.stopPrank();
  }
}
