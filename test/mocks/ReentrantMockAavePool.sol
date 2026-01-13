// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {FlashLoanArbitrage} from "../../src/FlashLoanArbitrage.sol";
import {MockERC20} from "./MockERC20.sol";
import {IFlashLoanReceiver} from "@aave/core-v3/contracts/flashloan/interfaces/IFlashLoanReceiver.sol";

contract ReentrantMockAavePool {
    FlashLoanArbitrage public target;
    
    function setTarget(FlashLoanArbitrage _target) external {
        target = _target;
    }
    
    function flashLoan(
        address receiverAddress,
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata,
        address onBehalfOf,
        bytes calldata params,
        uint16
    ) external {
        MockERC20(assets[0]).mint(receiverAddress, amounts[0]);
        
        IFlashLoanReceiver(receiverAddress).executeOperation(
            assets,
            amounts,
            new uint256[](1),
            onBehalfOf,
            params
        );
        
        FlashLoanArbitrage.SwapRoute[] memory emptyRoutes = new FlashLoanArbitrage.SwapRoute[](0);
        target.executeArbitrage(assets[0], amounts[0], emptyRoutes);
        
        MockERC20(assets[0]).transferFrom(
            receiverAddress, 
            address(this), 
            amounts[0] + (amounts[0] * 9 / 10000)
        );
    }
}
