// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.20;

// solhint-disable no-global-import
// solhint-disable no-console

import "@std/Test.sol";

import {
  Vault,
  DepositVerifier,
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
  ERC2771Forwarder
} from "src/Vault.sol";
import {MockERC20} from "src/MockERC20.sol";
import {
  DepositParams,
  DepositCommitmentParams,
  Transaction,
  OutputsOwners,
  WithdrawItem,
  PublicOutput
} from "src/Vault.types.sol";

// Mock DepositVerifier that always returns true
contract MockDepositVerifier {
  bool private verificationResult;

  function setVerificationResult(bool result) public {
    verificationResult = result;
  }

  function verify(uint256[24] calldata, uint256[4] calldata) external view returns (bool) {
    return verificationResult;
  }
}

contract VaultTest is Test {
  Vault private vault;
  MockDepositVerifier private depositVerifier;
  Spend11Verifier private spend11Verifier;
  Spend12Verifier private spend12Verifier;
  Spend13Verifier private spend13Verifier;
  Spend21Verifier private spend21Verifier;
  Spend22Verifier private spend22Verifier;
  Spend23Verifier private spend23Verifier;
  Spend31Verifier private spend31Verifier;
  Spend32Verifier private spend32Verifier;
  Spend33Verifier private spend33Verifier;
  Spend81Verifier private spend81Verifier;
  Spend161Verifier private spend161Verifier;
  ERC2771Forwarder private zeroLedgerForwarder;
  MockERC20 private mockToken;

  address private alice = address(0x1);
  address private bob = address(0x2);
  address private charlie = address(0x3);
  address private feeRecipient = address(0x4);

  function setUp() public {
    depositVerifier = new MockDepositVerifier();
    spend11Verifier = new Spend11Verifier();
    spend12Verifier = new Spend12Verifier();
    spend13Verifier = new Spend13Verifier();
    spend21Verifier = new Spend21Verifier();
    spend22Verifier = new Spend22Verifier();
    spend23Verifier = new Spend23Verifier();
    spend31Verifier = new Spend31Verifier();
    spend32Verifier = new Spend32Verifier();
    spend33Verifier = new Spend33Verifier();
    spend81Verifier = new Spend81Verifier();
    spend161Verifier = new Spend161Verifier();
    zeroLedgerForwarder = new ERC2771Forwarder("ZeroLedgerForwarder");

    vault = new Vault(
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
      address(spend161Verifier),
      address(zeroLedgerForwarder)
    );

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
    (address owner1, bool locked1) = vault.commitmentsMap(address(mockToken), 123456789);
    (address owner2, bool locked2) = vault.commitmentsMap(address(mockToken), 987654321);
    (address owner3, bool locked3) = vault.commitmentsMap(address(mockToken), 555666777);

    assertEq(owner1, alice, "Commitment 1 should be assigned to Alice");
    assertEq(owner2, bob, "Commitment 2 should be assigned to Bob");
    assertEq(owner3, charlie, "Commitment 3 should be assigned to Charlie");
    assertFalse(locked1, "Commitment 1 should not be locked");
    assertFalse(locked2, "Commitment 2 should not be locked");
    assertFalse(locked3, "Commitment 3 should not be locked");

    vm.stopPrank();
  }
}
