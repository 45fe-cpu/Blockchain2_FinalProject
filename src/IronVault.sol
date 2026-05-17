// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title IronVault
 * @notice ERC4626 Tokenized Vault for staking IRON tokens for yield.
 * @dev Implements all ERC4626 rounding invariants.
 *      The vault owner (DAO) can add yield by depositing additional IRON.
 *
 * Design Patterns:
 *   - ERC4626 standard compliance
 *   - Reentrancy Guard on deposit/withdraw
 *   - Access Control (Ownable) for yield management
 */
contract IronVault is ERC4626, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    event YieldAdded(uint256 amount);

    constructor(
        IERC20 _asset,
        address _owner
    )
        ERC4626(_asset)
        ERC20("Iron Vault Share", "vIRON")
        Ownable(_owner)
    {}

    /**
     * @notice Add yield to the vault (increases share value for all depositors).
     * @param amount Amount of IRON tokens to add as yield.
     * @dev Only owner (DAO via governance) can add yield.
     *      Uses SafeERC20 for safe token transfer.
     */
    function addYield(uint256 amount) external onlyOwner {
        IERC20(asset()).safeTransferFrom(msg.sender, address(this), amount);
        emit YieldAdded(amount);
    }

    /// @inheritdoc ERC4626
    function deposit(uint256 assets, address receiver) public override nonReentrant returns (uint256) {
        return super.deposit(assets, receiver);
    }

    /// @inheritdoc ERC4626
    function mint(uint256 shares, address receiver) public override nonReentrant returns (uint256) {
        return super.mint(shares, receiver);
    }

    /// @inheritdoc ERC4626
    function withdraw(uint256 assets, address receiver, address owner_) public override nonReentrant returns (uint256) {
        return super.withdraw(assets, receiver, owner_);
    }

    /// @inheritdoc ERC4626
    function redeem(uint256 shares, address receiver, address owner_) public override nonReentrant returns (uint256) {
        return super.redeem(shares, receiver, owner_);
    }
}
