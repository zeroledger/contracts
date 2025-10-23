// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {Invoice} from "src/invoice/Invoice.sol";
// Helper contract to test that other contracts cannot initialize clones

contract MaliciousFactory {
  address public immutable implementation;

  constructor(address implementation_) {
    implementation = implementation_;
  }

  function attemptDeploy(bytes32 paramsHash) external returns (address) {
    address clone = Clones.cloneDeterministic(implementation, paramsHash);
    Invoice(clone).initialize(paramsHash);
    return clone;
  }
}
