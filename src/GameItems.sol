// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title GameItems
 * @notice ERC1155 contract for in-game items: Part A (ID 1), Part B (ID 2), Legendary Sword (ID 3).
 * @dev Owned by GameEngine proxy. Includes a craftSword() function that burns Parts A & B,
 *      charges an IRON token fee, and mints a Legendary Sword (ID 3).
 *
 * Design Patterns:
 *   - Access Control (Ownable): only GameEngine can mint items
 *   - Checks-Effects-Interactions: state changes before external calls
 */
contract GameItems is ERC1155, Ownable {
    using SafeERC20 for IERC20;

    uint256 public constant PART_A = 1;
    uint256 public constant PART_B = 2;
    uint256 public constant LEGENDARY_SWORD = 3;

    IERC20 public ironToken;
    uint256 public craftingFee;

    event ItemsMinted(address indexed to, uint256 id, uint256 amount);
    event SwordCrafted(address indexed crafter, uint256 feeCharged);

    constructor(address _initialOwner, address _ironToken, uint256 _craftingFee)
        ERC1155("ipfs://bafybeiajtewitjck7bp2gocveszzw4czdbtug7s6nmhear3skgpjsmjjau/{id}.json")
        Ownable(_initialOwner)
    {
        ironToken = IERC20(_ironToken);
        craftingFee = _craftingFee;
    }

    /// @notice Mint game items. Restricted to owner (GameEngine).
    function mint(address to, uint256 id, uint256 amount, bytes memory data) external onlyOwner {
        _mint(to, id, amount, data);
        emit ItemsMinted(to, id, amount);
    }

    /**
     * @notice Craft a Legendary Sword by burning 1 Part A + 1 Part B + paying IRON fee.
     * @dev Checks-Effects-Interactions pattern:
     *      1. Check: caller has enough items and IRON allowance
     *      2. Effect: burn items
     *      3. Interaction: transfer IRON, mint sword
     */
    function craftSword() external {
        // Checks
        require(balanceOf(msg.sender, PART_A) >= 1, "Need Part A");
        require(balanceOf(msg.sender, PART_B) >= 1, "Need Part B");

        // Effects — burn items first
        _burn(msg.sender, PART_A, 1);
        _burn(msg.sender, PART_B, 1);

        // Interactions — transfer fee, then mint reward
        ironToken.safeTransferFrom(msg.sender, address(this), craftingFee);
        _mint(msg.sender, LEGENDARY_SWORD, 1, "");

        emit SwordCrafted(msg.sender, craftingFee);
    }

    /// @notice Update the crafting fee. Restricted to owner.
    function setCraftingFee(uint256 _newFee) external onlyOwner {
        craftingFee = _newFee;
    }

    /// @notice Withdraw accumulated IRON fees. Restricted to owner.
    function withdrawFees(address to) external onlyOwner {
        uint256 bal = ironToken.balanceOf(address(this));
        ironToken.safeTransfer(to, bal);
    }
}
