// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

// solhint-disable no-global-import
// solhint-disable no-console

import "@std/Test.sol";

import {Verifiers} from "src/Verifiers.sol";
import {Vault} from "src/Vault.sol";
import {Forwarder} from "src/Forwarder.sol";
import {MockERC20} from "src/helpers/MockERC20.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {MockVerifier} from "./mocks/MockVerifier.sol";
import {MockManager} from "./mocks/MockManager.sol";
import {DepositParams, DepositCommitmentParams} from "src/Vault.types.sol";

// solhint-disable max-states-count
contract VaultTest is Test {
  Vault internal vault;
  MockVerifier internal depositVerifier;
  MockVerifier internal spend11Verifier;
  MockVerifier internal spend12Verifier;
  MockVerifier internal spend13Verifier;
  MockVerifier internal spend21Verifier;
  MockVerifier internal spend22Verifier;
  MockVerifier internal spend23Verifier;
  MockVerifier internal spend31Verifier;
  MockVerifier internal spend32Verifier;
  MockVerifier internal spend33Verifier;
  MockVerifier internal spend81Verifier;
  MockVerifier internal spend161Verifier;
  Forwarder internal zeroLedgerForwarder;
  MockERC20 internal mockToken;
  MockManager internal mockManager;
  address internal alice = address(0x1);
  address internal bob = address(0x2);
  address internal charlie = address(0x3);
  address internal feeRecipient = address(0x4);

  function baseSetup() internal {
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
    mockManager = new MockManager();

    ERC1967Proxy forwarderProxy = new ERC1967Proxy(address(new Forwarder()), "");
    zeroLedgerForwarder = Forwarder(address(forwarderProxy));
    zeroLedgerForwarder.initialize(address(mockManager));

    ERC1967Proxy vaultProxy = new ERC1967Proxy(address(new Vault()), "");
    
    vault = Vault(address(vaultProxy));
    vault.initialize(address(verifiers), address(forwarderProxy), address(mockManager));
    mockToken = new MockERC20("Test Token", "TEST");

    // Mint tokens to test addresses
    mockToken.mint(alice, 1000e18);
    mockToken.mint(bob, 1000e18);
    mockToken.mint(charlie, 1000e18);
  }

  function getDummyProof() internal pure returns (uint256[24] memory) {
    uint256[24] memory proof;
    for (uint256 i = 0; i < 24; i++) {
      proof[i] = i + 1;
    }
    return proof;
  }

  // Helper function to create a deposit
  function createDeposit(
    address user,
    uint240 depositAmount,
    uint240 fee,
    uint256[3] memory poseidonHashes,
    address[3] memory owners
  ) internal {
    depositVerifier.setVerificationResult(true);

    DepositCommitmentParams[3] memory commitmentParams;
    commitmentParams[0] =
      DepositCommitmentParams({poseidonHash: poseidonHashes[0], owner: owners[0], metadata: "metadata1"});
    commitmentParams[1] =
      DepositCommitmentParams({poseidonHash: poseidonHashes[1], owner: owners[1], metadata: "metadata2"});
    commitmentParams[2] =
      DepositCommitmentParams({poseidonHash: poseidonHashes[2], owner: owners[2], metadata: "metadata3"});

    DepositParams memory depositParams = DepositParams({
      token: address(mockToken),
      total_deposit_amount: depositAmount,
      depositCommitmentParams: commitmentParams,
      fee: fee,
      feeRecipient: feeRecipient
    });

    uint256[24] memory proof = getDummyProof();

    vm.startPrank(user);
    mockToken.approve(address(vault), uint256(depositAmount + fee));
    vault.deposit(depositParams, proof);
    vm.stopPrank();
  }
}
