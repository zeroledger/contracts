// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

contract MockManager {
  bool private _isPaymaster;
  mapping(address => uint240) private _tokenFeeFloor;

  function setIsPaymaster(bool value) public {
    _isPaymaster = value;
  }

  function isPaymaster(address) external view returns (bool) {
    return _isPaymaster;
  }

  function setFeeFloor(address token, uint240 feeFloor) external {
    _tokenFeeFloor[token] = feeFloor;
  }

  function getFeeFloor(address token) external view returns (uint240) {
    return _tokenFeeFloor[token];
  }
}
