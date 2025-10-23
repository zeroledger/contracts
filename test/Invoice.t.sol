// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import {VaultTest} from "./VaultTest.util.sol";
import {Invoice} from "src/invoice/Invoice.sol";
import {InvoiceFactory} from "src/invoice/InvoiceFactory.sol";
import {DepositCommitmentParams, IVaultEvents} from "src/Vault.types.sol";
import {Fees} from "src/ProtocolManager.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {MaliciousFactory} from "./mocks/MaliciousFactory.sol";

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

  // Test 5: Execute invoice before priority deadline using deployAndProcessInvoice
  function test_execute_invoice_before_deadline() public {
    // Prepare deposit parameters
    uint240 depositAmount = 100e18;
    uint240 executionFee = 10e18;
    address executor = bob;

    DepositCommitmentParams[3] memory commitmentParams;
    commitmentParams[0] = DepositCommitmentParams({poseidonHash: 123456789, owner: alice, metadata: "metadata1"});
    commitmentParams[1] = DepositCommitmentParams({poseidonHash: 987654321, owner: bob, metadata: "metadata2"});
    commitmentParams[2] = DepositCommitmentParams({poseidonHash: 555666777, owner: charlie, metadata: "metadata3"});

    // Compute paramsHash and predict invoice address
    bytes32 paramsHash = invoiceFactory.computeParamsHash(
      address(vault), address(mockToken), depositAmount, executionFee, commitmentParams, executor
    );
    address predictedInvoiceAddress = invoiceFactory.computeInvoiceAddress(paramsHash);

    // Fund the predicted invoice contract address
    uint256 totalAmount = depositAmount + 5e18 + executionFee;
    mockToken.mint(predictedInvoiceAddress, totalAmount);

    // Approve vault to spend from invoice
    vm.prank(predictedInvoiceAddress);
    mockToken.approve(address(vault), totalAmount);

    // Set up verifier
    depositVerifier.setVerificationResult(true);

    // Deploy and execute in one transaction
    uint256[24] memory proof = getDummyProof();

    vm.prank(executor);
    address invoiceAddress = invoiceFactory.deployAndProcessInvoice(
      address(vault), address(mockToken), depositAmount, executionFee, commitmentParams, proof, executor
    );

    // Verify the deployed address matches prediction
    assertEq(invoiceAddress, predictedInvoiceAddress, "Invoice address should match prediction");

    // Verify commitments were created
    assertEq(vault.getCommitment(address(mockToken), 123456789), alice, "Commitment 1 should be created");
    assertEq(vault.getCommitment(address(mockToken), 987654321), bob, "Commitment 2 should be created");
  }

  // Test 6: Execute invoice after priority deadline using deployAndProcessInvoice (anyone can execute)
  function test_execute_invoice_after_deadline() public {
    // Prepare deposit parameters
    uint240 depositAmount = 100e18;
    uint240 executionFee = 10e18;
    address executor = bob;

    DepositCommitmentParams[3] memory commitmentParams;
    commitmentParams[0] = DepositCommitmentParams({poseidonHash: 123456789, owner: alice, metadata: "metadata1"});
    commitmentParams[1] = DepositCommitmentParams({poseidonHash: 987654321, owner: bob, metadata: "metadata2"});
    commitmentParams[2] = DepositCommitmentParams({poseidonHash: 555666777, owner: charlie, metadata: "metadata3"});

    // Compute paramsHash and predict invoice address
    bytes32 paramsHash = invoiceFactory.computeParamsHash(
      address(vault), address(mockToken), depositAmount, executionFee, commitmentParams, executor
    );
    address predictedInvoiceAddress = invoiceFactory.computeInvoiceAddress(paramsHash);

    // Fund the predicted invoice contract address
    uint256 totalAmount = depositAmount + 5e18 + executionFee;
    mockToken.mint(predictedInvoiceAddress, totalAmount);

    // Approve vault to spend from invoice
    vm.prank(predictedInvoiceAddress);
    mockToken.approve(address(vault), totalAmount);

    // Set up verifier
    depositVerifier.setVerificationResult(true);

    // Move time forward past priority deadline
    vm.warp(block.timestamp + 2 days);

    // Execute as charlie (not the original executor) after deadline
    uint256[24] memory proof = getDummyProof();

    vm.prank(charlie);
    address invoiceAddress = invoiceFactory.deployAndProcessInvoice(
      address(vault), address(mockToken), depositAmount, executionFee, commitmentParams, proof, executor
    );

    // Verify the deployed address matches prediction
    assertEq(invoiceAddress, predictedInvoiceAddress, "Invoice address should match prediction");

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
    Invoice(invoiceAddress).processInvoice(
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

  // Test 11: Only factory can initialize clones - direct call from EOA fails
  function test_only_factory_can_initialize_clone_eoa() public {
    bytes32 paramsHash = keccak256(abi.encode("test params for eoa"));

    // Manually deploy a clone using the same implementation
    address manualClone = Clones.cloneDeterministic(address(invoiceImplementation), paramsHash);

    // Try to initialize from an EOA (this contract) - should fail
    vm.expectRevert("Invoice: Only factory can initialize");
    Invoice(manualClone).initialize(paramsHash);
  }

  // Test 12: Only factory can initialize clones - direct call from different contract fails
  function test_only_factory_can_initialize_clone_different_contract() public {
    bytes32 paramsHash = keccak256(abi.encode("test params for different contract"));

    // Deploy a malicious factory
    MaliciousFactory maliciousFactory = new MaliciousFactory(address(invoiceImplementation));

    // Try to deploy and initialize through malicious factory - should fail
    vm.expectRevert("Invoice: Only factory can initialize");
    maliciousFactory.attemptDeploy(paramsHash);
  }

  // Test 13: Factory successfully initializes its own clones
  function test_factory_successfully_initializes_clone() public {
    bytes32 paramsHash = keccak256(abi.encode("test params for factory"));

    // Deploy through the legitimate factory - should succeed
    address invoiceAddress = invoiceFactory.deployInvoice(paramsHash);

    // Verify it was deployed and initialized
    assertTrue(invoiceAddress != address(0), "Invoice should be deployed");
    assertTrue(invoiceAddress != address(invoiceImplementation), "Should be a clone, not implementation");

    // Verify it cannot be initialized again
    vm.expectRevert();
    Invoice(invoiceAddress).initialize(paramsHash);
  }

  // Test 14: Verify factory address is correct in implementation
  function test_factory_address_in_implementation() public view {
    address factoryInImplementation = invoiceImplementation.factory();
    assertEq(factoryInImplementation, address(invoiceFactory), "Factory address should match");
  }

  // Test 15: Verify all clones see the same factory address
  function test_all_clones_see_same_factory() public {
    bytes32 paramsHash1 = keccak256(abi.encode("clone1"));
    bytes32 paramsHash2 = keccak256(abi.encode("clone2"));
    bytes32 paramsHash3 = keccak256(abi.encode("clone3"));

    address clone1 = invoiceFactory.deployInvoice(paramsHash1);
    address clone2 = invoiceFactory.deployInvoice(paramsHash2);
    address clone3 = invoiceFactory.deployInvoice(paramsHash3);

    // All clones should see the same factory address (from implementation's immutable)
    assertEq(Invoice(clone1).factory(), address(invoiceFactory), "Clone1 factory should match");
    assertEq(Invoice(clone2).factory(), address(invoiceFactory), "Clone2 factory should match");
    assertEq(Invoice(clone3).factory(), address(invoiceFactory), "Clone3 factory should match");
  }
}
