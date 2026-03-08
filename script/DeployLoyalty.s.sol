// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {LoyaltyHook} from "../src/LoyaltyHook.sol";
import {LoyaltyToken} from "../src/LoyaltyToken.sol";
import {ReactiveLoyalty} from "../src/ReactiveLoyalty.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";

contract DeployLoyalty is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address poolManager = vm.envAddress("POOL_MANAGER");

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy LoyaltyHook (Note: v4 hooks need special address prefixes,
        // this script alone doesn't guarantee the prefix.
        // Use hook-mining tools for production.)
        LoyaltyHook hook = new LoyaltyHook(IPoolManager(poolManager));

        // 2. Deploy LoyaltyToken
        LoyaltyToken token = new LoyaltyToken(address(hook));

        // 3. Deploy ReactiveLoyalty
        ReactiveLoyalty reactive = new ReactiveLoyalty(address(hook));

        // 4. Link everything
        hook.setLoyaltyToken(address(token));
        hook.setReactiveNetwork(address(reactive));

        vm.stopBroadcast();
    }
}
