// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {AccessManagedUpgradeable} from
  "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";

struct Fees {
  uint240 deposit;
  uint240 spend;
  uint240 withdraw;
}

interface IProtocolEvents {
  event FeesChanged(address indexed token, Fees indexed fees);
  event SetMaxTVL(address indexed token, uint240 indexed maxTVL);
}

/**
 * @dev Contract to manage protocol parameters
 */
contract ProtocolManager is Initializable, UUPSUpgradeable, IProtocolEvents, AccessManagedUpgradeable {
  using SafeERC20 for IERC20;

  struct State {
    mapping(address => Fees) fees;
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

  function initialize(address initialAuthority) public initializer {
    __UUPSUpgradeable_init();
    __AccessManaged_init(initialAuthority);
    __protocol_init_unchained();
  }

  function upgradeCallBack() external reinitializer(0) {}

  function __protocol_init_unchained() internal {}

  function _authorizeUpgrade(address newImplementation) internal override restricted {}

  /* Fees */

  function setFees(address token, Fees calldata fees) external restricted {
    _getStorage().fees[token] = fees;
    emit FeesChanged(token, fees);
  }

  function transferFees(address token, address recipient) external restricted {
    IERC20(token).safeTransfer(recipient, IERC20(token).balanceOf(address(this)));
  }

  function getFees(address token) external view returns (Fees memory) {
    return _getStorage().fees[token];
  }

  /* Max TVL */

  function setMaxTVL(address token, uint240 maxTVL) external restricted {
    _getStorage().maxTVL[token] = maxTVL;
    emit SetMaxTVL(token, maxTVL);
  }

  function getMaxTVL(address token) external view returns (uint240) {
    return _getStorage().maxTVL[token];
  }
}
