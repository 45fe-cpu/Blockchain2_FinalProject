// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title MockV3Aggregator
 * @notice Mock Chainlink AggregatorV3Interface for testing oracle integrations.
 * @dev Simulates latestRoundData() with configurable price, decimals, and timestamp.
 */
contract MockV3Aggregator {
    uint8 public decimals;
    int256 public latestAnswer;
    uint256 public latestTimestamp;
    uint80 public latestRound;

    mapping(uint80 => int256) public answers;
    mapping(uint80 => uint256) public timestamps;

    constructor(uint8 _decimals, int256 _initialAnswer) {
        decimals = _decimals;
        latestAnswer = _initialAnswer;
        latestTimestamp = block.timestamp;
        latestRound = 1;
        answers[1] = _initialAnswer;
        timestamps[1] = block.timestamp;
    }

    function updateAnswer(int256 _answer) external {
        latestRound++;
        latestAnswer = _answer;
        latestTimestamp = block.timestamp;
        answers[latestRound] = _answer;
        timestamps[latestRound] = block.timestamp;
    }

    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        return (latestRound, latestAnswer, latestTimestamp, latestTimestamp, latestRound);
    }

    function getRoundData(uint80 _roundId)
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        return (_roundId, answers[_roundId], timestamps[_roundId], timestamps[_roundId], _roundId);
    }
}
