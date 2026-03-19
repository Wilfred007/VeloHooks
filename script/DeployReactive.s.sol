// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {ReactiveLoyalty} from "../src/ReactiveLoyalty.sol";
import {console} from "forge-std/console.sol";

contract DeployReactive is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("REACTIVE_PRIVATE_KEY");
        address hook = 0xD8629CbfbEDd994CF68121fB8Cbb868Fa99CBFF0;

        vm.startBroadcast(deployerPrivateKey);

        // Deploy ReactiveLoyalty
        ReactiveLoyalty reactive = new ReactiveLoyalty(hook);

        vm.stopBroadcast();

        console.log("ReactiveLoyalty deployed to:", address(reactive));
    }
}
