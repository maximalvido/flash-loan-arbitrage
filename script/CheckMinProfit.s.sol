// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {FlashLoanArbitrage} from "../src/FlashLoanArbitrage.sol";

contract CheckMinProfit is Script {
    function run() public view {
        // Get contract address from environment or use default
        address contractAddress = vm.envOr("FLASH_LOAN_CONTRACT_ADDRESS", address(0));

        if (contractAddress == address(0)) {
            console.log("Error: FLASH_LOAN_CONTRACT_ADDRESS not set in .env");
            console.log("Usage: Set FLASH_LOAN_CONTRACT_ADDRESS=<address> in .env");
            return;
        }

        FlashLoanArbitrage arbitrageBot = FlashLoanArbitrage(contractAddress);

        console.log("=== FlashLoanArbitrage Contract Info ===");
        console.log("Contract Address:", contractAddress);
        console.log("Owner:", arbitrageBot.owner());
        console.log("Aave Pool:", address(arbitrageBot.AAVE_POOL()));
        console.log("Current minProfit (wei):", arbitrageBot.minProfitWei());
        console.log("Current minProfit (ETH):", arbitrageBot.minProfitWei() / 1e18);
    }
}
