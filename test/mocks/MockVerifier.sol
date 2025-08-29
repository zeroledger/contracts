// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

contract MockVerifier {
  bool private verificationResult;

  function setVerificationResult(bool result) public {
    verificationResult = result;
  }

  function verify(uint256[24] calldata, uint256[4] calldata) external view returns (bool) {
    return verificationResult;
  }

  function verify(uint256[24] calldata, uint256[3] calldata) external view returns (bool) {
    return verificationResult;
  }

  function verify(uint256[24] calldata, uint256[5] calldata) external view returns (bool) {
    return verificationResult;
  }

  function verify(uint256[24] calldata, uint256[6] calldata) external view returns (bool) {
    return verificationResult;
  }

  function verify(uint256[24] calldata, uint256[7] calldata) external view returns (bool) {
    return verificationResult;
  }

  function verify(uint256[24] calldata, uint256[10] calldata) external view returns (bool) {
    return verificationResult;
  }

  function verify(uint256[24] calldata, uint256[18] calldata) external view returns (bool) {
    return verificationResult;
  }
}
