// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract VaultProxy is ERC1967Proxy {
  constructor(address implementation, bytes memory data) ERC1967Proxy(implementation, data) {}
}
