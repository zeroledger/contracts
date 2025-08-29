// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

library Roles {
  bytes32 public constant MAINTAINER = keccak256("maintainer");
  bytes32 public constant SECURITY_COUNCIL = keccak256("security_council");
  bytes32 public constant MANAGER = keccak256("manager");
}
