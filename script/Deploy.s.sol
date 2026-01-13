// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {FlashLoanArbitrage} from "../src/FlashLoanArbitrage.sol";

contract DeployFlashLoanArbitrage is Script {
    uint256 constant DEFAULT_MIN_PROFIT = 0.001 ether;

    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envOr("PRIVATE_KEY", uint256(0));
        if (deployerPrivateKey == 0) {
            console.log("Error: PRIVATE_KEY not set in .env");
            console.log("Usage: Set PRIVATE_KEY=<private_key> in .env");
            return;
        }

        address aavePool = vm.envOr("AAVE_POOL_ADDRESS", address(0));
        if (aavePool == address(0)) {
            console.log("Error: AAVE_POOL_ADDRESS not set in .env");
            console.log("Usage: Set AAVE_POOL_ADDRESS=<address> in .env");
            return;
        }

        uint256 minProfit = vm.envOr("MIN_PROFIT_WEI", DEFAULT_MIN_PROFIT);
        
        vm.startBroadcast(deployerPrivateKey);

        console.log("=== Deploying FlashLoanArbitrage ===");
        console.log("Aave Pool:", aavePool);
        console.log("Min Profit (wei):", minProfit);
        console.log("Min Profit (ETH):", minProfit / 1e18);
        
        FlashLoanArbitrage arbitrageBot = new FlashLoanArbitrage(
            aavePool,
            minProfit
        );

        console.log("\n=== Deployment Successful ===");
        console.log("Contract Address:", address(arbitrageBot));
        console.log("Owner:", arbitrageBot.owner());
        console.log("Aave Pool:", address(arbitrageBot.AAVE_POOL()));
        console.log("Min Profit:", arbitrageBot.minProfitWei());

        vm.stopBroadcast();
    }
}
