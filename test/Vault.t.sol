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
  Spend161Verifier,
  ERC2771Forwarder
} from "src/Vault.sol";

contract VautTest is Test {
  Vault private vault;
  DepositVerifier private depositVerifier;
  Spend11Verifier private spend11Verifier;
  Spend12Verifier private spend12Verifier;
  Spend13Verifier private spend13Verifier;
  Spend21Verifier private spend21Verifier;
  Spend22Verifier private spend22Verifier;
  Spend23Verifier private spend23Verifier;
  Spend31Verifier private spend31Verifier;
  Spend32Verifier private spend32Verifier;
  Spend161Verifier private spend161Verifier;
  ERC2771Forwarder private zeroLedgerForwarder;

  function setUp() public {
    depositVerifier = new DepositVerifier();
    spend11Verifier = new Spend11Verifier();
    spend12Verifier = new Spend12Verifier();
    spend13Verifier = new Spend13Verifier();
    spend21Verifier = new Spend21Verifier();
    spend22Verifier = new Spend22Verifier();
    spend23Verifier = new Spend23Verifier();
    spend31Verifier = new Spend31Verifier();
    spend32Verifier = new Spend32Verifier();
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
      address(spend161Verifier),
      address(zeroLedgerForwarder)
    );
  }

  function test_computePoseidonHash() public {
    uint256 amount = 1000000000000000000;
    uint256 sValue = 1000000000000000000;
    uint256 hash = vault.computePoseidonHash(amount, sValue);
    assertEq(hash, 15196373595714768051696025584583401928266812183015116537231151879335506775479);
  }
}
