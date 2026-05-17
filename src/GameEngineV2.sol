// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./GameEngineV1.sol";

/**
 * @title GameEngineV2
 * @notice Upgraded version of GameEngineV1 demonstrating the UUPS V1 → V2 upgrade path.
 * @dev Adds a maxLoopsPerTx variable and overrides version().
 *      Storage layout is compatible — new variables use the __gap slots.
 *
 * Design Pattern: Proxy / UUPS — documented upgrade path.
 * Storage Safety: Uses gap slots from V1, no storage collision.
 */
contract GameEngineV2 is GameEngineV1 {
    /// @notice Maximum loops per single farmLoot call (governance-adjustable).
    /// @dev Stored in the first slot of the V1 __gap, so no storage collision.
    uint256 public maxLoopsPerTx;

    event MaxLoopsUpdated(uint256 oldMax, uint256 newMax);

    /// @notice Re-initializer for V2 — sets the maxLoopsPerTx.
    function initializeV2(uint256 _maxLoops) external reinitializer(2) {
        maxLoopsPerTx = _maxLoops;
    }

    /// @notice Returns the V2 version.
    function version() external pure override returns (string memory) {
        return "2.0.0";
    }

    /// @notice Set max loops per transaction. Restricted to owner.
    function setMaxLoopsPerTx(uint256 _maxLoops) external onlyOwner {
        uint256 old = maxLoopsPerTx;
        maxLoopsPerTx = _maxLoops;
        emit MaxLoopsUpdated(old, _maxLoops);
    }
}
