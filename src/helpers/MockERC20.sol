// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import {ERC20Permit, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

/**
 * @title MockERC20
 * @dev A mock ERC20 token for testing purposes
 */
contract MockERC20 is ERC20Permit {
  constructor(string memory name, string memory symbol) ERC20(name, symbol) ERC20Permit(name) {}

  /**
   * @dev Mint tokens to a specific address
   * @param to The address to mint tokens to
   * @param amount The amount of tokens to mint
   */
  function mint(address to, uint256 amount) external {
    _mint(to, amount);
  }

  /**
   * @dev Burn tokens from a specific address
   * @param amount The amount of tokens to burn
   */
  function burn(uint256 amount) external {
    _burn(msg.sender, amount);
  }
}
