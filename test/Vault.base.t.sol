// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import {VaultTest} from "./VaultTest.util.sol";

contract VaultBaseTest is VaultTest {
  function setUp() public {
    baseSetup();
  }

  // ============ Storage Location Tests ============

  function test_vault_storage_location() public pure {
    assertEq(
      keccak256(abi.encode(uint256(keccak256("storage.zeroledger.vault")) - 1)) & ~bytes32(uint256(0xff)),
      0x4ff14ff3d6d11019b33840a324a7911c48c76118cab5bf9ddf96218a30397600
    );
  }

  function test_protocolManager_storage_location() public pure {
    assertEq(
      keccak256(abi.encode(uint256(keccak256("storage.zeroledger.protocolManager")) - 1)) & ~bytes32(uint256(0xff)),
      0xe0580d69c76a1485a3ec232504ae744d7dbd58648ec64d89403a4e1fbff1fb00
    );
  }

  // ============ computePoseidonHash Tests ============

  function test_computeSharedInputPoseidonHash() public view {
    uint256 amount = 0;
    uint256 sValue = uint256(keccak256("shared-input"));
    uint256 hash = vault.computePoseidonHash(amount, sValue);
    assertEq(hash, 15137436504035450233189320721078414488136960400594787218856438198681086299747);
  }

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
