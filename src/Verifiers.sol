// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.21;

// solhint-disable cam


import {DepositVerifier} from "circuits/contracts/DepositVerifier.sol";
import {Spend11Verifier} from "circuits/contracts/Spend11Verifier.sol";
import {Spend12Verifier} from "circuits/contracts/Spend12Verifier.sol";
import {Spend13Verifier} from "circuits/contracts/Spend13Verifier.sol";
import {Spend21Verifier} from "circuits/contracts/Spend21Verifier.sol";
import {Spend22Verifier} from "circuits/contracts/Spend22Verifier.sol";
import {Spend23Verifier} from "circuits/contracts/Spend23Verifier.sol";
import {Spend31Verifier} from "circuits/contracts/Spend31Verifier.sol";
import {Spend32Verifier} from "circuits/contracts/Spend32Verifier.sol";
import {Spend33Verifier} from "circuits/contracts/Spend33Verifier.sol";
import {Spend81Verifier} from "circuits/contracts/Spend81Verifier.sol";
import {Spend161Verifier} from "circuits/contracts/Spend161Verifier.sol";

contract Verifiers {
  DepositVerifier public immutable depositVerifier;
  Spend11Verifier public immutable spend11Verifier;
  Spend12Verifier public immutable spend12Verifier;
  Spend13Verifier public immutable spend13Verifier;
  Spend21Verifier public immutable spend21Verifier;
  Spend22Verifier public immutable spend22Verifier;
  Spend23Verifier public immutable spend23Verifier;
  Spend31Verifier public immutable spend31Verifier;
  Spend32Verifier public immutable spend32Verifier;
  Spend33Verifier public immutable spend33Verifier;
  Spend81Verifier public immutable spend81Verifier;
  Spend161Verifier public immutable spend161Verifier;

  constructor(
    address _depositVerifier,
    address _spend11Verifier,
    address _spend12Verifier,
    address _spend13Verifier,
    address _spend21Verifier,
    address _spend22Verifier,
    address _spend23Verifier,
    address _spend31Verifier,
    address _spend32Verifier,
    address _spend33Verifier,
    address _spend81Verifier,
    address _spend161Verifier
  ) {
    depositVerifier = DepositVerifier(_depositVerifier);
    spend11Verifier = Spend11Verifier(_spend11Verifier);
    spend12Verifier = Spend12Verifier(_spend12Verifier);
    spend13Verifier = Spend13Verifier(_spend13Verifier);
    spend21Verifier = Spend21Verifier(_spend21Verifier);
    spend22Verifier = Spend22Verifier(_spend22Verifier);
    spend23Verifier = Spend23Verifier(_spend23Verifier);
    spend31Verifier = Spend31Verifier(_spend31Verifier);
    spend32Verifier = Spend32Verifier(_spend32Verifier);
    spend33Verifier = Spend33Verifier(_spend33Verifier);
    spend81Verifier = Spend81Verifier(_spend81Verifier);
    spend161Verifier = Spend161Verifier(_spend161Verifier);
  }
}
