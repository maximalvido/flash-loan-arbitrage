// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IUniswapV3Pool} from "v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {IUniswapV3FlashCallback} from "v3-core/contracts/interfaces/callback/IUniswapV3FlashCallback.sol";
import {IUniswapV3SwapCallback} from "v3-core/contracts/interfaces/callback/IUniswapV3SwapCallback.sol";
import {MockERC20} from "./MockERC20.sol";

contract MockUniswapFlashPool is IUniswapV3Pool {
    address public token0;
    address public token1;
    uint24 public fee = 3000; // 0.3%
    
    // Flash fee: 0.01% of borrowed amount
    uint256 public constant FLASH_FEE_BPS = 1; // 0.01% = 1 basis point
    
    constructor(address _token0, address _token1) {
        token0 = _token0;
        token1 = _token1;
    }
    
    function flash(
        address recipient,
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) external override {
        uint256 balance0Before = MockERC20(token0).balanceOf(address(this));
        uint256 balance1Before = MockERC20(token1).balanceOf(address(this));
        
        // Transfer tokens to recipient
        if (amount0 > 0) {
            MockERC20(token0).mint(recipient, amount0);
        }
        if (amount1 > 0) {
            MockERC20(token1).mint(recipient, amount1);
        }
        
        // Calculate fees
        uint256 fee0 = (amount0 * FLASH_FEE_BPS) / 10000;
        uint256 fee1 = (amount1 * FLASH_FEE_BPS) / 10000;
        
        // Call flash callback
        IUniswapV3FlashCallback(recipient).uniswapV3FlashCallback(fee0, fee1, data);
        
        // Check that tokens were repaid
        uint256 balance0After = MockERC20(token0).balanceOf(address(this));
        uint256 balance1After = MockERC20(token1).balanceOf(address(this));
        
        require(balance0After >= balance0Before + amount0 + fee0, "Insufficient token0 repayment");
        require(balance1After >= balance1Before + amount1 + fee1, "Insufficient token1 repayment");
    }
    
    function swap(
        address recipient,
        bool zeroForOne,
        int256 amountSpecified,
        uint160,
        bytes calldata data
    ) external override returns (int256 amount0, int256 amount1) {
        // Simple mock: simulate swap with 0.3% fee (Uniswap V3 standard)
        uint256 amountIn = uint256(amountSpecified);
        uint256 amountOut = amountIn * 997 / 1000; // 0.3% fee
        
        if (zeroForOne) {
            amount0 = int256(amountIn); // Positive (we pay token0)
            amount1 = -int256(amountOut); // Negative (we receive token1)
        } else {
            amount1 = int256(amountIn); // Positive (we pay token1)
            amount0 = -int256(amountOut); // Negative (we receive token0)
        }
        
        // Call callback to collect payment
        IUniswapV3SwapCallback(msg.sender).uniswapV3SwapCallback(amount0, amount1, data);
        
        // Transfer output tokens to recipient
        address outputToken = zeroForOne ? token1 : token0;
        MockERC20(outputToken).mint(recipient, amountOut);
    }
    
    // Minimal implementations for IUniswapV3Pool interface
    function slot0() external pure override returns (
        uint160 sqrtPriceX96,
        int24 tick,
        uint16 observationIndex,
        uint16 observationCardinality,
        uint16 observationCardinalityNext,
        uint8 feeProtocol,
        bool unlocked
    ) {
        return (0, 0, 0, 0, 0, 0, true);
    }
    
    function feeGrowthGlobal0X128() external pure override returns (uint256) { return 0; }
    function feeGrowthGlobal1X128() external pure override returns (uint256) { return 0; }
    function protocolFees() external pure override returns (uint128, uint128) { return (0, 0); }
    function liquidity() external pure override returns (uint128) { return 0; }
    function ticks(int24) external pure override returns (
        uint128 liquidityGross,
        int128 liquidityNet,
        uint256 feeGrowthOutside0X128,
        uint256 feeGrowthOutside1X128,
        int56 tickCumulativeOutside,
        uint160 secondsPerLiquidityOutsideX128,
        uint32 secondsOutside,
        bool initialized
    ) {
        return (0, 0, 0, 0, 0, 0, 0, false);
    }
    function tickBitmap(int16) external pure override returns (uint256) { return 0; }
    function positions(bytes32) external pure override returns (
        uint128 _liquidity,
        uint256 feeGrowthInside0LastX128,
        uint256 feeGrowthInside1LastX128,
        uint128 tokensOwed0,
        uint128 tokensOwed1
    ) {
        return (0, 0, 0, 0, 0);
    }
    function observations(uint256) external pure override returns (
        uint32 blockTimestamp,
        int56 tickCumulative,
        uint160 secondsPerLiquidityCumulativeX128,
        bool initialized
    ) {
        return (0, 0, 0, false);
    }
    function observe(uint32[] calldata) external pure override returns (
        int56[] memory tickCumulatives,
        uint160[] memory secondsPerLiquidityCumulativeX128s
    ) {
        return (new int56[](0), new uint160[](0));
    }
    function increaseObservationCardinalityNext(uint16) external pure override {}
    function tickSpacing() external pure override returns (int24) { return 60; }
    function snapshotCumulativesInside(int24, int24) external pure override returns (
        int56 tickCumulativeInside,
        uint160 secondsPerLiquidityInsideX128,
        uint32 secondsInside
    ) {
        return (0, 0, 0);
    }
    function setFeeProtocol(uint8, uint8) external pure override {}
    function collectProtocol(address, uint128, uint128) external pure override returns (uint128, uint128) {
        return (0, 0);
    }
    function factory() external pure override returns (address) { return address(0); }
    function initialize(uint160) external pure override {}
    function maxLiquidityPerTick() external pure override returns (uint128) { return 0; }
    function mint(address, int24, int24, uint128, bytes calldata) external pure override returns (uint256, uint256) {
        return (0, 0);
    }
    function collect(address, int24, int24, uint128, uint128) external pure override returns (uint128, uint128) {
        return (0, 0);
    }
    function burn(int24, int24, uint128) external pure override returns (uint256, uint256) {
        return (0, 0);
    }
}
