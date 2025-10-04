// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

struct Fees {
  uint240 deposit;
  uint240 spend;
  uint240 withdraw;
}

struct TokenTVLConfig {
  address token;
  uint240 maxTVL;
}

interface IProtocolEvents {
  event FeesChanged(address indexed token, Fees indexed fees);
  event SetMaxTVL(address indexed token, uint240 indexed maxTVL);
}
