// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

library RolesLib {
  // keccak256("maintainer")
  bytes32 internal constant MAINTAINER = 0xddb9610f823ee4fc79a9d6f81490c93108f5c8a62aad74abbdf4620bfc3e24cd;
  // keccak256("security_council")
  bytes32 internal constant SECURITY_COUNCIL = 0x3af227978ba13c18dd802878be88b0856d7edba1c796d8d5cf690551b3edf549;
  // keccak256("treasure_manager")
  bytes32 internal constant TREASURE_MANAGER = 0x1047eaab78bac649d20efd7e2f6cd82cb12ff7ef3940bbaadce0ef322c16e036;
}
