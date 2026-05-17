// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

/**
 * @title IronToken
 * @notice ERC20 token used as the in-game base currency for the GameFi economy.
 * @dev Owned by the Timelock (DAO), so minting is governance-controlled.
 *
 * Design Pattern: Access Control (Ownable) — only DAO-controlled owner can mint.
 */
contract IronToken is ERC20, ERC20Permit, Ownable {
    constructor(
        address _initialOwner
    ) ERC20("IronToken", "IRON") ERC20Permit("IronToken") Ownable(_initialOwner) {}

    /// @notice Mint IRON tokens. Restricted to owner (Timelock / deployer initially).
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    /// @notice Burn IRON tokens from the caller's balance.
    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }
}
