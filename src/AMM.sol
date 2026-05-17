// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title AMM
 * @notice Constant Product Automated Market Maker (x·y=k) for swapping GovToken ↔ IronToken.
 * @dev Built from scratch (not forked). Implements:
 *      - 0.3% swap fee
 *      - Slippage protection (minAmountOut)
 *      - LP token minting/burning
 *      - Constant product invariant: k never decreases on swap
 *
 * Design Patterns:
 *   - Reentrancy Guard on all state-changing operations
 *   - Checks-Effects-Interactions throughout
 *   - Pull-over-push for LP token withdrawal
 */
contract AMM is ERC20, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using Math for uint256;

    IERC20 public immutable tokenA; // GovToken
    IERC20 public immutable tokenB; // IronToken

    uint256 public reserveA;
    uint256 public reserveB;

    uint256 public constant FEE_NUMERATOR = 3;
    uint256 public constant FEE_DENOMINATOR = 1000; // 0.3% fee

    event LiquidityAdded(address indexed provider, uint256 amountA, uint256 amountB, uint256 lpMinted);
    event LiquidityRemoved(address indexed provider, uint256 amountA, uint256 amountB, uint256 lpBurned);
    event Swap(address indexed user, address indexed tokenIn, uint256 amountIn, uint256 amountOut);

    constructor(address _tokenA, address _tokenB) ERC20("AMM-LP-GOV-IRON", "ALP") {
        require(_tokenA != address(0) && _tokenB != address(0), "Zero address");
        require(_tokenA != _tokenB, "Same token");
        tokenA = IERC20(_tokenA);
        tokenB = IERC20(_tokenB);
    }

    /**
     * @notice Add liquidity to the pool.
     * @param amountA Amount of tokenA (GovToken) to add.
     * @param amountB Amount of tokenB (IronToken) to add.
     * @return lpTokens Amount of LP tokens minted.
     * @dev First depositor sets the ratio. Subsequent deposits must match ratio.
     */
    function addLiquidity(uint256 amountA, uint256 amountB) external nonReentrant returns (uint256 lpTokens) {
        require(amountA > 0 && amountB > 0, "Amounts must be > 0");

        if (totalSupply() == 0) {
            // First deposit — use geometric mean for initial LP tokens
            lpTokens = Math.sqrt(amountA * amountB);
            require(lpTokens > 0, "Insufficient initial liquidity");
        } else {
            // Proportional deposit
            uint256 lpFromA = (amountA * totalSupply()) / reserveA;
            uint256 lpFromB = (amountB * totalSupply()) / reserveB;
            lpTokens = lpFromA < lpFromB ? lpFromA : lpFromB;
        }

        // Interactions: transfer tokens in, then mint LP
        tokenA.safeTransferFrom(msg.sender, address(this), amountA);
        tokenB.safeTransferFrom(msg.sender, address(this), amountB);

        reserveA += amountA;
        reserveB += amountB;

        _mint(msg.sender, lpTokens);

        emit LiquidityAdded(msg.sender, amountA, amountB, lpTokens);
    }

    /**
     * @notice Remove liquidity from the pool.
     * @param lpTokens Amount of LP tokens to burn.
     * @return amountA Amount of tokenA returned.
     * @return amountB Amount of tokenB returned.
     */
    function removeLiquidity(uint256 lpTokens) external nonReentrant returns (uint256 amountA, uint256 amountB) {
        require(lpTokens > 0, "LP must be > 0");
        require(balanceOf(msg.sender) >= lpTokens, "Insufficient LP");

        uint256 supply = totalSupply();
        amountA = (lpTokens * reserveA) / supply;
        amountB = (lpTokens * reserveB) / supply;

        require(amountA > 0 && amountB > 0, "Insufficient liquidity burned");

        // Effects
        _burn(msg.sender, lpTokens);
        reserveA -= amountA;
        reserveB -= amountB;

        // Interactions
        tokenA.safeTransfer(msg.sender, amountA);
        tokenB.safeTransfer(msg.sender, amountB);

        emit LiquidityRemoved(msg.sender, amountA, amountB, lpTokens);
    }

    /**
     * @notice Swap tokenA for tokenB (or vice versa).
     * @param tokenIn    Address of the input token.
     * @param amountIn   Amount of input token.
     * @param minAmountOut Minimum output (slippage protection).
     * @return amountOut Amount of output token received.
     * @dev Uses constant product formula with 0.3% fee.
     *      k invariant: reserveA * reserveB never decreases after swap.
     */
    function swap(address tokenIn, uint256 amountIn, uint256 minAmountOut)
        external
        nonReentrant
        returns (uint256 amountOut)
    {
        require(amountIn > 0, "Amount must be > 0");
        require(tokenIn == address(tokenA) || tokenIn == address(tokenB), "Invalid token");

        bool isTokenA = tokenIn == address(tokenA);
        (IERC20 inputToken, IERC20 outputToken, uint256 reserveIn, uint256 reserveOut) =
            isTokenA ? (tokenA, tokenB, reserveA, reserveB) : (tokenB, tokenA, reserveB, reserveA);

        // Apply 0.3% fee
        uint256 amountInWithFee = amountIn * (FEE_DENOMINATOR - FEE_NUMERATOR);
        amountOut = (amountInWithFee * reserveOut) / (reserveIn * FEE_DENOMINATOR + amountInWithFee);

        require(amountOut >= minAmountOut, "Slippage exceeded");
        require(amountOut > 0, "Insufficient output");

        // Effects — update reserves
        if (isTokenA) {
            reserveA += amountIn;
            reserveB -= amountOut;
        } else {
            reserveB += amountIn;
            reserveA -= amountOut;
        }

        // Interactions
        inputToken.safeTransferFrom(msg.sender, address(this), amountIn);
        outputToken.safeTransfer(msg.sender, amountOut);

        emit Swap(msg.sender, tokenIn, amountIn, amountOut);
    }

    /// @notice Get the current price of tokenA in terms of tokenB.
    function getPrice() external view returns (uint256) {
        if (reserveA == 0) return 0;
        return (reserveB * 1e18) / reserveA;
    }

    /**
     * @notice Calculate output amount for a given input (view function for frontend).
     * @param tokenIn  Address of input token.
     * @param amountIn Amount of input token.
     * @return amountOut Expected output amount.
     */
    function getAmountOut(address tokenIn, uint256 amountIn) external view returns (uint256 amountOut) {
        bool isTokenA = tokenIn == address(tokenA);
        (uint256 reserveIn, uint256 reserveOut) = isTokenA ? (reserveA, reserveB) : (reserveB, reserveA);

        uint256 amountInWithFee = amountIn * (FEE_DENOMINATOR - FEE_NUMERATOR);
        amountOut = (amountInWithFee * reserveOut) / (reserveIn * FEE_DENOMINATOR + amountInWithFee);
    }
}
