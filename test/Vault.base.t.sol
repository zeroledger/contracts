// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.21;

import {VaultTest} from "./VaultTest.util.sol";

contract VaultBaseTest is VaultTest {
  function setUp() public {
    baseSetup();
  }

  // ============ Storage Location Tests ============

  function test_vault_storage_location() public pure {
    assertEq(
      keccak256(abi.encode(uint256(keccak256("storage.zeroledger")) - 1)) & ~bytes32(uint256(0xff)),
      0x60ea44b2fada15ab3d55d1b53c0f3a65e4a3da4f8f909905e012d14a90d3b300
    );
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
}
