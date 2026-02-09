// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IUniswapV3Pool} from "v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {IUniswapV3FlashCallback} from "v3-core/contracts/interfaces/callback/IUniswapV3FlashCallback.sol";
import {IUniswapV3SwapCallback} from "v3-core/contracts/interfaces/callback/IUniswapV3SwapCallback.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

/**
 * @title UniswapFlashArbitrage
 * @notice Executes arbitrage opportunities using Uniswap V3 flash swaps
 * @dev Uses direct Uniswap V3 pool calls for optimal gas efficiency
 */
contract UniswapFlashArbitrage is IUniswapV3FlashCallback, IUniswapV3SwapCallback {
    address public immutable owner;
    uint256 public minProfitWei;
    uint256 private locked = 1;
    address private expectedPool;
    address private expectedFlashPool;

    struct SwapRoute {
        address pool;         // Uniswap V3 pool address
        bool zeroForOne;      // Swap direction (token0 -> token1)
        address tokenIn;
        address tokenOut;
    }

    struct FlashCallbackData {
        address token;        // Token borrowed (token0 or token1)
        uint256 amount;       // Amount borrowed
        SwapRoute[] routes;   // Arbitrage routes to execute
        address payer;        // Original caller (for profit distribution)
    }

    event ArbitrageExecuted(
        address indexed token,
        uint256 amountBorrowed,
        uint256 profit,
        uint256 gasUsed
    );

    event ProfitWithdrawn(address indexed token, uint256 amount);

    error Unauthorized();
    error ReentrancyGuard();
    error InvalidCallback();
    error InsufficientProfit(uint256 expected, uint256 actual);
    error InvalidRoute();
    error InvalidFlashPool();

    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    modifier nonReentrant() {
        if (locked != 1) revert ReentrancyGuard();
        locked = 2;
        _;
        locked = 1;
    }

    constructor(uint256 _minProfitWei) {
        owner = msg.sender;
        minProfitWei = _minProfitWei;
    }

    /**
     * @notice Execute arbitrage opportunity using Uniswap flash swap
     * @param flashPool Uniswap V3 pool to borrow from
     * @param borrowToken0 If true, borrow token0; if false, borrow token1
     * @param amountToBorrow Amount to borrow from the pool
     * @param routes Array of swap routes to execute
     */
    function executeArbitrage(
        address flashPool,
        bool borrowToken0,
        uint256 amountToBorrow,
        SwapRoute[] calldata routes
    ) external onlyOwner nonReentrant {
        uint256 gasStart = gasleft();

        IUniswapV3Pool pool = IUniswapV3Pool(flashPool);
        address token = borrowToken0 ? pool.token0() : pool.token1();

        // Encode callback data
        FlashCallbackData memory callbackData = FlashCallbackData({
            token: token,
            amount: amountToBorrow,
            routes: routes,
            payer: msg.sender
        });

        expectedFlashPool = flashPool;

        // Call flash on the pool
        if (borrowToken0) {
            pool.flash(address(this), amountToBorrow, 0, abi.encode(callbackData));
        } else {
            pool.flash(address(this), 0, amountToBorrow, abi.encode(callbackData));
        }

        expectedFlashPool = address(0);

        uint256 gasUsed = gasStart - gasleft();
        uint256 balance = IERC20(token).balanceOf(address(this));
        
        emit ArbitrageExecuted(token, amountToBorrow, balance, gasUsed);
    }

    /**
     * @notice Uniswap V3 flash callback
     * @param fee0 Flash fee for token0
     * @param fee1 Flash fee for token1
     * @param data Encoded FlashCallbackData
     */
    function uniswapV3FlashCallback(
        uint256 fee0,
        uint256 fee1,
        bytes calldata data
    ) external override {
        if (msg.sender != expectedFlashPool) revert InvalidFlashPool();

        FlashCallbackData memory decoded = abi.decode(data, (FlashCallbackData));
        IUniswapV3Pool flashPool = IUniswapV3Pool(msg.sender);

        uint256 currentBalance = decoded.amount;
        address currentToken = decoded.token;

        // Execute all swap routes
        for (uint256 i = 0; i < decoded.routes.length; i++) {
            SwapRoute memory route = decoded.routes[i];
            
            currentBalance = _executeSwap(
                route.pool,
                route.zeroForOne,
                route.tokenIn,
                currentBalance
            );
            
            currentToken = route.tokenOut;
        }

        // Verify we end up with the borrowed token
        if (currentToken != decoded.token) {
            revert InvalidRoute();
        }

        // Calculate total debt (borrowed amount + flash fee)
        uint256 flashFee = decoded.token == flashPool.token0() ? fee0 : fee1;
        uint256 totalDebt = decoded.amount + flashFee;

        // Check final balance
        uint256 finalBalance = IERC20(decoded.token).balanceOf(address(this));
        if (finalBalance < totalDebt + minProfitWei) {
            revert InsufficientProfit(totalDebt + minProfitWei, finalBalance);
        }

        // Transfer tokens back to pool (pool checks balance after callback)
        IERC20(decoded.token).transfer(msg.sender, totalDebt);
    }

    /**
     * @notice Execute a single swap on Uniswap V3 pool
     * @param pool Uniswap V3 pool address
     * @param zeroForOne Swap direction
     * @param tokenIn Input token
     * @param amountIn Amount to swap
     * @return amountOut Amount received
     */
    function _executeSwap(
        address pool,
        bool zeroForOne,
        address tokenIn,
        uint256 amountIn
    ) private returns (uint256 amountOut) {
        expectedPool = pool;

        uint160 sqrtPriceLimitX96 = zeroForOne 
            ? 4295128739  // MIN_SQRT_RATIO + 1
            : 1461446703485210103287273052203988822378723970342; // MAX_SQRT_RATIO - 1

        (int256 amount0, int256 amount1) = IUniswapV3Pool(pool).swap(
            address(this),
            zeroForOne,
            int256(amountIn),
            sqrtPriceLimitX96,
            abi.encode(tokenIn)
        );

        amountOut = uint256(-(zeroForOne ? amount1 : amount0));
        expectedPool = address(0);

        return amountOut;
    }

    /**
     * @notice Uniswap V3 swap callback
     * @param amount0Delta Amount of token0
     * @param amount1Delta Amount of token1
     */
    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata /* data */
    ) external override {
        if (msg.sender != expectedPool) revert InvalidCallback();
        IUniswapV3Pool pool = IUniswapV3Pool(msg.sender);

        // Pay the token corresponding to the positive delta
        if (amount0Delta > 0) {
            IERC20(pool.token0()).transfer(msg.sender, uint256(amount0Delta));
        } else if (amount1Delta > 0) {
            IERC20(pool.token1()).transfer(msg.sender, uint256(amount1Delta));
        }
    }

    /**
     * @notice Withdraw profits
     * @param token Token to withdraw
     */
    function withdrawProfits(address token) external onlyOwner {
        uint256 balance = IERC20(token).balanceOf(address(this));
        if (balance > 0) {
            IERC20(token).transfer(owner, balance);
            emit ProfitWithdrawn(token, balance);
        }
    }

    /**
     * @notice Update minimum profit threshold
     * @param newMinProfit New minimum profit in wei
     */
    function setMinProfit(uint256 newMinProfit) external onlyOwner {
        minProfitWei = newMinProfit;
    }

    /**
     * @notice Emergency token recovery
     * @param token Token to recover
     */
    function recoverToken(address token) external onlyOwner {
        uint256 balance = IERC20(token).balanceOf(address(this));
        if (balance > 0) {
            IERC20(token).transfer(owner, balance);
        }
    }
}
