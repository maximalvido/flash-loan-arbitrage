// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IPool} from "@aave/core-v3/contracts/interfaces/IPool.sol";
import {IPoolAddressesProvider} from "@aave/core-v3/contracts/interfaces/IPoolAddressesProvider.sol";
import {IFlashLoanReceiver} from "@aave/core-v3/contracts/flashloan/interfaces/IFlashLoanReceiver.sol";
import {IUniswapV3Pool} from "v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {IUniswapV3SwapCallback} from "v3-core/contracts/interfaces/callback/IUniswapV3SwapCallback.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title FlashLoanArbitrage
 * @notice Executes arbitrage opportunities using Aave V3 flash loans
 * @dev Uses direct Uniswap V3 pool calls for optimal gas efficiency
 */
contract FlashLoanArbitrage is IFlashLoanReceiver, IUniswapV3SwapCallback {
    using SafeERC20 for IERC20;

    IPool public immutable AAVE_POOL;
    address public immutable OWNER;
    uint256 public minProfitWei;
    uint256 private locked = 1;
    address private expectedPool;

    struct SwapRoute {
        address pool; // Uniswap V3 pool address
        bool zeroForOne; // Swap direction (token0 -> token1)
        address tokenIn;
        address tokenOut;
    }

    event ArbitrageExecuted(address indexed token, uint256 amountBorrowed, uint256 profit, uint256 gasUsed);

    event ProfitWithdrawn(address indexed token, uint256 amount);

    error Unauthorized();
    error ReentrancyGuard();
    error InvalidCallback();
    error InsufficientProfit(uint256 expected, uint256 actual);
    error FlashLoanFailed();
    error InvalidRoute();

    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    modifier nonReentrant() {
        _nonReentrantBefore();
        _;
        _nonReentrantAfter();
    }

    constructor(address _aavePool, uint256 _minProfitWei) {
        AAVE_POOL = IPool(_aavePool);
        OWNER = msg.sender;
        minProfitWei = _minProfitWei;
    }

    function _checkOwner() internal view {
        if (msg.sender != OWNER) revert Unauthorized();
    }

    function _nonReentrantBefore() internal {
        if (locked != 1) revert ReentrancyGuard();
        locked = 2;
    }

    function _nonReentrantAfter() internal {
        locked = 1;
    }

    /**
     * @notice Execute arbitrage opportunity
     * @param token Token to borrow for arbitrage
     * @param amountToBorrow Amount to borrow from Aave
     * @param routes Array of swap routes to execute
     */
    function executeArbitrage(address token, uint256 amountToBorrow, SwapRoute[] calldata routes)
        external
        onlyOwner
        nonReentrant
    {
        uint256 gasStart = gasleft();

        // Prepare flash loan parameters
        address[] memory assets = new address[](1);
        assets[0] = token;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amountToBorrow;
        uint256[] memory interestRateModes = new uint256[](1);
        interestRateModes[0] = 0; // No debt

        // Encode routes for callback
        bytes memory params = abi.encode(routes);

        AAVE_POOL.flashLoan(address(this), assets, amounts, interestRateModes, address(this), params, 0);

        uint256 gasUsed = gasStart - gasleft();
        uint256 balance = IERC20(token).balanceOf(address(this));

        emit ArbitrageExecuted(token, amountToBorrow, balance, gasUsed);
    }

    /**
     * @notice Aave V3 flash loan callback
     * @param assets Borrowed assets
     * @param amounts Borrowed amounts
     * @param premiums Flash loan fees
     * @param initiator Initiator of the flash loan
     * @param params Encoded swap routes
     */
    function executeOperation(
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata premiums,
        address initiator,
        bytes calldata params
    ) external returns (bool) {
        if (msg.sender != address(AAVE_POOL)) revert Unauthorized();
        if (initiator != address(this)) revert Unauthorized();

        SwapRoute[] memory routes = abi.decode(params, (SwapRoute[]));

        uint256 currentBalance = amounts[0];
        address currentToken = assets[0];

        for (uint256 i = 0; i < routes.length; i++) {
            SwapRoute memory route = routes[i];

            currentBalance = _executeSwap(route.pool, route.zeroForOne, route.tokenIn, currentBalance);

            currentToken = route.tokenOut;
        }

        uint256 totalDebt = amounts[0] + premiums[0];

        if (currentToken != assets[0]) {
            revert InvalidRoute();
        }

        uint256 finalBalance = IERC20(assets[0]).balanceOf(address(this));
        if (finalBalance < totalDebt + minProfitWei) {
            revert InsufficientProfit(totalDebt + minProfitWei, finalBalance);
        }

        IERC20(assets[0]).forceApprove(address(AAVE_POOL), totalDebt);

        return true;
    }

    /**
     * @notice Execute a single swap on Uniswap V3 pool
     * @param pool Uniswap V3 pool address
     * @param zeroForOne Swap direction
     * @param tokenIn Input token
     * @param amountIn Amount to swap
     * @return amountOut Amount received
     */
    function _executeSwap(address pool, bool zeroForOne, address tokenIn, uint256 amountIn)
        private
        returns (uint256 amountOut)
    {
        expectedPool = pool;

        uint160 sqrtPriceLimitX96 = zeroForOne
            ? 4295128740  // MIN_SQRT_RATIO + 1
            : 1461446703485210103287273052203988822378723970341; // MAX_SQRT_RATIO - 1

        (int256 amount0, int256 amount1) = IUniswapV3Pool(pool).
            // forge-lint: disable-next-line(unsafe-typecast)
            swap(address(this), zeroForOne, int256(amountIn), sqrtPriceLimitX96, abi.encode(tokenIn));

        amountOut = uint256(-(zeroForOne ? amount1 : amount0));
        expectedPool = address(0);

        return amountOut;
    }

    /**
     * @notice Uniswap V3 swap callback
     * @param amount0Delta Amount of token0
     * @param amount1Delta Amount of token1
     *
     */
    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata /* data */
    )
        external
        override
    {
        if (msg.sender != expectedPool) revert InvalidCallback();
        IUniswapV3Pool pool = IUniswapV3Pool(msg.sender);

        // Pay the token corresponding to the positive delta
        if (amount0Delta > 0) {
            // forge-lint: disable-next-line(unsafe-typecast)
            IERC20(pool.token0()).safeTransfer(msg.sender, uint256(amount0Delta));
        } else if (amount1Delta > 0) {
            // forge-lint: disable-next-line(unsafe-typecast)
            IERC20(pool.token1()).safeTransfer(msg.sender, uint256(amount1Delta));
        }
    }

    /**
     * @notice Withdraw profits
     * @param token Token to withdraw
     */
    function withdrawProfits(address token) external onlyOwner {
        uint256 balance = IERC20(token).balanceOf(address(this));
        if (balance > 0) {
            IERC20(token).safeTransfer(OWNER, balance);
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
            IERC20(token).safeTransfer(OWNER, balance);
        }
    }

    /**
     * @notice Returns the Aave Pool addresses provider (required by IFlashLoanReceiver)
     * @return The addresses provider
     */
    function ADDRESSES_PROVIDER() external view returns (IPoolAddressesProvider) {
        return AAVE_POOL.ADDRESSES_PROVIDER();
    }

    /**
     * @notice Returns the Aave Pool (required by IFlashLoanReceiver)
     * @return The pool address
     */
    function POOL() external view returns (IPool) {
        return AAVE_POOL;
    }
}
