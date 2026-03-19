// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {LoyaltyHook} from "../src/LoyaltyHook.sol";
import {LoyaltyToken} from "../src/LoyaltyToken.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";

contract DeployUnichain is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("UNICHAIN_PRIVATE_KEY");
        address poolManager = vm.envAddress("POOL_MANAGER");

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy LoyaltyHook with mined salt 12739
        LoyaltyHook hook = new LoyaltyHook{salt: bytes32(uint256(12739))}(IPoolManager(poolManager));

        // 2. Deploy LoyaltyToken
        LoyaltyToken token = new LoyaltyToken(address(hook));

        // 3. Link Token to Hook
        hook.setLoyaltyToken(address(token));

        vm.stopBroadcast();
        
        console.log("LoyaltyHook deployed to:", address(hook));
        console.log("LoyaltyToken deployed to:", address(token));
    }
}
import {console} from "forge-std/console.sol";
