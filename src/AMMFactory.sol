// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./AMM.sol";

/**
 * @title AMMFactory
 * @notice Factory contract for deploying AMM pools using both CREATE and CREATE2.
 * @dev Demonstrates the Factory pattern with deterministic deployment.
 *
 * Design Patterns:
 *   - Factory pattern: deploys new AMM instances
 *   - CREATE: standard deployment
 *   - CREATE2: deterministic deployment (address can be pre-computed)
 *   - Access Control: only owner can deploy new pools
 */
contract AMMFactory {
    address public owner;
    address[] public allPools;

    mapping(address => mapping(address => address)) public getPool;

    event PoolCreated(address indexed tokenA, address indexed tokenB, address pool, uint256 poolIndex);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    /**
     * @notice Deploy a new AMM pool using standard CREATE opcode.
     * @param tokenA First token in the pair.
     * @param tokenB Second token in the pair.
     * @return pool Address of the newly deployed AMM.
     */
    function createPool(address tokenA, address tokenB) external onlyOwner returns (address pool) {
        require(tokenA != tokenB, "Identical tokens");
        require(getPool[tokenA][tokenB] == address(0), "Pool exists");

        AMM newPool = new AMM(tokenA, tokenB);
        pool = address(newPool);

        getPool[tokenA][tokenB] = pool;
        getPool[tokenB][tokenA] = pool;
        allPools.push(pool);

        emit PoolCreated(tokenA, tokenB, pool, allPools.length - 1);
    }

    /**
     * @notice Deploy a new AMM pool using CREATE2 for deterministic addressing.
     * @param tokenA First token in the pair.
     * @param tokenB Second token in the pair.
     * @param salt   Salt for CREATE2 deterministic deployment.
     * @return pool Address of the newly deployed AMM.
     */
    function createPoolDeterministic(address tokenA, address tokenB, bytes32 salt)
        external
        onlyOwner
        returns (address pool)
    {
        require(tokenA != tokenB, "Identical tokens");
        require(getPool[tokenA][tokenB] == address(0), "Pool exists");

        bytes memory bytecode = abi.encodePacked(type(AMM).creationCode, abi.encode(tokenA, tokenB));

        assembly {
            pool := create2(0, add(bytecode, 0x20), mload(bytecode), salt)
            if iszero(extcodesize(pool)) { revert(0, 0) }
        }

        getPool[tokenA][tokenB] = pool;
        getPool[tokenB][tokenA] = pool;
        allPools.push(pool);

        emit PoolCreated(tokenA, tokenB, pool, allPools.length - 1);
    }

    /**
     * @notice Pre-compute the address of a CREATE2-deployed pool.
     * @param tokenA First token.
     * @param tokenB Second token.
     * @param salt   Salt used for CREATE2.
     * @return predicted The predicted address.
     */
    function computePoolAddress(address tokenA, address tokenB, bytes32 salt)
        external
        view
        returns (address predicted)
    {
        bytes memory bytecode = abi.encodePacked(type(AMM).creationCode, abi.encode(tokenA, tokenB));
        bytes32 hash = keccak256(abi.encodePacked(bytes1(0xff), address(this), salt, keccak256(bytecode)));
        predicted = address(uint160(uint256(hash)));
    }

    /// @notice Total number of deployed pools.
    function allPoolsLength() external view returns (uint256) {
        return allPools.length;
    }
}
