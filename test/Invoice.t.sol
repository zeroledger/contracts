// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import {VaultTest} from "./VaultTest.util.sol";
import {Invoice} from "src/invoice/Invoice.sol";
import {InvoiceFactory} from "src/invoice/InvoiceFactory.sol";
import {DepositCommitmentParams, IVaultEvents} from "src/Vault.types.sol";
import {Fees} from "src/ProtocolManager.sol";

contract InvoiceTest is VaultTest, IVaultEvents {
  InvoiceFactory public invoiceFactory;
  Invoice public invoiceImplementation;

  function setUp() public {
    baseSetup();
    protocolManager.setFees(address(mockToken), Fees({deposit: 5e18, spend: 0, withdraw: 0}));

    // Deploy InvoiceFactory (which deploys the implementation)
    invoiceFactory = new InvoiceFactory();
    invoiceImplementation = Invoice(invoiceFactory.invoiceImplementation());
  }

  function test_invoice_storage_location() public pure {
    assertEq(
      keccak256(abi.encode(uint256(keccak256("invoice.zeroledger")) - 1)) & ~bytes32(uint256(0xff)),
      0xf1ee228d9f24f6e688c439ca913a801b6d219979c1a4f6a63061be9d75e25000
    );
  }

  // Test 1: Factory deployment and implementation
  function test_factory_deploys_implementation() public view {
    address impl = invoiceFactory.invoiceImplementation();
    assertTrue(impl != address(0), "Implementation should be deployed");
  }

  // Test 2: Compute invoice address before deployment
  function test_compute_invoice_address() public {
    bytes32 paramsHash = keccak256(abi.encode("test params"));

    address predictedAddress = invoiceFactory.computeInvoiceAddress(paramsHash);
    assertTrue(predictedAddress != address(0), "Predicted address should not be zero");

    // Deploy and verify the address matches
    address deployedAddress = invoiceFactory.deployInvoice(paramsHash);
    assertEq(deployedAddress, predictedAddress, "Deployed address should match predicted address");
  }

  // Test 3: Deploy invoice clone using CREATE2
  function test_deploy_invoice_clone() public {
    bytes32 paramsHash = keccak256(abi.encode("test params"));

    address invoiceAddress = invoiceFactory.deployInvoice(paramsHash);

    assertTrue(invoiceAddress != address(0), "Invoice should be deployed");
    assertTrue(invoiceAddress != address(invoiceImplementation), "Should be a clone, not the implementation");
  }

  // Test 4: Cannot deploy same invoice twice
  function test_cannot_deploy_duplicate_invoice() public {
    bytes32 paramsHash = keccak256(abi.encode("test params"));

    invoiceFactory.deployInvoice(paramsHash);

    // Try to deploy again with same paramsHash
    vm.expectRevert();
    invoiceFactory.deployInvoice(paramsHash);
  }

  // Test 5: Execute invoice before priority deadline
  function test_execute_invoice_before_deadline() public {
    // Prepare deposit parameters
    uint240 depositAmount = 100e18;
    uint240 executionFee = 10e18;
    address executor = bob;

    DepositCommitmentParams[3] memory commitmentParams;
    commitmentParams[0] = DepositCommitmentParams({poseidonHash: 123456789, owner: alice, metadata: "metadata1"});
    commitmentParams[1] = DepositCommitmentParams({poseidonHash: 987654321, owner: bob, metadata: "metadata2"});
    commitmentParams[2] = DepositCommitmentParams({poseidonHash: 555666777, owner: charlie, metadata: "metadata3"});

    // Compute paramsHash
    bytes32 paramsHash = keccak256(
      abi.encode(address(vault), address(mockToken), depositAmount, executionFee, commitmentParams, executor)
    );

    // Deploy invoice
    address invoiceAddress = invoiceFactory.deployInvoice(paramsHash);

    // Fund the invoice contract
    uint256 totalAmount = depositAmount + 5e18 + executionFee; // deposit + fee + executionFee
    mockToken.mint(invoiceAddress, totalAmount);

    // Approve vault to spend from invoice
    vm.prank(invoiceAddress);
    mockToken.approve(address(vault), totalAmount);

    // Set up verifier
    depositVerifier.setVerificationResult(true);

    // Execute invoice
    uint256[24] memory proof = getDummyProof();

    vm.prank(executor);
    Invoice(invoiceAddress).createInvoice(
      address(vault), address(mockToken), depositAmount, executionFee, commitmentParams, proof, executor
    );

    // Verify commitments were created
    assertEq(vault.getCommitment(address(mockToken), 123456789), alice, "Commitment 1 should be created");
    assertEq(vault.getCommitment(address(mockToken), 987654321), bob, "Commitment 2 should be created");
  }

  // Test 6: Execute invoice after priority deadline (anyone can execute)
  function test_execute_invoice_after_deadline() public {
    // Prepare deposit parameters
    uint240 depositAmount = 100e18;
    uint240 executionFee = 10e18;
    address executor = bob;

    DepositCommitmentParams[3] memory commitmentParams;
    commitmentParams[0] = DepositCommitmentParams({poseidonHash: 123456789, owner: alice, metadata: "metadata1"});
    commitmentParams[1] = DepositCommitmentParams({poseidonHash: 987654321, owner: bob, metadata: "metadata2"});
    commitmentParams[2] = DepositCommitmentParams({poseidonHash: 555666777, owner: charlie, metadata: "metadata3"});

    // Compute paramsHash
    bytes32 paramsHash = keccak256(
      abi.encode(address(vault), address(mockToken), depositAmount, executionFee, commitmentParams, executor)
    );

    // Deploy invoice
    address invoiceAddress = invoiceFactory.deployInvoice(paramsHash);

    // Move time forward past priority deadline
    vm.warp(block.timestamp + 2 days);

    // Fund the invoice contract
    uint256 totalAmount = depositAmount + 5e18 + executionFee;
    mockToken.mint(invoiceAddress, totalAmount);

    // Approve vault to spend from invoice
    vm.prank(invoiceAddress);
    mockToken.approve(address(vault), totalAmount);

    // Set up verifier
    depositVerifier.setVerificationResult(true);

    // Execute invoice as charlie (not the original executor)
    uint256[24] memory proof = getDummyProof();

    vm.prank(charlie);
    Invoice(invoiceAddress).createInvoice(
      address(vault), address(mockToken), depositAmount, executionFee, commitmentParams, proof, executor
    );

    // Verify commitments were created (execution succeeded)
    assertEq(vault.getCommitment(address(mockToken), 123456789), alice, "Commitment 1 should be created");
    // Note: The executionFee goes to msg.sender (charlie) after deadline
    // This is handled by the deposit's forwarderFee mechanism
  }

  // Test 7: Cannot execute with wrong params
  function test_cannot_execute_with_wrong_params() public {
    // Deploy invoice with one set of params
    bytes32 paramsHash = keccak256(abi.encode("correct params"));
    address invoiceAddress = invoiceFactory.deployInvoice(paramsHash);

    // Try to execute with different params
    uint240 depositAmount = 100e18;
    uint240 executionFee = 10e18;

    DepositCommitmentParams[3] memory commitmentParams;
    commitmentParams[0] = DepositCommitmentParams({poseidonHash: 123456789, owner: alice, metadata: "metadata1"});
    commitmentParams[1] = DepositCommitmentParams({poseidonHash: 987654321, owner: bob, metadata: "metadata2"});
    commitmentParams[2] = DepositCommitmentParams({poseidonHash: 555666777, owner: charlie, metadata: "metadata3"});

    uint256[24] memory proof = getDummyProof();

    vm.expectRevert("Invoice: Invalid params hash");
    Invoice(invoiceAddress).createInvoice(
      address(vault), address(mockToken), depositAmount, executionFee, commitmentParams, proof, bob
    );
  }

  // Test 8: Multiple invoices with different params get different addresses
  function test_deploy_multiple_invoices_different_params() public {
    bytes32 paramsHash1 = keccak256(abi.encode("params1"));
    bytes32 paramsHash2 = keccak256(abi.encode("params2"));
    bytes32 paramsHash3 = keccak256(abi.encode("params3"));

    address invoice1 = invoiceFactory.deployInvoice(paramsHash1);
    address invoice2 = invoiceFactory.deployInvoice(paramsHash2);
    address invoice3 = invoiceFactory.deployInvoice(paramsHash3);

    assertTrue(invoice1 != invoice2, "Invoice 1 and 2 should be different");
    assertTrue(invoice2 != invoice3, "Invoice 2 and 3 should be different");
    assertTrue(invoice1 != invoice3, "Invoice 1 and 3 should be different");
  }

  // Test 9: InvoiceDeployed event emission
  function test_invoice_deployed_event() public {
    bytes32 paramsHash = keccak256(abi.encode("test params"));

    address predictedAddress = invoiceFactory.computeInvoiceAddress(paramsHash);

    vm.expectEmit(true, true, false, true);
    emit InvoiceFactory.InvoiceDeployed(predictedAddress, paramsHash);

    invoiceFactory.deployInvoice(paramsHash);
  }

  // Test 10: Implementation contract is initialized and cannot be reinitialized
  function test_implementation_cannot_be_reinitialized() public {
    vm.expectRevert();
    invoiceImplementation.initialize(keccak256(abi.encode("test")));
  }
}
