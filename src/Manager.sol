// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {RolesLib} from "src/Roles.lib.sol";

/**
 * Manages fee floors and paymasters
 */
contract Manager is Initializable, UUPSUpgradeable, AccessControlUpgradeable {
  struct State {
    mapping(address => uint240) feeFloor;
    mapping(address => bool) paymasters;
  }

  // keccak256(abi.encode(uint256(keccak256("storage.zeroledger.manager")) - 1)) & ~bytes32(uint256(0xff))
  bytes32 internal constant STORAGE_LOCATION = 0x1e6edab0c58916f2cdb4173a0950c64e221f1070d5cd2e7a1af36c4a77561400;

  function _getStorage() internal pure returns (State storage $) {
    // solhint-disable-next-line no-inline-assembly
    assembly {
      $.slot := STORAGE_LOCATION
    }
  }

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }

  function initialize(address defaultPaymaster, address admin, address maintainer, address securityCouncil) public initializer {
    __AccessControl_init();
    __UUPSUpgradeable_init();
    __manager_init_unchained(defaultPaymaster);

    _grantRole(DEFAULT_ADMIN_ROLE, admin);
    _grantRole(RolesLib.MAINTAINER, maintainer);
    _grantRole(RolesLib.MANAGER, securityCouncil);
  }

  function upgradeCallBack() external reinitializer(0) {}

  function _authorizeUpgrade(address newImplementation) internal override onlyRole(RolesLib.MAINTAINER) {}

  function __manager_init_unchained(address defaultPaymaster) internal {
    _getStorage().paymasters[defaultPaymaster] = true;
  }

  function setFeeFloor(address token, uint240 feeFloor) external onlyRole(RolesLib.MANAGER) {
    _getStorage().feeFloor[token] = feeFloor;
  }

  function setPaymaster(address paymaster) public onlyRole(RolesLib.MANAGER) {
    _getStorage().paymasters[paymaster] = true;
  }

  function removePaymaster(address paymaster) external onlyRole(RolesLib.MANAGER) {
    delete _getStorage().paymasters[paymaster];
  }

  function getFeeFloor(address token) external view returns (uint240) {
    return _getStorage().feeFloor[token];
  }

  function isPaymaster(address paymaster) external view returns (bool) {
    return _getStorage().paymasters[paymaster];
  }
}
