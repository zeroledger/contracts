// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

// solhint-disable no-global-import
// solhint-disable no-console

import "@std/Test.sol";

import {Verifiers} from "src/Verifiers.sol";
import {Vault} from "src/Vault.sol";
import {Forwarder} from "src/Forwarder.sol";
import {ProtocolManager} from "src/ProtocolManager.sol";
import {Administrator} from "src/Administrator.sol";
import {MockERC20} from "src/helpers/MockERC20.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {MockVerifier} from "./mocks/MockVerifier.sol";
import {DepositParams, DepositCommitmentParams} from "src/Vault.types.sol";
import {PermitUtils} from "./Permit.util.sol";

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
  ProtocolManager internal protocolManager;
  PermitUtils internal permitUtils;
  address internal alice;
  address internal bob;
  address internal charlie;
  uint256 internal alicePrivateKey;
  uint256 internal bobPrivateKey;
  uint256 internal charliePrivateKey;
  mapping(address => uint256) internal signerToPrivateKey;

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
    mockToken = new MockERC20("Test Token", "TEST");
    permitUtils = new PermitUtils(mockToken.DOMAIN_SEPARATOR());

    address runner = address(this);

    Administrator administrator = new Administrator(runner, runner, runner, runner, 5 days);

    ERC1967Proxy protocolManagerProxy = new ERC1967Proxy(address(new ProtocolManager()), "");
    protocolManager = ProtocolManager(address(protocolManagerProxy));
    protocolManager.initialize(address(administrator));
    protocolManager.setMaxTVL(address(mockToken), type(uint240).max);

    ERC1967Proxy zeroLedgerForwarderProxy = new ERC1967Proxy(address(new Forwarder()), "");
    zeroLedgerForwarder = Forwarder(address(zeroLedgerForwarderProxy));
    zeroLedgerForwarder.initialize(address(administrator));

    ERC1967Proxy vaultProxy = new ERC1967Proxy(address(new Vault()), "");
    vault = Vault(address(vaultProxy));
    vault.initialize(
      address(verifiers), address(zeroLedgerForwarder), address(protocolManager), address(administrator)
    );

    // Create deterministic test accounts with private keys for signing
    (alice, alicePrivateKey) = makeAddrAndKey("alice");
    (bob, bobPrivateKey) = makeAddrAndKey("bob");
    (charlie, charliePrivateKey) = makeAddrAndKey("charlie");
    signerToPrivateKey[alice] = alicePrivateKey;
    signerToPrivateKey[bob] = bobPrivateKey;
    signerToPrivateKey[charlie] = charliePrivateKey;

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

  function doPermit(address signer, address spender, uint256 value, uint256 nonce, uint256 deadline)
    internal
    view
    returns (PermitUtils.Signature memory)
  {
    PermitUtils.Permit memory _permit =
      PermitUtils.Permit({owner: signer, spender: spender, value: value, nonce: nonce, deadline: deadline});

    bytes32 digest = permitUtils.getTypedDataHash(_permit);

    uint256 signerPrivateKey = signerToPrivateKey[signer];
    require(signerPrivateKey != 0, "unknown signer");
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, digest);
    return PermitUtils.Signature(v, r, s);
  }

  // Helper function to create a deposit
  function createDeposit(
    address user,
    uint240 depositAmount,
    uint240 fee,
    uint240 forwarderFee,
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
      amount: depositAmount,
      depositCommitmentParams: commitmentParams,
      forwarderFee: forwarderFee,
      forwarderFeeRecipient: address(zeroLedgerForwarder)
    });

    uint256[24] memory proof = getDummyProof();

    vm.startPrank(user);
    mockToken.approve(address(vault), uint256(depositAmount + fee + forwarderFee));
    vault.deposit(depositParams, proof);
    vm.stopPrank();
  }

  // Helper function to create a deposit using permit (native permit support)
  function createDepositWithPermit(
    address user,
    uint240 depositAmount,
    uint240 fee,
    uint240 forwarderFee,
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
      amount: depositAmount,
      depositCommitmentParams: commitmentParams,
      forwarderFee: forwarderFee,
      forwarderFeeRecipient: address(zeroLedgerForwarder)
    });

    uint256[24] memory proof = getDummyProof();

    vm.startPrank(user);
    // Create permit signature
    PermitUtils.Signature memory signature =
      doPermit(user, address(vault), uint256(depositAmount + fee + forwarderFee), 0, block.timestamp + 1000);

    // Use the new depositWithPermit method
    vault.depositWithPermit(depositParams, proof, block.timestamp + 1000, signature.v, signature.r, signature.s);
    vm.stopPrank();
  }
}
