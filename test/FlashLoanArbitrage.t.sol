// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/FlashLoanArbitrage.sol";
import {IPool} from "@aave/core-v3/contracts/interfaces/IPool.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IUniswapV3Pool} from "v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {MockAavePool} from "./mocks/MockAavePool.sol";
import {MockUniswapPool} from "./mocks/MockUniswapPool.sol";
import {IFlashLoanReceiver} from "@aave/core-v3/contracts/flashloan/interfaces/IFlashLoanReceiver.sol";
import {ReentrantMockAavePool} from "./mocks/ReentrantMockAavePool.sol";

contract FlashLoanArbitrageTest is Test {
    FlashLoanArbitrage public arbitrageBot;
    address public owner;
    address public user;

    // Mock addresses
    address public mockAavePool;
    address public mockToken;
    address public mockPool;

    uint256 public constant MIN_PROFIT = 0.001 ether;

    event ArbitrageExecuted(address indexed token, uint256 amountBorrowed, uint256 profit, uint256 gasUsed);

    event ProfitWithdrawn(address indexed token, uint256 amount);

    function setUp() public {
        owner = address(this);
        user = address(0x123);

        mockAavePool = address(new MockAavePool());
        address token0 = address(new MockERC20("Token0", "T0"));
        address token1 = address(new MockERC20("Token1", "T1"));
        mockToken = token0;
        mockPool = address(new MockUniswapPool(token0, token1));

        arbitrageBot = new FlashLoanArbitrage(mockAavePool, MIN_PROFIT);
    }

    function test_Deployment() public {
        assertEq(address(arbitrageBot.AAVE_POOL()), mockAavePool);
        assertEq(arbitrageBot.owner(), owner);
        assertEq(arbitrageBot.minProfitWei(), MIN_PROFIT);
    }

    /**
     * Test access control for executeArbitrage
     */
    function test_OnlyOwnerCanExecuteArbitrage() public {
        FlashLoanArbitrage.SwapRoute[] memory routes = new FlashLoanArbitrage.SwapRoute[](0);

        vm.prank(user);
        vm.expectRevert(FlashLoanArbitrage.Unauthorized.selector);
        arbitrageBot.executeArbitrage(mockToken, 1000, routes);
    }

    function test_OnlyOwnerCanSetMinProfit() public {
        vm.prank(user);
        vm.expectRevert(FlashLoanArbitrage.Unauthorized.selector);
        arbitrageBot.setMinProfit(100);
    }

    function test_OnlyOwnerCanWithdrawProfits() public {
        vm.prank(user);
        vm.expectRevert(FlashLoanArbitrage.Unauthorized.selector);
        arbitrageBot.withdrawProfits(mockToken);
    }

    function test_OnlyOwnerCanRecoverToken() public {
        vm.prank(user);
        vm.expectRevert(FlashLoanArbitrage.Unauthorized.selector);
        arbitrageBot.recoverToken(mockToken);
    }

    function test_OwnerCanSetMinProfit() public {
        uint256 newMinProfit = 0.002 ether;
        arbitrageBot.setMinProfit(newMinProfit);
        assertEq(arbitrageBot.minProfitWei(), newMinProfit);
    }

    function test_ReentrancyProtection_ExecuteArbitrage() public {
        ReentrantMockAavePool reentrantPool = new ReentrantMockAavePool();

        vm.prank(address(reentrantPool));
        FlashLoanArbitrage reentrantBot = new FlashLoanArbitrage(address(reentrantPool), 0);

        reentrantPool.setTarget(reentrantBot);

        MockERC20(mockToken).mint(address(reentrantBot), 2000);

        FlashLoanArbitrage.SwapRoute[] memory routes = new FlashLoanArbitrage.SwapRoute[](0);

        vm.prank(address(reentrantPool));
        vm.expectRevert(FlashLoanArbitrage.ReentrancyGuard.selector);
        reentrantBot.executeArbitrage(mockToken, 1000, routes);
    }

    function test_WithdrawProfits() public {
        MockERC20(mockToken).mint(address(arbitrageBot), 1000);

        uint256 ownerBalanceBefore = MockERC20(mockToken).balanceOf(owner);

        vm.expectEmit(true, false, false, true);
        emit ProfitWithdrawn(mockToken, 1000);

        arbitrageBot.withdrawProfits(mockToken);

        assertEq(MockERC20(mockToken).balanceOf(owner), ownerBalanceBefore + 1000);
        assertEq(MockERC20(mockToken).balanceOf(address(arbitrageBot)), 0);
    }

    function test_WithdrawProfits_ZeroBalance() public {
        arbitrageBot.withdrawProfits(mockToken);
        assertEq(MockERC20(mockToken).balanceOf(owner), 0);
    }

    function test_RecoverToken() public {
        MockERC20(mockToken).mint(address(arbitrageBot), 500);

        uint256 ownerBalanceBefore = MockERC20(mockToken).balanceOf(owner);

        arbitrageBot.recoverToken(mockToken);

        assertEq(MockERC20(mockToken).balanceOf(owner), ownerBalanceBefore + 500);
        assertEq(MockERC20(mockToken).balanceOf(address(arbitrageBot)), 0);
    }

    function test_RecoverToken_ZeroBalance() public {
        arbitrageBot.recoverToken(mockToken);
    }

    function test_POOL() public {
        IPool pool = arbitrageBot.POOL();
        assertEq(address(pool), address(mockAavePool));
    }

    function test_ExecuteArbitrage_InvalidRoute() public {
        address token0 = MockUniswapPool(mockPool).token0();

        FlashLoanArbitrage.SwapRoute[] memory routes = new FlashLoanArbitrage.SwapRoute[](1);
        routes[0] = FlashLoanArbitrage.SwapRoute({
            pool: mockPool,
            zeroForOne: true,
            tokenIn: token0,
            tokenOut: address(0x999) // Different from token0 (borrowed token), will cause InvalidRoute
        });

        vm.expectRevert(FlashLoanArbitrage.InvalidRoute.selector);
        arbitrageBot.executeArbitrage(token0, 1000, routes);
    }

    function test_Callback_InvalidPool() public {
        vm.prank(address(0xBAD)); // Wrong pool address, will cause InvalidCallback
        vm.expectRevert(FlashLoanArbitrage.InvalidCallback.selector);
        arbitrageBot.uniswapV3SwapCallback(1000, 0, "");
    }
}
