// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {MockERC20} from "./MockERC20.sol";
import {IFlashLoanReceiver} from "@aave/core-v3/contracts/flashloan/interfaces/IFlashLoanReceiver.sol";

contract MockAavePool {
    function flashLoan(
        address receiverAddress,
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata,
        address onBehalfOf,
        bytes calldata params,
        uint16
    ) external {
        // Transfer tokens to receiver
        for (uint256 i = 0; i < assets.length; i++) {
            MockERC20(assets[i]).mint(receiverAddress, amounts[i]);
        }

        // Call executeOperation
        IFlashLoanReceiver(receiverAddress)
            .executeOperation(
                assets,
                amounts,
                new uint256[](assets.length), // premiums
                onBehalfOf,
                params
            );

        // Collect repayment (0.09% fee)
        for (uint256 i = 0; i < assets.length; i++) {
            uint256 premium = amounts[i] * 9 / 10000; // 0.09% fee
            uint256 totalDebt = amounts[i] + premium;
            MockERC20(assets[i]).transferFrom(receiverAddress, address(this), totalDebt);
        }
    }
}
