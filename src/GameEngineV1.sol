// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

interface IGameItems {
    function mint(address to, uint256 id, uint256 amount, bytes memory data) external;
}

/**
 * @title GameEngineV1
 * @notice Core game logic deployed behind a UUPS proxy.
 * @dev Implements farmLoot() with configurable drop chance.
 *      CRUCIAL: Drop chance is set to 100% in initialize() for testing.
 *      CRUCIAL: Items are minted to msg.sender, NOT address(this).
 *
 * Design Patterns:
 *   - Proxy / UUPS: upgradeability with documented V1 → V2 path
 *   - Pausable / Circuit Breaker: can pause game operations
 *   - Reentrancy Guard: protects against reentrancy in farmLoot
 *   - Checks-Effects-Interactions: state changes before external calls
 */
contract GameEngineV1 is
    Initializable,
    UUPSUpgradeable,
    OwnableUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable
{
    IGameItems public gameItems;

    /// @notice Drop chance in basis points (10000 = 100%).
    uint256 public dropChanceBps;

    /// @notice Nonce used for pseudo-random drop calculation.
    uint256 public nonce;

    /// @notice Total loot events across all users.
    uint256 public totalLoots;

    /// @dev Storage gap for future V2 variables — prevents storage collisions.
    uint256[44] private __gap;

    event LootFarmed(address indexed player, uint256 itemId, uint256 loops);
    event DropChanceUpdated(uint256 oldChance, uint256 newChance);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initialize the game engine. Called once via proxy.
     * @param _gameItems Address of the GameItems ERC1155 contract.
     * @param _owner     Owner address (initially deployer, later Timelock).
     * @dev CRUCIAL: dropChanceBps is set to 10000 (100%) for testing purposes.
     */
    function initialize(address _gameItems, address _owner) external initializer {
        __Ownable_init(_owner);
        __UUPSUpgradeable_init();
        __Pausable_init();
        __ReentrancyGuard_init();

        gameItems = IGameItems(_gameItems);
        dropChanceBps = 10000; // 100% for testing
    }

    /**
     * @notice Farm loot: iterate `loops` times and mint items based on drop chance.
     * @param loops Number of farming iterations.
     * @dev Uses Checks-Effects-Interactions pattern.
     *      Items are minted to msg.sender (NOT address(this)).
     *      Uses inline Yul assembly for gas-efficient random number generation.
     */
    function farmLoot(uint256 loops) external whenNotPaused nonReentrant {
        require(loops > 0 && loops <= 10, "Loops: 1-10");

        for (uint256 i = 0; i < loops; i++) {
            // Inline Yul assembly for gas-efficient pseudo-random generation
            uint256 rand;
            uint256 currentNonce = nonce;
            assembly {
                // Gas-efficient pseudo-random using Yul assembly
                let ptr := mload(0x40)
                mstore(ptr, prevrandao())
                mstore(add(ptr, 0x20), caller())
                mstore(add(ptr, 0x40), currentNonce)
                rand := mod(keccak256(ptr, 0x60), 10000)
            }

            nonce = currentNonce + 1;
            totalLoots++;

            if (rand < dropChanceBps) {
                // User requested 100% drop chance for the parts, so we mint both
                gameItems.mint(msg.sender, 1, 1, "");
                gameItems.mint(msg.sender, 2, 1, "");
                emit LootFarmed(msg.sender, 1, loops);
                emit LootFarmed(msg.sender, 2, loops);
            }
        }
    }

    /**
     * @notice Pure Solidity equivalent of the Yul random generation (for benchmarking).
     * @dev This function exists solely for gas comparison in the gas optimization report.
     */
    function farmLootPureSolidity(uint256 loops) external whenNotPaused nonReentrant {
        require(loops > 0 && loops <= 10, "Loops: 1-10");

        for (uint256 i = 0; i < loops; i++) {
            // Pure Solidity random generation (more expensive than Yul)
            uint256 rand = uint256(
                keccak256(abi.encodePacked(block.prevrandao, msg.sender, nonce))
            ) % 10000;

            nonce++;
            totalLoots++;

            if (rand < dropChanceBps) {
                gameItems.mint(msg.sender, 1, 1, "");
                gameItems.mint(msg.sender, 2, 1, "");
                emit LootFarmed(msg.sender, 1, loops);
                emit LootFarmed(msg.sender, 2, loops);
            }
        }
    }

    /// @notice Update drop chance. Restricted to owner (Timelock via governance).
    function setDropChance(uint256 _newChanceBps) external onlyOwner {
        require(_newChanceBps <= 10000, "Max 10000 bps");
        uint256 old = dropChanceBps;
        dropChanceBps = _newChanceBps;
        emit DropChanceUpdated(old, _newChanceBps);
    }

    /// @notice Pause game operations. Restricted to owner.
    function pause() external onlyOwner {
        _pause();
    }

    /// @notice Unpause game operations. Restricted to owner.
    function unpause() external onlyOwner {
        _unpause();
    }

    /// @notice Returns the current version.
    function version() external pure virtual returns (string memory) {
        return "1.0.0";
    }

    /// @notice UUPS authorization — only owner can upgrade.
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
