// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.21;

// solhint-disable no-global-import
// solhint-disable no-console

import "@std/Test.sol";

import {
  Spend11Verifier,
  Spend12Verifier,
  Spend13Verifier,
  Spend21Verifier,
  Spend22Verifier,
  Spend23Verifier,
  Spend31Verifier,
  Spend32Verifier,
  Spend33Verifier,
  Spend81Verifier,
  Spend161Verifier,
  Verifiers
} from "src/Verifiers.sol";
import {Vault, ERC2771Forwarder} from "src/Vault.sol";
import {MockERC20} from "src/helpers/MockERC20.sol";
import {DepositParams, DepositCommitmentParams} from "src/Vault.types.sol";
import {VaultProxy} from "src/helpers/Vault.proxy.sol";
import {MockVerifier} from "src/helpers/MockVerifier.sol";

// solhint-disable max-states-count
contract VaultTest is Test {
  Vault private vault;
  MockVerifier private depositVerifier;
  MockVerifier private spend11Verifier;
  MockVerifier private spend12Verifier;
  MockVerifier private spend13Verifier;
  MockVerifier private spend21Verifier;
  MockVerifier private spend22Verifier;
  MockVerifier private spend23Verifier;
  MockVerifier private spend31Verifier;
  MockVerifier private spend32Verifier;
  MockVerifier private spend33Verifier;
  MockVerifier private spend81Verifier;
  MockVerifier private spend161Verifier;
  ERC2771Forwarder private zeroLedgerForwarder;
  MockERC20 private mockToken;

  address private alice = address(0x1);
  address private bob = address(0x2);
  address private charlie = address(0x3);
  address private feeRecipient = address(0x4);

  function setUp() public {
    depositVerifier = new MockVerifier();
    spend11Verifier = new MockVerifier();
    spend12Verifier = new MockVerifier();
    spend13Verifier = new MockVerifier();
    spend21Verifier = new MockVerifier();
    spend22Verifier = new MockVerifier();
    spend23Verifier = new MockVerifier();
    spend31Verifier = new MockVerifier();
    spend32Verifier = new MockVerifier();
    spend33Verifier = new MockVerifier();
    spend81Verifier = new MockVerifier();
    spend161Verifier = new MockVerifier();
    zeroLedgerForwarder = new ERC2771Forwarder("ZeroLedgerForwarder");
    Verifiers verifiers = new Verifiers(
      address(depositVerifier),
      address(spend11Verifier),
      address(spend12Verifier),
      address(spend13Verifier),
      address(spend21Verifier),
      address(spend22Verifier),
      address(spend23Verifier),
      address(spend31Verifier),
      address(spend32Verifier),
      address(spend33Verifier),
      address(spend81Verifier),
      address(spend161Verifier)
    );

    VaultProxy proxy = new VaultProxy(address(vault = new Vault()), "");

    vault = Vault(address(proxy));
    vault.initialize(address(verifiers), address(zeroLedgerForwarder));
    mockToken = new MockERC20("Test Token", "TEST");

    // Mint tokens to test addresses
    mockToken.mint(alice, 1000e18);
    mockToken.mint(bob, 1000e18);
    mockToken.mint(charlie, 1000e18);
  }

  function getDummyProof() public pure returns (uint256[24] memory) {
    uint256[24] memory proof;
    for (uint256 i = 0; i < 24; i++) {
      proof[i] = i + 1;
    }
    return proof;
  }

  // ============ computePoseidonHash Tests ============

  function test_computePoseidonHash() public view {
    uint256 amount = 1000000000000000000;
    uint256 sValue = 1000000000000000000;
    uint256 hash = vault.computePoseidonHash(amount, sValue);
    assertEq(hash, 15196373595714768051696025584583401928266812183015116537231151879335506775479);
  }

  function test_computePoseidonHash_zeroValues() public view {
    uint256 hash = vault.computePoseidonHash(0, 0);
    assertEq(hash, 14744269619966411208579211824598458697587494354926760081771325075741142829156);
  }

  function test_computePoseidonHash_largeValues() public view {
    uint256 amount = type(uint256).max;
    uint256 sValue = type(uint256).max - 1;
    uint256 hash = vault.computePoseidonHash(amount, sValue);
    assertTrue(hash != 0);
  }

  // ============ Deposit Tests ============

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
