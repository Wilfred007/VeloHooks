// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {LoyaltyHook} from "../src/LoyaltyHook.sol";

contract LinkEverything is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("UNICHAIN_PRIVATE_KEY");
        address hookAddress = 0xD8629CbfbEDd994CF68121fB8Cbb868Fa99CBFF0;
        address reactiveAddress = vm.envAddress("REACTIVE_CONTRACT_ADDRESS");

        vm.startBroadcast(deployerPrivateKey);
        LoyaltyHook(hookAddress).setReactiveNetwork(reactiveAddress);
        vm.stopBroadcast();
    }
}
