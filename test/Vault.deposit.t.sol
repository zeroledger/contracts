// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import {VaultTest} from "./VaultTest.util.sol";
import {DepositParams, DepositCommitmentParams, IVaultErrors} from "src/Vault.types.sol";
import {Fees} from "src/ProtocolManager.sol";
import {IVaultEvents} from "src/Vault.types.sol";
import {PermitUtils} from "./Permit.util.sol";

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

contract VaultDepositTest is VaultTest, IVaultEvents {
  uint240 public constant defaultTotalAmount = uint240(100e18);
  uint240 public constant defaultFee = uint240(5e18);
  uint240 public constant defaultForwarderFee = uint240(5e18);
  uint240 public constant defaultDepositAmount = defaultTotalAmount - defaultFee - defaultForwarderFee;

  function setUp() public {
    baseSetup();
    protocolManager.setFees(address(mockToken), Fees({deposit: defaultFee, spend: 0, withdraw: 0}));
  }

  // Fuzzy test for various deposit amounts and fee scenarios
  function testFuzz_deposit_amounts_and_fees(uint256 totalAmount, uint16 feePercentage, uint16 split) public {
    vm.assume(type(uint240).max >= totalAmount && totalAmount > 1e18);
    vm.assume(feePercentage < 100);
    vm.assume(split <= 100);
    uint240 totalFee = uint240(Math.mulDiv(totalAmount, feePercentage, 100));
    uint240 fee = uint240(Math.mulDiv(totalFee, split, 100));
    uint240 forwarderFee = totalFee - fee;
    uint240 depositAmount = uint240(totalAmount - fee - forwarderFee);
    protocolManager.setFees(address(mockToken), Fees({deposit: fee, spend: 0, withdraw: 0}));

    // Ensure Alice has enough tokens for this test
    if (mockToken.balanceOf(alice) < totalAmount) {
      mockToken.mint(alice, totalAmount);
    }

    uint256 aliceInitialBalance = mockToken.balanceOf(alice);
    uint256 vaultInitialBalance = mockToken.balanceOf(address(vault));
    uint256 forwarderFeeRecipientInitialBalance = mockToken.balanceOf(address(zeroLedgerForwarder));

    createDeposit(
      alice,
      depositAmount,
      fee,
      forwarderFee,
      [uint256(123456789), uint256(987654321), uint256(555666777)],
      [alice, bob, charlie]
    );

    // Verify balances
    assertEq(mockToken.balanceOf(alice), aliceInitialBalance - totalAmount, "Alice balance should be reduced");
    assertEq(
      mockToken.balanceOf(address(vault)), vaultInitialBalance + depositAmount, "Vault should receive deposit amount"
    );
    assertEq(mockToken.balanceOf(address(protocolManager)), fee, "ProtocolManager should receive correct fee");
    assertEq(
      mockToken.balanceOf(address(zeroLedgerForwarder)),
      forwarderFeeRecipientInitialBalance + forwarderFee,
      "Forwarder fee recipient should receive correct fee"
    );
    // Verify commitments were created
    address owner1 = vault.getCommitment(address(mockToken), 123456789);
    address owner2 = vault.getCommitment(address(mockToken), 987654321);
    address owner3 = vault.getCommitment(address(mockToken), 555666777);

    assertEq(owner1, alice, "Commitment 1 should be assigned to Alice");
    assertEq(owner2, bob, "Commitment 2 should be assigned to Bob");
    assertEq(owner3, charlie, "Commitment 3 should be assigned to Charlie");

    vm.stopPrank();
  }

  function test_deposit_with_shared_input() public {
    depositVerifier.setVerificationResult(true);

    DepositCommitmentParams[3] memory commitmentParams;
    commitmentParams[0] = DepositCommitmentParams({poseidonHash: 123456789, owner: alice, metadata: "metadata1"});
    commitmentParams[1] = DepositCommitmentParams({
      poseidonHash: 15137436504035450233189320721078414488136960400594787218856438198681086299747,
      owner: bob,
      metadata: "metadata2"
    }); // Shared input
    commitmentParams[2] = DepositCommitmentParams({poseidonHash: 555666777, owner: charlie, metadata: "metadata3"});

    DepositParams memory depositParams = DepositParams({
      token: address(mockToken),
      amount: defaultTotalAmount, // Now includes all fees
      depositCommitmentParams: commitmentParams,
      forwarderFee: defaultForwarderFee,
      forwarderFeeRecipient: address(zeroLedgerForwarder)
    });

    uint256[24] memory proof = getDummyProof();

    vm.startPrank(alice);
    mockToken.approve(address(vault), defaultTotalAmount);

    vault.deposit(depositParams, proof);

    // Verify only non-shared commitments were created
    address owner1 = vault.getCommitment(address(mockToken), 123456789);
    address owner2 = vault.getCommitment(
      address(mockToken), 15137436504035450233189320721078414488136960400594787218856438198681086299747
    );
    address owner3 = vault.getCommitment(address(mockToken), 555666777);

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
      defaultForwarderFee,
      [uint256(123456789), uint256(987654321), uint256(555666777)],
      [alice, alice, alice]
    );

    // Verify all commitments were created for Alice
    address owner1 = vault.getCommitment(address(mockToken), 123456789);
    address owner2 = vault.getCommitment(address(mockToken), 987654321);
    address owner3 = vault.getCommitment(address(mockToken), 555666777);

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
      amount: defaultTotalAmount, // Now includes all fees
      depositCommitmentParams: commitmentParams,
      forwarderFee: defaultForwarderFee,
      forwarderFeeRecipient: address(zeroLedgerForwarder)
    });

    uint256[24] memory proof = getDummyProof();

    vm.startPrank(alice);
    mockToken.approve(address(vault), defaultTotalAmount);

    vault.deposit(depositParams, proof);

    // Verify commitments were created
    address owner1 = vault.getCommitment(address(mockToken), 123456789);
    address owner2 = vault.getCommitment(address(mockToken), 987654321);
    address owner3 = vault.getCommitment(address(mockToken), 555666777);

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
      amount: 0,
      depositCommitmentParams: commitmentParams,
      forwarderFee: defaultForwarderFee,
      forwarderFeeRecipient: address(zeroLedgerForwarder)
    });

    uint256[24] memory proof = getDummyProof();

    vm.startPrank(alice);
    mockToken.approve(address(vault), defaultTotalAmount);

    vm.expectRevert(abi.encodeWithSelector(AmountMustBeGreaterThanZero.selector));
    vault.deposit(depositParams, proof);

    vm.stopPrank();
  }

  // Test deposit exceeding max TVL (should fail)
  function test_deposit_exceeds_max_tvl_reverts() public {
    depositVerifier.setVerificationResult(true);

    // Set max TVL lower than the intended deposit amount
    protocolManager.setMaxTVL(prepareTvlConfig(defaultDepositAmount - 1));

    DepositCommitmentParams[3] memory commitmentParams;
    commitmentParams[0] = DepositCommitmentParams({poseidonHash: 123456789, owner: alice, metadata: "metadata1"});
    commitmentParams[1] = DepositCommitmentParams({poseidonHash: 987654321, owner: bob, metadata: "metadata2"});
    commitmentParams[2] = DepositCommitmentParams({poseidonHash: 555666777, owner: charlie, metadata: "metadata3"});

    DepositParams memory depositParams = DepositParams({
      token: address(mockToken),
      amount: defaultTotalAmount, // Now includes all fees
      depositCommitmentParams: commitmentParams,
      forwarderFee: defaultForwarderFee,
      forwarderFeeRecipient: address(zeroLedgerForwarder)
    });

    uint256[24] memory proof = getDummyProof();

    vm.startPrank(alice);
    mockToken.approve(address(vault), defaultTotalAmount);

    vm.expectRevert(
      abi.encodeWithSelector(AmountExceedsMaxTVL.selector, 0, defaultDepositAmount, defaultDepositAmount - 1)
    );
    vault.deposit(depositParams, proof);

    vm.stopPrank();
  }

  // Test deposit exactly at max TVL (should succeed)
  function test_deposit_equals_max_tvl_succeeds() public {
    depositVerifier.setVerificationResult(true);

    // Set max TVL exactly equal to the intended deposit amount
    protocolManager.setMaxTVL(prepareTvlConfig(defaultDepositAmount));

    DepositCommitmentParams[3] memory commitmentParams;
    commitmentParams[0] = DepositCommitmentParams({poseidonHash: 123456789, owner: alice, metadata: "metadata1"});
    commitmentParams[1] = DepositCommitmentParams({poseidonHash: 987654321, owner: bob, metadata: "metadata2"});
    commitmentParams[2] = DepositCommitmentParams({poseidonHash: 555666777, owner: charlie, metadata: "metadata3"});

    DepositParams memory depositParams = DepositParams({
      token: address(mockToken),
      amount: defaultTotalAmount, // Now includes all fees
      depositCommitmentParams: commitmentParams,
      forwarderFee: defaultForwarderFee,
      forwarderFeeRecipient: address(zeroLedgerForwarder)
    });

    uint256[24] memory proof = getDummyProof();

    vm.startPrank(alice);
    mockToken.approve(address(vault), defaultTotalAmount);

    vault.deposit(depositParams, proof);

    // Basic post-conditions: vault balance increased by deposit amount
    assertEq(mockToken.balanceOf(address(vault)), defaultDepositAmount, "Vault should hold the deposited amount");

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
      amount: defaultTotalAmount, // Now includes all fees
      depositCommitmentParams: commitmentParams,
      forwarderFee: defaultForwarderFee,
      forwarderFeeRecipient: address(zeroLedgerForwarder)
    });

    uint256[24] memory proof = getDummyProof();

    vm.startPrank(alice);
    mockToken.approve(address(vault), defaultTotalAmount);

    vm.expectRevert(abi.encodeWithSelector(InvalidZKProof.selector));
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
      amount: defaultTotalAmount, // Now includes all fees
      depositCommitmentParams: commitmentParams,
      forwarderFee: defaultForwarderFee,
      forwarderFeeRecipient: address(zeroLedgerForwarder)
    });

    uint256[24] memory proof = getDummyProof();

    vm.startPrank(alice);
    mockToken.approve(address(vault), defaultTotalAmount);

    // First deposit should succeed
    vault.deposit(depositParams, proof);

    // Second deposit with same commitments should fail
    vm.expectRevert(abi.encodeWithSelector(CommitmentAlreadyUsed.selector, 123456789));
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
      amount: defaultTotalAmount, // Now includes all fees
      depositCommitmentParams: commitmentParams,
      forwarderFee: defaultForwarderFee,
      forwarderFeeRecipient: address(zeroLedgerForwarder)
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
      amount: defaultTotalAmount, // Now includes all fees
      depositCommitmentParams: commitmentParams,
      forwarderFee: defaultForwarderFee,
      forwarderFeeRecipient: address(zeroLedgerForwarder)
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
      amount: defaultTotalAmount, // Now includes all fees
      depositCommitmentParams: commitmentParams,
      forwarderFee: defaultForwarderFee,
      forwarderFeeRecipient: address(zeroLedgerForwarder)
    });

    uint256[24] memory proof = getDummyProof();

    // Bob deposits but commitments are for Alice, Bob, and Charlie
    vm.startPrank(bob);
    mockToken.approve(address(vault), defaultTotalAmount);

    vault.deposit(depositParams, proof);

    // Verify commitments were created correctly despite different depositor
    address owner1 = vault.getCommitment(address(mockToken), 123456789);
    address owner2 = vault.getCommitment(address(mockToken), 987654321);
    address owner3 = vault.getCommitment(address(mockToken), 555666777);

    assertEq(owner1, alice, "Commitment 1 should be assigned to Alice");
    assertEq(owner2, bob, "Commitment 2 should be assigned to Bob");
    assertEq(owner3, charlie, "Commitment 3 should be assigned to Charlie");

    vm.stopPrank();
  }

  // Test deposit events emission
  function test_deposit_events() public {
    depositVerifier.setVerificationResult(true);

    DepositCommitmentParams[3] memory commitmentParams;
    commitmentParams[0] = DepositCommitmentParams({poseidonHash: 123456789, owner: alice, metadata: "metadata1"});
    commitmentParams[1] = DepositCommitmentParams({poseidonHash: 987654321, owner: bob, metadata: "metadata2"});
    commitmentParams[2] = DepositCommitmentParams({poseidonHash: 555666777, owner: charlie, metadata: "metadata3"});

    DepositParams memory depositParams = DepositParams({
      token: address(mockToken),
      amount: defaultTotalAmount, // Now includes all fees
      depositCommitmentParams: commitmentParams,
      forwarderFee: defaultForwarderFee,
      forwarderFeeRecipient: address(zeroLedgerForwarder)
    });

    uint256[24] memory proof = getDummyProof();

    vm.startPrank(alice);
    mockToken.approve(address(vault), defaultTotalAmount);

    // Expect events to be emitted (in the order they are actually emitted)
    vm.expectEmit(true, true, false, true);
    emit CommitmentCreated(alice, address(mockToken), 123456789, "metadata1");

    vm.expectEmit(true, true, false, true);
    emit CommitmentCreated(bob, address(mockToken), 987654321, "metadata2");

    vm.expectEmit(true, true, false, true);
    emit CommitmentCreated(charlie, address(mockToken), 555666777, "metadata3");

    vm.expectEmit(true, true, false, true);
    emit Deposit(alice, address(mockToken), defaultDepositAmount);

    vault.deposit(depositParams, proof);
    vm.stopPrank();
  }

  // Test depositWithPermit with same owner for all commitments
  function test_depositWithPermit_same_owner_all_commitments() public {
    createDepositWithPermit(
      alice,
      defaultDepositAmount,
      defaultFee,
      defaultForwarderFee,
      [uint256(123456789), uint256(987654321), uint256(555666777)],
      [alice, alice, alice]
    );

    // Verify all commitments were created for Alice
    address owner1 = vault.getCommitment(address(mockToken), 123456789);
    address owner2 = vault.getCommitment(address(mockToken), 987654321);
    address owner3 = vault.getCommitment(address(mockToken), 555666777);

    assertEq(owner1, alice, "Commitment 1 should be assigned to Alice");
    assertEq(owner2, alice, "Commitment 2 should be assigned to Alice");
    assertEq(owner3, alice, "Commitment 3 should be assigned to Alice");
  }

  // Test depositWithPermit with different owners
  function test_depositWithPermit_different_owners() public {
    createDepositWithPermit(
      alice,
      defaultDepositAmount,
      defaultFee,
      defaultForwarderFee,
      [uint256(123456789), uint256(987654321), uint256(555666777)],
      [alice, bob, charlie]
    );

    // Verify commitments were created for different owners
    address owner1 = vault.getCommitment(address(mockToken), 123456789);
    address owner2 = vault.getCommitment(address(mockToken), 987654321);
    address owner3 = vault.getCommitment(address(mockToken), 555666777);

    assertEq(owner1, alice, "Commitment 1 should be assigned to Alice");
    assertEq(owner2, bob, "Commitment 2 should be assigned to Bob");
    assertEq(owner3, charlie, "Commitment 3 should be assigned to Charlie");
  }

  // Test depositWithPermit with expired permit (should fail)
  function test_depositWithPermit_expired_permit() public {
    depositVerifier.setVerificationResult(true);

    DepositCommitmentParams[3] memory commitmentParams;
    commitmentParams[0] = DepositCommitmentParams({poseidonHash: 123456789, owner: alice, metadata: "metadata1"});
    commitmentParams[1] = DepositCommitmentParams({poseidonHash: 987654321, owner: bob, metadata: "metadata2"});
    commitmentParams[2] = DepositCommitmentParams({poseidonHash: 555666777, owner: charlie, metadata: "metadata3"});

    DepositParams memory depositParams = DepositParams({
      token: address(mockToken),
      amount: defaultTotalAmount, // Now includes all fees
      depositCommitmentParams: commitmentParams,
      forwarderFee: defaultForwarderFee,
      forwarderFeeRecipient: address(zeroLedgerForwarder)
    });

    uint256[24] memory proof = getDummyProof();

    vm.startPrank(alice);
    // Create permit signature with expired deadline
    PermitUtils.Signature memory signature =
      doPermit(alice, address(vault), uint256(defaultTotalAmount), 0, block.timestamp - 1);

    vm.expectRevert(abi.encodeWithSelector(PermitExpired.selector));
    vault.depositWithPermit(
      depositParams,
      proof,
      block.timestamp - 1, // Expired deadline
      signature.v,
      signature.r,
      signature.s
    );
    vm.stopPrank();
  }

  // Test depositWithPermit with invalid permit signature (should fail)
  function test_depositWithPermit_invalid_signature() public {
    depositVerifier.setVerificationResult(true);

    DepositCommitmentParams[3] memory commitmentParams;
    commitmentParams[0] = DepositCommitmentParams({poseidonHash: 123456789, owner: alice, metadata: "metadata1"});
    commitmentParams[1] = DepositCommitmentParams({poseidonHash: 987654321, owner: bob, metadata: "metadata2"});
    commitmentParams[2] = DepositCommitmentParams({poseidonHash: 555666777, owner: charlie, metadata: "metadata3"});

    DepositParams memory depositParams = DepositParams({
      token: address(mockToken),
      amount: defaultTotalAmount, // Now includes all fees
      depositCommitmentParams: commitmentParams,
      forwarderFee: defaultForwarderFee,
      forwarderFeeRecipient: address(zeroLedgerForwarder)
    });

    uint256[24] memory proof = getDummyProof();

    vm.startPrank(alice);
    vm.expectRevert(); // Should revert due to invalid signature
    vault.depositWithPermit(
      depositParams,
      proof,
      block.timestamp + 1000,
      0, // Invalid v
      bytes32(0), // Invalid r
      bytes32(0) // Invalid s
    );
    vm.stopPrank();
  }

  // Test depositWithPermit events emission
  function test_depositWithPermit_events() public {
    depositVerifier.setVerificationResult(true);

    DepositCommitmentParams[3] memory commitmentParams;
    commitmentParams[0] = DepositCommitmentParams({poseidonHash: 123456789, owner: alice, metadata: "metadata1"});
    commitmentParams[1] = DepositCommitmentParams({poseidonHash: 987654321, owner: bob, metadata: "metadata2"});
    commitmentParams[2] = DepositCommitmentParams({poseidonHash: 555666777, owner: charlie, metadata: "metadata3"});

    DepositParams memory depositParams = DepositParams({
      token: address(mockToken),
      amount: defaultTotalAmount, // Now includes all fees
      depositCommitmentParams: commitmentParams,
      forwarderFee: defaultForwarderFee,
      forwarderFeeRecipient: address(zeroLedgerForwarder)
    });

    uint256[24] memory proof = getDummyProof();

    // Create permit signature
    PermitUtils.Signature memory signature =
      doPermit(alice, address(vault), uint256(defaultTotalAmount), 0, block.timestamp + 1000);

    // Expect events to be emitted
    vm.expectEmit(true, true, false, true);
    emit CommitmentCreated(alice, address(mockToken), 123456789, "metadata1");

    vm.expectEmit(true, true, false, true);
    emit CommitmentCreated(bob, address(mockToken), 987654321, "metadata2");

    vm.expectEmit(true, true, false, true);
    emit CommitmentCreated(charlie, address(mockToken), 555666777, "metadata3");

    vm.expectEmit(true, true, false, true);
    emit Deposit(alice, address(mockToken), defaultDepositAmount);

    vm.startPrank(alice);
    vault.depositWithPermit(depositParams, proof, block.timestamp + 1000, signature.v, signature.r, signature.s);
    vm.stopPrank();
  }

  // Fuzzy test for depositWithPermit with various amounts and fees
  function testFuzz_depositWithPermit_amounts_and_fees(uint256 totalAmount, uint16 feePercentage, uint16 split) public {
    vm.assume(type(uint240).max >= totalAmount && totalAmount > 1e18);
    vm.assume(feePercentage < 100);
    vm.assume(split <= 100);
    uint240 totalFee = uint240(Math.mulDiv(totalAmount, feePercentage, 100));
    uint240 fee = uint240(Math.mulDiv(totalFee, split, 100));
    uint240 forwarderFee = totalFee - fee;
    uint240 depositAmount = uint240(totalAmount - fee - forwarderFee);
    protocolManager.setFees(address(mockToken), Fees({deposit: fee, spend: 0, withdraw: 0}));

    // Ensure Alice has enough tokens for this test
    if (mockToken.balanceOf(alice) < totalAmount) {
      mockToken.mint(alice, totalAmount);
    }

    uint256 aliceInitialBalance = mockToken.balanceOf(alice);
    uint256 vaultInitialBalance = mockToken.balanceOf(address(vault));
    uint256 forwarderFeeRecipientInitialBalance = mockToken.balanceOf(address(zeroLedgerForwarder));

    createDepositWithPermit(
      alice,
      depositAmount,
      fee,
      forwarderFee,
      [uint256(123456789), uint256(987654321), uint256(555666777)],
      [alice, bob, charlie]
    );

    // Verify balances
    assertEq(mockToken.balanceOf(alice), aliceInitialBalance - totalAmount, "Alice balance should be reduced");
    assertEq(
      mockToken.balanceOf(address(vault)), vaultInitialBalance + depositAmount, "Vault should receive deposit amount"
    );
    assertEq(mockToken.balanceOf(address(protocolManager)), fee, "ProtocolManager should receive correct fee");
    assertEq(
      mockToken.balanceOf(address(zeroLedgerForwarder)),
      forwarderFeeRecipientInitialBalance + forwarderFee,
      "Forwarder fee recipient should receive correct fee"
    );
    // Verify commitments were created
    address owner1 = vault.getCommitment(address(mockToken), 123456789);
    address owner2 = vault.getCommitment(address(mockToken), 987654321);
    address owner3 = vault.getCommitment(address(mockToken), 555666777);

    assertEq(owner1, alice, "Commitment 1 should be assigned to Alice");
    assertEq(owner2, bob, "Commitment 2 should be assigned to Bob");
    assertEq(owner3, charlie, "Commitment 3 should be assigned to Charlie");
  }
}
