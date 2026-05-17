// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/governance/TimelockController.sol";

/**
 * @title Timelock
 * @notice TimelockController wrapping all privileged DAO actions behind a 2-day delay.
 * @dev Acts as the ultimate owner of the game economy contracts.
 *      All governance proposals must go through the timelock queue.
 *
 * Design Pattern: Timelock — enforces a mandatory delay on governance actions
 *                 to give token holders time to react.
 */
contract Timelock is TimelockController {
    /**
     * @param minDelay  Minimum delay in seconds before execution (2 days = 172800).
     * @param proposers Array of addresses allowed to schedule operations (Governor).
     * @param executors Array of addresses allowed to execute operations (anyone = address(0)).
     * @param admin     Optional admin; set to address(0) to renounce immediately.
     */
    constructor(uint256 minDelay, address[] memory proposers, address[] memory executors, address admin)
        TimelockController(minDelay, proposers, executors, admin)
    {}
}
