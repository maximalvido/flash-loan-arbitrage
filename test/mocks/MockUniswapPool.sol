// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IUniswapV3SwapCallback} from "v3-core/contracts/interfaces/callback/IUniswapV3SwapCallback.sol";
import {MockERC20} from "./MockERC20.sol";

contract MockUniswapPool {
    address public token0;
    address public token1;
    
    constructor(address _token0, address _token1) {
        token0 = _token0;
        token1 = _token1;
    }
    
    function swap(
        address recipient,
        bool zeroForOne,
        int256 amountSpecified,
        uint160,
        bytes calldata data
    ) external returns (int256 amount0, int256 amount1) {
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
}
