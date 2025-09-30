// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {RolesLib} from "src/Roles.lib.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

struct Fees {
  uint240 deposit;
  uint240 spend;
  uint240 withdraw;
}

interface IProtocolManagerEvents {
  event FeesChanged(address indexed token, Fees indexed fees);
  event UpgradeApproved(address indexed proxy, address indexed implementation);
  event SetMaxTVL(address indexed token, uint240 indexed maxTVL);
}

/**
 * @dev Contract to manage protocol contracts, such as Forwarder or Vault
 * Roles Description:
 * ADMIN - multisig 3/5 wallet, upgrades ProtocolManager contract, grand / suspend roles
 * TREASURE_MANAGER - multisig 2/3 wallet to manage protocol tokenomics
 * SECURITY_COUNCIL - multisig 2/3 wallet to pause/unpause critical protocol functionality
 * MAINTAINER - multisig 2/3 wallet to approve dependant contract upgrades
 */
contract ProtocolManager is Initializable, UUPSUpgradeable, AccessControlUpgradeable, IProtocolManagerEvents {
  using SafeERC20 for IERC20;

  struct State {
    mapping(address => Fees) fees;
    mapping(address => address) approvedImplementation;
    mapping(address => uint240) maxTVL;
  }

  // keccak256(abi.encode(uint256(keccak256("storage.zeroledger.manager")) - 1)) & ~bytes32(uint256(0xff))
  bytes32 internal constant STORAGE_LOCATION = 0x1e6edab0c58916f2cdb4173a0950c64e221f1070d5cd2e7a1af36c4a77561400;

  function _getStorage() internal pure returns (State storage $) {
    // solhint-disable-next-line no-inline-assembly
    assembly {
      $.slot := STORAGE_LOCATION
    }
  }

  modifier onlyPercentages(uint256 percentage) {
    require(percentage <= 100, "Percentage must be less than or equal to 100");
    _;
  }

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }

  function initialize(address admin, address securityCouncil, address treasureManager) public initializer {
    __AccessControl_init();
    __UUPSUpgradeable_init();
    __manager_init_unchained(admin, securityCouncil, treasureManager);
  }

  function upgradeCallBack() external reinitializer(0) {}

  function _authorizeUpgrade(address newImplementation) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}

  function __manager_init_unchained(address admin, address securityCouncil, address treasureManager) internal {
    _grantRole(DEFAULT_ADMIN_ROLE, admin);
    _grantRole(RolesLib.MAINTAINER, admin);
    _grantRole(RolesLib.SECURITY_COUNCIL, securityCouncil);
    _grantRole(RolesLib.TREASURE_MANAGER, treasureManager);
  }

  /* Upgrades Approval */

  function approveUpgrade(address uupsProxy, address newImplementation) external onlyRole(RolesLib.MAINTAINER) {
    _getStorage().approvedImplementation[uupsProxy] = newImplementation;
    emit UpgradeApproved(uupsProxy, newImplementation);
  }

  function isImplementationApproved(address uupsProxy, address newImplementation) external view returns (bool) {
    return _getStorage().approvedImplementation[uupsProxy] == newImplementation;
  }

  /* Fees */

  function setFees(address token, Fees calldata fees) external onlyRole(RolesLib.TREASURE_MANAGER) {
    _getStorage().fees[token] = fees;
    emit FeesChanged(token, fees);
  }

  function transferFees(address token, address recipient) external onlyRole(RolesLib.TREASURE_MANAGER) {
    IERC20(token).safeTransfer(recipient, IERC20(token).balanceOf(address(this)));
  }

  function getFees(address token) external view returns (Fees memory) {
    return _getStorage().fees[token];
  }

  /* Max TVL */

  function setMaxTVL(address token, uint240 maxTVL) external onlyRole(RolesLib.SECURITY_COUNCIL) {
    _getStorage().maxTVL[token] = maxTVL;
    emit SetMaxTVL(token, maxTVL);
  }

  function getMaxTVL(address token) external view returns (uint240) {
    return _getStorage().maxTVL[token];
  }
}
