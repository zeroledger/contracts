// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

// solhint-disable no-global-import
// solhint-disable no-console

import "@std/Test.sol";

// solhint-disable max-states-count
contract RunnerTest is Test {
  function baseSetup() internal {}

  function test_runner() public {
    console.logBytes32(keccak256(abi.encode(uint256(keccak256("storage.zeroledger.vault")) - 1)) & ~bytes32(uint256(0xff)));
    console.logBytes32(
      keccak256(abi.encode(uint256(keccak256("storage.zeroledger.protocolManager")) - 1)) & ~bytes32(uint256(0xff))
    );
  }
}
