// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import {AccessManager} from "@openzeppelin/contracts/access/manager/AccessManager.sol";
import {RolesLib} from "src/Roles.lib.sol";

/**
 * @dev Contract to admin roles for Forwarder, Vault, ProtocolManager contract administration
 * Roles Description:
 * ADMIN - multisig 3/5 wallet, grand / suspend roles, freeze / unfreeze roles
 * TREASURE_MANAGER - multisig 2/3 wallet to manage protocol tokenomics
 * SECURITY_COUNCIL - multisig 2/3 wallet to pause/unpause vault operations
 * MAINTAINER - multisig 2/3 wallet to approve dependant contract upgrades
 */
contract Administrator is AccessManager {
  constructor(address admin, address securityCouncil, address treasureManager, uint32 defaultGrantDelay)
    AccessManager(admin)
  {
    _grantRole(RolesLib.MAINTAINER, admin, 0, 5 days);
    _grantRole(RolesLib.SECURITY_COUNCIL, securityCouncil, 0, 0);
    _grantRole(RolesLib.TREASURE_MANAGER, treasureManager, 0, 0);
    setGrantDelay(RolesLib.MAINTAINER, defaultGrantDelay);
    setGrantDelay(RolesLib.SECURITY_COUNCIL, defaultGrantDelay);
    setGrantDelay(RolesLib.TREASURE_MANAGER, defaultGrantDelay);
  }
}
