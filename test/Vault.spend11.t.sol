// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import {VaultTest} from "./VaultTest.util.sol";
import {Transaction, OutputsOwners, PublicOutput} from "src/Vault.types.sol";
import {IVaultEvents} from "src/Vault.sol";
import {Fees} from "src/ProtocolManager.sol";

contract VaultSpend11Test is VaultTest, IVaultEvents {
  function setUp() public {
    baseSetup();
  }

  function test_spend11_success() public {
    // Setup: Create a deposit first to establish commitments
    uint240 depositAmount = uint240(100e18);
    uint240 fee = uint240(5e18);
    uint240 forwarderFee = uint240(5e18);
    protocolManager.setFees(address(mockToken), Fees({deposit: 0, spend: fee, withdraw: 0}));

    // Create unique poseidon hashes for the deposit
    uint256[3] memory depositHashes = [uint256(123456789), uint256(987654321), uint256(555666777)];
    address[3] memory depositOwners = [alice, bob, charlie];

    // Create the initial deposit
    createDeposit(alice, depositAmount, fee, forwarderFee, depositHashes, depositOwners);

    // Now create a spend11 transaction (1 input, 1 output)
    uint256 inputHash = depositHashes[0]; // Use the first commitment as input
    uint256 outputHash = 999888777; // New output hash

    // Create output owners array
    OutputsOwners[] memory outputsOwners = new OutputsOwners[](1);
    outputsOwners[0] = OutputsOwners({owner: alice, indexes: new uint8[](1)});
    outputsOwners[0].indexes[0] = 0; // First output goes to Alice

    // Create public outputs array (empty for this test)
    PublicOutput[] memory publicOutputs = new PublicOutput[](0);

    // Create metadata array
    bytes[] memory metadata = new bytes[](1);
    metadata[0] = "spend11_metadata";

    // Create the transaction
    Transaction memory transaction = Transaction({
      token: address(mockToken),
      inputsPoseidonHashes: new uint256[](1),
      outputsPoseidonHashes: new uint256[](1),
      metadata: metadata,
      outputsOwners: outputsOwners,
      publicOutputs: publicOutputs
    });

    transaction.inputsPoseidonHashes[0] = inputHash;
    transaction.outputsPoseidonHashes[0] = outputHash;

    // Set up the mock verifier to return true
    spend11Verifier.setVerificationResult(true);

    // Create a dummy proof
    uint256[24] memory proof = getDummyProof();

    // Record initial state
    (address inputOwnerBefore,) = vault.getCommitment(address(mockToken), inputHash);
    (address outputOwnerBefore,) = vault.getCommitment(address(mockToken), outputHash);

    // Expect events to be emitted
    vm.expectEmit(true, true, false, true);
    emit CommitmentRemoved(alice, address(mockToken), inputHash);

    vm.expectEmit(true, true, false, true);
    emit CommitmentCreated(alice, address(mockToken), outputHash, "spend11_metadata");

    vm.expectEmit(true, true, false, true);
    emit TransactionSpent(
      alice, address(mockToken), transaction.inputsPoseidonHashes, transaction.outputsPoseidonHashes
    );

    // Execute the spend transaction
    vm.startPrank(alice);
    vault.spend(transaction, proof);
    vm.stopPrank();

    // Verify the input commitment was removed
    (address inputOwnerAfter,) = vault.getCommitment(address(mockToken), inputHash);
    assertEq(inputOwnerAfter, address(0), "Input commitment should be removed");

    // Verify the output commitment was created
    (address outputOwnerAfter,) = vault.getCommitment(address(mockToken), outputHash);
    assertEq(outputOwnerAfter, alice, "Output commitment should be assigned to Alice");

    // Verify the input commitment was originally assigned to Alice
    assertEq(inputOwnerBefore, alice, "Input commitment should have been assigned to Alice");

    // Verify the output commitment didn't exist before
    assertEq(outputOwnerBefore, address(0), "Output commitment should not have existed before");
  }
}
