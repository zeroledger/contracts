// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {ERC2771ForwarderUpgradeable} from "@openzeppelin/contracts-upgradeable/metatx/ERC2771ForwarderUpgradeable.sol";
import {Roles} from "src/Roles.lib.sol";
import {Manager} from "src/Manager.sol";

/**
 * Manages allowed paymasters
 */
contract Forwarder is Initializable, UUPSUpgradeable, AccessControlUpgradeable, ERC2771ForwarderUpgradeable {
  struct State {
    Manager manager;
  }

  // keccak256(abi.encode(uint256(keccak256("storage.zeroledger.Forwarder")) - 1)) & ~bytes32(uint256(0xff))
  bytes32 internal constant STORAGE_LOCATION = 0x60ea44b2fada15ab3d55d1b53c0f3a65e4a3da4f8f909905e012d14a90d3b300;

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

  function initialize(address manager) public initializer {
    __AccessControl_init();
    __UUPSUpgradeable_init();
    __ERC2771Forwarder_init("ZeroLedgerForwarder");
    __forwarder_init_unchained(manager);

    _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    _grantRole(Roles.MAINTAINER, msg.sender);
  }

  function upgradeCallBack() external reinitializer(0) {}

  function _authorizeUpgrade(address newImplementation) internal override onlyRole(Roles.MAINTAINER) {}

  function __forwarder_init_unchained(address manager) internal {
    _getStorage().manager = Manager(manager);
  }

  function getTrustedManager() external view returns (address) {
    return address(_getStorage().manager);
  }

  /**
   * @dev Validates if the provided request can be executed at current block timestamp with
   * the given `request.signature` on behalf of `request.signer`.
   */
  function _validate(ERC2771ForwarderUpgradeable.ForwardRequestData calldata request)
    internal
    view
    virtual
    override
    returns (bool isTrustedForwarder, bool active, bool signerMatch, address signer)
  {
    require(_getStorage().manager.isPaymaster(msg.sender), "Forwarder: Not whitelisted paymaster");
    (bool isValid, address recovered) = _recoverForwardRequestSigner(request);

    return (
      _isTrustedByTarget(request.to),
      request.deadline >= block.timestamp,
      isValid && recovered == request.from,
      recovered
    );
  }
}
