// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {FlashLoanArbitrage} from "../src/FlashLoanArbitrage.sol";

contract UpdateMinProfit is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address contractAddress = vm.envAddress("FLASH_LOAN_CONTRACT_ADDRESS");
        
        // Get new min profit from env or use 1 wei as default
        uint256 newMinProfit = vm.envOr("NEW_MIN_PROFIT_WEI", uint256(1));

        vm.startBroadcast(deployerPrivateKey);

        FlashLoanArbitrage arbitrageBot = FlashLoanArbitrage(contractAddress);
        
        console.log("=== Updating Min Profit ===");
        console.log("Contract:", contractAddress);
        console.log("Current minProfit (wei):", arbitrageBot.minProfitWei());
        console.log("Current minProfit (ETH):", arbitrageBot.minProfitWei() / 1e18);
        console.log("New minProfit (wei):", newMinProfit);
        console.log("New minProfit (ETH):", newMinProfit / 1e18);
        
        arbitrageBot.setMinProfit(newMinProfit);
        
        console.log("\n=== Update Successful ===");
        console.log("Updated minProfit (wei):", arbitrageBot.minProfitWei());
        console.log("Updated minProfit (ETH):", arbitrageBot.minProfitWei() / 1e18);

        vm.stopBroadcast();
    }
}
