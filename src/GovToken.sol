// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title GovToken
 * @notice ERC20 governance token with voting and permit extensions.
 * @dev Used as the governance token for the GameFi DAO.
 *      Implements ERC20Votes for on-chain governance weight and
 *      ERC20Permit for gasless approvals (EIP-2612).
 *
 * Design Pattern: Access Control (Ownable) — only owner can mint.
 */
contract GovToken is ERC20, ERC20Permit, ERC20Votes, Ownable {
    constructor(
        address _initialOwner
    ) ERC20("GovToken", "GOV") ERC20Permit("GovToken") Ownable(_initialOwner) {
        _mint(_initialOwner, 1_000_000 * 1e18);
    }

    /// @notice Mint new governance tokens. Restricted to owner (Timelock).
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    // ──── Required Overrides ────

    function _update(address from, address to, uint256 value) internal override(ERC20, ERC20Votes) {
        super._update(from, to, value);
    }

    function nonces(address owner) public view override(ERC20Permit, Nonces) returns (uint256) {
        return super.nonces(owner);
    }
}
